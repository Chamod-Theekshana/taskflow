abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const signup = '/signup';

  // Tabs, in dock order.
  static const search = '/search';
  static const calendar = '/calendar';
  static const stats = '/stats';
  static const home = '/home';
  static const profile = '/profile';

  static const addTask = '/add-task';

  static String task(int id) => '/task/$id';
  static String editTask(int id) => '/edit-task/$id';

  static String addTaskOn(DateTime day) {
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return '$addTask?date=${day.year}-$m-$d';
  }
}

/// Where the router should send the user, or null to stay put.
///
/// * Until the splash screen has finished, everything goes to the splash.
/// * Signed-out users can only see login and sign-up.
/// * Signed-in users never see splash, login or sign-up.
///
/// Kept free of Flutter types so it can be unit tested.
String? resolveRedirect({
  required bool splashDone,
  required bool isLoggedIn,
  required String location,
}) {
  final onSplash = location == AppRoutes.splash;
  final onAuthPage =
      location == AppRoutes.login || location == AppRoutes.signup;

  if (!splashDone) return onSplash ? null : AppRoutes.splash;
  if (!isLoggedIn) return onAuthPage ? null : AppRoutes.login;
  if (onSplash || onAuthPage) return AppRoutes.home;
  return null;
}
