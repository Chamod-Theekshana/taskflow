import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/error/failures.dart';
import '../../../core/sync/data_change_bus.dart';
import '../../settings/data/models/settings_dto.dart';
import '../../settings/domain/repositories/settings_repository.dart';
import '../../tasks/data/datasources/task_local_data_source.dart';
import '../../tasks/data/models/task_model.dart';
import '../../tasks/domain/entities/task.dart';
import '../domain/sync_status.dart';
import 'datasources/sync_remote_data_source.dart';

/// Keeps this device and the server in step for one signed-in user.
///
/// 1. **Push**: local changes (tasks marked pending, tombstones, settings)
///    go up in batches of 100. The server answers per task: `applied`,
///    `stale` (it has something newer) or `rejected`; either way the row is
///    done, and anything newer arrives with the pull.
/// 2. **Pull**: everything that changed on the server after the saved
///    cursor, page by page. A local edit that is newer and not pushed yet
///    wins; everything else is applied.
///
/// Only one sync runs at a time; asking again while one runs queues exactly
/// one more round. Errors never escape: they end up in [status].
class SyncEngine {
  SyncEngine({
    required this.userId,
    required this.email,
    required SyncRemoteDataSource remote,
    required TaskLocalDataSource tasks,
    required SettingsRepository settings,
    required SharedPreferences prefs,
    required DataChangeBus bus,
    required Future<String?> Function() timeZone,
  }) : _remote = remote,
       _tasks = tasks,
       _settings = settings,
       _prefs = prefs,
       _bus = bus,
       _timeZone = timeZone {
    _status = SyncStatus(
      lastSyncedAt: DateTime.tryParse(_prefs.getString(_lastKey) ?? ''),
    );
  }

  final String userId;
  final String email;
  final SyncRemoteDataSource _remote;
  final TaskLocalDataSource _tasks;
  final SettingsRepository _settings;
  final SharedPreferences _prefs;
  final DataChangeBus _bus;
  final Future<String?> Function() _timeZone;

  static const _batchSize = 100;

  late SyncStatus _status;
  final _statusChanges = StreamController<SyncStatus>.broadcast();
  Future<void>? _running;
  bool _again = false;
  bool _adopted = false;
  bool _disposed = false;
  bool _zoneMissing = false;
  Timer? _debounce;

  String get _cursorKey => 'sync.cursor.$userId';
  String get _lastKey => 'sync.lastSyncedAt.$userId';

  SyncStatus get status => _status;
  Stream<SyncStatus> get statusChanges => _statusChanges.stream;

  /// Syncs soon; many calls in a row (e.g. ticking off subtasks) become one.
  void schedule([Duration delay = const Duration(seconds: 1)]) {
    if (_disposed) return;
    _debounce?.cancel();
    _debounce = Timer(delay, () => unawaited(sync()));
  }

