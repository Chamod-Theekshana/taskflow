import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/settings/presentation/screens/profile_screen.dart';
import '../../features/stats/presentation/stats_screen.dart';
import '../../features/tasks/presentation/screens/add_edit_task_screen.dart';
import '../../features/tasks/presentation/screens/calendar_screen.dart';
import '../../features/tasks/presentation/screens/home_screen.dart';
import '../../features/tasks/presentation/screens/search_screen.dart';
import '../../features/tasks/presentation/screens/task_detail_screen.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/not_found_screen.dart';
import 'route_guard.dart';
import 'splash_gate.dart';

export 'route_guard.dart' show AppRoutes;

int? _idParam(GoRouterState state) =>
    int.tryParse(state.pathParameters['id'] ?? '');

DateTime? _dateParam(GoRouterState state) =>
    DateTime.tryParse(state.uri.queryParameters['date'] ?? '');

Page<void> _fade(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

Page<void> _tab(GoRouterState state, Widget child) =>
    NoTransitionPage<void>(key: state.pageKey, child: child);

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, _) => refresh.value++);
  ref.listen(splashDoneProvider, (_, _) => refresh.value++);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => resolveRedirect(
      splashDone: ref.read(splashDoneProvider),
      isLoggedIn: ref.read(authProvider).value != null,
      location: state.matchedLocation,
    ),
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => AppRoutes.home),
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (_, state) => _fade(state, const LoginScreen()),
      ),
      GoRoute(
        path: AppRoutes.signup,
        pageBuilder: (_, state) => _fade(state, const SignupScreen()),
      ),
      ShellRoute(
        pageBuilder: (context, state, child) =>
            _fade(state, AppShell(location: state.uri.path, child: child)),
        routes: [
          GoRoute(
            path: AppRoutes.search,
            pageBuilder: (_, state) => _tab(state, const SearchScreen()),
          ),
          GoRoute(
            path: AppRoutes.calendar,
            pageBuilder: (_, state) => _tab(state, const CalendarScreen()),
          ),
          GoRoute(
            path: AppRoutes.stats,
            pageBuilder: (_, state) => _tab(state, const StatsScreen()),
          ),
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (_, state) => _tab(state, const HomeScreen()),
          ),
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (_, state) => _tab(state, const ProfileScreen()),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.addTask,
        builder: (_, state) =>
            AddEditTaskScreen(initialDate: _dateParam(state)),
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
