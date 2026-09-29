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
    final ok = await _run(
      () => ref.read(taskListProvider.notifier).addSubtask(id, title),
    );
    // Keep what was typed if it couldn't be saved.
    if (ok && mounted) _subtaskController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taskListProvider);
    final task = state.taskById(widget.taskId);
    final p = context.palette;

    if (task == null) {
      if (state.isLoading || _deleting) {
        return Scaffold(
          backgroundColor: p.canvas,
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      return const NotFoundScreen(
        title: 'Task not found',
        message: 'This task no longer exists. It may have been deleted.',
      );
    }

    final id = task.id!;
    return Scaffold(
      backgroundColor: p.canvas,
      body: Column(
        children: [
          BackHeader(
            title: 'Task Details',
            actions: [
              SquareIconButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit task',
                onTap: () => context.push(AppRoutes.editTask(id)),
              ),
              SquareIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Delete task',
                color: p.danger,
                onTap: () => _delete(task),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              children: [
                _Badges(task: task),
                const SizedBox(height: 14),
                Text(
                  task.title,
                  style: context.text.displayMedium?.copyWith(
                    height: 1.25,
                    color: task.isCompleted ? p.textSecondary : p.text,
                    decoration: task.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                    decorationColor: p.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                _DueBanner(task: task, onReschedule: () => _reschedule(task)),
                const SizedBox(height: 12),
                _Notes(
                  text: task.description,
                  onTap: () => context.push(AppRoutes.editTask(id)),
                ),
                const SizedBox(height: 28),
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
                const SizedBox(height: 28),
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

class _Badges extends StatelessWidget {
  final Task task;

  const _Badges({required this.task});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        PriorityBadge(
          priority: task.priority,
          long: true,
          pulse: !task.isCompleted,
        ),
        if (task.category.isNotEmpty) CategoryTag(category: task.category),
        if (task.repeat != RepeatRule.none)
          Pill(
            label: task.repeat.describe(task.dueDate),
            icon: Icons.repeat_rounded,
            background: p.raised,
            foreground: p.textSecondary,
            border: p.border,
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
    final p = context.palette;
    final text = context.text;
    final now = DateTime.now();
    final done = task.isCompleted;
    final overdue = task.isOverdue(now);

    final Color tone;
    final IconData icon;
    if (done) {
      tone = p.success;
      icon = Icons.check_circle_outline_rounded;
    } else if (overdue) {
      tone = p.danger;
      icon = Icons.history_rounded;
    } else {
      tone = p.accent;
      icon = Icons.schedule_rounded;
    }

    final completedAt = task.effectiveCompletedAt;
    final subtitle = done && completedAt != null
        ? 'Completed ${timeAgo(completedAt, now: now)}'
        : task.isAllDay && daysBetween(now, task.dueDate) == 0
        ? 'Any time today'
        : relativeDueLabel(task.deadline, now: now);

    return Panel(
      radius: 16,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          IconTile(icon: icon, color: tone, size: 42, radius: 14),
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
                const SizedBox(height: 2),
                Row(
                  children: [
                    Dot(color: tone, size: 6),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        subtitle,
                        style: text.bodySmall?.copyWith(
                          color: p.textSecondary,
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
              semanticLabel: 'Reschedule',
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: p.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: p.accent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Reschedule',
                  style: text.labelSmall?.copyWith(
                    color: p.accent,
                    fontWeight: FontWeight.w600,
                  ),
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
    final p = context.palette;
    final empty = text.trim().isEmpty;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: empty ? onTap : null,
      child: Panel(
        radius: 16,
        color: p.cardMuted,
        shadow: false,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notes_rounded, size: 16, color: p.warmMuted),
                const SizedBox(width: 6),
                Text(
                  'DESCRIPTION & CONTEXT',
                  style: context.text.labelSmall?.copyWith(
                    color: p.warmMuted,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(
              empty ? 'No notes yet. Tap to add some context.' : text,
              onTap: empty ? onTap : null,
              style: context.text.bodyMedium?.copyWith(
                height: 1.6,
                color: empty ? p.textMuted : p.text,
              ),
            ),
          ],
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
    final p = context.palette;
    final text = context.text;
    final total = task.subtasks.length;
    final done = task.completedSubtasks;
    final progress = total == 0 ? 0.0 : done / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.checklist_rounded, size: 20, color: p.accent),
            const SizedBox(width: 6),
            Text('Subtasks', style: text.headlineMedium),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$done/$total done',
                style: text.labelSmall?.copyWith(color: p.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${(progress * 100).round()}%',
              style: text.labelMedium?.copyWith(color: p.accent),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: p.track,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            builder: (context, value, _) => FractionallySizedBox(
              widthFactor: value,
              child: Container(
                decoration: BoxDecoration(
                  gradient: p.accentGradient,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: value > 0 ? null : null,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
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
                  color: p.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.danger.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.delete_outline_rounded, color: p.danger),
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
              style: text.labelSmall?.copyWith(color: p.textMuted),
            ),
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => onAdd(),
                style: text.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Add a new subtask...',
                  fillColor: p.card,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
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
                  color: p.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.add_rounded, size: 18, color: p.accent),
                    const SizedBox(width: 4),
                    Text(
                      'Add',
                      style: text.labelMedium?.copyWith(color: p.accent),
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
    final p = context.palette;
    final done = subtask.isCompleted;
    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? p.accent : p.well,
                    border: Border.all(color: done ? p.accent : p.border),
                  ),
                  child: done
                      ? const Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: done ? 0.5 : 1,
                    child: Text(
                      subtask.title,
                      style: context.text.bodyMedium?.copyWith(
                        decoration: done ? TextDecoration.lineThrough : null,
                        decorationColor: p.textSecondary,
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
    final p = context.palette;
    final style = context.text.bodySmall?.copyWith(color: p.textSecondary);
    final name = ref.watch(authProvider.select((a) => a.value?.firstName));

    Widget line(IconData icon, InlineSpan span) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: p.textMuted),
          const SizedBox(width: 10),
          Expanded(child: Text.rich(span, style: style)),
        ],
      ),
    );

    return Panel(
      radius: 16,
      shadow: false,
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
                      color: p.text,
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
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.canvas,
        border: Border(top: BorderSide(color: p.border.withValues(alpha: 0.6))),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448),
          child: done
              ? _ReopenButton(onPressed: onPressed)
              : PrimaryButton(
                  label: 'Mark as Complete',
                  icon: Icons.check_circle_outline_rounded,
                  iconAfter: false,
                  height: 56,
                  radius: 16,
                  onPressed: onPressed,
                ),
        ),
      ),
    );
  }
}

/// Full-width dark button shown once the task is done.
class _ReopenButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ReopenButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: onPressed,
      scale: 0.98,
      semanticLabel: 'Reopen task',
      child: Container(
        height: 56,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restart_alt_rounded, size: 20, color: p.text),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Completed · Reopen Task',
                style: context.text.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
