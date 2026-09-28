import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/routing/route_guard.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/not_found_screen.dart';
import '../../../../shared/widgets/ui.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/task.dart';
import '../providers/task_provider.dart';
import '../widgets/task_card.dart';
import '../widgets/task_option_sheets.dart';
import '../widgets/task_ui.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  final int taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  final _subtaskController = TextEditingController();
  // Subtasks swiped away but not yet gone from the reloaded list.
  final _removedSubtasks = <int>{};
  bool _deleting = false;

  @override
  void dispose() {
    _subtaskController.dispose();
    super.dispose();
  }

  /// Runs [action], showing any error. Returns whether it succeeded.
  Future<bool> _run(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (e) {
      if (mounted) showMessage(context, describeError(e));
      return false;
    }
  }

  Future<void> _deleteSubtask(Subtask subtask) async {
    final id = subtask.id;
    if (id == null) return;
    setState(() => _removedSubtasks.add(id));
    final ok = await _run(
      () => ref.read(taskListProvider.notifier).deleteSubtask(id),
    );
    if (!ok && mounted) {
      // Let the dismissed row leave the tree before it comes back.
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) setState(() => _removedSubtasks.remove(id));
    }
  }

  Future<void> _delete(Task task) async {
    final id = task.id;
    if (id == null) return;
    final confirmed = await confirmDelete(context);
    if (!confirmed || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref.read(taskListProvider.notifier).deleteTask(id);
      if (!mounted) return;
      showMessage(context, 'Task deleted.');
      closeScreen(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      showMessage(context, describeError(e));
    }
  }

  Future<void> _reschedule(Task task) async {
    final today = dateOnly(DateTime.now());
    final day = await showDatePicker(
      context: context,
      initialDate: task.dueDate,
      firstDate: task.dueDate.isBefore(today) ? dateOnly(task.dueDate) : today,
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Reschedule to',
    );
    if (day == null || !mounted) return;

    var time = parseTimeOfDay(task.dueTime);
    if (!task.isAllDay) {
      final picked = await showTimePicker(
        context: context,
        initialTime: time ?? const TimeOfDay(hour: 9, minute: 0),
      );
      if (picked == null || !mounted) return;
      time = picked;
    }

    final ok = await _run(
      () => ref
          .read(taskListProvider.notifier)
          .updateTask(
            task.copyWith(
              dueDate: combineDateAndTime(day, task.isAllDay ? null : time),
              dueTime: task.isAllDay || time == null
                  ? ''
                  : formatTimeOfDay(time),
            ),
          ),
    );
    if (ok && mounted) showMessage(context, 'Moved to ${dayLabel(day)}.');
  }

  Future<void> _addSubtask(Task task) async {
    final title = _subtaskController.text.trim();
    final id = task.id;
    if (title.isEmpty || id == null) return;
    _subtaskController.clear();
    await _run(() => ref.read(taskListProvider.notifier).addSubtask(id, title));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taskListProvider);
    final task = state.taskById(widget.taskId);

    if (task == null) {
      if (state.isLoading || _deleting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return const NotFoundScreen(
        title: 'Task not found',
        message: 'This task no longer exists. It may have been deleted.',
      );
    }

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: Column(
        children: [
          const BackHeader(title: 'Task Details'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _ActionRow(
                  onEdit: () => context.push(AppRoutes.editTask(task.id!)),
                  onDelete: () => _delete(task),
                ),
                const SizedBox(height: 8),
                _Badges(task: task),
                const SizedBox(height: 12),
                _DueBanner(task: task, onReschedule: () => _reschedule(task)),
                const SizedBox(height: 16),
                Text(
                  task.title,
                  style: context.text.displayMedium?.copyWith(height: 1.25),
                ),
                const SizedBox(height: 16),
                _Notes(
                  text: task.description,
                  onTap: () => context.push(AppRoutes.editTask(task.id!)),
                ),
                const SizedBox(height: 32),
                _Subtasks(
                  task: task.copyWith(
                    subtasks: [
                      for (final s in task.subtasks)
                        if (!_removedSubtasks.contains(s.id)) s,
                    ],
                  ),
                  controller: _subtaskController,
                  onAdd: () => _addSubtask(task),
                  onToggle: (s) => _run(
                    () => ref.read(taskListProvider.notifier).toggleSubtask(s),
                  ),
                  onDelete: _deleteSubtask,
                ),
                const SizedBox(height: 32),
                _Activity(task: task),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _CompleteBar(
        done: task.isCompleted,
        onPressed: () => toggleTaskDone(context, ref, task),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;

  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.surfaceContainerLow,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: danger ? colors.errorContainer : null,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 20,
              color: danger ? colors.error : colors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ActionRow({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CircleButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back',
          onTap: () => closeScreen(context),
        ),
        const Spacer(),
        _CircleButton(
          icon: Icons.edit_outlined,
          tooltip: 'Edit task',
          onTap: onEdit,
        ),
        const SizedBox(width: 4),
        _CircleButton(
          icon: Icons.delete_outline_rounded,
          tooltip: 'Delete task',
          onTap: onDelete,
          danger: true,
        ),
      ],
    );
  }
}

class _Badges extends StatelessWidget {
  final Task task;

  const _Badges({required this.task});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = context.text.labelMedium;
    const padding = EdgeInsets.symmetric(horizontal: 12, vertical: 5);

    final (bg, fg, dot) = switch (task.priority) {
      TaskPriority.high => (
        colors.errorContainer,
        colors.onErrorContainer,
        colors.error,
      ),
      TaskPriority.medium => (
        colors.tertiaryFixed,
        colors.onTertiaryFixed,
        colors.tertiary,
      ),
      TaskPriority.low => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
        colors.secondary,
      ),
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Pill(
          label: '${task.priority.label} Priority',
          background: bg,
          foreground: fg,
          dot: dot,
          pulseDot: task.priority == TaskPriority.high && !task.isCompleted,
          style: label,
          padding: padding,
        ),
        if (task.category.isNotEmpty)
          Pill(
            label: task.category,
            icon: categoryIcon(task.category),
            background: colors.primaryFixed,
            foreground: colors.onPrimaryFixed,
            style: label,
            padding: padding,
          ),
        if (task.repeat != RepeatRule.none)
          Pill(
            label: task.repeat.describe(task.dueDate),
            icon: Icons.repeat_rounded,
            background: colors.surfaceContainerHigh,
            foreground: colors.onSurfaceVariant,
            style: label,
            padding: padding,
          ),
      ],
    );
  }
}

