import 'package:shared_preferences/shared_preferences.dart';

abstract class SettingsLocalDataSource {
  Future<bool> getPushNotificationsEnabled();
  Future<void> setPushNotificationsEnabled(bool value);
  
  Future<bool> getDailyDigestEnabled();
  Future<void> setDailyDigestEnabled(bool value);
  
  Future<String> getDailyDigestTime();
  Future<void> setDailyDigestTime(String value);
  
  Future<String> getThemeMode();
  Future<void> setThemeMode(String value);
  
  Future<int> getDefaultPriority();
  Future<void> setDefaultPriority(int value);
}

class SettingsLocalDataSourceImpl implements SettingsLocalDataSource {
  final SharedPreferences prefs;

  SettingsLocalDataSourceImpl(this.prefs);

  @override
  Future<bool> getPushNotificationsEnabled() async => prefs.getBool('pushNotificationsEnabled') ?? true;
  @override
  Future<void> setPushNotificationsEnabled(bool value) async => await prefs.setBool('pushNotificationsEnabled', value);

  @override
  Future<bool> getDailyDigestEnabled() async => prefs.getBool('dailyDigestEnabled') ?? false;
  @override
  Future<void> setDailyDigestEnabled(bool value) async => await prefs.setBool('dailyDigestEnabled', value);

  @override
  Future<String> getDailyDigestTime() async => prefs.getString('dailyDigestTime') ?? '08:00';
  @override
  Future<void> setDailyDigestTime(String value) async => await prefs.setString('dailyDigestTime', value);

  @override
  Future<String> getThemeMode() async => prefs.getString('themeMode') ?? 'system';
  @override
  Future<void> setThemeMode(String value) async => await prefs.setString('themeMode', value);

  @override
  Future<int> getDefaultPriority() async => prefs.getInt('defaultPriority') ?? 1;
  @override
  Future<void> setDefaultPriority(int value) async => await prefs.setInt('defaultPriority', value);
}