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

/// Accent for the category chip icon on the add / edit screen.
Color categoryTint(ColorScheme colors, String category) {
  return switch (category.trim().toLowerCase()) {
    'work' => colors.primary,
    'personal' || 'health' => colors.secondary,
    'shopping' => colors.tertiary,
    _ => colors.primary,
  };
}

/// Stable colour for a category's dot on the calendar and in stats.
Color categoryDotColor(ColorScheme colors, String category) {
  final palette = [
    colors.primary,
    colors.tertiaryContainer,
    colors.secondary,
    colors.primaryContainer,
    colors.error,
  ];
  final key = category.trim().toLowerCase();
  if (key.isEmpty) return colors.outline;
  var hash = 0;
  for (final unit in key.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return palette[hash % palette.length];
}

/// The vertical strip on the left of task cards.
Color priorityAccent(ColorScheme colors, TaskPriority priority) {
  return switch (priority) {
    TaskPriority.high => colors.error,
    TaskPriority.medium => colors.tertiary,
    TaskPriority.low => colors.secondary,
  };
}

/// Small coloured badge for a priority, as used on the task cards.
class PriorityBadge extends StatelessWidget {
  final TaskPriority priority;
  final bool long;

  const PriorityBadge({super.key, required this.priority, this.long = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return switch (priority) {
      TaskPriority.high => Pill(
        label: long ? 'High Priority' : 'High',
        background: colors.errorContainer.withValues(alpha: 0.6),
        foreground: colors.onErrorContainer,
        dot: colors.error,
        pulseDot: true,
      ),
      TaskPriority.medium => Pill(
        label: 'Medium',
        background: colors.tertiaryFixed,
        foreground: colors.onTertiaryFixed,
        dot: colors.tertiaryContainer,
      ),
      TaskPriority.low => Pill(
        label: 'Low',
        background: colors.secondaryContainer.withValues(alpha: 0.6),
        foreground: colors.onSecondaryContainer,
        dot: colors.secondary,
      ),
    };
  }
}

class CategoryTag extends StatelessWidget {
  final String category;
  final bool muted;

  const CategoryTag({super.key, required this.category, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Pill(
      label: category,
      icon: categoryIcon(category),
      iconSize: 13,
      background: muted ? colors.surfaceContainer : colors.surfaceContainerHigh,
      foreground: muted ? colors.outline : colors.onSurfaceVariant,
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

class DueBadge extends StatelessWidget {
  final Task task;

  const DueBadge({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final now = DateTime.now();
    final diff = daysBetween(now, task.dueDate);
    final overdue = task.isOverdue(now);
    final urgent = overdue || (diff == 0 && task.priority == TaskPriority.high);

    final icon = switch (diff) {
      0 when !task.isAllDay => Icons.schedule_rounded,
      1 => Icons.calendar_today_outlined,
      _ => Icons.event_outlined,
    };

    return Pill(
      label: overdue ? 'Overdue · ${dueText(task, now: now)}' : dueText(task),
      icon: overdue ? Icons.history_rounded : icon,
      background: urgent ? colors.errorContainer : colors.surfaceContainer,
      foreground: urgent ? colors.onErrorContainer : colors.onSurface,
      iconColor: urgent ? colors.onErrorContainer : colors.onSurfaceVariant,
    );
  }
}

/// Round completion checkbox with a little pop when ticked.
class TaskCheckbox extends StatelessWidget {
  final bool checked;
  final VoidCallback? onTap;
  final double size;
  final Color? uncheckedColor;
  final String? semanticLabel;

  const TaskCheckbox({
    super.key,
    required this.checked,
    required this.onTap,
    this.size = 24,
    this.uncheckedColor,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
                color: checked
                    ? colors.secondary
                    : (uncheckedColor ?? colors.surfaceContainerLowest),
                border: checked
                    ? null
                    : Border.all(
                        color: colors.outlineVariant.withValues(alpha: 0.7),
                        width: 1.5,
                      ),
              ),
              child: checked
                  ? Icon(
                      Icons.check_rounded,
                      size: size * 0.67,
                      color: colors.onSecondary,
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
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