class _DueBanner extends StatelessWidget {
  final Task task;
  final VoidCallback onReschedule;

  const _DueBanner({required this.task, required this.onReschedule});

  String _title(DateTime now) {
    final diff = daysBetween(now, task.dueDate);
    final day = switch (diff) {
      0 => 'Today',
      1 => 'Tomorrow',
      -1 => 'Yesterday',
      _ => DateFormat('EEE, MMM d').format(task.dueDate),
    };
    if (task.isAllDay) return 'Due $day · All day';
    return 'Due $day at ${shortTime(task.deadline)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final now = DateTime.now();
    final done = task.isCompleted;
    final overdue = task.isOverdue(now);

    final Color tint;
    final Color iconBg;
    final Color iconColor;
    final IconData icon;
    if (done) {
      tint = colors.secondaryContainer.withValues(alpha: 0.3);
      iconBg = colors.secondaryContainer;
      iconColor = colors.onSecondaryContainer;
      icon = Icons.check_circle_outline_rounded;
    } else if (overdue) {
      tint = colors.errorContainer.withValues(alpha: 0.4);
      iconBg = colors.errorContainer;
      iconColor = colors.error;
      icon = Icons.history_rounded;
    } else {
      tint = colors.tertiaryFixed.withValues(alpha: 0.3);
      iconBg = colors.tertiaryFixed;
      iconColor = colors.tertiary;
      icon = Icons.schedule_rounded;
    }

    final completedAt = task.effectiveCompletedAt;
    final subtitle = done && completedAt != null
        ? 'Completed ${timeAgo(completedAt, now: now)}'
        : task.isAllDay && daysBetween(now, task.dueDate) == 0
        ? 'Any time today'
        : relativeDueLabel(task.deadline, now: now);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(16),
        boxShadow: context.isDark ? null : AppShadows.sm,
      ),
      child: Row(
        children: [
          IconTile(
            icon: icon,
            background: iconBg,
            color: iconColor,
            size: 40,
            radius: 12,
            iconSize: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title(now),
                  style: text.headlineSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Dot(color: iconColor, size: 6),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        subtitle,
                        style: text.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!done) ...[
            const SizedBox(width: 8),
            Pressable(
              onTap: onReschedule,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: context.isDark ? null : AppShadows.sm,
                ),
                child: Text(
                  'Reschedule',
                  style: text.labelMedium?.copyWith(color: colors.primary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Notes extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _Notes({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final empty = text.trim().isEmpty;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: empty ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.notes_rounded,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'DESCRIPTION & CONTEXT',
                    style: context.text.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SelectableText(
                empty ? 'No notes yet. Tap to add some context.' : text,
                onTap: empty ? onTap : null,
                style: context.text.bodyMedium?.copyWith(
                  height: 1.6,
                  color: empty ? colors.outline : colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Subtasks extends StatelessWidget {
  final Task task;
  final TextEditingController controller;
  final VoidCallback onAdd;
  final ValueChanged<Subtask> onToggle;
  final ValueChanged<Subtask> onDelete;

  const _Subtasks({
    required this.task,
    required this.controller,
    required this.onAdd,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final total = task.subtasks.length;
    final done = task.completedSubtasks;
    final progress = total == 0 ? 0.0 : done / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.checklist_rounded, size: 20, color: colors.primary),
            const SizedBox(width: 4),
            Text('Subtasks', style: text.headlineMedium),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '($done/$total completed)',
                style: text.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${(progress * 100).round()}%',
              style: text.labelMedium?.copyWith(color: colors.primary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 8,
              color: colors.primary,
              backgroundColor: colors.surfaceContainerHigh,
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final subtask in task.subtasks)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Dismissible(
              key: ValueKey('subtask-${subtask.id}'),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => onDelete(subtask),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: colors.onErrorContainer,
                ),
              ),
              child: _SubtaskRow(
                subtask: subtask,
                onTap: () => onToggle(subtask),
              ),
            ),
          ),
        if (total > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text(
              'Swipe a step to the left to remove it.',
              style: text.labelSmall?.copyWith(color: colors.outline),
            ),
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => onAdd(),
                  style: text.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Add a new subtask...',
                    hintStyle: text.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    fillColor: colors.surfaceContainerLow,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Pressable(
              onTap: onAdd,
              semanticLabel: 'Add subtask',
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: colors.primaryFixed,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: colors.onPrimaryFixed,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Add',
                      style: text.labelMedium?.copyWith(
                        color: colors.onPrimaryFixed,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SubtaskRow extends StatelessWidget {
  final Subtask subtask;
  final VoidCallback onTap;

  const _SubtaskRow({required this.subtask, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final done = subtask.isCompleted;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: context.isDark ? null : AppShadows.sm,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? colors.secondary
                        : colors.surfaceContainerHighest,
                  ),
                  child: done
                      ? Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: colors.onSecondary,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: done ? 0.45 : 1,
                    child: Text(
                      subtask.title,
                      style: context.text.bodyMedium?.copyWith(
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                    ),
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

class _Activity extends ConsumerWidget {
  final Task task;

  const _Activity({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final style = context.text.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final name = ref.watch(authProvider.select((a) => a.value?.firstName));

    Widget line(IconData icon, InlineSpan span) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text.rich(span, style: style)),
        ],
      ),
    );

    return SurfaceCard(
      radius: 16,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          line(
            Icons.account_circle_outlined,
            TextSpan(
              children: [
                TextSpan(text: 'Created ${dayAgo(task.createdAt)}'),
                if (name != null && name.isNotEmpty) ...[
                  const TextSpan(text: ' by '),
                  TextSpan(
                    text: name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                ],
              ],
            ),
          ),
          line(
            Icons.history_rounded,
            TextSpan(text: 'Last updated ${timeAgo(task.updatedAt)}'),
          ),
          if (task.reminder && !task.isCompleted)
            line(
              Icons.notifications_none_rounded,
              TextSpan(
                text: task.isAllDay
                    ? 'Reminder at 9:00 AM on the day'
                    : task.reminderMinutes <= 0
                    ? 'Reminder when it is due'
                    : 'Reminder ${reminderLabel(task.reminderMinutes)}',
              ),
            ),
        ],
      ),
    );
  }
}

class _CompleteBar extends StatelessWidget {
  final bool done;
  final VoidCallback onPressed;

  const _CompleteBar({required this.done, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      color: colors.surface.withValues(alpha: 0.94),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448),
          child: PrimaryButton(
            label: done ? 'Completed · Reopen Task' : 'Mark as Complete',
            icon: done ? Icons.restart_alt_rounded : Icons.check_circle_outline,
            iconAfter: false,
            height: 56,
            radius: 999,
            color: done ? colors.surfaceContainerHighest : colors.secondary,
            foreground: done ? colors.onSurface : colors.onSecondary,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}
