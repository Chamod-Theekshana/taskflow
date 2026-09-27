import '../../domain/entities/task.dart';

class TaskModel extends Task {
  TaskModel({
    super.id,
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
    required super.createdAt,
    required super.updatedAt,
    super.subtasks,
  });

  factory TaskModel.fromEntity(Task t) => TaskModel(
        id: t.id,
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
        createdAt: t.createdAt,
        updatedAt: t.updatedAt,
        subtasks: t.subtasks,
      );

  factory TaskModel.fromMap(Map<String, dynamic> map, {List<SubtaskModel>? subtasks}) => TaskModel(
        id: map['id'] as int?,
        title: map['title'] as String,
        description: map['description'] as String? ?? '',
        dueDate: DateTime.parse(map['dueDate'] as String),
        dueTime: map['dueTime'] as String? ?? '',
        priority: TaskPriority.values[map['priority'] as int? ?? 1],
        category: map['category'] as String? ?? '',
        isCompleted: (map['isCompleted'] as int? ?? 0) == 1,
        isAllDay: (map['isAllDay'] as int? ?? 0) == 1,
        reminder: (map['reminder'] as int? ?? 0) == 1,
        reminderMinutes: map['reminderMinutes'] as int? ?? 0,
        createdAt: DateTime.parse(map['createdAt'] as String),
        updatedAt: DateTime.parse(map['updatedAt'] as String),
        subtasks: subtasks ?? [],
      );
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

  factory SubtaskModel.fromMap(Map<String, dynamic> map) => SubtaskModel(
        id: map['id'] as int?,
        taskId: map['taskId'] as int,
        title: map['title'] as String,
        isCompleted: (map['isCompleted'] as int? ?? 0) == 1,
      );
}
