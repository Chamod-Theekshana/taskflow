import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/reminder_sync.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/devices/presentation/providers/device_registration_provider.dart';
import 'features/settings/presentation/providers/settings_provider.dart';
import 'features/sync/presentation/providers/sync_provider.dart';

class TaskFlowApp extends ConsumerWidget {
  const TaskFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final router = ref.watch(appRouterProvider);
    // Background services that live as long as the app.
    ref.watch(reminderSyncProvider);
    ref.watch(syncControllerProvider);
    ref.watch(deviceRegistrationProvider);

    return MaterialApp.router(
      title: 'TaskFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        // Status and navigation bar icons that match the current theme.
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
              .copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
              ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
