import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'notification_service.dart';

/// Runs in a background isolate when a push arrives while the app is closed.
///
/// Visible reminders are drawn by the operating system from the notification
/// payload, and silent "sync" pushes are picked up the next time the app is
/// opened, so there is nothing to do here. It still has to exist: without a
/// handler Firebase drops data messages in the background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Firebase Cloud Messaging: remote pushes sent by the TaskFlow server.
///
/// * `reminder` / `digest` / `test` pushes carry a notification. In the
///   background the OS shows them; in the foreground on Android they are shown
///   through [NotificationService] (Android doesn't show FCM notifications
///   while the app is open; iOS does, see `setForegroundNotificationPresentationOptions`).
/// * `sync` pushes are silent and make the app sync right away.
///
/// Push is optional: without Firebase options (see `AppConfig`) everything
/// else keeps working and [available] stays false.
class PushService {
  PushService._();

  static final instance = PushService._();

  final _syncRequests = StreamController<void>.broadcast();
  final _taskTaps = StreamController<String>.broadcast();
  final _tokenChanges = StreamController<String>.broadcast();

  bool _available = false;
  String? _launchTaskUuid;

  bool get available => _available;

  /// A silent push asked for a sync.
  Stream<void> get syncRequests => _syncRequests.stream;

  /// Task uuid of a push notification the user tapped.
  Stream<String> get taskTaps => _taskTaps.stream;

  /// FCM issued a new registration token.
  Stream<String> get tokenChanges => _tokenChanges.stream;

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Called once from `main()`, before `runApp`.
  Future<void> initialize() async {
    final options = AppConfig.firebaseOptions;
    if (!_supported || options == null) return;
    try {
      await Firebase.initializeApp(options: options);
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      // iOS shows pushes that arrive in the foreground like any other.
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);
      messaging.onTokenRefresh.listen(_tokenChanges.add);

      final initial = await messaging.getInitialMessage();
      if (initial != null) _launchTaskUuid = _taskUuid(initial);
      _available = true;
    } catch (error) {
      debugPrint('Push notifications are not available: $error');
    }
  }

  /// The task behind the push that launched the app, if any. Returned once.
  String? takeLaunchTaskUuid() {
    final uuid = _launchTaskUuid;
    _launchTaskUuid = null;
    return uuid;
  }

  /// Asks for permission (iOS; Android 13+ uses the local notifications
  /// prompt) and returns the FCM token, or null.
  Future<String?> token() async {
    if (!_available) return null;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return null;
      }
      // ignore: deprecated_member_use
      return await FirebaseMessaging.instance.getToken();
    } catch (error) {
      debugPrint('Could not get a push token: $error');
      return null;
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    if (message.data['type'] == 'sync') {
      _syncRequests.add(null);
      return;
    }
    final notification = message.notification;
    if (notification == null) return;
    // A reminder often means the task changed elsewhere: fetch it too.
    _syncRequests.add(null);
    if (defaultTargetPlatform == TargetPlatform.android) {
      unawaited(
        NotificationService.instance.showRemote(
          title: notification.title ?? 'TaskFlow',
          body: notification.body ?? '',
          taskUuid: _taskUuid(message),
        ),
      );
    }
  }

  void _onOpened(RemoteMessage message) {
    final uuid = _taskUuid(message);
    if (uuid != null) _taskTaps.add(uuid);
  }

  static String? _taskUuid(RemoteMessage message) {
    final id = message.data['taskId'];
    return id is String && id.isNotEmpty ? id : null;
  }
}
