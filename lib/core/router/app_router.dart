import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../screens/splash_screen.dart';
import '../../screens/login_screen.dart';
import '../../screens/signup_screen.dart';
import '../../screens/home_screen.dart';
import '../../screens/calendar_screen.dart';
import '../../screens/profile_screen.dart';
import '../../screens/add_edit_task_screen.dart';
import '../../screens/task_detail_screen.dart';
import '../../widgets/app_shell.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'shell');

class AppRouter {
  static GoRouter? _router;

  static GoRouter router(BuildContext context) {
    _router ??= GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/',
      redirect: (BuildContext context, GoRouterState state) {
        final authProvider =
            Provider.of<AuthProvider>(context, listen: false);
        final isAuthenticated = authProvider.isAuthenticated;

        final isAuthRoute = state.matchedLocation == '/login' ||
            state.matchedLocation == '/signup';
        final isSplashRoute = state.matchedLocation == '/';

        if (!isAuthenticated && !isAuthRoute && !isSplashRoute) {
          return '/login';
        }

        if (isAuthenticated && isAuthRoute) {
          return '/home';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/signup',
          builder: (context, state) => const SignupScreen(),
        ),
        ShellRoute(
          navigatorKey: _shellNavigatorKey,
          builder: (context, state, child) {
            return AppShell(child: child);
          },
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
            GoRoute(
              path: '/calendar',
              builder: (context, state) => const CalendarScreen(),
            ),
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/add-task',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const AddEditTaskScreen(),
        ),
        GoRoute(
          path: '/edit-task/:id',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '');
            return AddEditTaskScreen(taskId: id);
          },
        ),
        GoRoute(
          path: '/task/:id',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final id =
                int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
            return TaskDetailScreen(taskId: id);
          },
        ),
      ],
    );
    return _router!;
  }
}
