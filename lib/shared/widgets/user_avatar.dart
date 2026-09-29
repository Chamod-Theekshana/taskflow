import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

/// Initials of the signed-in user on a dark disc with an orange ring.
class UserAvatar extends ConsumerWidget {
  final double size;
  final bool ring;

  const UserAvatar({super.key, this.size = 32, this.ring = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
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
          colors: [p.accent.withValues(alpha: 0.28), p.raised],
        ),
        border: ring
            ? Border.all(
                color: p.accent.withValues(alpha: 0.4),
                width: size >= 56 ? 2 : 1,
              )
            : null,
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: size * 0.36,
          height: 1,
          fontWeight: FontWeight.w700,
          color: p.accentSoft,
        ),
      ),
    );
  }
}
