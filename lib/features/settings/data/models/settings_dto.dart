import 'package:flutter/material.dart';

import '../../../tasks/domain/entities/task.dart';
import '../../domain/settings.dart';

/// API JSON <-> [AppSettings].
abstract final class SettingsDto {
  static Map<String, dynamic> toJson(
    AppSettings s, {
    required DateTime updatedAt,
    required String timezone,
  }) => {
    'notificationsEnabled': s.notificationsEnabled,
    'dailyDigestEnabled': s.dailyDigestEnabled,
    'dailyDigestTime': s.dailyDigestTime,
    'themeMode': s.themeMode.name,
    'defaultPriority': s.defaultPriority.name,
    'dailyGoal': s.dailyGoal.clamp(1, 20),
    // The server accepts up to 50 tags of up to 24 characters.
    'customCategories': [
      for (final c in s.customCategories.take(50))
        if (c.trim().isNotEmpty)
          c.trim().length > 24 ? c.trim().substring(0, 24) : c.trim(),
    ],
    'timezone': timezone,
    'updatedAt': DateTime.fromMillisecondsSinceEpoch(
      updatedAt.millisecondsSinceEpoch,
      isUtc: true,
    ).toIso8601String(),
  };

  static ({AppSettings settings, DateTime updatedAt}) fromJson(
    Map<String, dynamic> json,
  ) {
    const defaults = AppSettings();
    return (
      settings: AppSettings(
        notificationsEnabled:
            json['notificationsEnabled'] as bool? ??
            defaults.notificationsEnabled,
        dailyDigestEnabled:
            json['dailyDigestEnabled'] as bool? ?? defaults.dailyDigestEnabled,
        dailyDigestTime:
            json['dailyDigestTime'] as String? ?? defaults.dailyDigestTime,
        themeMode: ThemeMode.values.firstWhere(
          (m) => m.name == json['themeMode'],
          orElse: () => defaults.themeMode,
        ),
        defaultPriority: TaskPriority.values.firstWhere(
          (p) => p.name == json['defaultPriority'],
          orElse: () => defaults.defaultPriority,
        ),
        dailyGoal: (json['dailyGoal'] as num?)?.toInt() ?? defaults.dailyGoal,
        customCategories: [
          for (final c in (json['customCategories'] as List? ?? const []))
            '$c',
        ],
      ),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
