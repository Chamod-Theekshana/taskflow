import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/route_guard.dart';

/// Bottom padding for scrollable screens inside the shell.
///
/// The shell's Scaffold uses `extendBody: true`, so inside the shell
/// `MediaQuery.padding.bottom` already includes the height of the floating
/// dock; adding a little breathing room keeps the last list item fully
/// visible above it.
double dockClearance(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom + 16;

class AppShell extends StatelessWidget {
  /// Current path (without query string), used to highlight the active tab.
  final String location;
  final Widget child;

  const AppShell({super.key, required this.location, required this.child});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Hide the dock while the keyboard is open (e.g. typing in search), it
    // would otherwise float above the keyboard and cover the content.
    final keyboardOpen = media.viewInsets.bottom > 0;

    // The dock is the Scaffold's bottomNavigationBar (with extendBody so the
    // content still scrolls behind it). That way SnackBars are laid out
    // above the dock instead of covering it.
    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: keyboardOpen
          ? null
          : Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + media.padding.bottom),
              child: _BottomNavDock(currentLocation: location),
            ),
    );
  }
}

class _BottomNavDock extends StatelessWidget {
  final String currentLocation;

  const _BottomNavDock({required this.currentLocation});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _NavItem(
            icon: Icons.check_circle_outline,
            activeIcon: Icons.check_circle,
            label: 'Home',
            isActive: currentLocation.startsWith(AppRoutes.home),
            onTap: () => context.go(AppRoutes.home),
          ),
          _NavItem(
            icon: Icons.calendar_today_outlined,
            activeIcon: Icons.calendar_today,
            label: 'Calendar',
            isActive: currentLocation.startsWith(AppRoutes.calendar),
            onTap: () => context.go(AppRoutes.calendar),
          ),
          Transform.translate(
            offset: const Offset(0, -16),
            child: Semantics(
              button: true,
              label: 'Add task',
              child: GestureDetector(
                onTap: () => context.push(AppRoutes.addTask),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: colorScheme.surface, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.add,
                    color: colorScheme.onPrimary,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
          _NavItem(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: 'Profile',
            isActive: currentLocation.startsWith(AppRoutes.profile),
            onTap: () => context.go(AppRoutes.profile),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isActive ? colorScheme.primary : colorScheme.outline;

    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 60,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isActive ? activeIcon : icon, color: color, size: 24),
              const SizedBox(height: 4),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: isActive ? color : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
