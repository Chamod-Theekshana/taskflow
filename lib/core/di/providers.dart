import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../config/app_config.dart';
import '../network/api_client.dart';
import '../storage/token_store.dart';
import '../utils/uuid.dart';

/// Opened in `main()` before the app starts and injected with an override.
final databaseProvider = Provider<Database>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) =>
      throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

/// Random id of this installation, sent as `X-Device-Id`. Created once.
final installationIdProvider = Provider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  const key = 'installation_id';
  final existing = prefs.getString(key);
  if (existing != null && existing.isNotEmpty) return existing;
  final id = newUuid();
  unawaited(prefs.setString(key, id));
  return id;
});

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => TokenStore(const FlutterSecureStorage()),
);

/// Session events raised by the network layer, e.g. when the server ended
/// the session. The auth feature listens and signs the user out.
class SessionEvents {
  final _expired = StreamController<void>.broadcast();

  Stream<void> get expired => _expired.stream;

  Future<void> notifyExpired() async => _expired.add(null);

  void dispose() => _expired.close();
}

final sessionEventsProvider = Provider<SessionEvents>((ref) {
  final events = SessionEvents();
  ref.onDispose(events.dispose);
  return events;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final events = ref.watch(sessionEventsProvider);
  return ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    tokens: ref.watch(tokenStoreProvider),
    installationId: ref.watch(installationIdProvider),
    onSessionExpired: events.notifyExpired,
  );
});
