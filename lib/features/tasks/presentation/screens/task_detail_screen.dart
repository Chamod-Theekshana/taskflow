import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/routing/route_guard.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../shared/widgets/not_found_screen.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/task.dart';
import '../providers/task_provider.dart';
import '../widgets/task_ui.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  final int taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  final TextEditingController _subtaskController = TextEditingController();
  bool _deleting = false;

  @override
  void dispose() {
    _subtaskController.dispose();
    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  Future<void> _addSubtask() async {
    final title = _subtaskController.text.trim();
    if (title.isEmpty) return;
    _subtaskController.clear();
    await _run(
      () => ref
          .read(taskListProvider.notifier)
          .addSubtask(Subtask(taskId: widget.taskId, title: title)),
    );
  }

  Future<void> _reschedule(Task task) async {
    final today = dateOnly(DateTime.now());
    final initial = task.dueDate.isBefore(today) ? today : task.dueDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today.isBefore(task.dueDate) ? today : dateOnly(task.dueDate),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null || !mounted) return;
    final time = task.isAllDay ? null : parseTimeOfDay(task.dueTime);
    await _run(
      () => ref
          .read(taskListProvider.notifier)
          .updateTask(task.copyWith(dueDate: combineDateAndTime(picked, time))),
    );
  }

  Future<void> _delete() async {
    final confirmed = await confirmDeleteTask(context);
    if (!confirmed || !mounted) return;
    setState(() => _deleting = true);
    final notifier = ref.read(taskListProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    // Leave the screen first so it never renders a task that is gone.
    _goBack();
    try {
      await notifier.deleteTask(widget.taskId);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final taskState = ref.watch(taskListProvider);

    // `firstWhere` without `orElse` used to throw (red error screen) while
    // tasks were still loading, for bad links, and right after deleting.
    final task = taskState.taskById(widget.taskId);

    if (task == null) {
      if (taskState.isLoading || _deleting) {
        return Scaffold(
          backgroundColor: colorScheme.surface,
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      return const NotFoundScreen(
        title: 'Task not found',
        message: 'This task no longer exists.',
      );
    }

    final user = ref.watch(authProvider).value;
    final isDone = task.isCompleted;
    final overdue = task.isOverdue();
    final completedSubtasks = task.subtasks.where((s) => s.isCompleted).length;
    final totalSubtasks = task.subtasks.length;
    final subtaskProgress = totalSubtasks > 0
        ? completedSubtasks / totalSubtasks
        : 0.0;
    final subtaskPercent = (subtaskProgress * 100).round();

    final dueTitle = task.isAllDay || task.dueTime.isEmpty
        ? 'Due ${dayLabel(task.dueDate)} · All day'
        : 'Due ${dayLabel(task.dueDate)} at ${task.dueTime}';
    final dueSubtitle = isDone
        ? 'Completed ${timeAgo(task.effectiveCompletedAt!)}'
        : relativeDueLabel(task.deadline);

    final createdBy = user == null || user.fullName.isEmpty
        ? ''
        : ' by ${user.fullName}';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(Icons.arrow_back_ios_new, color: colorScheme.onSurface),
          onPressed: _goBack,
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF818CF8), Color(0xFF4F46E5)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            Text(
              'Task Details',
              style: textTheme.headlineMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: UserAvatar(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _CircleAction(
                        tooltip: 'Edit task',
                        icon: Icons.edit_outlined,
                        background: colorScheme.surfaceContainerLowest,
                        foreground: colorScheme.onSurface,
                        bordered: true,
                        onPressed: () =>
                            context.push(AppRoutes.editTask(widget.taskId)),
                      ),
                      const SizedBox(width: 8),
                      _CircleAction(
                        tooltip: 'Delete task',
                        icon: Icons.delete_outline,
                        background: colorScheme.errorContainer,
                        foreground: colorScheme.error,
                        onPressed: _delete,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Priority & Category Badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: priorityBackground(colorScheme, task.priority),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: priorityAccent(
                                  colorScheme,
                                  task.priority,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              task.priority.displayName,
                              style: textTheme.labelMedium?.copyWith(
                                color: priorityForeground(
                                  colorScheme,
                                  task.priority,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (task.category.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryFixed,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                categoryIcon(task.category),
                                size: 14,
                                color: colorScheme.onPrimaryFixedVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                task.category,
                                style: textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onPrimaryFixedVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Due Date Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: overdue
                          ? colorScheme.errorContainer
                          : colorScheme.tertiaryFixed.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: overdue
                                ? colorScheme.error
                                : colorScheme.tertiaryFixed,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            overdue ? Icons.warning_amber_rounded : Icons.schedule,
                            color: overdue
                                ? colorScheme.onError
                                : colorScheme.onTertiaryFixedVariant,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dueTitle,
                                style: textTheme.headlineSmall?.copyWith(
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: overdue
                                          ? colorScheme.error
                                          : colorScheme.tertiary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      dueSubtitle,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: overdue
                                            ? colorScheme.onErrorContainer
                                            : colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          label: const Text('Reschedule'),
                          labelStyle: textTheme.labelMedium?.copyWith(
                            color: colorScheme.primary,
                          ),
                          backgroundColor: colorScheme.surfaceContainerLowest,
                          side: BorderSide.none,
                          shape: const StadiumBorder(),
                          onPressed: () => _reschedule(task),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    task.title,
                    style: textTheme.displayMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Description Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.notes,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'DESCRIPTION & CONTEXT',
                              style: textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          task.description.isNotEmpty
                              ? task.description
                              : 'No description provided.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Subtasks Section
                  Row(
                    children: [
                      Icon(Icons.checklist, color: colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Subtasks',
                        style: textTheme.headlineMedium?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '($completedSubtasks/$totalSubtasks completed)',
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        '$subtaskPercent%',
                        style: textTheme.labelLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: subtaskProgress,
                      backgroundColor: colorScheme.surfaceContainerHigh,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Subtask Items
                  ...task.subtasks.map(
                    (subtask) => _buildSubtaskItem(context, subtask),
                  ),

                  // Add Subtask Row
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TextField(
                            controller: _subtaskController,
                            style: textTheme.bodyMedium,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _addSubtask(),
                            decoration: InputDecoration(
                              hintText: 'Add a new subtask...',
                              hintStyle: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.outline,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _addSubtask,
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(
                            'Add',
                            style: textTheme.labelMedium?.copyWith(
                              color: colorScheme.onPrimaryFixed,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primaryFixed,
                            foregroundColor: colorScheme.onPrimaryFixed,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Activity Metadata
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _MetaRow(
                          icon: Icons.account_circle,
                          text: 'Created ${timeAgo(task.createdAt)}$createdBy',
                        ),
                        const SizedBox(height: 8),
                        _MetaRow(
                          icon: Icons.history,
                          text: 'Last updated ${timeAgo(task.updatedAt)}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Bottom CTA
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.95),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.05),
                  offset: const Offset(0, -4),
                  blurRadius: 16,
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => _run(
                    () => ref
                        .read(taskListProvider.notifier)
                        .toggleComplete(task),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDone
                        ? colorScheme.surfaceContainerHighest
                        : colorScheme.secondary,
                    foregroundColor: isDone
                        ? colorScheme.onSurface
                        : colorScheme.onSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: isDone ? 0 : 6,
                    shadowColor: isDone
                        ? Colors.transparent
                        : colorScheme.secondary.withValues(alpha: 0.35),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isDone ? Icons.restart_alt : Icons.check_circle,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isDone ? 'Completed! Reopen Task' : 'Mark as Complete',
                        style: textTheme.labelLarge?.copyWith(
                          color: isDone
                              ? colorScheme.onSurface
                              : colorScheme.onSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtaskItem(BuildContext context, Subtask subtask) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final subtaskId = subtask.id;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.04),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: subtaskId == null
                  ? null
                  : () => _run(
                      () => ref
                          .read(taskListProvider.notifier)
                          .toggleSubtask(widget.taskId, subtaskId),
                    ),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: subtask.isCompleted
                      ? colorScheme.secondary
                      : colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: subtask.isCompleted
                    ? Icon(Icons.check, color: colorScheme.onSecondary, size: 16)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                subtask.title,
                style: textTheme.bodyMedium?.copyWith(
                  color: subtask.isCompleted
                      ? colorScheme.outline
                      : colorScheme.onSurface,
                  decoration: subtask.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                  decorationColor: colorScheme.outline,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Remove subtask',
              icon: Icon(Icons.close, size: 18, color: colorScheme.outline),
              onPressed: subtaskId == null
                  ? null
                  : () => _run(
                      () => ref
                          .read(taskListProvider.notifier)
                          .deleteSubtask(subtaskId),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color background;
  final Color foreground;
  final bool bordered;
  final VoidCallback onPressed;

  const _CircleAction({
    required this.tooltip,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.bordered = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: bordered ? Border.all(color: colorScheme.outlineVariant) : null,
      ),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, size: 18, color: foreground),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.outline),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
