import '../../domain/entities/task.dart';

DateTime? _parseDate(Object? value) =>
    value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;

/// SQLite row <-> [Task].
abstract final class TaskRow {
  static Task fromMap(Map<String, Object?> map, {List<Subtask>? subtasks}) {
    final now = DateTime.now();
    return Task(
      id: map['id'] as int?,
      userId: map['userId'] as String?,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      dueDate: _parseDate(map['dueDate']) ?? now,
      dueTime: map['dueTime'] as String? ?? '',
      priority: taskPriorityFromIndex(map['priority'] as int?),
      category: map['category'] as String? ?? '',
      isCompleted: (map['isCompleted'] as int? ?? 0) == 1,
      isAllDay: (map['isAllDay'] as int? ?? 0) == 1,
      reminder: (map['reminder'] as int? ?? 0) == 1,
      reminderMinutes: map['reminderMinutes'] as int? ?? 15,
      repeat: repeatRuleFromName(map['repeatRule'] as String?),
      completedAt: _parseDate(map['completedAt']),
      createdAt: _parseDate(map['createdAt']) ?? now,
      updatedAt: _parseDate(map['updatedAt']) ?? now,
      subtasks: subtasks ?? const [],
    );
  }

  /// Column values for `tasks`. The id is left out so SQLite assigns it on
  /// insert and it's never overwritten on update.
  static Map<String, Object?> toMap(Task task) => {
    'userId': task.userId,
    'title': task.title,
    'description': task.description,
    'dueDate': task.dueDate.toIso8601String(),
    'dueTime': task.dueTime,
    'priority': task.priority.index,
    'category': task.category,
    'isCompleted': task.isCompleted ? 1 : 0,
    'isAllDay': task.isAllDay ? 1 : 0,
    'reminder': task.reminder ? 1 : 0,
    'reminderMinutes': task.reminderMinutes,
    'repeatRule': task.repeat == RepeatRule.none ? null : task.repeat.name,
    'completedAt': task.completedAt?.toIso8601String(),
    'createdAt': task.createdAt.toIso8601String(),
    'updatedAt': task.updatedAt.toIso8601String(),
  };
}

abstract final class SubtaskRow {
  static Subtask fromMap(Map<String, Object?> map) => Subtask(
    id: map['id'] as int?,
    taskId: map['taskId'] as int,
    title: map['title'] as String? ?? '',
    isCompleted: (map['isCompleted'] as int? ?? 0) == 1,
  );

  static Map<String, Object?> toMap(Subtask subtask) => {
    'taskId': subtask.taskId,
    'title': subtask.title,
    'isCompleted': subtask.isCompleted ? 1 : 0,
  };
}
