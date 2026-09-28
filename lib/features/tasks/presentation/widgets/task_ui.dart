import 'package:flutter/material.dart';

import '../../../../core/utils/date_time_utils.dart';
import '../../domain/entities/task.dart';

/// Categories offered in the add / edit screen.
const List<({String name, IconData icon})> kTaskCategories = [
  (name: 'Work', icon: Icons.business_center),
  (name: 'Personal', icon: Icons.person),
  (name: 'Health', icon: Icons.favorite),
  (name: 'Shopping', icon: Icons.shopping_bag),
];

IconData categoryIcon(String category) {
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
    case 'shopping':
      return Icons.shopping_bag;
    default:
      return Icons.folder;
  }
}

/// Accent colour for a priority, taken from the current theme so it also
/// works in dark mode.
Color priorityAccent(ColorScheme scheme, TaskPriority priority) {
  switch (priority) {
    case TaskPriority.high:
      return scheme.error;
    case TaskPriority.medium:
      return scheme.tertiary;
    case TaskPriority.low:
      return scheme.secondary;
  }
}

Color priorityBackground(ColorScheme scheme, TaskPriority priority) {
  switch (priority) {
    case TaskPriority.high:
      return scheme.errorContainer;
    case TaskPriority.medium:
      return scheme.tertiaryFixed;
    case TaskPriority.low:
      return scheme.secondaryContainer;
  }
}

Color priorityForeground(ColorScheme scheme, TaskPriority priority) {
  switch (priority) {
    case TaskPriority.high:
      return scheme.onErrorContainer;
    case TaskPriority.medium:
      return scheme.onTertiaryFixed;
    case TaskPriority.low:
      return scheme.onSecondaryContainer;
  }
}

/// `Today · 02:00 PM`, `Tomorrow`, `Mon, Oct 5 · 09:30 AM`, ...
String dueSummary(Task task, {DateTime? now}) {
  final day = dayLabel(task.dueDate, now: now);
  if (task.isAllDay || task.dueTime.isEmpty) return day;
  return '$day · ${task.dueTime}';
}

/// Asks the user to confirm deleting a task. Returns true when confirmed.
Future<bool> confirmDeleteTask(BuildContext context) async {
  final colorScheme = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete task?'),
      content: const Text('This action cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('Delete', style: TextStyle(color: colorScheme.error)),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
