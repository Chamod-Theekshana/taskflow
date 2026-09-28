import '../entities/user.dart';

abstract class AuthRepository {
  Future<User?> getCurrentUser();

  /// Signs in. When [rememberSession] is false the session is kept in memory
  /// only and the user has to sign in again after restarting the app.
  Future<User> login(
    String email,
    String password, {
    bool rememberSession = true,
  });

  Future<User> signup({
    required String fullName,
    required String email,
    required String password,
  });

  Future<User> updateFullName(String userId, String fullName);

  Future<void> logout();
}
