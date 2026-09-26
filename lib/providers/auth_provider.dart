import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../data/database_helper.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = false;
  User? _currentUser;
  bool _rememberMe = false;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  User? get currentUser => _currentUser;
  bool get rememberMe => _rememberMe;

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final isAuth = prefs.getBool('isAuthenticated') ?? false;

    if (isAuth) {
      final user = await _dbHelper.getUser();
      if (user != null) {
        _currentUser = user;
        _isAuthenticated = true;
      } else {
        await _clearAuth(prefs);
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password,
      {bool rememberMe = true}) async {
    _isLoading = true;
    _rememberMe = rememberMe;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 800));

    User? user = await _dbHelper.getUser();

    if (user == null) {
      final defaultUser = User(
        fullName: 'Alex Morgan',
        email: email,
        avatarUrl: 'https://i.pravatar.cc/150?u=alex',
        workspace: 'Studio Core',
        memberSince: DateTime(2023, 10, 1),
        plan: 'Pro Plan',
      );
      final id = await _dbHelper.insertUser(defaultUser);
      user = defaultUser.copyWith(id: id);
    }

    _currentUser = user;
    _isAuthenticated = true;

    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setBool('isAuthenticated', true);
    } else {
      await prefs.setBool('isAuthenticated', false);
    }

    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> signup(String name, String email, String password) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 800));

    final newUser = User(
      fullName: name,
      email: email,
      avatarUrl: 'https://i.pravatar.cc/150?u=$email',
      workspace: 'Personal',
      memberSince: DateTime.now(),
      plan: 'Free',
    );

    final id = await _dbHelper.insertUser(newUser);
    final user = newUser.copyWith(id: id);

    _currentUser = user;
    _isAuthenticated = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAuthenticated', true);

    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await _clearAuth(prefs);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _clearAuth(SharedPreferences prefs) async {
    await prefs.remove('isAuthenticated');
    _isAuthenticated = false;
    _currentUser = null;
  }
}
