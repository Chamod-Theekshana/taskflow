import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/routing/route_guard.dart';
import '../../domain/entities/task.dart';
import '../providers/task_provider.dart';
import 'task_ui.dart';

enum _CardAction { edit, delete }

class TaskCard extends ConsumerWidget {
  final Task task;

  const TaskCard({super.key, required this.task});

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    _CardAction action,
  ) async {
    final id = task.id;
    if (id == null) return;
    switch (action) {
      case _CardAction.edit:
        context.push(AppRoutes.editTask(id));
      case _CardAction.delete:
        final confirmed = await confirmDeleteTask(context);
        if (!confirmed || !context.mounted) return;
        await _run(
          context,
          () => ref.read(taskListProvider.notifier).deleteTask(id),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final accent = priorityAccent(colorScheme, task.priority);
    final isCompleted = task.isCompleted;
    final overdue = task.isOverdue();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: task.id == null
              ? null
              : () => context.push(AppRoutes.task(task.id!)),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left accent strip
                Container(width: 4, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 4, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Circular checkbox
                        Semantics(
                          checked: isCompleted,
                          label: isCompleted
                              ? 'Mark as not done'
                              : 'Mark as done',
                          child: GestureDetector(
                            onTap: task.id == null
                                ? null
                                : () => _run(
                                    context,
                                    () => ref
                                        .read(taskListProvider.notifier)
                                        .toggleComplete(task),
                                  ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 24,
                              height: 24,
                              margin: const EdgeInsets.only(top: 2, right: 12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCompleted
                                    ? colorScheme.secondary
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isCompleted
                                      ? colorScheme.secondary
                                      : colorScheme.outline,
                                  width: 2,
                                ),
                              ),
                              child: isCompleted
                                  ? Icon(
                                      Icons.check,
                                      size: 16,
                                      color: colorScheme.onSecondary,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.headlineSmall?.copyWith(
                                  decoration: isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: isCompleted
                                      ? colorScheme.onSurface.withValues(
                                          alpha: 0.45,
                                        )
                                      : colorScheme.onSurface,
                                ),
                              ),
                              if (task.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  task.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              // Metadata pills
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _Pill(
                                    icon: overdue
                                        ? Icons.warning_amber_rounded
                                        : Icons.calendar_today,
                                    label: dueSummary(task),
                                    background: overdue
                                        ? colorScheme.errorContainer
                                        : colorScheme.surfaceContainerHigh,
                                    foreground: overdue
                                        ? colorScheme.onErrorContainer
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                  _PriorityPill(priority: task.priority),
                                  if (task.category.isNotEmpty)
                                    _Pill(
                                      icon: categoryIcon(task.category),
                                      label: task.category,
                                      background:
                                          colorScheme.surfaceContainerHigh,
                                      foreground: colorScheme.onSurfaceVariant,
                                    ),
                                  if (task.subtasks.isNotEmpty)
                                    _Pill(
                                      icon: Icons.checklist,
                                      label:
                                          '${task.subtasks.where((s) => s.isCompleted).length}'
                                          '/${task.subtasks.length}',
                                      background:
                                          colorScheme.surfaceContainerHigh,
                                      foreground: colorScheme.onSurfaceVariant,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // More menu (was a decorative icon that did nothing)
                        PopupMenuButton<_CardAction>(
                          tooltip: 'Task options',
                          icon: Icon(Icons.more_horiz, color: colorScheme.outline),
                          onSelected: (action) => _onMenu(context, ref, action),
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: _CardAction.edit,
                              child: ListTile(
                                leading: Icon(Icons.edit_outlined),
                                title: Text('Edit'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: _CardAction.delete,
                              child: ListTile(
                                leading: Icon(Icons.delete_outline),
                                title: Text('Delete'),
                                contentPadding: EdgeInsets.zero,
                              ),
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
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  const _Pill({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(label, style: textTheme.labelMedium?.copyWith(color: foreground)),
        ],
      ),
    );
  }
}

class _PriorityPill extends StatelessWidget {
  final TaskPriority priority;

  const _PriorityPill({required this.priority});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final foreground = priorityForeground(colorScheme, priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: priorityBackground(colorScheme, priority),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: priorityAccent(colorScheme, priority),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            priority.label,
            style: textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
