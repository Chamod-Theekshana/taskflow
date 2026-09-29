import 'package:flutter/material.dart';

import '../../tasks/domain/entities/task.dart';

class AppSettings {
  final bool notificationsEnabled;
  final bool dailyDigestEnabled;

  /// `HH:mm`, 24-hour.
  final String dailyDigestTime;
  final ThemeMode themeMode;
  final TaskPriority defaultPriority;

  /// Tasks per day the weekly chart on the profile aims for.
  final int dailyGoal;

  /// Tags the user added on top of the built-in categories.
  final List<String> customCategories;

  const AppSettings({
    this.notificationsEnabled = true,
    this.dailyDigestEnabled = false,
    this.dailyDigestTime = '08:00',
    this.themeMode = ThemeMode.dark,
    this.defaultPriority = TaskPriority.medium,
    this.dailyGoal = 4,
    this.customCategories = const [],
  });

  AppSettings copyWith({
    bool? notificationsEnabled,
    bool? dailyDigestEnabled,
    String? dailyDigestTime,
    ThemeMode? themeMode,
    TaskPriority? defaultPriority,
    int? dailyGoal,
    List<String>? customCategories,
  }) {
    return AppSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      dailyDigestEnabled: dailyDigestEnabled ?? this.dailyDigestEnabled,
      dailyDigestTime: dailyDigestTime ?? this.dailyDigestTime,
      themeMode: themeMode ?? this.themeMode,
      defaultPriority: defaultPriority ?? this.defaultPriority,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      customCategories: customCategories ?? this.customCategories,
    );
  }
}
