import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/notifications/push_service.dart';
import '../../../../core/sync/data_change_bus.dart';
import '../../../../core/utils/device_timezone.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../tasks/presentation/providers/task_provider.dart';
import '../../data/datasources/sync_remote_data_source.dart';
import '../../data/sync_engine.dart';
import '../../domain/sync_status.dart';

final syncRemoteDataSourceProvider = Provider<SyncRemoteDataSource>(
  (ref) => SyncRemoteDataSource(ref.watch(apiClientProvider)),
);

/// The engine of the signed-in user; null while signed out. A new account
/// gets a new engine.
final syncEngineProvider = Provider<SyncEngine?>((ref) {
  final userId = ref.watch(authProvider.select((auth) => auth.value?.id));
  if (userId == null) return null;
  final engine = SyncEngine(
    userId: userId,
    email: ref.read(authProvider).value?.email ?? '',
    remote: ref.watch(syncRemoteDataSourceProvider),
    tasks: ref.watch(taskLocalDataSourceProvider),
    settings: ref.watch(settingsRepositoryProvider),
    prefs: ref.watch(sharedPreferencesProvider),
    bus: ref.watch(dataChangeBusProvider),
    timeZone: tryDeviceTimeZone,
  );
  ref.onDispose(engine.dispose);
  return engine;
});

final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncStatus>(
  SyncStatusNotifier.new,
);

class SyncStatusNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() {
    final engine = ref.watch(syncEngineProvider);
    if (engine == null) return const SyncStatus();
    final sub = engine.statusChanges.listen((status) {
      if (ref.mounted) state = status;
    });
    ref.onDispose(sub.cancel);
    return engine.status;
  }

  Future<void> syncNow() async {
    await ref.read(syncEngineProvider)?.sync();
  }
}

/// When to sync. Watched once from the app root:
///
/// * right after sign-in (or start-up with a saved session),
/// * shortly after every local change,
/// * when the app comes back to the foreground, and every 5 minutes while it
///   is open,
/// * when the server sends a silent "sync" push (another device changed
///   something).
final syncControllerProvider = Provider<void>((ref) {
  final engine = ref.watch(syncEngineProvider);
  final bus = ref.watch(dataChangeBusProvider);
  if (engine == null) {
    bus.attachSync(null);
    return;
  }

  bus.attachSync(engine.sync);
  final local = bus.localChanges.listen((_) => engine.schedule());
  final pushes = PushService.instance.syncRequests.listen((_) => engine.sync());

  var foreground = true;
  final lifecycle = AppLifecycleListener(
    onResume: () {
      foreground = true;
      unawaited(engine.sync());
    },
    onPause: () => foreground = false,
  );
  final timer = Timer.periodic(const Duration(minutes: 5), (_) {
    if (foreground) unawaited(engine.sync());
  });

  unawaited(engine.sync());

  ref.onDispose(() {
    bus.attachSync(null);
    local.cancel();
    pushes.cancel();
    lifecycle.dispose();
    timer.cancel();
  });
});
