import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/notifications/push_service.dart';
import '../../../../core/utils/device_timezone.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/device_remote_data_source.dart';

final deviceRemoteDataSourceProvider = Provider<DeviceRemoteDataSource>(
  (ref) => DeviceRemoteDataSource(ref.watch(apiClientProvider)),
);

/// Registers this device with the server whenever someone is signed in, and
/// again when Firebase rotates the push token. Watched from the app root.
/// Signing out unregisters it (see `AuthRemoteDataSource.logout`).
final deviceRegistrationProvider = Provider<void>((ref) {
  final userId = ref.watch(authProvider.select((auth) => auth.value?.id));
  if (userId == null) return;

  final remote = ref.watch(deviceRemoteDataSourceProvider);
  final installationId = ref.watch(installationIdProvider);
  var disposed = false;

  Future<void> register([String? knownToken]) async {
    try {
      final push = PushService.instance;
      final token = knownToken ?? await push.token();
      if (disposed) return;
      await remote.register(
        installationId: installationId,
        platform: switch (defaultTargetPlatform) {
          TargetPlatform.android => 'android',
          TargetPlatform.iOS => 'ios',
          _ => 'other',
        },
        pushToken: token,
        appVersion: kAppVersion,
        timezone: await deviceTimeZone(),
      );
    } catch (error) {
      // Offline: the next start-up or token change tries again.
      debugPrint('Device registration failed: $error');
    }
  }

  unawaited(register());
  final tokens = PushService.instance.tokenChanges.listen(register);
  ref.onDispose(() {
    disposed = true;
    tokens.cancel();
  });
});
