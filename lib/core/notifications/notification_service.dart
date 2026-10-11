import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/settings/domain/settings.dart';
import '../../features/tasks/domain/entities/task.dart';
import '../utils/date_time_utils.dart';

/// Local notifications: task reminders and the morning digest, scheduled on
/// the device so they fire on time even offline.
///
/// Everything is rebuilt from the task list on each change (see
/// `reminderSyncProvider`), so there is no per-task bookkeeping to get out of
/// sync. Tasks edited on another device arrive through sync and are
/// rescheduled the same way; until then the server's push covers them (see
/// `PushService`).
class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  static const _digestIdBase = 1000000;
  static const _remoteIdBase = 2000000;
  static const _maxReminders = 50; // iOS keeps at most 64 pending.

  static const reminderChannel = 'task_reminders';
  static const digestChannel = 'daily_digest';

  final _plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<int>.broadcast();
  final _remoteTaps = StreamController<String>.broadcast();
  Future<bool>? _ready;
  Future<void> _queue = Future.value();
  int? _launchTaskId;
  String? _launchTaskUuid;
  bool _askedThisSession = false;
  int _remoteCounter = 0;

  /// Task ids from reminders the user tapped while the app was running.
  Stream<int> get taskTaps => _taps.stream;

  /// Task uuids from server pushes shown while the app was open, then tapped.
  Stream<String> get remoteTaskTaps => _remoteTaps.stream;

  /// The uuid behind a shown push that launched the app, if any. Returned once.
  Future<String?> takeLaunchTaskUuid() async {
    await _init();
    final uuid = _launchTaskUuid;
    _launchTaskUuid = null;
    return uuid;
  }

  /// The task behind the reminder that launched the app, if any. Returned
  /// once.
  Future<int?> takeLaunchTaskId() async {
    await _init();
    final id = _launchTaskId;
    _launchTaskId = null;
    return id;
  }

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<bool> _init() => _ready ??= _initialize();

  Future<bool> _initialize() async {
    if (!_supported) return false;
    try {
      tz_data.initializeTimeZones();
      try {
        final zone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(zone.identifier));
      } catch (_) {
        // Unknown zone: stay on UTC. Reminders are absolute instants, so
        // they still fire at the right moment.
      }

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          final id = _taskIdFrom(response.payload);
          if (id != null) _taps.add(id);
          final uuid = _taskUuidFrom(response.payload);
          if (uuid != null) _remoteTaps.add(uuid);
        },
      );

      // Created up front so pushes from the server use the same channels.
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          reminderChannel,
          'Task reminders',
          description: 'A heads-up before a task is due.',
          importance: Importance.high,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          digestChannel,
          'Daily digest',
          description: 'A short summary of the day each morning.',
        ),
      );

      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch != null && launch.didNotificationLaunchApp) {
        final payload = launch.notificationResponse?.payload;
        _launchTaskId = _taskIdFrom(payload);
        _launchTaskUuid = _taskUuidFrom(payload);
      }
      return true;
    } catch (error) {
      debugPrint('Notifications are not available: $error');
      return false;
    }
  }

  static int? _taskIdFrom(String? payload) {
    if (payload == null || !payload.startsWith('task:')) return null;
    return int.tryParse(payload.substring(5));
  }

  static String? _taskUuidFrom(String? payload) {
    if (payload == null || !payload.startsWith('uuid:')) return null;
    final uuid = payload.substring(5);
    return uuid.isEmpty ? null : uuid;
  }

  /// Shows a push from the server right away (Android, app in foreground).
  Future<void> showRemote({
    required String title,
    required String body,
    String? taskUuid,
  }) async {
    if (!await _init()) return;
    _remoteCounter = (_remoteCounter + 1) % 1000;
    try {
      await _plugin.show(
        id: _remoteIdBase + _remoteCounter,
        title: title,
        body: body,
        notificationDetails: _reminderDetails,
        payload: taskUuid == null ? null : 'uuid:$taskUuid',
      );
    } catch (error) {
      debugPrint('Could not show a push: $error');
    }
  }

  /// Shows the system permission prompt. Only asks once per app session;
  /// returns whether notifications are allowed.
  Future<bool> requestPermission({bool force = false}) async {
    if (!await _init()) return false;
    if (_askedThisSession && !force) return true;
    _askedThisSession = true;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await android?.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static DateTime reminderTime(Task task) {
    if (task.isAllDay) {
      final d = task.dueDate;
      return DateTime(d.year, d.month, d.day, 9);
    }
    return task.deadline.subtract(Duration(minutes: task.reminderMinutes));
  }

  /// Replaces every pending notification with ones built from [tasks].
  ///
  /// Runs are queued, so an older run can never finish after a newer one
  /// and bring back a reminder for a task that was just completed.
  Future<void> reschedule({
    required List<Task> tasks,
    required AppSettings settings,
    required bool signedIn,
  }) {
    return _queue = _queue.then(
      (_) => _reschedule(tasks: tasks, settings: settings, signedIn: signedIn),
    );
  }

  Future<void> _reschedule({
    required List<Task> tasks,
    required AppSettings settings,
    required bool signedIn,
  }) async {
    if (!await _init()) return;
    try {
      await _plugin.cancelAllPendingNotifications();
      if (!signedIn || !settings.notificationsEnabled) return;

      final now = DateTime.now();
      final reminders = [
        for (final t in tasks)
          if (!t.isCompleted && t.reminder && t.id != null)
            if (reminderTime(t).isAfter(now)) t,
      ]..sort((a, b) => reminderTime(a).compareTo(reminderTime(b)));

      for (final task in reminders.take(_maxReminders)) {
        await _schedule(
          id: task.id!,
          at: reminderTime(task),
          title: task.title,
          body: task.isAllDay
              ? 'Due today'
              : 'Due at ${shortTime(task.deadline)}',
          payload: 'task:${task.id}',
          details: _reminderDetails,
        );
      }

      if (settings.dailyDigestEnabled) {
        await _scheduleDigests(tasks, settings.dailyDigestTime, now);
      }
    } catch (error) {
      debugPrint('Could not schedule notifications: $error');
    }
  }

  /// One digest per day for the coming week, each with that day's numbers.
  Future<void> _scheduleDigests(
    List<Task> tasks,
    String time,
    DateTime now,
  ) async {
    final at = parseTimeOfDay(time);
    if (at == null) return;
    for (var i = 0; i < 7; i++) {
      final day = addDays(dateOnly(now), i);
      final when = combineDateAndTime(day, at);
      if (!when.isAfter(now)) continue;

      final due = tasks
          .where((t) => !t.isCompleted && isSameDate(t.dueDate, day))
          .toList();
      final urgent = due.where((t) => t.priority == TaskPriority.high).length;
      final body = due.isEmpty
          ? 'Nothing is due today. A good day to plan ahead.'
          : '${plural(due.length, 'task')} due today'
                '${urgent > 0 ? ' · $urgent high priority' : ''}';

      await _schedule(
        id: _digestIdBase + i,
        at: when,
        title: 'Your day at a glance',
        body: body,
        details: _digestDetails,
      );
    }
  }

  Future<void> _schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required NotificationDetails details,
    String? payload,
  }) {
    return _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      payload: payload,
    );
  }

  static const _brand = Color(0xFFFF6B00);

  static const _reminderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      reminderChannel,
      'Task reminders',
      channelDescription: 'A heads-up before a task is due.',
      importance: Importance.high,
      priority: Priority.high,
      color: _brand,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static const _digestDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      digestChannel,
      'Daily digest',
      channelDescription: 'A short summary of the day each morning.',
      color: _brand,
    ),
    iOS: DarwinNotificationDetails(),
  );
}
