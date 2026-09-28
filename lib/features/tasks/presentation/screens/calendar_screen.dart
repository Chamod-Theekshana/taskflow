import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/routing/route_guard.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../domain/entities/task.dart';
import '../providers/task_provider.dart';
import '../widgets/task_ui.dart';

final DateTime _firstDay = DateTime(2000, 1, 1);
final DateTime _lastDay = DateTime(2100, 12, 31);

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = dateOnly(DateTime.now());

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _focusedDay = now;
      _selectedDay = dateOnly(now);
    });
  }

  void _shiftMonth(int delta) {
    final target = DateTime(_focusedDay.year, _focusedDay.month + delta, 1);
    if (target.isBefore(_firstDay) || target.isAfter(_lastDay)) return;
    setState(() => _focusedDay = target);
  }

  Future<void> _toggle(Task task) async {
    try {
      await ref.read(taskListProvider.notifier).toggleComplete(task);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final taskState = ref.watch(taskListProvider);
    final selectedDayTasks = taskState.tasksOn(_selectedDay);
    final isTodaySelected = isSameDate(_selectedDay, DateTime.now());
    final selectedLabel = isTodaySelected
        ? "Today's Tasks • ${DateFormat('MMM d').format(_selectedDay)}"
        : 'Tasks • ${DateFormat('EEE, MMM d').format(_selectedDay)}';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: Text(
          'Calendar',
          style: textTheme.headlineSmall?.copyWith(color: colorScheme.onSurface),
        ),
        centerTitle: false,
      ),
      // A single scroll view: the old fixed Column + Expanded list overflowed
      // on short screens and its last items sat behind the navigation dock.
      body: ListView(
        padding: EdgeInsets.only(bottom: dockClearance(context)),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('MMMM y').format(_focusedDay),
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _goToToday,
                  style: TextButton.styleFrom(
                    backgroundColor: colorScheme.surfaceContainer,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Today',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Previous month',
                  icon: Icon(Icons.chevron_left, color: colorScheme.onSurface),
                  onPressed: () => _shiftMonth(-1),
                ),
                IconButton(
                  tooltip: 'Next month',
                  icon: Icon(Icons.chevron_right, color: colorScheme.onSurface),
                  onPressed: () => _shiftMonth(1),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.only(bottom: 8),
              child: TableCalendar<Task>(
                firstDay: _firstDay,
                lastDay: _lastDay,
                focusedDay: _focusedDay,
                startingDayOfWeek: StartingDayOfWeek.monday,
                availableGestures: AvailableGestures.horizontalSwipe,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: taskState.tasksOn,
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = dateOnly(selectedDay);
                    _focusedDay = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) {
                  // Keep the header in sync when swiping between months.
                  setState(() => _focusedDay = focusedDay);
                },
                headerVisible: false,
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: true,
                  defaultTextStyle: TextStyle(color: colorScheme.onSurface),
                  weekendTextStyle: TextStyle(color: colorScheme.onSurface),
                  outsideTextStyle: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  selectedDecoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: TextStyle(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  todayDecoration: BoxDecoration(
                    color: colorScheme.primaryFixed,
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: TextStyle(
                    color: colorScheme.onPrimaryFixed,
                    fontWeight: FontWeight.bold,
                  ),
                  markerDecoration: BoxDecoration(
                    color: colorScheme.tertiary,
                    shape: BoxShape.circle,
                  ),
                  markersMaxCount: 3,
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                  weekendStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    selectedLabel,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${selectedDayTasks.length} '
                    '${selectedDayTasks.length == 1 ? 'task' : 'tasks'}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (taskState.isLoading && taskState.tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (selectedDayTasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No tasks for this day',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
              ),
            )
          else
            ...selectedDayTasks.map(
              (task) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _CalendarTaskTile(
                  task: task,
                  onTap: task.id == null
                      ? null
                      : () => context.push(AppRoutes.task(task.id!)),
                  onToggle: task.id == null ? null : () => _toggle(task),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CalendarTaskTile extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;

  const _CalendarTaskTile({required this.task, this.onTap, this.onToggle});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final timeLabel = task.isAllDay || task.dueTime.isEmpty
        ? 'All day'
        : task.dueTime;

    return Material(
      color: colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6,
                color: priorityAccent(colorScheme, task.priority),
              ),
              IconButton(
                tooltip: task.isCompleted ? 'Mark as not done' : 'Mark as done',
                onPressed: onToggle,
                icon: Icon(
                  task.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                  color: task.isCompleted
                      ? colorScheme.secondary
                      : colorScheme.outline,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            timeLabel,
                            style: textTheme.bodySmall?.copyWith(
                              color: task.isOverdue()
                                  ? colorScheme.error
                                  : colorScheme.outline,
                            ),
                          ),
                          if (task.category.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryFixed,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                task.category,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onPrimaryFixedVariant,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}
