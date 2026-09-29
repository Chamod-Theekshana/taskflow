import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants.dart';
import '../../../../core/routing/route_guard.dart';
import '../../../../core/routing/splash_gate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/ui.dart';
import '../../domain/entities/user.dart';
import '../providers/auth_provider.dart';

enum _Stage { starting, signedIn, signedOut }

/// Plays a short intro while the saved session is restored.
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
    with TickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  _Stage _stage = _Stage.starting;
  String _name = '';
  bool _showActions = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(splashDoneProvider)) {
      // Back from sign in / sign up: the intro has already played.
      _progress.value = 1;
      _stage = _Stage.signedOut;
      _showActions = true;
    } else {
      _run();
    }
  }

  Future<void> _run() async {
    // Completes with false if the screen goes away mid-animation.
    final intro = _progress
        .animateTo(1, curve: Curves.easeOutCubic)
        .orCancel
        .then((_) => true, onError: (_) => false);

    User? user;
    try {
      user = await ref.read(authProvider.future);
    } catch (_) {
      user = null; // Treated as signed out.
    }
    if (!mounted) return;
    setState(() {
      _stage = user == null ? _Stage.signedOut : _Stage.signedIn;
      _name = user?.firstName ?? '';
    });

    if (!await intro || !mounted) return;

    if (user != null) {
      // A beat to read "Welcome back", then the router opens the tasks.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (mounted) ref.read(splashDoneProvider.notifier).finish();
    } else {
      ref.read(splashDoneProvider.notifier).finish();
      setState(() => _showActions = true);
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _pulse.dispose();
    super.dispose();
  }

  String get _statusText => switch (_stage) {
    _Stage.starting => 'Starting up',
    _Stage.signedIn =>
      _name.isEmpty ? 'Welcome back' : 'Welcome back, $_name',
    _Stage.signedOut => 'Welcome',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.canvas,
      body: Stack(
        children: [
          const Positioned.fill(child: RepaintBoundary(child: _Backdrop())),
          SafeArea(
            // Scrolls only when it has to (landscape, very large text).
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(0.0, box.maxHeight - 32),
                  ),
                  child: IntrinsicHeight(child: _content(context)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context) {
    final p = context.palette;
    final text = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(flex: 3),
        const Center(child: _Logo()),
        const SizedBox(height: 28),
        Center(
          child: Wordmark(
            style: text.displayMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 270),
            child: Text(
              'Streamline your daily focus & high-velocity execution.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: p.warm, height: 1.6),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: _StatusPill(pulse: _pulse, text: _statusText),
        ),
        const SizedBox(height: 16),
        Center(
          child: SizedBox(
            width: 240,
            child: AnimatedBuilder(
              animation: _progress,
              builder: (context, _) =>
                  _LoadingBar(value: _progress.value, pulse: _pulse),
            ),
          ),
        ),
        const Spacer(flex: 2),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 350),
          opacity: _showActions ? 1 : 0,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            offset: _showActions ? Offset.zero : const Offset(0, 0.15),
            child: IgnorePointer(
              ignoring: !_showActions,
              child: _Actions(
                onGetStarted: () => context.go(AppRoutes.signup),
                onLogIn: () => context.go(AppRoutes.login),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Dot(color: p.warmMuted.withValues(alpha: 0.6), size: 6),
            const SizedBox(width: 6),
            Text(
              'v$kAppVersion • Obsidian Kinetic'.toUpperCase(),
              style: text.labelSmall?.copyWith(
                fontSize: 10,
                letterSpacing: 1.2,
                color: p.warmMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        
      ),
      child: const AppLogo(size: 104, radius: 28, glow: false),
    );
  }
}

/// "Welcome back" pill with two alternately breathing dots.
class _StatusPill extends StatelessWidget {
  final Animation<double> pulse;
  final String text;

  const _StatusPill({required this.pulse, required this.text});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        // 0 -> 1 -> 0 over one cycle.
        final wave = 0.5 - 0.5 * math.cos(2 * math.pi * pulse.value);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: p.track.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Color.lerp(
                p.border,
                p.accent.withValues(alpha: 0.5),
                wave,
              )!,
            ),
            
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BreathingDot(color: p.accent, wave: wave),
              const SizedBox(width: 4),
              _BreathingDot(color: p.accentSoft, wave: 1 - wave),
              const SizedBox(width: 8),
              child!,
            ],
          ),
        );
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            text.toUpperCase(),
            key: ValueKey(text),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(
              color: p.warm,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _BreathingDot extends StatelessWidget {
  final Color color;
  final double wave;

  const _BreathingDot({required this.color, required this.wave});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.85 + 0.3 * wave,
      child: Opacity(
        opacity: 0.35 + 0.65 * wave,
        child: Dot(color: color, size: 6),
      ),
    );
  }
}

/// Thin progress bar with a travelling highlight and the percentage below.
class _LoadingBar extends StatelessWidget {
  final double value;
  final Animation<double> pulse;

  const _LoadingBar({required this.value, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final done = value >= 1;
    final style = context.text.labelSmall?.copyWith(color: p.warmMuted);
    return Column(
      children: [
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: p.track,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  colors: [p.accent, p.accentSoft, p.accent],
                ),
                
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: AnimatedBuilder(
                  animation: pulse,
                  builder: (context, _) => FractionalTranslation(
                    translation: Offset(-1 + 3 * pulse.value, 0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: 0.4),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                done ? 'Workspace ready' : 'Loading workspace',
                style: style,
              ),
            ),
            Text(
              '${(value * 100).round()}%',
              style: style?.copyWith(
                color: done ? p.accentSoft : p.warmMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
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




