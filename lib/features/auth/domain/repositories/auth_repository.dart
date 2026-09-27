import '../entities/user.dart';

abstract class AuthRepository {
  Future<User?> getCurrentUser();
  Future<User> login(String email, String password);
  Future<User> signup({required String fullName, required String email, required String password});
  Future<void> logout();
}
