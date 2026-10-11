import '../entities/user.dart';

abstract class AuthRepository {
  /// The signed-in user from the saved session, without a network round trip.
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

  /// The latest profile from the server, or null when it can't be fetched.
  Future<User?> refreshProfile();

  /// Signs out on the server (best effort) and forgets the session here.
  Future<void> logout();

  /// Forgets the session locally only (the server already ended it).
  Future<void> clearSession();
}
