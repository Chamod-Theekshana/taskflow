import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class GetCurrentUserUseCase {
  final AuthRepository _repo;
  GetCurrentUserUseCase(this._repo);
  Future<User?> call() => _repo.getCurrentUser();
}

class LoginUseCase {
  final AuthRepository _repo;
  LoginUseCase(this._repo);
  Future<User> call(
    String email,
    String password, {
    bool rememberSession = true,
  }) => _repo.login(email, password, rememberSession: rememberSession);
}

class SignupUseCase {
  final AuthRepository _repo;
  SignupUseCase(this._repo);
  Future<User> call({
    required String fullName,
    required String email,
    required String password,
  }) => _repo.signup(fullName: fullName, email: email, password: password);
}

class UpdateProfileUseCase {
  final AuthRepository _repo;
  UpdateProfileUseCase(this._repo);
  Future<User> call(String userId, String fullName) =>
      _repo.updateFullName(userId, fullName);
}

class LogoutUseCase {
  final AuthRepository _repo;
  LogoutUseCase(this._repo);
  Future<void> call() => _repo.logout();
}
