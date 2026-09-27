import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import '../models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<UserModel?> getUser(String id);
  Future<UserModel?> getUserByEmail(String email);
  Future<UserModel> saveUser(UserModel user, String passwordHash);
  Future<bool> verifyPassword(String email, String password);
  Future<void> deleteUser(String id);
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final Database db;

  AuthLocalDataSourceImpl(this.db);

  static String _hash(String password) =>
      sha256.convert(utf8.encode(password)).toString();

  @override
  Future<UserModel?> getUser(String id) async {
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : UserModel.fromMap(rows.first);
  }

  @override
  Future<UserModel?> getUserByEmail(String email) async {
    final rows = await db.query('users', where: 'email = ?', whereArgs: [email]);
    return rows.isEmpty ? null : UserModel.fromMap(rows.first);
  }

  @override
  Future<UserModel> saveUser(UserModel user, String password) async {
    final map = {...user.toMap(), 'password_hash': _hash(password)};
    await db.insert('users', map, conflictAlgorithm: ConflictAlgorithm.replace);
    return user;
  }

  @override
  Future<bool> verifyPassword(String email, String password) async {
    final rows = await db.query('users', where: 'email = ?', whereArgs: [email]);
    if (rows.isEmpty) return false;
    return rows.first['password_hash'] == _hash(password);
  }

  @override
  Future<void> deleteUser(String id) async {
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }
}
