import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/core/network/api_client.dart';

DioException _error({int? status, Object? data, DioExceptionType? type}) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: type ?? DioExceptionType.badResponse,
    response: status == null
        ? null
        : Response<Object?>(requestOptions: options, statusCode: status, data: data),
  );
}

void main() {
  test('problem details become readable failures', () {
    final failure = ApiClient.toFailure(
      _error(
        status: 409,
        data: {
          'detail': 'An account with this email already exists.',
          'code': 'email_taken',
        },
      ),
    );
    expect(failure, isA<ApiFailure>());
    expect(failure.message, 'An account with this email already exists.');
    expect((failure as ApiFailure).code, 'email_taken');
  });

  test('the first field error is shown for validation problems', () {
    final failure = ApiClient.toFailure(
      _error(
        status: 422,
        data: {
          'detail': 'The request body is invalid.',
          'errors': [
            {'path': 'password', 'message': 'Use 8+ characters.'},
          ],
        },
      ),
    );
    expect(failure.message, 'Use 8+ characters.');
  });

  test('no response means offline', () {
    final failure = ApiClient.toFailure(
      _error(type: DioExceptionType.connectionError),
    );
    expect(failure, isA<NetworkFailure>());
  });

  test('server errors get a generic message', () {
    final failure = ApiClient.toFailure(_error(status: 500, data: 'oops'));
    expect(failure.message, contains('server'));
  });
}
