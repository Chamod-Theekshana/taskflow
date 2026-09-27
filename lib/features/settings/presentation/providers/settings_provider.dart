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

  Future<void> updatePushNotificationsEnabled(bool value) async {
    final current = state.value;
    if (current == null) return;
    final updated = current.copyWith(pushNotificationsEnabled: value);
    state = AsyncData(updated);
    await ref.read(settingsRepositoryProvider).saveSettings(updated);
  }

  Future<void> updateDailyDigestEnabled(bool value) async {
    final current = state.value;
    if (current == null) return;
    final updated = current.copyWith(dailyDigestEnabled: value);
    state = AsyncData(updated);
    await ref.read(settingsRepositoryProvider).saveSettings(updated);
  }

  Future<void> updateDailyDigestTime(String time) async {
    final current = state.value;
    if (current == null) return;
    final updated = current.copyWith(dailyDigestTime: time);
    state = AsyncData(updated);
    await ref.read(settingsRepositoryProvider).saveSettings(updated);
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    final current = state.value;
    if (current == null) return;
    final updated = current.copyWith(themeMode: mode);
    state = AsyncData(updated);
    await ref.read(settingsRepositoryProvider).saveSettings(updated);
  }

  Future<void> updateDefaultPriority(TaskPriority priority) async {
    final current = state.value;
    if (current == null) return;
    final updated = current.copyWith(defaultPriority: priority);
    state = AsyncData(updated);
    await ref.read(settingsRepositoryProvider).saveSettings(updated);
  }
}
