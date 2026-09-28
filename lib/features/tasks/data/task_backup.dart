import 'dart:convert';

import '../../../core/error/failures.dart';
import '../domain/entities/task.dart';

/// Plain-JSON backups of a task list (Profile > Export / Import).
///
/// The format is a list of task objects. It is the same shape older versions
/// of the app exported, so those backups can still be imported.
abstract final class TaskBackup {
  static String encode(List<Task> tasks) {
    final data = [
      for (final t in tasks)
        {
          'title': t.title,
          'description': t.description,
          'dueDate': t.dueDate.toIso8601String(),
          'dueTime': t.dueTime,
          'allDay': t.isAllDay,
          'priority': t.priority.label,
          'category': t.category,
          'completed': t.isCompleted,
          'completedAt': t.completedAt?.toIso8601String(),
          'reminder': t.reminder,
          'reminderMinutes': t.reminderMinutes,
          'repeat': t.repeat.name,
          'createdAt': t.createdAt.toIso8601String(),
          'subtasks': [
            for (final s in t.subtasks)
              {'title': s.title, 'completed': s.isCompleted},
          ],
        },
    ];
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Throws a [Failure] when [text] isn't a TaskFlow backup.
  static List<Task> decode(String text, {DateTime? now}) {
    final Object? json;
    try {
      json = jsonDecode(text.trim());
    } on FormatException {
      throw const Failure("The clipboard doesn't contain a TaskFlow backup.");
    }

    final items = switch (json) {
      List<dynamic> list => list,
      {'tasks': List<dynamic> list} => list,
      _ => throw const Failure(
        "The clipboard doesn't contain a TaskFlow backup.",
      ),
    };

    final created = now ?? DateTime.now();
    final tasks = <Task>[];
    for (final item in items) {
      if (item is! Map) continue;
      final title = (item['title'] as String? ?? '').trim();
      final due = DateTime.tryParse(item['dueDate'] as String? ?? '');
      if (title.isEmpty || due == null) continue;

      final completed = item['completed'] == true;
      tasks.add(
        Task(
          title: title,
          description: item['description'] as String? ?? '',
          dueDate: due,
          dueTime: item['dueTime'] as String? ?? '',
          isAllDay: item['allDay'] == true,
          priority: TaskPriority.values.firstWhere(
            (p) => p.label.toLowerCase() == '${item['priority']}'.toLowerCase(),
            orElse: () => TaskPriority.medium,
          ),
          category: item['category'] as String? ?? '',
          isCompleted: completed,
          completedAt: completed
              ? DateTime.tryParse(item['completedAt'] as String? ?? '') ??
                    created
              : null,
          reminder: item['reminder'] == true,
          reminderMinutes: (item['reminderMinutes'] as num?)?.toInt() ?? 15,
          repeat: repeatRuleFromName(item['repeat'] as String?),
          createdAt:
              DateTime.tryParse(item['createdAt'] as String? ?? '') ?? created,
          updatedAt: created,
          subtasks: [
            for (final s in (item['subtasks'] as List? ?? const []))
              if (s is Map && '${s['title'] ?? ''}'.trim().isNotEmpty)
                Subtask(
                  taskId: 0,
                  title: '${s['title']}'.trim(),
                  isCompleted: s['completed'] == true,
                ),
          ],
        ),
      );
    }
    if (tasks.isEmpty) {
      throw const Failure('That backup has no tasks in it.');
    }
    return tasks;
  }
}
