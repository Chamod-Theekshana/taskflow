import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

String? _cached;

/// The device's IANA time zone, e.g. `Asia/Colombo`, or null when it can't
/// be read right now (not cached, so the next call tries again).
///
/// Sent with tasks and settings so the server can turn a due day and time
/// into the right instant (reminders, digest, stats).
Future<String?> tryDeviceTimeZone() async {
  final cached = _cached;
  if (cached != null) return cached;
  try {
    final zone = await FlutterTimezone.getLocalTimezone();
    return _cached = zone.identifier;
  } catch (error) {
    debugPrint('Could not read the time zone: $error');
    return null;
  }
}

/// Like [tryDeviceTimeZone], falling back to `UTC` (e.g. for sign-up).
Future<String> deviceTimeZone() async => await tryDeviceTimeZone() ?? 'UTC';
