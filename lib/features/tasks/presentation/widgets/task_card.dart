import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/routing/route_guard.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../shared/widgets/ui.dart';
import '../../domain/entities/task.dart';
import '../providers/task_provider.dart';
import 'task_ui.dart';

/// Completes / reopens a task and tells the user when a repeating task has
/// been scheduled again.
Future<void> toggleTaskDone(
  BuildContext context,
  WidgetRef ref,
  Task task,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final next = await ref.read(taskListProvider.notifier).toggleComplete(task);
    if (next != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Next one is set for ${dayLabel(next.dueDate)}.'),
          ),
        );
    }
  } catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(describeError(e))));
  }
}

/// A task in a list: priority strip, round checkbox, title, one line of
/// notes and badges for the due date, priority and category.
class TaskCard extends ConsumerWidget {
  final Task task;

  const TaskCard({super.key, required this.task});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final id = task.id;
    if (id == null || !await confirmDelete(context)) return;
    if (!context.mounted) return;
    try {
      await ref.read(taskListProvider.notifier).deleteTask(id);
      if (context.mounted) showMessage(context, 'Task deleted.');
    } catch (e) {
      if (context.mounted) showMessage(context, describeError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final text = context.text;
    final done = task.isCompleted;
    final id = task.id;
    final strip = done
        ? p.accent.withValues(alpha: 0.4)
        : priorityAccent(p, task.priority);
    final glowStrip = !done && task.priority == TaskPriority.high;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: done ? 0.75 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: done ? p.cardMuted.withValues(alpha: 0.8) : p.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: done ? p.border.withValues(alpha: 0.5) : p.border,
          ),
          boxShadow: done ? null : p.cardShadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: id == null ? null : () => context.push(AppRoutes.task(id)),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 16,
                  bottom: 16,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: strip,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(4),
                      ),
                      boxShadow: null,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TaskCheckbox(
                        checked: done,
                        onTap: () => toggleTaskDone(context, ref, task),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    task.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.headlineSmall?.copyWith(
                                      color: done ? p.textSecondary : p.text,
                                      decoration: done
                                          ? TextDecoration.lineThrough
                                          : null,
                                      decorationColor: p.textSecondary,
                                    ),
                                  ),
                                ),
                                _TaskMenu(
                                  onEdit: id == null
                                      ? null
                                      : () => context.push(
                                          AppRoutes.editTask(id),
                                        ),
                                  onDelete: () => _delete(context, ref),
                                ),
                              ],
                            ),
                            if (task.description.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Text(
                                  task.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.bodySmall?.copyWith(
                                    color: done
                                        ? p.textSecondary.withValues(alpha: 0.6)
                                        : p.textSecondary,
                                    decoration: done
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: p.textSecondary,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (done)
                                  Pill(
                                    label: 'Completed',
                                    icon: Icons.done_all_rounded,
                                    background: p.accent.withValues(
                                      alpha: 0.15,
                                    ),
                                    foreground: p.accent,
                                    border: p.accent.withValues(alpha: 0.3),
                                    style: text.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                else ...[
                                  DueBadge(task: task),
                                  PriorityBadge(
                                    priority: task.priority,
                                    long: true,
                                  ),
                                ],
                                if (task.category.isNotEmpty)
                                  CategoryTag(category: task.category),
                              ],
                            ),
                          ],
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

class _TaskMenu extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback onDelete;

  const _TaskMenu({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: 32,
      height: 28,
      child: PopupMenuButton<String>(
        tooltip: 'Task options',
        useRootNavigator: true,
        padding: EdgeInsets.zero,
        iconSize: 18,
        icon: Icon(Icons.more_vert_rounded, color: p.textSecondary),
        onSelected: (value) {
          if (value == 'edit') onEdit?.call();
          if (value == 'delete') onDelete();
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'edit',
            enabled: onEdit != null,
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 18, color: p.textSecondary),
                const SizedBox(width: 12),
                const Text('Edit'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded, size: 18, color: p.danger),
                const SizedBox(width: 12),
                Text('Delete', style: TextStyle(color: p.danger)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
