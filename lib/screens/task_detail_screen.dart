import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../providers/task_provider.dart';
import '../models/task.dart';

class TaskDetailScreen extends StatefulWidget {
  final int taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final TextEditingController _subtaskController = TextEditingController();

  @override
  void dispose() {
    _subtaskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final task = taskProvider.getTaskByIdSync(widget.taskId);

    if (task == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: const Text('Task Not Found'),
          backgroundColor: AppColors.surface,
        ),
        body: const Center(child: Text('This task no longer exists.')),
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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.onSurface),
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
              child: const Icon(Icons.check, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            Text('Task Details',
                style: AppTypography.headlineMd
                    .copyWith(color: AppColors.onSurface)),
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
                          color: AppColors.surfaceContainerLow,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppColors.outlineVariant),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back,
                              size: 18, color: AppColors.onSurface),
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
                              color: AppColors.surfaceContainerLowest,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.outlineVariant),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  size: 18, color: AppColors.onSurface),
                              onPressed: () => context
                                  .push('/edit-task/\\'),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: AppColors.errorContainer,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: AppColors.error),
                              onPressed: () => _showDeleteDialog(context),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Priority & Category Badges
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isHighPriority
                              ? AppColors.errorContainer
                              : AppColors.tertiaryFixed,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: task.priority.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              task.priority.displayName,
                              style: AppTypography.labelMd.copyWith(
                                color: isHighPriority
                                    ? AppColors.onErrorContainer
                                    : AppColors.onTertiaryFixed,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryFixed,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(_getCategoryIcon(task.category),
                                size: 14,
                                color: AppColors.onPrimaryFixedVariant),
                            const SizedBox(width: 4),
                            Text(
                              task.category,
                              style: AppTypography.labelMd.copyWith(
                                  color: AppColors.onPrimaryFixedVariant),
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
                      color: AppColors.tertiaryFixed.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.tertiaryFixed,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.schedule,
                              color: AppColors.tertiary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Due Today at \\',
                                style: AppTypography.headlineSm
                                    .copyWith(color: AppColors.onSurface),
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: const BoxDecoration(
                                      color: AppColors.tertiary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text('In 3 hours',
                                      style: AppTypography.bodySm.copyWith(
                                          color: AppColors.onSurfaceVariant)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      AppColors.onSurface.withOpacity(0.04),
                                  blurRadius: 4)
                            ],
                          ),
                          child: Text('Reschedule',
                              style: AppTypography.labelMd
                                  .copyWith(color: AppColors.primary)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    task.title,
                    style: AppTypography.displayLgMobile.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Description Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.notes,
                                size: 16, color: AppColors.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Text(
                              'DESCRIPTION & CONTEXT',
                              style: AppTypography.labelMd.copyWith(
                                color: AppColors.onSurfaceVariant,
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
                          style: AppTypography.bodyMd
                              .copyWith(color: AppColors.onSurface),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Subtasks Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.checklist,
                              color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text('Subtasks',
                              style: AppTypography.headlineMd
                                  .copyWith(color: AppColors.onSurface)),
                          const SizedBox(width: 8),
                          Text(
                            '(\\/\\ completed)',
                            style: AppTypography.bodyMd.copyWith(
                                color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                      Text(
                        '\\%',
                        style: AppTypography.labelLg.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: subtaskProgress,
                      backgroundColor: AppColors.surfaceContainerHigh,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Subtask Items
                  ...task.subtasks.map((subtask) => _buildSubtaskItem(
                      subtask, taskProvider)),

                  // Add Subtask Row
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TextField(
                            controller: _subtaskController,
                            style: AppTypography.bodyMd,
                            decoration: InputDecoration(
                              hintText: 'Add a new subtask...',
                              hintStyle: AppTypography.bodyMd
                                  .copyWith(color: AppColors.outline),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (_subtaskController.text.trim().isNotEmpty) {
                              taskProvider.addSubtask(Subtask(
                                taskId: widget.taskId,
                                title: _subtaskController.text.trim(),
                              ));
                              _subtaskController.clear();
                            }
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: Text('Add',
                              style: AppTypography.labelMd
                                  .copyWith(color: AppColors.onPrimaryFixed)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryFixed,
                            foregroundColor: AppColors.onPrimaryFixed,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
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
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_circle,
                                size: 16, color: AppColors.outline),
                            const SizedBox(width: 8),
                            Text(
                              'Created yesterday by Alex',
                              style: AppTypography.bodySm
                                  .copyWith(color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.history,
                                size: 16, color: AppColors.outline),
                            const SizedBox(width: 8),
                            Text(
                              'Last updated 2 hours ago',
                              style: AppTypography.bodySm
                                  .copyWith(color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // Bottom CTA
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.9),
              boxShadow: [
                BoxShadow(
                  color: AppColors.onSurface.withOpacity(0.03),
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
                    taskProvider.toggleTaskComplete(widget.taskId);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDone
                        ? AppColors.surfaceContainerHighest
                        : AppColors.secondary,
                    foregroundColor: isDone
                        ? AppColors.onSurface
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                    elevation: isDone ? 0 : 6,
                    shadowColor: isDone
                        ? Colors.transparent
                        : AppColors.secondary.withOpacity(0.35),
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
                      const SizedBox(width: 8),
                      Text(
                        isDone
                            ? 'Completed! Reopen Task'
                            : 'Mark as Complete',
                        style: AppTypography.labelLg.copyWith(
                          color:
                              isDone ? AppColors.onSurface : Colors.white,
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

  Widget _buildSubtaskItem(Subtask subtask, TaskProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withOpacity(0.03),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () =>
                  provider.toggleSubtask(subtask.id!, widget.taskId),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: subtask.isCompleted
                      ? AppColors.secondary
                      : AppColors.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: subtask.isCompleted
                    ? const Icon(Icons.check,
                        color: Colors.white, size: 16)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                subtask.title,
                style: AppTypography.bodyMd.copyWith(
                  color: subtask.isCompleted
                      ? AppColors.outline
                      : AppColors.onSurface,
                  decoration: subtask.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                  decorationColor: AppColors.outline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<TaskProvider>().deleteTask(widget.taskId);
              Navigator.pop(ctx);
              context.pop();
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
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
