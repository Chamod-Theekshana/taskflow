import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/routing/route_guard.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/ui.dart';
import '../../domain/entities/task.dart';
import '../providers/calendar_day_provider.dart';
import '../providers/task_provider.dart';
import '../widgets/task_card.dart';
import '../widgets/task_ui.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _month = _monthOf(ref.read(calendarDayProvider));

  static DateTime _monthOf(DateTime d) => DateTime(d.year, d.month);

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  void _goToday() {
    final today = DateTime.now();
    ref.read(calendarDayProvider.notifier).select(today);
    setState(() => _month = _monthOf(today));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taskListProvider);
    final selected = ref.watch(calendarDayProvider);
    final dayTasks = state.tasksOn(selected);
    final colors = context.colors;
    final text = context.text;

    return Column(
      children: [
        const AppHeader(subtitle: 'Calendar View'),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              dockClearance(context) + 72,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            DateFormat('MMMM y').format(_month),
                            style: text.headlineLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Pressable(
                          onTap: _goToday,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: context.isDark ? null : AppShadows.sm,
                            ),
                            child: Text(
                              'Today',
                              style: text.labelMedium?.copyWith(
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: context.isDark ? null : AppShadows.sm,
                    ),
                    child: Row(
                      children: [
                        _RoundIcon(
                          icon: Icons.chevron_left_rounded,
                          tooltip: 'Previous month',
                          onTap: () => _changeMonth(-1),
                        ),
                        const SizedBox(width: 4),
                        _RoundIcon(
                          icon: Icons.chevron_right_rounded,
                          tooltip: 'Next month',
                          onTap: () => _changeMonth(1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onHorizontalDragEnd: (details) {
                  final v = details.primaryVelocity ?? 0;
                  if (v.abs() > 250) _changeMonth(v < 0 ? 1 : -1);
                },
                child: _MonthGrid(
                  month: _month,
                  selected: selected,
                  tasks: state.tasks,
                  onSelect: (day) =>
                      ref.read(calendarDayProvider.notifier).select(day),
                ),
              ),
              const SizedBox(height: 24),
              _DayHeader(day: selected, tasks: dayTasks),
              const SizedBox(height: 16),
              if (dayTasks.isEmpty)
                EmptyState(
                  icon: Icons.event_available_outlined,
                  title: 'Nothing planned',
                  message: 'This day is free. Add a task to give it focus.',
                  action: TextButton.icon(
                    onPressed: () =>
                        context.push(AppRoutes.addTaskOn(selected)),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add a task'),
                  ),
                )
              else
                for (final task in dayTasks)
                  Padding(
                    key: ValueKey(task.id),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CalendarTaskTile(task: task),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        scale: 0.9,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 22, color: context.colors.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime selected;
  final List<Task> tasks;
  final ValueChanged<DateTime> onSelect;

  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.tasks,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final first = DateTime(month.year, month.month);
    final leading = first.weekday % 7; // Sunday first
    final days = daysInMonth(month.year, month.month);
    final cells = ((leading + days) / 7).ceil() * 7;
    final today = DateTime.now();

    final byDay = <int, List<Task>>{};
    for (final t in tasks) {
      if (t.dueDate.year == month.year && t.dueDate.month == month.month) {
        byDay.putIfAbsent(t.dueDate.day, () => []).add(t);
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: context.isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x080F172A),
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final d in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      d,
                      textAlign: TextAlign.center,
                      style: context.text.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (var row = 0; row < cells ~/ 7; row++)
            Padding(
              padding: EdgeInsets.only(bottom: row == cells ~/ 7 - 1 ? 0 : 8),
              child: Row(
                children: [
                  for (var col = 0; col < 7; col++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _dayCell(
                          context,
                          DateTime(
                            month.year,
                            month.month,
                            row * 7 + col - leading + 1,
                          ),
                          byDay,
                          today,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayCell(
    BuildContext context,
    DateTime day,
    Map<int, List<Task>> byDay,
    DateTime today,
  ) {
    final colors = context.colors;
    final text = context.text;

    if (day.month != month.month) {
      return SizedBox(
        height: 40,
        child: Center(
          child: Text(
            '${day.day}',
            style: text.labelMedium?.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.25),
            ),
          ),
        ),
      );
    }

    final isSelected = isSameDate(day, selected);
    final isToday = isSameDate(day, today);
    final dayTasks = [...?byDay[day.day]]
      ..sort((a, b) {
        if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
        return b.priority.index.compareTo(a.priority.index);
      });

    Color dotColor(Task t) {
      if (isSelected) {
        if (t.isCompleted) return colors.primaryFixedDim;
        return switch (t.priority) {
          TaskPriority.high => colors.errorContainer,
          TaskPriority.medium => colors.tertiaryFixed,
          TaskPriority.low => colors.secondaryFixed,
        };
      }
      if (t.isCompleted) return colors.outlineVariant;
      return priorityAccent(colors, t.priority);
    }

    final label = DateFormat('EEEE, MMMM d').format(day);
    final count = dayTasks.length;

    return Semantics(
      button: true,
      selected: isSelected,
      label: count == 0 ? label : '$label, ${plural(count, 'task')}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(day),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          scale: isSelected ? 1.05 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 40,
            decoration: BoxDecoration(
              color: isSelected ? colors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isSelected && !context.isDark
                  ? const [
                      BoxShadow(
                        color: Color(0x734648D4),
                        blurRadius: 14,
                        spreadRadius: -2,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.day}',
                  style: isSelected
                      ? text.headlineSmall?.copyWith(
                          color: colors.onPrimary,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        )
                      : text.labelMedium?.copyWith(
                          color: isToday ? colors.primary : colors.onSurface,
                          fontWeight: isToday ? FontWeight.w800 : null,
                        ),
                ),
                if (dayTasks.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final t in dayTasks.take(3))
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Dot(color: dotColor(t), size: 4),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final DateTime day;
  final List<Task> tasks;

  const _DayHeader({required this.day, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final now = DateTime.now();
    final diff = daysBetween(now, day);
    final title = switch (diff) {
      0 => "Today's Tasks",
      1 => "Tomorrow's Tasks",
      -1 => "Yesterday's Tasks",
      _ => "${DateFormat('EEEE').format(day)}'s Tasks",
    };
    final left = tasks.where((t) => !t.isCompleted).length;
    final badge = tasks.isEmpty
        ? 'No tasks'
        : left == 0
        ? 'All done'
        : left == tasks.length
        ? plural(tasks.length, 'task')
        : '$left left';

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: text.headlineSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Dot(color: colors.outlineVariant, size: 6),
              const SizedBox(width: 8),
              Text(
                DateFormat('MMM d').format(day),
                style: text.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Pill(
          label: badge,
          background: colors.primaryFixed,
          foreground: colors.onPrimaryFixed,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        ),
      ],
    );
  }
}

class _CalendarTaskTile extends ConsumerWidget {
  final Task task;

  const _CalendarTaskTile({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.text;
    final done = task.isCompleted;
    final id = task.id;

    final (pillBg, pillFg) = switch (task.priority) {
      TaskPriority.high => (colors.errorContainer, colors.onErrorContainer),
      TaskPriority.medium => (
        colors.tertiaryFixed,
        colors.onTertiaryFixedVariant,
      ),
      TaskPriority.low => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
    };
    final accent = switch (task.priority) {
      TaskPriority.high => colors.error,
      TaskPriority.medium => colors.tertiaryFixedDim,
      TaskPriority.low => colors.secondary,
    };

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: done ? 0.75 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: context.isDark ? null : AppShadows.card,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: id == null ? null : () => context.push(AppRoutes.task(id)),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 12,
                  bottom: 12,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: done ? colors.secondary : accent,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 16, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TaskCheckbox(
                        checked: done,
                        size: 22,
                        uncheckedColor: colors.surfaceContainerHigh,
                        onTap: () => toggleTaskDone(context, ref, task),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Opacity(
                                      opacity: done ? 0.4 : 1,
                                      child: Text(
                                        task.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: text.headlineSmall?.copyWith(
                                          decoration: done
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Pill(
                                    label: task.priority.label,
                                    background: pillBg,
                                    foreground: pillFg,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    style: text.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 12,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _Meta(
                                    leading: Icon(
                                      Icons.schedule_rounded,
                                      size: 15,
                                      color: colors.onSurfaceVariant,
                                    ),
                                    label: task.isAllDay
                                        ? 'All day'
                                        : DateFormat(
                                            'hh:mm a',
                                          ).format(task.deadline),
                                  ),
                                  if (task.category.isNotEmpty)
                                    _Meta(
                                      leading: Dot(
                                        color: categoryDotColor(
                                          colors,
                                          task.category,
                                        ),
                                        size: 6,
                                      ),
                                      label: task.category,
                                    ),
                                  if (task.repeat != RepeatRule.none)
                                    _Meta(
                                      leading: Icon(
                                        Icons.repeat_rounded,
                                        size: 15,
                                        color: colors.onSurfaceVariant,
                                      ),
                                      label: task.repeat.describe(task.dueDate),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final Widget leading;
  final String label;

  const _Meta({required this.leading, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        leading,
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
