import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../providers/task_provider.dart';
import '../models/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;

  const TaskCard({Key? key, required this.task}) : super(key: key);

  Color _getPriorityAccentColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return AppColors.error;
      case 'medium':
        return AppColors.tertiary;
      case 'low':
      default:
        return AppColors.secondary;
    }
  }

  Color _getPriorityBgColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return AppColors.errorContainer;
      case 'medium':
        return AppColors.tertiaryFixed;
      case 'low':
      default:
        return AppColors.secondaryContainer;
    }
  }
  
  Color _getPriorityTextColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return AppColors.error;
      case 'medium':
        return AppColors.tertiary;
      case 'low':
      default:
        return AppColors.secondary;
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
  Widget build(BuildContext context) {
    final priorityAccent = _getPriorityAccentColor(task.priority.name);
    final isCompleted = task.isCompleted;

    return GestureDetector(
      onTap: () => context.push('/task/${task.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
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
                          if (task.id != null) context.read<TaskProvider>().toggleTaskComplete(task.id!);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.only(top: 2, right: 12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCompleted ? AppColors.secondary : Colors.transparent,
                            border: Border.all(
                              color: isCompleted ? AppColors.secondary : AppColors.outlineVariant,
                              width: 2,
                            ),
                          ),
                          child: isCompleted
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
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
                              style: AppTypography.headlineSmall.copyWith(
                                decoration: isCompleted ? TextDecoration.lineThrough : null,
                                color: isCompleted ? AppColors.onSurface.withOpacity(0.45) : AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              task.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.onSurfaceVariant,
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
                                  icon: Icons.calendar_today,
                                  label: DateFormat('MMM d').format(task.dueDate),
                                ),
                                // Priority pill
                                _buildPriorityPill(task.priority.name),
                                // Category pill
                                _buildPill(
                                  icon: _getCategoryIcon(task.category),
                                  label: task.category,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // More menu
                      Icon(Icons.more_horiz, color: AppColors.outline),
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

  Widget _buildPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.labelMedium.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityPill(String priority) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getPriorityBgColor(priority),
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
              color: _getPriorityTextColor(priority),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            priority,
            style: AppTypography.labelMedium.copyWith(
              color: _getPriorityTextColor(priority),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
