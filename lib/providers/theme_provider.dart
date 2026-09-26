import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  bool _pushNotifications = true;
  bool _dailyDigest = true;
  String _digestTime = '08:00 AM';
  TaskPriority _defaultPriority = TaskPriority.medium;

  ThemeMode get themeMode => _themeMode;
  bool get pushNotifications => _pushNotifications;
  bool get dailyDigest => _dailyDigest;
  String get digestTime => _digestTime;
  TaskPriority get defaultPriority => _defaultPriority;

  ThemeProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDark') ?? false;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    _pushNotifications = prefs.getBool('pushNotifications') ?? true;
    _dailyDigest = prefs.getBool('dailyDigest') ?? true;
    _digestTime = prefs.getString('digestTime') ?? '08:00 AM';
    final prioIndex = prefs.getInt('defaultPriority') ?? 1;
    _defaultPriority = TaskPriority.values.length > prioIndex ? TaskPriority.values[prioIndex] : TaskPriority.medium;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', _themeMode == ThemeMode.dark);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', _themeMode == ThemeMode.dark);
  }

  Future<void> toggleNotifications() async {
    _pushNotifications = !_pushNotifications;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pushNotifications', _pushNotifications);
  }

  Future<void> toggleDailyDigest() async {
    _dailyDigest = !_dailyDigest;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dailyDigest', _dailyDigest);
  }

  Future<void> setDigestTime(String time) async {
    _digestTime = time;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('digestTime', _digestTime);
  }

  Future<void> setDefaultPriority(TaskPriority priority) async {
    _defaultPriority = priority;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('defaultPriority', priority.index);
  }
}
