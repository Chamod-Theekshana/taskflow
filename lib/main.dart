import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/di/providers.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/db_provider.dart';
import 'features/settings/presentation/providers/settings_provider.dart';

/// Opening the database and preferences normally takes well under a second.
/// If either hangs, show the error screen instead of the launch screen
/// forever.
const _startupTimeout = Duration(seconds: 20);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    debugPrint('TaskFlow: opening database...');
    final db = await openAppDatabase().timeout(_startupTimeout);
    debugPrint('TaskFlow: database ready, loading preferences...');
    final prefs = await SharedPreferences.getInstance().timeout(
      _startupTimeout,
    );
    debugPrint('TaskFlow: preferences ready, starting app');

    runApp(
      ProviderScope(
        overrides: [
          dbProviderProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const TaskFlowApp(),
      ),
    );
  } catch (error, stackTrace) {
    // Without this an exception here left the user on the native launch
    // screen forever with no hint of what went wrong.
    debugPrint('TaskFlow failed to start: $error\n$stackTrace');
    runApp(StartupErrorApp(error: error));
  }
}

class TaskFlowApp extends ConsumerWidget {
  const TaskFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(
      settingsControllerProvider.select(
        (settings) => settings.value?.themeMode ?? ThemeMode.system,
      ),
    );
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'TaskFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

class StartupErrorApp extends StatelessWidget {
  final Object error;

  const StartupErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 56),
                  const SizedBox(height: 16),
                  const Text(
                    'TaskFlow could not start.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text('$error', textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
