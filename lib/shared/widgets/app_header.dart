import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/route_guard.dart';
import '../../core/theme/app_theme.dart';
import 'app_logo.dart';
import 'ui.dart';
import 'user_avatar.dart';

/// Top bar of the tab screens: logo and name on the left, the user's avatar
/// (a shortcut to the profile) on the right.
class AppHeader extends StatelessWidget {
  final String? subtitle;
  final Widget? action;

  const AppHeader({super.key, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = context.text;
    return _HeaderBar(
      children: [
        const AppLogo(size: 36, radius: 12),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TaskFlow',
                style: text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: subtitle == null ? null : 1.15,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!.toUpperCase(),
                  style: text.labelSmall?.copyWith(
                    color: p.textSecondary,
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
            ],
          ),
        ),
        if (action != null) ...[action!, const SizedBox(width: 4)],
        const ProfileButton(),
      ],
    );
  }
}

/// Top bar of pushed screens (task details, add / edit): a square back
/// button, the logo and a title, with optional actions on the right.
class BackHeader extends StatelessWidget {
  final String title;
  final List<Widget> actions;

  const BackHeader({super.key, required this.title, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return _HeaderBar(
      children: [
        SquareIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: 'Back',
          onTap: () => closeScreen(context),
        ),
        const SizedBox(width: 12),
        const AppLogo(size: 32, radius: 11),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: context.text.headlineMedium,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        for (final action in actions) ...[const SizedBox(width: 8), action],
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
        child: Center(child: UserAvatar(size: 34)),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  final List<Widget> children;

  const _HeaderBar({required this.children});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(16, top, 12, 0),
      height: top + 64,
      decoration: BoxDecoration(
        color: p.canvas,
        border: Border(
          bottom: BorderSide(color: p.border.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(children: children),
    );
  }
}
