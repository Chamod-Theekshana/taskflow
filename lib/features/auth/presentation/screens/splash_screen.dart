import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants.dart';
import '../../../../core/routing/splash_gate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/ui.dart';
import '../../domain/entities/user.dart';
import '../providers/auth_provider.dart';

/// Plays a short intro while the saved session is restored, then tells the
/// router it may move on (to the task list, or to sign in).
///
/// The screen decides when it is done instead of the router guessing, so it
/// can neither flash past nor get stuck.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  static const _stages = [
    (until: 0.35, text: 'Retrieving your lists...'),
    (until: 0.70, text: 'Organizing daily flow...'),
    (until: 1.00, text: 'Ready for clarity.'),
  ];

  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  String? _welcome;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    // Completes with false if the screen goes away mid-animation.
    final intro = _progress.forward().orCancel.then(
      (_) => true,
      onError: (_) => false,
    );

    User? user;
    try {
      user = await ref.read(authProvider.future);
    } catch (_) {
      user = null; // Treated as signed out; the login screen takes over.
    }

    if (!await intro || !mounted) return;

    final name = user?.firstName ?? '';
    setState(() {
      _welcome = user == null
          ? "Let's get started"
          : (name.isEmpty ? 'Welcome back' : 'Welcome back, $name');
    });

    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (mounted) ref.read(splashDoneProvider.notifier).finish();
  }

  @override
  void dispose() {
    _progress.dispose();
    _pulse.dispose();
    super.dispose();
  }

  String _stageText(double value) {
    for (final stage in _stages) {
      if (value < stage.until) return stage.text;
    }
    return _stages.last.text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: Stack(
        children: [
          const Positioned.fill(child: RepaintBoundary(child: _Backdrop())),
          SafeArea(
            // Scrolls only when it has to (landscape, very large text).
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (box.maxHeight - 40).clamp(0.0, double.infinity),
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
    final colors = context.colors;
    final text = context.text;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(999),
            boxShadow: context.isDark ? null : AppShadows.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PulsingDot(color: colors.secondary),
              const SizedBox(width: 6),
              Text(
                'OFFLINE READY',
                style: text.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        const _Logo(),
        const SizedBox(height: 32),
        Wordmark(
          style: text.displayMedium?.copyWith(fontWeight: FontWeight.w700),
          dotSize: 8,
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Text(
            'Find your daily focus. Flow effortlessly through what '
            'matters.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 40),
        AnimatedBuilder(
          animation: _progress,
          builder: (context, _) => _Status(
            pulse: _pulse,
            text: _welcome ?? _stageText(_progress.value),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: 176,
          height: 6,
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(999),
          ),
          child: AnimatedBuilder(
            animation: _progress,
            builder: (context, _) => FractionallySizedBox(
              widthFactor: Curves.easeInOut.transform(_progress.value),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 15,
              color: colors.secondary,
            ),
            const SizedBox(width: 4),
            Text(
              'Stored on this device • 100% Private',
              style: text.labelSmall?.copyWith(
                color: colors.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'TaskFlow v$kAppVersion',
              style: text.labelSmall?.copyWith(
                color: colors.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 6),
            Dot(color: colors.outlineVariant, size: 4),
            const SizedBox(width: 6),
            Text(
              'Serene Focus',
              style: text.labelSmall?.copyWith(
                color: colors.onSurfaceVariant.withValues(alpha: 0.6),
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
    final colors = context.colors;
    return Pressable(
      scale: 0.95,
      onTap: () {},
      child: Container(
        width: 112,
        height: 112,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.28),
              blurRadius: 36,
              spreadRadius: 4,
            ),
            BoxShadow(
              color: colors.secondaryContainer.withValues(alpha: 0.35),
              blurRadius: 40,
              offset: const Offset(10, 12),
            ),
          ],
        ),
        child: const AppLogo(size: 104, radius: 28, glow: false),
      ),
    );
  }
}

/// "Syncing" pill: three breathing dots and the current step.
class _Status extends StatelessWidget {
  final Animation<double> pulse;
  final String text;

  const _Status({required this.pulse, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        boxShadow: context.isDark ? null : AppShadows.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: pulse,
            builder: (context, _) {
              final t = pulse.value;
              return Row(
                children: [
                  Transform.scale(
                    scale: 1 + t * 0.6,
                    child: Dot(
                      color: colors.primary.withValues(alpha: 1 - t * 0.7),
                      size: 6,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Dot(
                    color: colors.primary.withValues(
                      alpha: 0.4 + 0.3 * (1 - (2 * t - 1).abs()),
                    ),
                    size: 6,
                  ),
                  const SizedBox(width: 4),
                  Dot(color: colors.primary.withValues(alpha: 0.4), size: 6),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              text,
              key: ValueKey(text),
              style: context.text.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft coloured glows behind the splash content. Radial gradients instead
/// of a blur filter: they look the same and cost nothing to draw.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
          left: -150,
          child: glow(colors.primaryFixed.withValues(alpha: 0.55), 420),
        ),
        Positioned(
          top: size.height / 3 - 60,
          right: -170,
          child: glow(colors.surfaceContainerHigh.withValues(alpha: 0.8), 440),
        ),
        Positioned(
          bottom: -130,
          left: size.width / 4 - 60,
          child: glow(colors.secondaryFixed.withValues(alpha: 0.3), 400),
        ),
      ],
    );
  }
}
