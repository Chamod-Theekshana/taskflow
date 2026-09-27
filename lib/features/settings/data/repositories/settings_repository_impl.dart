import 'package:flutter/material.dart';
import '../datasources/settings_local_data_source.dart';
import '../../domain/entities/settings_entity.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../../tasks/domain/entities/task.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsLocalDataSource localDataSource;

  SettingsRepositoryImpl(this.localDataSource);

  @override
  Future<SettingsEntity> getSettings() async {
    final pushNotificationsEnabled = await localDataSource.getPushNotificationsEnabled();
    final dailyDigestEnabled = await localDataSource.getDailyDigestEnabled();
    final dailyDigestTime = await localDataSource.getDailyDigestTime();
    final themeModeStr = await localDataSource.getThemeMode();
    final defaultPriorityInt = await localDataSource.getDefaultPriority();

    ThemeMode themeMode = ThemeMode.values.firstWhere((e) => e.toString() == 'ThemeMode.$themeModeStr', orElse: () => ThemeMode.system);
    TaskPriority defaultPriority = TaskPriority.values[defaultPriorityInt];

    return SettingsEntity(
      pushNotificationsEnabled: pushNotificationsEnabled,
      dailyDigestEnabled: dailyDigestEnabled,
      dailyDigestTime: dailyDigestTime,
      themeMode: themeMode,
      defaultPriority: defaultPriority,
    );
  }

  @override
  Future<void> saveSettings(SettingsEntity settings) async {
    await localDataSource.setPushNotificationsEnabled(settings.pushNotificationsEnabled);
    await localDataSource.setDailyDigestEnabled(settings.dailyDigestEnabled);
    await localDataSource.setDailyDigestTime(settings.dailyDigestTime);
    await localDataSource.setThemeMode(settings.themeMode.name);
    await localDataSource.setDefaultPriority(settings.defaultPriority.index);
  }
}