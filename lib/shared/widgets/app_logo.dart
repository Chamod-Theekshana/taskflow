import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The TaskFlow mark: an orange tile with a white check ring.
class AppLogo extends StatelessWidget {
  final double size;
  final double? radius;
  final bool glow;

  const AppLogo({super.key, this.size = 36, this.radius, this.glow = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.logoGradient,
        borderRadius: BorderRadius.circular(radius ?? size / 3),
        boxShadow: null,
      ),
      child: Icon(
        Icons.task_alt_rounded,
        color: Colors.white,
        size: size * 0.62,
      ),
    );
  }
}

/// "TaskFlow" followed by the orange full stop from the splash screen.
class Wordmark extends StatelessWidget {
  final TextStyle? style;

  const Wordmark({super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final base = style ?? context.text.displayMedium;
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'TaskFlow'),
          TextSpan(
            text: ' .',
            style: TextStyle(
              color: context.palette.accentSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      style: base,
    );
  }
}