  /// Syncs now. Completes when this round (and any queued one) is done.
  Future<void> sync() {
    if (_disposed) return Future<void>.value();
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    final run = _loop().whenComplete(() => _running = null);
    _running = run;
    return run;
  }

  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _statusChanges.close();
  }

  Future<void> _loop() async {
    do {
      _again = false;
      await _runOnce();
    } while (_again && !_disposed);
  }

  Future<void> _runOnce() async {
    _emit(_status.copyWith(phase: SyncPhase.syncing));
    try {
      if (!_adopted) {
        await _tasks.adoptLegacyRows(userId, email);
        // Another account used this device since: fetch this account's
        // settings again from the start.
        if (await _settings.claimForUser(userId)) {
          await _prefs.remove(_cursorKey);
        }
        _adopted = true;
      }
      _zoneMissing = false;
      await _push();
      await _pull();
      if (_zoneMissing) {
        throw const Failure("Couldn't read the time zone. Will try again.");
      }
      final now = DateTime.now();
      await _prefs.setString(_lastKey, now.toIso8601String());
      _emit(SyncStatus(lastSyncedAt: now));
    } on NetworkFailure catch (error) {
      _emit(_status.copyWith(phase: SyncPhase.offline, message: error.message));
    } on Failure catch (error) {
      _emit(_status.copyWith(phase: SyncPhase.error, message: error.message));
    } catch (error, stack) {
      debugPrint('Sync failed: $error\n$stack');
      _emit(
        _status.copyWith(
          phase: SyncPhase.error,
          message: "Couldn't sync. Will try again.",
        ),
      );
    }
  }

  Future<void> _push() async {
    var settings = _settings.pendingUpload();
    if (settings == null && !await _tasks.hasPending(userId)) return;

    // Times are sent as wall-clock + zone; without the zone they'd be wrong.
    // Skip the upload this round (the pull still runs).
    final timezone = await _timeZone();
    if (timezone == null) {
      _zoneMissing = true;
      return;
    }

    for (var round = 0; round < 50 && !_disposed; round++) {
      final pending = await _tasks.pending(userId, limit: _batchSize);
      if (pending.isEmpty && settings == null) return;

      final changes = <Map<String, dynamic>>[
        for (final change in pending)
          if (change.task.uuid != null)
            change.deletedAt != null
                ? {
                    'op': 'delete',
                    'id': change.task.uuid,
                    'deletedAt': _utc(change.deletedAt!),
                  }
                : {
                    'op': 'upsert',
                    'task': TaskDto.toJson(change.task, timezone: timezone),
                  },
      ];
      final uploadedSettings = settings;
      final response = await _remote.push(
        changes: changes,
        settings: uploadedSettings == null
            ? null
            : SettingsDto.toJson(
                uploadedSettings.settings,
                updatedAt: uploadedSettings.updatedAt,
                timezone: timezone,
              ),
      );

      var done = 0;
      for (final change in pending) {
        final result = response.statusById[change.task.uuid];
        if (result == null) continue;
        if (result == 'rejected') {
          debugPrint('Server rejected task ${change.task.uuid}');
        }
        await _tasks.markPushed(userId, change);
        done++;
      }
      if (uploadedSettings != null && response.settingsStatus != null) {
        await _settings.markUploaded(uploadedSettings.updatedAt);
      }
      settings = null;

      // Last batch, or nothing could be marked (don't spin).
      if (pending.length < _batchSize || done == 0) return;
    }
  }

  Future<void> _pull() async {
    var cursor = _prefs.getInt(_cursorKey) ?? 0;
    var tasksChanged = false;
    var settingsChanged = false;

    for (var page = 0; page < 1000 && !_disposed; page++) {
      final result = await _remote.pull(cursor);

      final items = <({Task task, DateTime? deletedAt})>[];
      for (final json in result.tasks) {
        try {
          items.add(TaskDto.fromJson(json));
        } catch (error) {
          debugPrint('Skipped a malformed task from the server: $error');
        }
      }
      if (items.isNotEmpty) {
        final applied = await _tasks.applyRemote(userId, items);
        if (applied > 0) tasksChanged = true;
      }

      final remoteSettings = result.settings;
      if (remoteSettings != null) {
        final parsed = SettingsDto.fromJson(remoteSettings);
        if (await _settings.applyRemote(parsed.settings, parsed.updatedAt)) {
          settingsChanged = true;
        }
      }

      cursor = result.cursor;
      await _prefs.setInt(_cursorKey, cursor);
      if (!result.hasMore) break;
    }

    if (tasksChanged) _bus.remoteChanged(DataScope.tasks);
    if (settingsChanged) _bus.remoteChanged(DataScope.settings);
  }

  void _emit(SyncStatus status) {
    _status = status;
    if (!_disposed) _statusChanges.add(status);
  }

  static String _utc(DateTime time) => DateTime.fromMillisecondsSinceEpoch(
    time.millisecondsSinceEpoch,
    isUtc: true,
  ).toIso8601String();
}
