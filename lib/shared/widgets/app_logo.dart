import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The TaskFlow mark: an indigo tile with a check.
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
        boxShadow: glow
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Icon(
        Icons.task_alt_rounded,
        color: Colors.white,
        size: size * 0.56,
      ),
    );
  }
}

/// "TaskFlow" followed by the little brand dot.
class Wordmark extends StatelessWidget {
  final TextStyle? style;
  final double dotSize;

  const Wordmark({super.key, this.style, this.dotSize = 6});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('TaskFlow', style: style),
        SizedBox(width: dotSize * 0.7),
        Container(
          width: dotSize,
          height: dotSize,
          margin: EdgeInsets.only(top: dotSize * 0.4),
          decoration: BoxDecoration(
            color: context.colors.primary,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}
