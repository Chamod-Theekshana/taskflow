import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Set by the splash screen once the saved session is restored and the
/// intro has played. Until then the router keeps the user on the splash.
final splashDoneProvider = NotifierProvider<SplashDone, bool>(SplashDone.new);

class SplashDone extends Notifier<bool> {
  @override
  bool build() => false;

  void finish() => state = true;
}
