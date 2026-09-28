import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/routing/route_guard.dart';
import '../../core/theme/app_theme.dart';
import '../../features/tasks/presentation/providers/calendar_day_provider.dart';
import 'ui.dart';

/// Room the tab screens leave at the bottom so their last item clears the
/// floating dock.
double dockClearance(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom + 24;

class _Tab {
  final String path;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _Tab(this.path, this.label, this.icon, this.activeIcon);
}

const _tabs = [
  _Tab(AppRoutes.search, 'Search', Icons.search_rounded, Icons.search_rounded),
  _Tab(
    AppRoutes.calendar,
    'Calendar',
    Icons.calendar_today_outlined,
    Icons.calendar_today_rounded,
  ),
  _Tab(
    AppRoutes.stats,
    'Stats',
    Icons.bar_chart_rounded,
    Icons.bar_chart_rounded,
  ),
  _Tab(
    AppRoutes.home,
    'Tasks',
    Icons.checklist_rounded,
    Icons.checklist_rounded,
  ),
  _Tab(
    AppRoutes.profile,
    'Profile',
    Icons.person_outline_rounded,
    Icons.person_rounded,
  ),
];

/// Frame around the five main tabs: the notched dock at the bottom and the
/// add button on the task list and calendar.
class AppShell extends ConsumerStatefulWidget {
  final String location;
  final Widget child;

  const AppShell({super.key, required this.location, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  StreamSubscription<int>? _reminderTaps;

  @override
  void initState() {
    super.initState();
    final notifications = NotificationService.instance;
    _reminderTaps = notifications.taskTaps.listen(_openTask);
    notifications.takeLaunchTaskId().then((id) {
      if (id != null) _openTask(id);
    });
  }

  @override
  void dispose() {
    _reminderTaps?.cancel();
    super.dispose();
  }

  void _openTask(int id) {
    if (mounted) context.push(AppRoutes.task(id));
  }

  void _addTask() {
    if (widget.location.startsWith(AppRoutes.calendar)) {
      context.push(AppRoutes.addTaskOn(ref.read(calendarDayProvider)));
    } else {
      context.push(AppRoutes.addTask);
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = _tabs.indexWhere((t) => widget.location.startsWith(t.path));
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final showAdd =
        widget.location.startsWith(AppRoutes.home) ||
        widget.location.startsWith(AppRoutes.calendar);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      extendBody: true,
      body: widget.child,
      floatingActionButton: showAdd && !keyboardOpen
          ? _AddButton(onTap: _addTask)
          : null,
      bottomNavigationBar: keyboardOpen
          ? null
          : Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 20 + bottomInset),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: _Dock(
                    index: index < 0 ? 3 : index,
                    onSelect: (i) => context.go(_tabs[i].path),
                  ),
                ),
              ),
            ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: 'Add task',
      onTap: onTap,
      scale: 0.92,
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: AppColors.indigo,
          shape: BoxShape.circle,
          boxShadow: AppShadows.fab,
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

/// The floating indigo dock. The active tab sits in a white disc that rides
/// in a notch cut into the top edge; both slide when the tab changes.
class _Dock extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;

  const _Dock({required this.index, required this.onSelect});

  static const height = 64.0;
  static const _inset = 8.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final slot = (width - 2 * _inset) / _tabs.length;
          double centerOf(int i) => _inset + slot * (i + 0.5);

          return TweenAnimationBuilder<double>(
            tween: Tween(begin: centerOf(index), end: centerOf(index)),
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic,
            builder: (context, notchX, _) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _DockPainter(notchX)),
                  ),
                  Positioned.fill(
                    left: _inset,
                    right: _inset,
                    child: Row(
                      children: [
                        for (var i = 0; i < _tabs.length; i++)
                          SizedBox(
                            width: slot,
                            child: _DockIcon(
                              tab: _tabs[i],
                              selected: i == index,
                              onTap: () => onSelect(i),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: notchX - 24,
                    top: 4,
                    child: _ActiveDisc(
                      tab: _tabs[index],
                      onTap: () => onSelect(index),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _DockIcon extends StatelessWidget {
  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  const _DockIcon({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.9,
        child: SizedBox(
          height: _Dock.height,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: selected ? 0 : 1,
            child: Icon(
              tab.icon,
              size: 24,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveDisc extends StatelessWidget {
  final _Tab tab;
  final VoidCallback onTap;

  const _ActiveDisc({required this.tab, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.22),
                spreadRadius: 4,
              ),
              const BoxShadow(
                color: Color(0x2E000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              tab.activeIcon,
              key: ValueKey(tab.path),
              size: 24,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _DockPainter extends CustomPainter {
  final double notchX;

  _DockPainter(this.notchX);

  static const _radius = 32.0;
  static const _notchHalf = 36.0;
  static const _notchDepth = 24.0;

  Path _outline(Size size) {
    final w = size.width;
    final h = size.height;
    final c = notchX;
    final left = c - _notchHalf;
    final right = c + _notchHalf;
    // Near either end the notch eats into the corner, so that top corner
    // gets smaller (as in the profile design).
    final topLeft = left.clamp(0.0, _radius);
    final topRight = (w - right).clamp(0.0, _radius);
    const d = _notchDepth;

    return Path()
      ..moveTo(0, h / 2)
      ..lineTo(0, topLeft)
      ..arcToPoint(Offset(topLeft, 0), radius: Radius.circular(topLeft))
      ..lineTo(left, 0)
      ..cubicTo(c - 29.5, 0, c - 24.5, d * 0.1, c - 21.5, d * 0.29)
      ..cubicTo(c - 16.5, d * 0.6, c - 9.5, d, c, d)
      ..cubicTo(c + 9.5, d, c + 16.5, d * 0.6, c + 21.5, d * 0.29)
      ..cubicTo(c + 24.5, d * 0.1, c + 29.5, 0, right, 0)
      ..lineTo(w - topRight, 0)
      ..arcToPoint(Offset(w, topRight), radius: Radius.circular(topRight))
      ..lineTo(w, h / 2)
      ..arcToPoint(
        Offset(w - _radius, h),
        radius: const Radius.circular(_radius),
      )
      ..lineTo(_radius, h)
      ..arcToPoint(Offset(0, h / 2), radius: const Radius.circular(_radius))
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _outline(size);

    canvas.drawPath(
      path.shift(const Offset(0, 12)),
      Paint()
        ..color = const Color(0x524648D4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawPath(
      path,
      Paint()..shader = AppColors.dockGradient.createShader(Offset.zero & size),
    );

    // Faint highlight along the top edge.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, _notchDepth + 2));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.2),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DockPainter old) => old.notchX != notchX;
}
