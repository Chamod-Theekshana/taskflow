import 'package:flutter/material.dart';
import '../../../tasks/domain/entities/task.dart';

class SettingsEntity {
  final bool pushNotificationsEnabled;
  final bool dailyDigestEnabled;
  final String dailyDigestTime;
  final ThemeMode themeMode;
  final TaskPriority defaultPriority;

  const SettingsEntity({
    this.pushNotificationsEnabled = true,
    this.dailyDigestEnabled = false,
    this.dailyDigestTime = '08:00',
    this.themeMode = ThemeMode.system,
    this.defaultPriority = TaskPriority.medium,
  });

  SettingsEntity copyWith({
    bool? pushNotificationsEnabled,
    bool? dailyDigestEnabled,
    String? dailyDigestTime,
    ThemeMode? themeMode,
    TaskPriority? defaultPriority,
  }) {
    return SettingsEntity(
      pushNotificationsEnabled: pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      dailyDigestEnabled: dailyDigestEnabled ?? this.dailyDigestEnabled,
      dailyDigestTime: dailyDigestTime ?? this.dailyDigestTime,
      themeMode: themeMode ?? this.themeMode,
      defaultPriority: defaultPriority ?? this.defaultPriority,
    );
  }
}