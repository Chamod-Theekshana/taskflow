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
      messenger.showSnackBar(
        SnackBar(
          content: Text('Next one is set for ${dayLabel(next.dueDate)}.'),
        ),
      );
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(describeError(e))));
  }
}

class TaskCard extends ConsumerWidget {
  final Task task;

  const TaskCard({super.key, required this.task});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final id = task.id;
    if (id == null || !await confirmDelete(context)) return;
    try {
      await ref.read(taskListProvider.notifier).deleteTask(id);
      if (context.mounted) showMessage(context, 'Task deleted.');
    } catch (e) {
      if (context.mounted) showMessage(context, describeError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.text;
    final done = task.isCompleted;
    final id = task.id;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: done ? 0.8 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: done
              ? colors.surfaceContainerLow.withValues(alpha: 0.7)
              : colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: context.isDark ? null : AppShadows.sm,
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
                      color: done
                          ? colors.secondary
                          : priorityAccent(colors, task.priority),
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 4, 16),
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
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      task.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: text.headlineSmall?.copyWith(
                                        letterSpacing: -0.2,
                                        color: done ? colors.outline : null,
                                        decoration: done
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
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
                                padding: const EdgeInsets.only(
                                  top: 2,
                                  right: 12,
                                ),
                                child: Text(
                                  task.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.bodySmall?.copyWith(
                                    color: done
                                        ? colors.outline
                                        : colors.onSurfaceVariant,
                                    decoration: done
                                        ? TextDecoration.lineThrough
                                        : null,
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
                                    background: colors.secondaryContainer,
                                    foreground: colors.onSecondaryContainer,
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
                                  CategoryTag(
                                    category: task.category,
                                    muted: done,
                                  ),
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
    final colors = context.colors;
    return SizedBox(
      width: 36,
      height: 32,
      child: PopupMenuButton<String>(
        tooltip: 'Task options',
        useRootNavigator: true,
        padding: EdgeInsets.zero,
        iconSize: 20,
        icon: Icon(Icons.more_vert_rounded, color: colors.outlineVariant),
        onSelected: (value) {
          if (value == 'edit') onEdit?.call();
          if (value == 'delete') onDelete();
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.edit_outlined),
              title: Text('Edit'),
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline_rounded, color: colors.error),
              title: Text('Delete', style: TextStyle(color: colors.error)),
            ),
          ),
        ],
      ),
    );
  }
}
