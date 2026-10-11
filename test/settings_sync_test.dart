import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskflow/features/settings/data/models/settings_dto.dart';
import 'package:taskflow/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:taskflow/features/settings/domain/settings.dart';
import 'package:taskflow/features/tasks/domain/entities/task.dart';

Future<SettingsRepositoryImpl> _repo([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return SettingsRepositoryImpl(await SharedPreferences.getInstance());
}

void main() {
  test('a fresh install has nothing to upload and takes the server settings', () async {
    final repo = await _repo();
    expect(repo.pendingUpload(), isNull);

    final applied = await repo.applyRemote(
      const AppSettings(themeMode: ThemeMode.light, dailyGoal: 6),
      DateTime.utc(2026, 9, 1),
    );
    expect(applied, isTrue);
    expect(repo.load().themeMode, ThemeMode.light);
    expect(repo.load().dailyGoal, 6);
  });

  test('preferences from the offline versions are uploaded once, oldest-possible', () async {
    final repo = await _repo({'themeMode': 'light', 'customCategories': ['Study']});
    final pending = repo.pendingUpload();
    expect(pending, isNotNull);
    expect(pending!.settings.customCategories, ['Study']);
    expect(pending.updatedAt.millisecondsSinceEpoch, 1);

    await repo.markUploaded(pending.updatedAt);
    expect(repo.pendingUpload(), isNull);
  });

  test('a newer local edit is not overwritten by an older server copy', () async {
    final repo = await _repo();
    await repo.save(const AppSettings(dailyGoal: 9));
    final pending = repo.pendingUpload();
    expect(pending, isNotNull);

    final applied = await repo.applyRemote(
      const AppSettings(dailyGoal: 2),
      DateTime.utc(2000),
    );
    expect(applied, isFalse);
    expect(repo.load().dailyGoal, 9);
  });

  test('another account on the same phone does not inherit unsent edits', () async {
    final repo = await _repo();
    expect(await repo.claimForUser('user-a'), isFalse);
    await repo.save(const AppSettings(dailyGoal: 9));
    expect(repo.pendingUpload(), isNotNull);

    // A different account signs in: it re-pulls its own settings instead.
    expect(await repo.claimForUser('user-b'), isTrue);
    expect(repo.pendingUpload(), isNull);
    expect(await repo.claimForUser('user-b'), isFalse);
  });

  test('settings round-trip through the API format', () {
    const settings = AppSettings(
      notificationsEnabled: false,
      dailyDigestEnabled: true,
      dailyDigestTime: '07:30',
      themeMode: ThemeMode.system,
      defaultPriority: TaskPriority.high,
      dailyGoal: 5,
      customCategories: ['Study', 'A very long tag name that is too long'],
    );
    final json = SettingsDto.toJson(
      settings,
      updatedAt: DateTime.utc(2026, 9, 29, 10),
      timezone: 'Asia/Colombo',
    );
    expect(json['themeMode'], 'system');
    expect(json['defaultPriority'], 'high');
    expect((json['customCategories'] as List)[1], hasLength(24));

    final back = SettingsDto.fromJson(json);
    expect(back.settings.dailyDigestTime, '07:30');
    expect(back.settings.defaultPriority, TaskPriority.high);
    expect(back.updatedAt.toUtc(), DateTime.utc(2026, 9, 29, 10));
  });
}
