import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthLocalDataSource _dataSource;
  final SharedPreferences _prefs;

  static const _sessionKey = 'current_user_id';

  AuthRepositoryImpl(this._dataSource, this._prefs);

  @override
  Future<User?> getCurrentUser() async {
    final id = _prefs.getString(_sessionKey);
    if (id == null) return null;
    final user = await _dataSource.getUser(id);
    // The account behind a stored session no longer exists: forget it.
    if (user == null) await _prefs.remove(_sessionKey);
    return user;
  }

  @override
  Future<User> login(
    String email,
    String password, {
    bool rememberSession = true,
  }) async {
    final valid = await _dataSource.verifyPassword(email, password);
    if (!valid) throw const AuthFailure('Invalid email or password');
    final user = await _dataSource.getUserByEmail(email);
    if (user == null) throw const AuthFailure('Invalid email or password');

    if (rememberSession) {
      await _prefs.setString(_sessionKey, user.id);
    } else {
      await _prefs.remove(_sessionKey);
    }
    return user;
  }

  @override
  Future<User> signup({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final existing = await _dataSource.getUserByEmail(email);
    if (existing != null) {
      throw const AuthFailure('An account with this email already exists');
    }
    final user = UserModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      fullName: fullName,
      email: email,
    );
    final saved = await _dataSource.saveUser(user, password);
    await _prefs.setString(_sessionKey, saved.id);
    return saved;
  }

  @override
  Future<User> updateFullName(String userId, String fullName) async {
    final name = fullName.trim();
    if (name.isEmpty) throw const AuthFailure('Name cannot be empty');
    final updated = await _dataSource.updateFullName(userId, name);
    if (updated == null) throw const AuthFailure('Account not found');
    return updated;
  }

  @override
  Future<void> logout() async {
    await _prefs.remove(_sessionKey);
  }
}
