import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../shared/widgets/ui.dart';
import '../../domain/entities/task.dart';

IconData categoryIcon(String category) {
  return switch (category.trim().toLowerCase()) {
    'work' => Icons.domain_rounded,
    'personal' => Icons.person_outline_rounded,
    'health' => Icons.favorite_border_rounded,
    'shopping' => Icons.shopping_bag_outlined,
    'strategy' => Icons.hub_outlined,
    'design' => Icons.palette_outlined,
    'meeting' || 'meetings' => Icons.group_outlined,
    'finance' => Icons.receipt_long_outlined,
    'study' || 'school' => Icons.school_outlined,
    'home' => Icons.home_outlined,
    _ => Icons.sell_outlined,
  };
}

/// Accent for the category chip icons on the add / edit screen.
Color categoryTint(AppPalette p, String category) {
  return switch (category.trim().toLowerCase()) {
    'work' => p.accent,
    'personal' => p.accentSoft,
    'health' => p.success,
    'shopping' => p.amber,
    _ => p.peach,
  };
}

/// Stable colour for a category in charts and on the calendar.
Color categoryDotColor(AppPalette p, String category) {
  final palette = [
    p.accent,
    const Color(0xFFFB923C),
    p.success,
    p.amber,
    p.peach,
  ];
  final key = category.trim().toLowerCase();
  if (key.isEmpty) return p.textMuted;
  var hash = 0;
  for (final unit in key.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return palette[hash % palette.length];
}

/// The strip on the left of task cards and the priority dots: orange for
/// high, peach for medium, slate for low.
Color priorityAccent(AppPalette p, TaskPriority priority) {
  return switch (priority) {
    TaskPriority.high => p.accent,
    TaskPriority.medium => p.peach,
    TaskPriority.low => p.low,
  };
}

/// Coloured badge for a priority, as used on the task cards.
class PriorityBadge extends StatelessWidget {
  final TaskPriority priority;
  final bool long;
  final bool pulse;

  const PriorityBadge({
    super.key,
    required this.priority,
    this.long = false,
    this.pulse = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return switch (priority) {
      TaskPriority.high => Pill(
        label: long ? 'High Priority' : 'High',
        background: p.accent.withValues(alpha: 0.2),
        foreground: p.accentSoft,
        border: p.accent.withValues(alpha: 0.3),
        dot: p.accent,
        pulseDot: pulse,
      ),
      TaskPriority.medium => Pill(
        label: 'Medium',
        background: p.peachTint,
        foreground: p.peachText,
        border: p.peach.withValues(alpha: 0.2),
        dot: p.peach,
      ),
      TaskPriority.low => Pill(
        label: 'Low',
        background: p.raised,
        foreground: p.textSecondary,
        border: p.border,
        dot: p.low,
      ),
    };
  }
}

class CategoryTag extends StatelessWidget {
  final String category;

  const CategoryTag({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pill(
      label: category,
      icon: categoryIcon(category),
      iconSize: 13,
      background: p.raised,
      foreground: p.textSecondary,
      border: p.border,
    );
  }
}

/// "Today, 2:00 PM", "Tomorrow, 10:00 AM", "Oct 26".
String dueText(Task task, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = daysBetween(current, task.dueDate);
  final time = task.isAllDay ? null : shortTime(task.deadline);
  final String day;
  if (diff == 0) {
    day = 'Today';
  } else if (diff == 1) {
    day = 'Tomorrow';
  } else if (diff == -1) {
    day = 'Yesterday';
  } else {
    day = DateFormat(
      task.dueDate.year == current.year ? 'MMM d' : 'MMM d, y',
    ).format(task.dueDate);
  }
  return time == null ? day : '$day, $time';
}

/// Due date badge: orange when a high-priority task is due today, rose when
/// overdue, neutral otherwise.
class DueBadge extends StatelessWidget {
  final Task task;

  const DueBadge({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final now = DateTime.now();
    final diff = daysBetween(now, task.dueDate);
    final overdue = task.isOverdue(now);
    final urgent = diff == 0 && task.priority == TaskPriority.high;

    final icon = overdue
        ? Icons.history_rounded
        : switch (diff) {
            0 => task.isAllDay ? Icons.today_rounded : Icons.schedule_rounded,
            1 => Icons.calendar_today_outlined,
            _ => Icons.event_outlined,
          };
    final label = overdue
        ? 'Overdue · ${dueText(task, now: now)}'
        : dueText(task, now: now);

    final Color bg;
    final Color fg;
    final Color border;
    if (overdue) {
      bg = p.danger.withValues(alpha: 0.12);
      fg = p.danger;
      border = p.danger.withValues(alpha: 0.3);
    } else if (urgent) {
      bg = p.accent.withValues(alpha: 0.15);
      fg = p.accent;
      border = p.accent.withValues(alpha: 0.3);
    } else {
      bg = p.raised;
      fg = p.textSecondary;
      border = p.border;
    }

    return Pill(
      label: label,
      icon: icon,
      background: bg,
      foreground: fg,
      border: border,
    );
  }
}

/// Round completion checkbox: a dark well that turns solid orange, with a
/// little pop when ticked.
class TaskCheckbox extends StatelessWidget {
  final bool checked;
  final VoidCallback? onTap;
  final double size;
  final String? semanticLabel;

  const TaskCheckbox({
    super.key,
    required this.checked,
    required this.onTap,
    this.size = 24,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      checked: checked,
      button: true,
      label: semanticLabel ?? (checked ? 'Mark as not done' : 'Mark as done'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: TweenAnimationBuilder<double>(
            key: ValueKey(checked),
            tween: Tween(begin: checked ? 1.2 : 1, end: 1),
            duration: const Duration(milliseconds: 180),
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: checked ? p.accent : p.well,
                border: Border.all(color: checked ? p.accent : p.border),
                boxShadow: null,
              ),
              child: checked
                  ? Icon(
                      Icons.check_rounded,
                      size: size * 0.67,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> confirmDelete(
  BuildContext context, {
  String title = 'Delete task?',
  String message = "This can't be undone.",
}) {
  return confirmAction(
    context,
    title: title,
    message: message,
    confirmLabel: 'Delete',
  );
}
