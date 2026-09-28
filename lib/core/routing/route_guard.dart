/// Route paths used across the app.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const signup = '/signup';
  static const home = '/home';
  static const calendar = '/calendar';
  static const profile = '/profile';
  static const addTask = '/add-task';

  static String task(int id) => '/task/$id';
  static String editTask(int id) => '/edit-task/$id';
}

/// Pure navigation guard, kept free of Flutter/Riverpod types so it can be
/// unit tested.
///
/// * While the saved session is still being restored, stay on the splash
///   screen.
/// * Signed-out users may only see the login and sign-up screens.
/// * Signed-in users never see splash / login / sign-up.
///
/// The original version counted `/splash` as an "auth route" that signed-out
/// users were allowed to stay on, so after start-up nothing ever navigated
/// away from the splash screen.
String? resolveAuthRedirect({
  required bool isRestoringSession,
  required bool isLoggedIn,
  required String location,
}) {
  final onSplash = location == AppRoutes.splash;
  final onAuthPage =
      location == AppRoutes.login || location == AppRoutes.signup;

  if (isRestoringSession) return onSplash ? null : AppRoutes.splash;
  if (!isLoggedIn) return onAuthPage ? null : AppRoutes.login;
  if (onSplash || onAuthPage) return AppRoutes.home;
  return null;
}
