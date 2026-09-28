import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/core/routing/route_guard.dart';

void main() {
  group('resolveAuthRedirect', () {
    String? redirect({
      bool restoring = false,
      bool loggedIn = false,
      required String at,
    }) => resolveAuthRedirect(
      isRestoringSession: restoring,
      isLoggedIn: loggedIn,
      location: at,
    );

    test('stays on splash while the session is being restored', () {
      expect(redirect(restoring: true, at: AppRoutes.splash), isNull);
      expect(redirect(restoring: true, at: AppRoutes.home), AppRoutes.splash);
    });

    test('signed-out user leaves the splash screen for login (the bug)', () {
      expect(redirect(at: AppRoutes.splash), AppRoutes.login);
    });

    test('signed-out user may use login and sign-up only', () {
      expect(redirect(at: AppRoutes.login), isNull);
      expect(redirect(at: AppRoutes.signup), isNull);
      expect(redirect(at: AppRoutes.home), AppRoutes.login);
      expect(redirect(at: '/task/3'), AppRoutes.login);
    });

    test('signed-in user is sent home from splash / auth pages', () {
      expect(redirect(loggedIn: true, at: AppRoutes.splash), AppRoutes.home);
      expect(redirect(loggedIn: true, at: AppRoutes.login), AppRoutes.home);
      expect(redirect(loggedIn: true, at: AppRoutes.signup), AppRoutes.home);
    });

    test('signed-in user can open app screens', () {
      expect(redirect(loggedIn: true, at: AppRoutes.home), isNull);
      expect(redirect(loggedIn: true, at: AppRoutes.calendar), isNull);
      expect(redirect(loggedIn: true, at: '/task/7'), isNull);
    });
  });
}
