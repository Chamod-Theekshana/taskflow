import 'package:flutter/foundation.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/storage/token_store.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';

/// Accounts live on the server; the device keeps the tokens (secure
/// storage) and a copy of the profile (to start offline).
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required AuthLocalDataSource local,
    required TokenStore tokens,
    required String installationId,
    required Future<String> Function() timeZone,
  }) : _remote = remote,
       _local = local,
       _tokens = tokens,
       _installationId = installationId,
       _timeZone = timeZone;

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;
  final TokenStore _tokens;
  final String _installationId;
  final Future<String> Function() _timeZone;

  @override
  Future<User?> getCurrentUser() async {
    final session = await _tokens.read();
    if (session == null) {
      await _local.clear();
      return null;
    }
    final cached = _local.cachedUser();
    if (cached != null) return cached;

    // Tokens without a cached profile (shouldn't happen): ask the server.
    try {
      final user = await _remote.me();
      await _local.cacheUser(user);
      return user;
    } on Failure catch (error) {
      debugPrint('Could not load the profile: $error');
      return null;
    }
  }

  @override
  Future<User> login(
    String email,
    String password, {
    bool rememberSession = true,
  }) async {
    final session = await _remote.login(email.trim(), password);
    await _tokens.save(session.tokens, persist: rememberSession);
    await _local.cacheUser(session.user);
    return session.user;
  }

  @override
  Future<User> signup({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final session = await _remote.register(
      fullName: fullName.trim(),
      email: email.trim(),
      password: password,
      timezone: await _timeZone(),
    );
    await _tokens.save(session.tokens, persist: true);
    await _local.cacheUser(session.user);
    return session.user;
  }

  @override
  Future<User> updateFullName(String userId, String fullName) async {
    final name = fullName.trim();
    if (name.isEmpty) throw const AuthFailure('Name cannot be empty');
    final user = await _remote.updateFullName(name);
    await _local.cacheUser(user);
    return user;
  }

  @override
  Future<User?> refreshProfile() async {
    try {
      final user = await _remote.me();
      await _local.cacheUser(user);
      return user;
    } on Failure {
      return null;
    }
  }

  @override
  Future<void> logout() async {
    final refreshToken = await _tokens.refreshToken();
    if (refreshToken != null) {
      try {
        await _remote
            .logout(refreshToken, _installationId)
            .timeout(const Duration(seconds: 5));
      } catch (error) {
        // Offline: the refresh token simply expires on its own.
        debugPrint('Server sign-out skipped: $error');
      }
    }
    await clearSession();
  }

  @override
  Future<void> clearSession() async {
    await _tokens.clear();
    await _local.clear();
  }
}
