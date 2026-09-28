import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tasks/domain/entities/task.dart';
import '../domain/settings.dart';

/// Preferences are small and flat, so they live in SharedPreferences.
class SettingsRepository {
  final SharedPreferences _prefs;

  SettingsRepository(this._prefs);

  // Keys kept from the first version so existing preferences carry over.
  static const _notifications = 'pushNotificationsEnabled';
  static const _digest = 'dailyDigestEnabled';
  static const _digestTime = 'dailyDigestTime';
  static const _theme = 'themeMode';
  static const _priority = 'defaultPriority';
  static const _goal = 'dailyGoal';
  static const _categories = 'customCategories';

  AppSettings load() {
    const defaults = AppSettings();
    final theme = _prefs.getString(_theme);
    return AppSettings(
      notificationsEnabled:
          _prefs.getBool(_notifications) ?? defaults.notificationsEnabled,
      dailyDigestEnabled:
          _prefs.getBool(_digest) ?? defaults.dailyDigestEnabled,
      dailyDigestTime:
          _prefs.getString(_digestTime) ?? defaults.dailyDigestTime,
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == theme,
        orElse: () => defaults.themeMode,
      ),
      defaultPriority: taskPriorityFromIndex(_prefs.getInt(_priority)),
      dailyGoal: (_prefs.getInt(_goal) ?? defaults.dailyGoal).clamp(1, 20),
      customCategories: _prefs.getStringList(_categories) ?? const [],
    );
  }

  Future<void> save(AppSettings s) async {
    await _prefs.setBool(_notifications, s.notificationsEnabled);
    await _prefs.setBool(_digest, s.dailyDigestEnabled);
    await _prefs.setString(_digestTime, s.dailyDigestTime);
    await _prefs.setString(_theme, s.themeMode.name);
    await _prefs.setInt(_priority, s.defaultPriority.index);
    await _prefs.setInt(_goal, s.dailyGoal);
    await _prefs.setStringList(_categories, s.customCategories);
  }
}
