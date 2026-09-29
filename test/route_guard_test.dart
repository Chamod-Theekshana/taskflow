import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/core/routing/route_guard.dart';

void main() {
  String? redirect({
    bool splashDone = true,
    bool loggedIn = false,
    required String at,
  }) => resolveRedirect(
    splashDone: splashDone,
    isLoggedIn: loggedIn,
    location: at,
  );

  test('everything waits on the splash screen until it has finished', () {
    expect(redirect(splashDone: false, at: AppRoutes.splash), isNull);
    expect(
      redirect(splashDone: false, loggedIn: true, at: AppRoutes.home),
      AppRoutes.splash,
    );
  });

  test('signed-out users stay on the finished splash (the welcome page)', () {
    expect(redirect(at: AppRoutes.splash), isNull);
  });

  test('signed-out users can only use welcome, login and sign-up', () {
    expect(redirect(at: AppRoutes.login), isNull);
    expect(redirect(at: AppRoutes.signup), isNull);
    expect(redirect(at: AppRoutes.home), AppRoutes.login);
    expect(redirect(at: AppRoutes.profile), AppRoutes.login);
    expect(redirect(at: '/task/3'), AppRoutes.login);
  });

  test('signed-in users skip splash, login and sign-up', () {
    expect(redirect(loggedIn: true, at: AppRoutes.splash), AppRoutes.home);
    expect(redirect(loggedIn: true, at: AppRoutes.login), AppRoutes.home);
    expect(redirect(loggedIn: true, at: AppRoutes.signup), AppRoutes.home);
  });

  test('signed-in users can open every tab and task screen', () {
    for (final path in [
      AppRoutes.home,
      AppRoutes.search,
      AppRoutes.calendar,
      AppRoutes.stats,
      AppRoutes.profile,
      AppRoutes.task(7),
      AppRoutes.editTask(7),
    ]) {
      expect(redirect(loggedIn: true, at: path), isNull, reason: path);
    }
  });

  test('addTaskOn formats the date as a query parameter', () {
    expect(
      AppRoutes.addTaskOn(DateTime(2026, 3, 5)),
      '/add-task?date=2026-03-05',
    );
  });
}
