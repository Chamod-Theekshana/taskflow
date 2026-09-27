import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/task_provider.dart';
import '../../domain/entities/task.dart';

class TaskCard extends ConsumerWidget {
  final Task task;

  const TaskCard({Key? key, required this.task}) : super(key: key);

  Color _getPriorityAccentColor(BuildContext context, String priority) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (priority.toLowerCase()) {
      case 'high':
        return colorScheme.error;
      case 'medium':
        return colorScheme.tertiary;
      case 'low':
      default:
        return colorScheme.secondary;
    }
  }

  Color _getPriorityBgColor(BuildContext context, String priority) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (priority.toLowerCase()) {
      case 'high':
        return colorScheme.errorContainer;
      case 'medium':
        return colorScheme.tertiaryContainer;
      case 'low':
      default:
        return colorScheme.secondaryContainer;
    }
  }
  
  Color _getPriorityTextColor(BuildContext context, String priority) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (priority.toLowerCase()) {
      case 'high':
        return colorScheme.error;
      case 'medium':
        return colorScheme.tertiary;
      case 'low':
      default:
        return colorScheme.secondary;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'strategy': return Icons.settings;
      case 'design': return Icons.palette;
      case 'meeting': return Icons.group;
      case 'personal': return Icons.person;
      case 'finance': return Icons.receipt_long;
      case 'work': return Icons.business_center;
      case 'health': return Icons.favorite;
      default: return Icons.folder;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final priorityAccent = _getPriorityAccentColor(context, task.priority.name);
    final isCompleted = task.isCompleted;

    return GestureDetector(
      onTap: () => context.push('/task/${task.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent strip
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: priorityAccent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Circular checkbox
                      GestureDetector(
                        onTap: () {
                          if (task.id != null) {
                            ref.read(taskListProvider.notifier).updateTask(task.copyWith(isCompleted: !isCompleted));
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.only(top: 2, right: 12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCompleted ? colorScheme.secondary : Colors.transparent,
                            border: Border.all(
                              color: isCompleted ? colorScheme.secondary : colorScheme.outlineVariant,
                              width: 2,
                            ),
                          ),
                          child: isCompleted
                              ? Icon(Icons.check, size: 16, color: colorScheme.onSecondary)
                              : null,
                        ),
                      ),
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: textTheme.headlineSmall?.copyWith(
                                decoration: isCompleted ? TextDecoration.lineThrough : null,
                                color: isCompleted ? colorScheme.onSurface.withOpacity(0.45) : colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              task.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Metadata pills
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                // Due date pill
                                _buildPill(
                                  context: context,
                                  icon: Icons.calendar_today,
                                  label: DateFormat('MMM d').format(task.dueDate),
                                ),
                                // Priority pill
                                _buildPriorityPill(context, task.priority.name),
                                // Category pill
                                _buildPill(
                                  context: context,
                                  icon: _getCategoryIcon(task.category),
                                  label: task.category,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // More menu
                      Icon(Icons.more_horiz, color: colorScheme.outline),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPill({required BuildContext context, required IconData icon, required String label}) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityPill(BuildContext context, String priority) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getPriorityBgColor(context, priority),
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
              color: _getPriorityTextColor(context, priority),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            priority,
            style: textTheme.labelMedium?.copyWith(
              color: _getPriorityTextColor(context, priority),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
