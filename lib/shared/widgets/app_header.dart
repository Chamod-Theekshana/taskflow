import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/route_guard.dart';
import '../../core/theme/app_theme.dart';
import 'app_logo.dart';
import 'ui.dart';
import 'user_avatar.dart';

/// Top bar of the tab screens: logo and title on the left, the user's
/// avatar (a shortcut to the profile) on the right.
class AppHeader extends StatelessWidget {
  final String? subtitle;

  const AppHeader({super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return _HeaderBar(
      children: [
        const AppLogo(size: 36, radius: 12),
        const SizedBox(width: 8),
        if (subtitle == null)
          Text(
            'TaskFlow',
            style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          )
        else
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TaskFlow',
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              Text(
                subtitle!,
                style: text.labelSmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        const Spacer(),
        const ProfileButton(),
      ],
    );
  }
}

/// Top bar of pushed screens (task details, add / edit).
class BackHeader extends StatelessWidget {
  final String title;

  const BackHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return _HeaderBar(
      children: [
        Transform.translate(
          offset: const Offset(-8, 0),
          child: IconButton(
            tooltip: 'Back',
            onPressed: () => closeScreen(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
          ),
        ),
        const AppLogo(size: 28, radius: 9),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: context.text.headlineMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const UserAvatar(size: 32),
      ],
    );
  }
}

/// Pops the current screen, or goes to the task list when there is nothing
/// to pop (e.g. the screen was opened from a notification).
void closeScreen(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(AppRoutes.home);
  }
}

class ProfileButton extends StatelessWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: 'Profile',
      onTap: () => context.go(AppRoutes.profile),
      child: const SizedBox(
        width: 44,
        height: 44,
        child: Center(child: UserAvatar(size: 32)),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  final List<Widget> children;

  const _HeaderBar({required this.children});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top, 16, 0),
      height: top + 64,
      decoration: BoxDecoration(
        color: context.colors.surface,
        boxShadow: context.isDark ? null : AppShadows.header,
      ),
      child: Row(children: children),
    );
  }
}
