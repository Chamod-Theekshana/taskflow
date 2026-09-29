import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/routing/route_guard.dart';
import '../../core/theme/app_theme.dart';
import 'ui.dart';

/// Room the tab screens leave at the bottom so their last item clears the
/// floating dock. (With `extendBody` the dock's height is already part of
/// the bottom padding.)
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

/// Frame around the five main tabs: the notched dock at the bottom.
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

  @override
  Widget build(BuildContext context) {
    final index = _tabs.indexWhere((t) => widget.location.startsWith(t.path));
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      extendBody: true,
      backgroundColor: context.palette.canvas,
      body: widget.child,
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

/// The floating dock. The active tab sits in an orange disc that rides in a
/// notch cut into the top edge; both slide when the tab changes.
class _Dock extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;

  const _Dock({required this.index, required this.onSelect});

  static const height = 64.0;
  static const _inset = 8.0;
  static const _disc = 48.0;
  static const _discTop = 12.0; // shared with the painter so the notch hugs the disc

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
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
                    child: CustomPaint(
                      painter: _DockPainter(
                        notchX: notchX,
                        top: p.dockTop,
                        bottom: p.dockBottom,
                        stroke: p.border,
                        shadow: context.isDark
                            ? const Color(0xA6000000)
                            : const Color(0x24000000),
                      ),
                    ),
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
                    left: notchX - _disc / 2,
                    top: _discTop,
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
      child: Tooltip(
        message: tab.label,
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
                size: 23,
                color: context.palette.textSecondary,
              ),
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
    final p = context.palette;
    return ExcludeSemantics(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: _Dock._disc,
          height: _Dock._disc,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              colors: [p.accent, p.accentBright],
            ),
            border: Border.all(color: p.dockBottom, width: 2),
            boxShadow: [
              BoxShadow(
                color: p.accent.withValues(alpha: 0),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              tab.activeIcon,
              key: ValueKey(tab.path),
              size: 24,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill-shaped dock with a notch above the active tab. The notch is a real
/// circle arc concentric with the disc (so it hugs it), joined to the top
/// edge by two mirrored smooth shoulders.
class _DockPainter extends CustomPainter {
  final double notchX;
  final Color top;
  final Color bottom;
  final Color stroke;
  final Color shadow;

  _DockPainter({
    required this.notchX,
    required this.top,
    required this.bottom,
    required this.stroke,
    required this.shadow,
  });

  static const _radius = 32.0;
  static const _discR = _Dock._disc / 2; // 24
  static const _cy = _Dock._discTop + _discR; // disc center y = 36
  static const _gap = 1.0; // space between disc and notch wall
  static const _cradle = _discR + _gap; // notch circle radius = 25
  static const _flare = 10.0; // shoulder width from circle to top edge

  Path _outline(Size size) {
    final w = size.width;
    final h = size.height;
    final c = notchX;
    const cr = _cradle;
    final left = c - cr - _flare;
    final right = c + cr + _flare;
    // Near either end the notch eats into the rounded corner, so that top
    // corner gets tighter.
    final topLeft = left.clamp(0.0, _radius);
    final topRight = (w - right).clamp(0.0, _radius);

    return Path()
      ..moveTo(0, h / 2)
      ..lineTo(0, topLeft)
      ..arcToPoint(Offset(topLeft, 0), radius: Radius.circular(topLeft))
      ..lineTo(left, 0)
      // left shoulder: horizontal at the top edge -> vertical at the circle
      ..cubicTo(left + _flare * 0.9, 0, c - cr, _cy * 0.4, c - cr, _cy)
      // the cradle: circle arc around the disc (left -> bottom -> right)
      ..arcToPoint(
        Offset(c + cr, _cy),
        radius: const Radius.circular(cr),
        clockwise: false,
      )
      // right shoulder: exact mirror
      ..cubicTo(c + cr, _cy * 0.4, right - _flare * 0.9, 0, right, 0)
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
        ..color = shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [top, bottom],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = stroke,
    );
  }

  @override
  bool shouldRepaint(_DockPainter old) =>
      old.notchX != notchX ||
      old.top != top ||
      old.bottom != bottom ||
      old.stroke != stroke ||
      old.shadow != shadow;
}