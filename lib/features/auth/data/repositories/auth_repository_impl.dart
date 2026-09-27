import 'package:shared_preferences/shared_preferences.dart';
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
    return _dataSource.getUser(id);
  }

  @override
  Future<User> login(String email, String password) async {
    final valid = await _dataSource.verifyPassword(email, password);
    if (!valid) throw Exception('Invalid email or password');
    final user = await _dataSource.getUserByEmail(email);
    if (user == null) throw Exception('User not found');
    await _prefs.setString(_sessionKey, user.id);
    return user;
  }

  @override
  Future<User> signup({required String fullName, required String email, required String password}) async {
    final existing = await _dataSource.getUserByEmail(email);
    if (existing != null) throw Exception('Email already in use');
    final user = UserModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fullName: fullName,
      email: email,
    );
    final saved = await _dataSource.saveUser(user, password);
    await _prefs.setString(_sessionKey, saved.id);
    return saved;
  }

  @override
  Future<void> logout() async {
    await _prefs.remove(_sessionKey);
  }
}
