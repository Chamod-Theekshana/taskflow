import '../../../../core/network/api_client.dart';
import '../../../../core/storage/token_store.dart';
import '../models/user_model.dart';

typedef Session = ({UserModel user, AuthTokens tokens});

/// The auth and account endpoints of the API.
abstract class AuthRemoteDataSource {
  Future<Session> register({
    required String fullName,
    required String email,
    required String password,
    required String timezone,
  });
  Future<Session> login(String email, String password);
  Future<UserModel> me();
  Future<UserModel> updateFullName(String fullName);

  /// Ends the session on the server and stops pushes to this device.
  Future<void> logout(String refreshToken, String installationId);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl(this._api);

  final ApiClient _api;

  Session _session(Map<String, dynamic> body) {
    final data = body['data'] as Map<String, dynamic>;
    return (
      user: UserModel.fromJson(data['user'] as Map<String, dynamic>),
      tokens: AuthTokens.fromJson(data['tokens'] as Map<String, dynamic>),
    );
  }

  @override
  Future<Session> register({
    required String fullName,
    required String email,
    required String password,
    required String timezone,
  }) async {
    final body = await _api.post(
      '/auth/register',
      authenticated: false,
      body: {
        'fullName': fullName,
        'email': email,
        'password': password,
        'timezone': timezone,
      },
    );
    return _session(body);
  }

  @override
  Future<Session> login(String email, String password) async {
    final body = await _api.post(
      '/auth/login',
      authenticated: false,
      body: {'email': email, 'password': password},
    );
    return _session(body);
  }

  @override
  Future<UserModel> me() async {
    final body = await _api.get('/users/me');
    return UserModel.fromJson(body['data'] as Map<String, dynamic>);
  }

  @override
  Future<UserModel> updateFullName(String fullName) async {
    final body = await _api.patch('/users/me', body: {'fullName': fullName});
    return UserModel.fromJson(body['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> logout(String refreshToken, String installationId) async {
    try {
      await _api.delete('/devices/$installationId');
    } catch (_) {
      // Not registered, or offline: nothing to undo.
    }
    await _api.post(
      '/auth/logout',
      authenticated: false,
      body: {'refreshToken': refreshToken},
    );
  }
}
