import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/sync/data_change_bus.dart';
import '../../../tasks/domain/entities/task.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/settings.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepositoryImpl(ref.watch(sharedPreferencesProvider)),
);

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    // Settings changed on another device.
    final pulled = ref
        .watch(dataChangeBusProvider)
        .remoteChanges
        .where((scope) => scope == DataScope.settings)
        .listen((_) {
          if (ref.mounted) state = ref.read(settingsRepositoryProvider).load();
        });
    ref.onDispose(pulled.cancel);
    return ref.read(settingsRepositoryProvider).load();
  }

  /// Applies [change] right away and saves it. If saving fails the old
  /// value comes back so the screen never lies about what is stored.
  Future<void> _update(AppSettings Function(AppSettings s) change) async {
    final previous = state;
    state = change(previous);
    try {
      await ref.read(settingsRepositoryProvider).save(state);
      ref.read(dataChangeBusProvider).localChanged(DataScope.settings);
    } catch (_) {
      if (ref.mounted) state = previous;
    }
  }

  Future<void> setNotificationsEnabled(bool value) =>
      _update((s) => s.copyWith(notificationsEnabled: value));

  Future<void> setDailyDigestEnabled(bool value) =>
      _update((s) => s.copyWith(dailyDigestEnabled: value));

  Future<void> setDailyDigestTime(String time) =>
      _update((s) => s.copyWith(dailyDigestTime: time));

  Future<void> setThemeMode(ThemeMode mode) =>
      _update((s) => s.copyWith(themeMode: mode));

  Future<void> setDefaultPriority(TaskPriority priority) =>
      _update((s) => s.copyWith(defaultPriority: priority));

  Future<void> setDailyGoal(int goal) =>
      _update((s) => s.copyWith(dailyGoal: goal.clamp(1, 20)));

  Future<void> addCategory(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return Future.value();
    return _update((s) {
      final exists = [
        ...kBuiltInCategories,
        ...s.customCategories,
      ].any((c) => c.toLowerCase() == clean.toLowerCase());
      if (exists) return s;
      return s.copyWith(customCategories: [...s.customCategories, clean]);
    });
  }

  Future<void> removeCategory(String name) => _update(
    (s) => s.copyWith(
      customCategories: [
        for (final c in s.customCategories)
          if (c != name) c,
      ],
    ),
  );
}
