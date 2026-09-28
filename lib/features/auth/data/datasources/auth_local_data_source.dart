import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<UserModel?> getUser(String id);
  Future<UserModel?> getUserByEmail(String email);
  Future<UserModel> saveUser(UserModel user, String password);
  Future<bool> verifyPassword(String email, String password);
  Future<UserModel?> updateFullName(String id, String fullName);
}

/// Salted, iterated SHA-256.
///
/// Stored as `v2$<salt>$<hash>`. Plain SHA-256 hashes from the first version
/// of the app still verify and are re-hashed on the next successful login.
class PasswordHasher {
  PasswordHasher._();

  static const _prefix = 'v2';
  static const _iterations = 10000;
  static final Random _random = Random.secure();

  static String hash(String password) => _hashWithSalt(password, _newSalt());

  static bool verify(String password, String stored) {
    final parts = stored.split(r'$');
    if (parts.length == 3 && parts[0] == _prefix) {
      return _hashWithSalt(password, parts[1]) == stored;
    }
    return sha256.convert(utf8.encode(password)).toString() == stored;
  }

  static bool isLegacy(String stored) => !stored.startsWith('$_prefix\$');

  static String _newSalt() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64Url.encode(bytes);
  }

  static String _hashWithSalt(String password, String salt) {
    List<int> bytes = utf8.encode('$salt:$password');
    for (var i = 0; i < _iterations; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return '$_prefix\$$salt\$${base64Url.encode(bytes)}';
  }
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final Database db;

  AuthLocalDataSourceImpl(this.db);

  static String normalizeEmail(String email) => email.trim().toLowerCase();

  @override
  Future<UserModel?> getUser(String id) async {
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : UserModel.fromMap(rows.first);
  }

  @override
  Future<UserModel?> getUserByEmail(String email) async {
    final rows = await db.query(
      'users',
      where: 'lower(email) = ?',
      whereArgs: [normalizeEmail(email)],
    );
    return rows.isEmpty ? null : UserModel.fromMap(rows.first);
  }

  @override
  Future<UserModel> saveUser(UserModel user, String password) async {
    final normalized = UserModel(
      id: user.id,
      fullName: user.fullName.trim(),
      email: normalizeEmail(user.email),
    );
    await db.insert('users', {
      ...normalized.toMap(),
      'password_hash': PasswordHasher.hash(password),
    });
    return normalized;
  }

  @override
  Future<bool> verifyPassword(String email, String password) async {
    final rows = await db.query(
      'users',
      where: 'lower(email) = ?',
      whereArgs: [normalizeEmail(email)],
    );
    if (rows.isEmpty) return false;

    final row = rows.first;
    final stored = row['password_hash'] as String? ?? '';
    if (!PasswordHasher.verify(password, stored)) return false;

    if (PasswordHasher.isLegacy(stored)) {
      await db.update(
        'users',
        {'password_hash': PasswordHasher.hash(password)},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
    return true;
  }

  @override
  Future<UserModel?> updateFullName(String id, String fullName) async {
    await db.update(
      'users',
      {'full_name': fullName.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
    return getUser(id);
  }
}
