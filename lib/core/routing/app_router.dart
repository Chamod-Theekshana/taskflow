import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/settings/presentation/screens/profile_screen.dart';
import '../../features/tasks/presentation/screens/add_edit_task_screen.dart';
import '../../features/tasks/presentation/screens/calendar_screen.dart';
import '../../features/tasks/presentation/screens/home_screen.dart';
import '../../features/tasks/presentation/screens/task_detail_screen.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/not_found_screen.dart';
import 'route_guard.dart';

export 'route_guard.dart' show AppRoutes;

/// Notifies GoRouter to re-run its redirect whenever the auth state changes.
class _AuthRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

int? _idParam(GoRouterState state) =>
    int.tryParse(state.pathParameters['id'] ?? '');

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshNotifier();
  ref.listen(authProvider, (_, _) => refresh.notify());

  final router = GoRouter(
    refreshListenable: refresh,
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final target = resolveAuthRedirect(
        // Only the initial session restore counts as "loading".
        isRestoringSession: isRestoringSession(auth),
        isLoggedIn: auth.value != null,
        location: state.matchedLocation,
      );
      if (kDebugMode) {
        debugPrint(
          'TaskFlow router: ${state.matchedLocation} -> '
          '${target ?? '(stay)'}',
        );
      }
      return target;
    },
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: [
      // `context.go('/')` used to crash with "no routes for location: /".
      GoRoute(path: '/', redirect: (_, _) => AppRoutes.home),
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: AppRoutes.signup, builder: (_, _) => const SignupScreen()),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (_, _) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.calendar,
            builder: (_, _) => const CalendarScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (_, _) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.addTask,
        builder: (_, _) => const AddEditTaskScreen(),
      ),
      GoRoute(
        path: '/edit-task/:id',
        builder: (_, state) {
          final id = _idParam(state);
          return id == null
              ? const NotFoundScreen()
              : AddEditTaskScreen(taskId: id);
        },
      ),
      GoRoute(
        path: '/task/:id',
        builder: (_, state) {
          final id = _idParam(state);
          return id == null
              ? const NotFoundScreen()
              : TaskDetailScreen(taskId: id);
        },
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
