import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../domain/entities/settings_entity.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../data/datasources/settings_local_data_source.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../../tasks/domain/entities/task.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final dataSource = SettingsLocalDataSourceImpl(prefs);
  return SettingsRepositoryImpl(dataSource);
});

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, SettingsEntity>(SettingsController.new);

class SettingsController extends AsyncNotifier<SettingsEntity> {
  @override
  Future<SettingsEntity> build() =>
      ref.read(settingsRepositoryProvider).getSettings();

  /// Applies [change] optimistically and persists it. If saving fails the
  /// previous value is restored instead of leaving the UI out of sync.
  Future<void> _update(
    SettingsEntity Function(SettingsEntity current) change,
  ) async {
    final current = state.value;
    if (current == null) return;
    final updated = change(current);
    state = AsyncData(updated);
    try {
      await ref.read(settingsRepositoryProvider).saveSettings(updated);
    } catch (_) {
      if (ref.mounted) state = AsyncData(current);
    }
  }

  Future<void> updatePushNotificationsEnabled(bool value) =>
      _update((s) => s.copyWith(pushNotificationsEnabled: value));

  Future<void> updateDailyDigestEnabled(bool value) =>
      _update((s) => s.copyWith(dailyDigestEnabled: value));

  Future<void> updateDailyDigestTime(String time) =>
      _update((s) => s.copyWith(dailyDigestTime: time));

  Future<void> updateThemeMode(ThemeMode mode) =>
      _update((s) => s.copyWith(themeMode: mode));

  Future<void> updateDefaultPriority(TaskPriority priority) =>
      _update((s) => s.copyWith(defaultPriority: priority));
}
