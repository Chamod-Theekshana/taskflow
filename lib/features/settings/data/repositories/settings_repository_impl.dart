import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../tasks/domain/entities/task.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/settings.dart';

/// Preferences are small and flat, so they live in SharedPreferences.
///
/// Sync bookkeeping: `settings.updatedAt` is when they were last changed
/// (here or on another device) and `settings.dirty` says a local change
/// still has to be uploaded.
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;

  // Keys kept from the first version so existing preferences carry over.
  static const _notifications = 'pushNotificationsEnabled';
  static const _digest = 'dailyDigestEnabled';
  static const _digestTime = 'dailyDigestTime';
  static const _theme = 'themeMode';
  static const _priority = 'defaultPriority';
  static const _goal = 'dailyGoal';
  static const _categories = 'customCategories';
  static const _updatedAt = 'settings.updatedAt';
  static const _dirty = 'settings.dirty';

  /// The account whose sync state the two keys above describe.
  static const _owner = 'settings.owner';

  /// Set once settings have been synced on this device: from then on local
  /// preferences are never treated as pre-account ones.
  static const _migrated = 'settings.migrated';

  @override
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

  Future<void> _write(AppSettings s) async {
    await _prefs.setBool(_notifications, s.notificationsEnabled);
    await _prefs.setBool(_digest, s.dailyDigestEnabled);
    await _prefs.setString(_digestTime, s.dailyDigestTime);
    await _prefs.setString(_theme, s.themeMode.name);
    await _prefs.setInt(_priority, s.defaultPriority.index);
    await _prefs.setInt(_goal, s.dailyGoal);
    await _prefs.setStringList(_categories, s.customCategories);
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _write(settings);
    await _prefs.setString(_updatedAt, DateTime.now().toIso8601String());
    await _prefs.setBool(_dirty, true);
  }

  DateTime? get _stamp => DateTime.tryParse(_prefs.getString(_updatedAt) ?? '');

  @override
  ({AppSettings settings, DateTime updatedAt})? pendingUpload() {
    final stamp = _stamp;
    if (stamp == null) {
      // Preferences from the offline-only versions: upload them once, but
      // let anything already on the server win (it is newer than 1970).
      final legacy =
          _prefs.getBool(_migrated) != true &&
          (_prefs.containsKey(_theme) || _prefs.containsKey(_categories));
      if (!legacy) return null;
      return (
        settings: load(),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
      );
    }
    if (_prefs.getBool(_dirty) != true) return null;
    return (settings: load(), updatedAt: stamp);
  }

  @override
  Future<void> markUploaded(DateTime updatedAt) async {
    await _prefs.setBool(_migrated, true);
    final stamp = _stamp;
    if (stamp == null) {
      await _prefs.setString(_updatedAt, updatedAt.toIso8601String());
      await _prefs.setBool(_dirty, false);
      return;
    }
    if (stamp.millisecondsSinceEpoch == updatedAt.millisecondsSinceEpoch) {
      await _prefs.setBool(_dirty, false);
    }
  }

  @override
  Future<bool> applyRemote(AppSettings settings, DateTime updatedAt) async {
    final stamp = _stamp;
    final dirty = _prefs.getBool(_dirty) == true;
    if (dirty &&
        stamp != null &&
        stamp.millisecondsSinceEpoch > updatedAt.millisecondsSinceEpoch) {
      return false;
    }
    await _prefs.setBool(_migrated, true);
    final changed = load() != settings;
    if (changed) await _write(settings);
    await _prefs.setString(_updatedAt, updatedAt.toIso8601String());
    await _prefs.setBool(_dirty, false);
    return changed;
  }

  @override
  Future<bool> claimForUser(String userId) async {
    final owner = _prefs.getString(_owner);
    if (owner == userId) return false;
    if (owner != null) {
      await _prefs.remove(_updatedAt);
      await _prefs.setBool(_dirty, false);
      await _prefs.setBool(_migrated, true);
    }
    await _prefs.setString(_owner, userId);
    return owner != null;
  }
}
