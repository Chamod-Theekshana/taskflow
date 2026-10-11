import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';

/// Keeps the signed-in user's profile on the device, so the app opens
/// straight into the task list even without a connection. The tokens
/// themselves live in secure storage (see `TokenStore`).
abstract class AuthLocalDataSource {
  UserModel? cachedUser();
  Future<void> cacheUser(UserModel user);
  Future<void> clear();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  AuthLocalDataSourceImpl(this._prefs);

  final SharedPreferences _prefs;

  static const _userKey = 'auth.user';

  /// Session key of the offline-only versions (local accounts).
  static const _legacySessionKey = 'current_user_id';

  @override
  UserModel? cachedUser() {
    final raw = _prefs.getString(_userKey);
    if (raw == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> cacheUser(UserModel user) async {
    await _prefs.setString(_userKey, jsonEncode(user.toJson()));
    await _prefs.remove(_legacySessionKey);
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(_userKey);
    await _prefs.remove(_legacySessionKey);
  }
}
