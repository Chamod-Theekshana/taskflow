import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

/// Initials of the signed-in user on a soft indigo disc.
class UserAvatar extends ConsumerWidget {
  final double size;

  const UserAvatar({super.key, this.size = 32});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final initials = ref.watch(authProvider).value?.initials ?? '?';

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primaryFixed, colors.surfaceContainerHigh],
        ),
      ),
      child: Text(
        initials,
        style: context.text.labelLarge?.copyWith(
          fontSize: size * 0.36,
          height: 1,
          fontWeight: FontWeight.w700,
          color: colors.onPrimaryFixedVariant,
        ),
      ),
    );
  }
}
