import '../../domain/entities/task.dart';

DateTime? _parseDate(Object? value) =>
    value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;

/// SQLite row <-> [Task] mapping.
class TaskModel extends Task {
  TaskModel({
    super.id,
    super.userId,
    required super.title,
    required super.description,
    required super.dueDate,
    required super.dueTime,
    required super.priority,
    required super.category,
    super.isCompleted,
    super.isAllDay,
    super.reminder,
    super.reminderMinutes,
    super.completedAt,
    required super.createdAt,
    required super.updatedAt,
    super.subtasks,
  });

  factory TaskModel.fromEntity(Task t) => TaskModel(
    id: t.id,
    userId: t.userId,
    title: t.title,
    description: t.description,
    dueDate: t.dueDate,
    dueTime: t.dueTime,
    priority: t.priority,
    category: t.category,
    isCompleted: t.isCompleted,
    isAllDay: t.isAllDay,
    reminder: t.reminder,
    reminderMinutes: t.reminderMinutes,
    completedAt: t.completedAt,
    createdAt: t.createdAt,
    updatedAt: t.updatedAt,
    subtasks: t.subtasks,
  );

  factory TaskModel.fromMap(
    Map<String, Object?> map, {
    List<Subtask>? subtasks,
  }) {
    final now = DateTime.now();
    return TaskModel(
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
      reminderMinutes: map['reminderMinutes'] as int? ?? 0,
      completedAt: _parseDate(map['completedAt']),
      createdAt: _parseDate(map['createdAt']) ?? now,
      updatedAt: _parseDate(map['updatedAt']) ?? now,
      subtasks: subtasks ?? const [],
    );
  }

  /// Row values for the `tasks` table. `id` is left out so SQLite assigns it
  /// on insert and it is never overwritten on update.
  Map<String, Object?> toMap() => {
    'userId': userId,
    'title': title,
    'description': description,
    'dueDate': dueDate.toIso8601String(),
    'dueTime': dueTime,
    'priority': priority.index,
    'category': category,
    'isCompleted': isCompleted ? 1 : 0,
    'isAllDay': isAllDay ? 1 : 0,
    'reminder': reminder ? 1 : 0,
    'reminderMinutes': reminderMinutes,
    'completedAt': completedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

class SubtaskModel extends Subtask {
  SubtaskModel({
    super.id,
    required super.taskId,
    required super.title,
    super.isCompleted,
  });

  factory SubtaskModel.fromEntity(Subtask s) => SubtaskModel(
    id: s.id,
    taskId: s.taskId,
    title: s.title,
    isCompleted: s.isCompleted,
  );

  factory SubtaskModel.fromMap(Map<String, Object?> map) => SubtaskModel(
    id: map['id'] as int?,
    taskId: map['taskId'] as int,
    title: map['title'] as String? ?? '',
    isCompleted: (map['isCompleted'] as int? ?? 0) == 1,
  );

  Map<String, Object?> toMap() => {
    'taskId': taskId,
    'title': title,
    'isCompleted': isCompleted ? 1 : 0,
  };
}
