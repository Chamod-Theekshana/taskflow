import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants.dart';
import '../error/failures.dart';
import '../storage/token_store.dart';

/// HTTP access to the TaskFlow API.
///
/// * Adds the access token and the `X-Device-Id` header to every request.
/// * When the access token has expired it refreshes it once (even if many
///   requests fail at the same time) and retries.
/// * If the session can't be refreshed it calls [onSessionExpired], which
///   signs the user out.
/// * Turns failures into [Failure]s with messages that can be shown as is.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required this.tokens,
    required this.installationId,
    required this.onSessionExpired,
    Dio? dio,
  }) : _dio = dio ?? Dio(_options(baseUrl)),
       _plain = Dio(_options(baseUrl)) {
    _dio.interceptors.add(
      _AuthInterceptor(
        tokens: tokens,
        installationId: installationId,
        refresh: _refreshSession,
        retry: _plain.fetch,
      ),
    );
  }

  final TokenStore tokens;
  final String installationId;
  final Future<void> Function() onSessionExpired;
  final Dio _dio;

  /// Without interceptors: used for the refresh call and for retries, so a
  /// retry can never wait on the interceptor queue it was started from.
  final Dio _plain;

  Future<String?>? _refreshing;

  static BaseOptions _options(String baseUrl) => BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    sendTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 30),
    contentType: Headers.jsonContentType,
    responseType: ResponseType.json,
    headers: {'Accept': 'application/json', 'X-App-Version': kAppVersion},
  );

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) => _send(() => _dio.get<Object?>(path, queryParameters: query));

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) => _send(
    () => _dio.post<Object?>(
      path,
      data: body,
      options: Options(extra: {'auth': authenticated}),
    ),
  );

  Future<Map<String, dynamic>> patch(String path, {Object? body}) =>
      _send(() => _dio.patch<Object?>(path, data: body));

  Future<Map<String, dynamic>> put(String path, {Object? body}) =>
      _send(() => _dio.put<Object?>(path, data: body));

  Future<Map<String, dynamic>> delete(String path, {Object? body}) =>
      _send(() => _dio.delete<Object?>(path, data: body));

  /// Runs the request and returns the JSON body (`{}` for 204 responses).
  Future<Map<String, dynamic>> _send(
    Future<Response<Object?>> Function() request,
  ) async {
    try {
      final response = await request();
      final data = response.data;
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } on DioException catch (error) {
      throw toFailure(error);
    }
  }

  /// Exchanges the refresh token for a new pair. Concurrent callers share
  /// one request. Returns the new access token, or null when the session is
  /// over.
  Future<String?> _refreshSession() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<String?> _doRefresh() async {
    final refreshToken = await tokens.refreshToken();
    if (refreshToken == null) return null;
    try {
      final response = await _plain.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(headers: {'X-Device-Id': installationId}),
      );
      final data = response.data?['data'] as Map<String, dynamic>?;
      final pair = data?['tokens'] as Map<String, dynamic>?;
      if (pair == null) return null;
      final fresh = AuthTokens.fromJson(pair);
      await tokens.save(fresh);
      return fresh.accessToken;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) {
        await tokens.clear();
        unawaited(onSessionExpired());
        return null;
      }
      // Offline or server trouble: keep the session, fail this request.
      rethrow;
    }
  }

  /// Maps a Dio error to a [Failure] the UI can show.
  static Failure toFailure(DioException error) {
    final inner = error.error;
    if (inner is Failure) return inner;

    final response = error.response;
    if (response == null) {
      return switch (error.type) {
        DioExceptionType.cancel => const Failure('The request was cancelled.'),
        DioExceptionType.badCertificate => const NetworkFailure(
          "The server's certificate is not trusted.",
        ),
        _ => const NetworkFailure(),
      };
    }

    final status = response.statusCode ?? 0;
    final body = response.data;
    var message = 'Something went wrong (HTTP $status). Please try again.';
    var code = 'http_$status';
    if (body is Map) {
      final errors = body['errors'];
      final detail = body['detail'];
      if (errors is List && errors.isNotEmpty && errors.first is Map) {
        message = '${(errors.first as Map)['message'] ?? detail}';
      } else if (detail is String && detail.isNotEmpty) {
        message = detail;
      }
      if (body['code'] is String) code = body['code'] as String;
    }
    if (status >= 500) {
      message = 'The server had a problem. Please try again in a moment.';
    }
    if (status == 401 && code.startsWith('refresh_token')) {
      return AuthFailure(message);
    }
    return ApiFailure(message, status: status, code: code);
  }
}

class _AuthInterceptor extends QueuedInterceptor {
  _AuthInterceptor({
    required this.tokens,
    required this.installationId,
    required this.refresh,
    required this.retry,
  });

  final TokenStore tokens;
  final String installationId;
  final Future<String?> Function() refresh;
  final Future<Response<dynamic>> Function(RequestOptions) retry;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.headers['X-Device-Id'] = installationId;
    if (options.extra['auth'] != false) {
      final token = await tokens.accessToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final options = error.requestOptions;
    final expired =
        error.response?.statusCode == 401 &&
        options.extra['auth'] != false &&
        options.extra['retried'] != true;
    if (!expired) {
      handler.next(error);
      return;
    }

    try {
      // Another request may already have refreshed while this one waited.
      final sent = options.headers['Authorization'];
      final current = await tokens.accessToken();
      final token = current != null && sent != 'Bearer $current'
          ? current
          : await refresh();
      if (token == null) {
        handler.next(error);
        return;
      }

      options.headers['Authorization'] = 'Bearer $token';
      options.extra['retried'] = true;
      handler.resolve(await retry(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    } catch (other) {
      debugPrint('Token refresh failed: $other');
      handler.next(error);
    }
  }
}
