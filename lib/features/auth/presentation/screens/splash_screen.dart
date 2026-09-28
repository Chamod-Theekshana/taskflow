import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/user.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _exitRequested = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // The session may already be restored by the time this screen mounts,
    // in which case the listener in build() never fires.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _leaveWhenReady(ref.read(authProvider)),
    );
  }

  /// Once the saved session is restored, ask the router to re-run its auth
  /// redirect (splash -> login or home). The router normally does this on
  /// its own; doing it here too guarantees the splash screen can never be
  /// left on screen after start-up has finished.
  void _leaveWhenReady(AsyncValue<User?> auth) {
    if (_exitRequested || !mounted || isRestoringSession(auth)) return;
    _exitRequested = true;
    // A microtask, so the router is never refreshed in the middle of a build.
    Future.microtask(() {
      if (mounted) GoRouter.of(context).refresh();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (_, next) => _leaveWhenReady(next));

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background orbs. They used to be solid circles blurred by a
          // full-screen BackdropFilter (sigma 50) that was re-rendered on
          // every frame of the two endless animations below. On the Android
          // emulator (Impeller on OpenGLES) that could stall rendering and
          // freeze the app on this screen. Radial gradients give the same
          // soft glow for free, and the RepaintBoundary keeps the animations
          // from repainting the background.
          Positioned.fill(
            child: RepaintBoundary(
              child: Stack(
                children: [
                  Positioned(
                    top: -150,
                    left: -150,
                    child: _buildOrb(
                      const Color(0xFF6366F1).withValues(alpha: 0.3),
                      400,
                    ),
                  ),
                  Positioned(
                    bottom: -100,
                    right: -150,
                    child: _buildOrb(
                      const Color(0xFF10B981).withValues(alpha: 0.2),
                      350,
                    ),
                  ),
                  Positioned(
                    top: 150,
                    right: -200,
                    child: _buildOrb(
                      const Color(0xFF818CF8).withValues(alpha: 0.2),
                      450,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                // Top Status Capsule
                Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            return Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colorScheme.secondary.withValues(
                                  alpha:
                                      0.3 + (_animationController.value * 0.7),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'OFFLINE READY',
                          style: textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                // Center Hero
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF818CF8), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.check_rounded,
                        color: Colors.white, size: 48),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'TaskFlow',
                      style: textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Find your daily focus. Flow effortlessly through what matters.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                // Sync Status
                Column(
                  children: [
                    Text(
                      'Getting things ready…',
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 200,
                      child: LinearProgressIndicator(
                        backgroundColor: colorScheme.surfaceContainerHigh,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Bottom
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_rounded,
                        size: 16, color: colorScheme.secondary),
                    const SizedBox(width: 6),
                    Text(
                      'Local-only • Your data stays on device',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'TaskFlow v1.0.0 • Serene Focus',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A soft glowing circle: full [color] in the middle fading to
  /// transparent at the edge (looks like a blurred circle, without a blur).
  Widget _buildOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color, color.withValues(alpha: 0)],
          stops: const [0, 0.4, 1],
        ),
      ),
    );
  }
}
