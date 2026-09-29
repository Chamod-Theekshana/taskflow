import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
    final p = context.palette;
    final text = context.text;
    final state = ref.watch(taskListProvider);
    final selected = ref.watch(calendarDayProvider);
    final dayTasks = state.tasksOn(selected);

    return Column(
      children: [
        const AppHeader(subtitle: 'Calendar'),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              dockClearance(context),
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
                        const SizedBox(width: 10),
                        Pressable(
                          onTap: _goToday,
                          semanticLabel: 'Go to today',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: p.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: p.accent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              'Today',
                              style: text.labelSmall?.copyWith(
                                color: p.accent,
                                fontWeight: FontWeight.w600,
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
                      color: p.card,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: p.border),
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
              const SizedBox(height: 20),
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
              const SizedBox(height: 14),
              if (dayTasks.isEmpty)
                const EmptyState(
                  icon: Icons.event_available_outlined,
                  title: 'Nothing planned',
                  message: 'This day is free. Add a task to give it focus.',
                )
              else
                for (final task in dayTasks)
                  Padding(
                    key: ValueKey(task.id),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TaskCard(task: task),
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
        semanticLabel: tooltip,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 22, color: context.palette.textSecondary),
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
    final p = context.palette;
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

    return Panel(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
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
                        color: p.textMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (var row = 0; row < cells ~/ 7; row++)
            Padding(
              padding: EdgeInsets.only(bottom: row == cells ~/ 7 - 1 ? 0 : 6),
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
    final p = context.palette;
    final text = context.text;

    if (day.month != month.month) {
      return SizedBox(
        height: 42,
        child: Center(
          child: Text(
            '${day.day}',
            style: text.labelMedium?.copyWith(color: p.textFaint),
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
        return Colors.white.withValues(alpha: t.isCompleted ? 0.45 : 0.95);
      }
      if (t.isCompleted) return p.textFaint;
      return priorityAccent(p, t.priority);
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 42,
          decoration: BoxDecoration(
            color: isSelected ? p.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isToday && !isSelected
                  ? p.accent.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
            boxShadow: null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: text.labelMedium?.copyWith(
                  height: 1.1,
                  color: isSelected
                      ? Colors.white
                      : isToday
                      ? p.accent
                      : p.text,
                  fontWeight: isSelected || isToday
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
              if (dayTasks.isNotEmpty) ...[
                const SizedBox(height: 3),
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
    );
  }
}

class _DayHeader extends StatelessWidget {
  final DateTime day;
  final List<Task> tasks;

  const _DayHeader({required this.day, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
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
              Dot(color: p.textFaint, size: 5),
              const SizedBox(width: 8),
              Text(
                DateFormat('MMM d').format(day),
                style: text.bodyMedium?.copyWith(color: p.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Pill(
          label: badge,
          background: p.accent.withValues(alpha: 0.15),
          foreground: p.accentSoft,
          border: p.accent.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        ),
      ],
    );
  }
}
