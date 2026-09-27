import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import '../providers/task_provider.dart';
import '../../domain/entities/task.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  final int taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  ColorScheme get colorScheme => Theme.of(context).colorScheme;
  TextTheme get textTheme => Theme.of(context).textTheme;

  final TextEditingController _subtaskController = TextEditingController();

  @override
  void dispose() {
    _subtaskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final taskState = ref.watch(taskListProvider);
    final task = taskState.tasks.firstWhere((t) => t.id == widget.taskId);

    if (task == null) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          title: Text('Task Not Found'),
          backgroundColor: colorScheme.surface,
        ),
        body: Center(child: Text('This task no longer exists.')),
      );
    }

    final isHighPriority = task.priority == TaskPriority.high;
    final isDone = task.isCompleted;
    final completedSubtasks =
        task.subtasks.where((s) => s.isCompleted).length;
    final totalSubtasks = task.subtasks.length;
    final subtaskProgress =
        totalSubtasks > 0 ? completedSubtasks / totalSubtasks : 0.0;
    final subtaskPercent =
        totalSubtasks > 0 ? (subtaskProgress * 100).round() : 0;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: colorScheme.onSurface),
          onPressed: () => context.pop(),
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
              child: Icon(Icons.check, color: Colors.white, size: 18),
            ),
            SizedBox(width: 8),
            Text('Task Details',
                style: textTheme.headlineMedium
                    ?.copyWith(color: colorScheme.onSurface)),
          ],
        ),
        centerTitle: true,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 16,
              backgroundImage:
                  NetworkImage('https://i.pravatar.cc/150?img=11'),
            ),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.arrow_back,
                              size: 18, color: colorScheme.onSurface),
                          onPressed: () => context.pop(),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerLowest,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: colorScheme.outlineVariant),
                            ),
                            child: IconButton(
                              icon: Icon(Icons.edit_outlined,
                                  size: 18, color: colorScheme.onSurface),
                              onPressed: () => context
                                  .push('/edit-task/${task.id}'),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(Icons.delete_outline,
                                  size: 18, color: colorScheme.error),
                              onPressed: () => _showDeleteDialog(context),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Priority & Category Badges
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isHighPriority
                              ? colorScheme.errorContainer
                              : colorScheme.tertiaryFixed,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: task.priority == TaskPriority.high ? colorScheme.error : colorScheme.tertiary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              task.priority.displayName,
                              style: textTheme.labelMedium?.copyWith(
                                color: isHighPriority
                                    ? colorScheme.onErrorContainer
                                    : colorScheme.onTertiaryFixed,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryFixed,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(_getCategoryIcon(task.category),
                                size: 14,
                                color: colorScheme.onPrimaryFixedVariant),
                            SizedBox(width: 4),
                            Text(
                              task.category,
                              style: textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onPrimaryFixedVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Due Date Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiaryFixed.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colorScheme.tertiaryFixed,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.schedule,
                              color: colorScheme.tertiary, size: 22),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Due Today at ${task.dueTime}',
                                style: textTheme.headlineSmall
                                    ?.copyWith(color: colorScheme.onSurface),
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: colorScheme.tertiary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Text('In 3 hours',
                                      style: textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      colorScheme.onSurface.withOpacity(0.04),
                                  blurRadius: 4)
                            ],
                          ),
                          child: Text('Reschedule',
                              style: textTheme.labelMedium
                                  ?.copyWith(color: colorScheme.primary)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // Title
                  Text(
                    task.title,
                    style: textTheme.displayMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 24),

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
                            Icon(Icons.notes,
                                size: 16, color: colorScheme.onSurfaceVariant),
                            SizedBox(width: 8),
                            Text(
                              'DESCRIPTION & CONTEXT',
                              style: textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text(
                          task.description.isNotEmpty
                              ? task.description
                              : 'No description provided.',
                          style: textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurface),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // Subtasks Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.checklist,
                              color: colorScheme.primary, size: 20),
                          SizedBox(width: 8),
                          Text('Subtasks',
                              style: textTheme.headlineMedium
                                  ?.copyWith(color: colorScheme.onSurface)),
                          SizedBox(width: 8),
                          Text(
                            '($completedSubtasks/$totalSubtasks completed)',
                            style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      Text(
                        '${subtaskPercent}%',
                        style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: subtaskProgress,
                      backgroundColor: colorScheme.surfaceContainerHigh,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.primary),
                      minHeight: 8,
                    ),
                  ),
                  SizedBox(height: 16),

                  // Subtask Items
                  ...task.subtasks.map((subtask) => _buildSubtaskItem(
                      subtask, context)),

                  // Add Subtask Row
                  SizedBox(height: 8),
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
                            decoration: InputDecoration(
                              hintText: 'Add a new subtask...',
                              hintStyle: textTheme.bodyMedium
                                  ?.copyWith(color: colorScheme.outline),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (_subtaskController.text.trim().isNotEmpty) {
                              ref.read(taskListProvider.notifier).addSubtask(Subtask(
                                taskId: widget.taskId,
                                title: _subtaskController.text.trim(),
                              ));
                              _subtaskController.clear();
                            }
                          },
                          icon: Icon(Icons.add, size: 18),
                          label: Text('Add',
                              style: textTheme.labelMedium
                                  ?.copyWith(color: colorScheme.onPrimaryFixed)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primaryFixed,
                            foregroundColor: colorScheme.onPrimaryFixed,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 32),

                  // Activity Metadata
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.account_circle,
                                size: 16, color: colorScheme.outline),
                            SizedBox(width: 8),
                            Text(
                              'Created yesterday by Alex',
                              style: textTheme.bodySmall
                                  ?.copyWith(color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.history,
                                size: 16, color: colorScheme.outline),
                            SizedBox(width: 8),
                            Text(
                              'Last updated 2 hours ago',
                              style: textTheme.bodySmall
                                  ?.copyWith(color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // Bottom CTA
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(0.9),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.onSurface.withOpacity(0.03),
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
                  onPressed: () {
                    ref.read(taskListProvider.notifier).updateTask(task.copyWith(isCompleted: !task.isCompleted));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDone
                        ? colorScheme.surfaceContainerHighest
                        : colorScheme.secondary,
                    foregroundColor: isDone
                        ? colorScheme.onSurface
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                    elevation: isDone ? 0 : 6,
                    shadowColor: isDone
                        ? Colors.transparent
                        : colorScheme.secondary.withOpacity(0.35),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isDone
                            ? Icons.restart_alt
                            : Icons.check_circle,
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        isDone
                            ? 'Completed! Reopen Task'
                            : 'Mark as Complete',
                        style: textTheme.labelLarge?.copyWith(
                          color:
                              isDone ? colorScheme.onSurface : Colors.white,
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

  Widget _buildSubtaskItem(Subtask subtask, BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colorScheme.onSurface.withOpacity(0.03),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () =>
                  ref.read(taskListProvider.notifier).toggleSubtask(widget.taskId, subtask.id!),
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
                    ? Icon(Icons.check,
                        color: Colors.white, size: 16)
                    : null,
              ),
            ),
            SizedBox(width: 12),
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
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Task?'),
        content: Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(taskListProvider.notifier).deleteTask(widget.taskId);
              Navigator.pop(ctx);
              context.pop();
            },
            child: Text('Delete',
                style: TextStyle(color: colorScheme.error)),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'strategy':
        return Icons.settings;
      case 'design':
        return Icons.palette;
      case 'meeting':
        return Icons.group;
      case 'personal':
        return Icons.person;
      case 'finance':
        return Icons.receipt_long;
      case 'work':
        return Icons.business_center;
      case 'health':
        return Icons.favorite;
      default:
        return Icons.folder;
    }
  }
}
