import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';

/// Initials avatar for the signed-in user.
///
/// Replaces the previous `NetworkImage('https://i.pravatar.cc/...')`, which
/// showed a stranger's photo, needed internet access in an offline-first app
/// and failed in release builds (no INTERNET permission).
class UserAvatar extends ConsumerWidget {
  final double radius;

  const UserAvatar({super.key, this.radius = 16});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = ref.watch(authProvider).value;
    final initials = user?.initials ?? '?';

    return CircleAvatar(
      radius: radius,
      backgroundColor: colorScheme.primaryFixed,
      child: Text(
        initials,
        style: TextStyle(
          color: colorScheme.onPrimaryFixed,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}
