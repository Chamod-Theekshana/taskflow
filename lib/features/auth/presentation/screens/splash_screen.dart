import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_guard.dart';
import '../../../../core/routing/splash_gate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/ui.dart';
import '../../domain/entities/user.dart';
import '../providers/auth_provider.dart';

/// Shows the logo while the saved session is restored (it's read from the
/// device, so this takes a moment only).
///
/// Signed-in users then go straight to their tasks. Signed-out users stay
/// here: the screen doubles as the welcome page with "Get Started" and
/// "Log In".
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _intro,
    curve: Curves.easeOutCubic,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 0.9,
    end: 1,
  ).animate(_fade);

  bool _showActions = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(splashDoneProvider)) {
      // Back from sign in / sign up: the intro has already played.
      _intro.value = 1;
      _showActions = true;
    } else {
      _run();
    }
  }

  Future<void> _run() async {
    // Completes with false if the screen goes away mid-animation.
    final intro = _intro.forward().orCancel.then(
      (_) => true,
      onError: (_) => false,
    );

    User? user;
    try {
      user = await ref.read(authProvider.future);
    } catch (_) {
      user = null; // Treated as signed out.
    }
    if (!await intro || !mounted) return;

    ref.read(splashDoneProvider.notifier).finish();
    if (user == null) setState(() => _showActions = true);
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return Scaffold(
      backgroundColor: context.palette.canvas,
      body: Stack(
        children: [
          const Positioned.fill(child: RepaintBoundary(child: _Backdrop())),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 3),
                  FadeTransition(
                    opacity: _fade,
                    child: ScaleTransition(
                      scale: _scale,
                      child: Column(
                        children: [
                          const AppLogo(size: 96, radius: 28, glow: false),
                          const SizedBox(height: 24),
                          Wordmark(
                            style: text.displayMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _showActions ? 1 : 0,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      offset: _showActions
                          ? Offset.zero
                          : const Offset(0, 0.15),
                      child: IgnorePointer(
                        ignoring: !_showActions,
                        child: _Actions(
                          onGetStarted: () => context.go(AppRoutes.signup),
                          onLogIn: () => context.go(AppRoutes.login),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onLogIn;

  const _Actions({required this.onGetStarted, required this.onLogIn});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryButton(
          label: 'Get Started',
          icon: Icons.arrow_forward_rounded,
          height: 52,
          textStyle: text.labelLarge,
          onPressed: onGetStarted,
        ),
        const SizedBox(height: 8),
        Pressable(
          onTap: onLogIn,
          semanticLabel: 'Log in',
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Already have an account? '),
                  TextSpan(
                    text: 'Log In',
                    style: TextStyle(
                      color: p.accentSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: p.warm),
            ),
          ),
        ),
      ],
    );
  }
}

/// Soft orange glows behind the content. Radial gradients instead of a blur
/// filter: they look the same and cost nothing to draw.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final size = MediaQuery.sizeOf(context);

    Widget glow(Color color, double diameter) => Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );

    return Stack(
      children: [
        Positioned(
          top: -140,
          left: size.width / 2 - 220,
          child: glow(p.accent.withValues(alpha: 0.22), 440),
        ),
        Positioned(
          top: size.height / 3 - 60,
          left: size.width / 2 - 170,
          child: glow(const Color(0xFFEC6A06).withValues(alpha: 0.12), 340),
        ),
      ],
    );
  }
}
