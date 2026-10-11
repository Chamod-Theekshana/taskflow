import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthTokens {
  final String accessToken;
  final String refreshToken;

  const AuthTokens({required this.accessToken, required this.refreshToken});

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
  );
}

/// Where the session tokens live: the Keychain (iOS) / Keystore-backed
/// storage (Android), plus an in-memory copy for fast access.
///
/// With "Remember me" off the tokens are kept in memory only, so the user
/// signs in again after restarting the app.
class TokenStore {
  TokenStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _accessKey = 'auth.accessToken';
  static const _refreshKey = 'auth.refreshToken';

  AuthTokens? _tokens;
  bool _persist = true;
  bool _loaded = false;

  Future<AuthTokens?> read() async {
    if (_loaded) return _tokens;
    try {
      final access = await _storage.read(key: _accessKey);
      final refresh = await _storage.read(key: _refreshKey);
      if (access != null && refresh != null) {
        _tokens = AuthTokens(accessToken: access, refreshToken: refresh);
      }
    } catch (error) {
      // A keystore that can't be read (e.g. restored from another phone)
      // just means "signed out".
      debugPrint('Could not read the saved session: $error');
    }
    _loaded = true;
    return _tokens;
  }

  Future<String?> accessToken() async => (await read())?.accessToken;

  Future<String?> refreshToken() async => (await read())?.refreshToken;

  /// Saves a new pair. [persist] defaults to the mode of the current session.
  Future<void> save(AuthTokens tokens, {bool? persist}) async {
    _tokens = tokens;
    _loaded = true;
    if (persist != null) _persist = persist;
    try {
      if (_persist) {
        await _storage.write(key: _accessKey, value: tokens.accessToken);
        await _storage.write(key: _refreshKey, value: tokens.refreshToken);
      } else {
        await _deleteStored();
      }
    } catch (error) {
      debugPrint('Could not store the session: $error');
    }
  }

  Future<void> clear() async {
    _tokens = null;
    _loaded = true;
    _persist = true;
    try {
      await _deleteStored();
    } catch (error) {
      debugPrint('Could not clear the session: $error');
    }
  }

  Future<void> _deleteStored() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
