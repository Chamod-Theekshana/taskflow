import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

enum TaskPriority { low, medium, high }

extension TaskPriorityExtension on TaskPriority {
  String get displayName {
    switch (this) {
      case TaskPriority.low:
        return 'Low Priority';
      case TaskPriority.medium:
        return 'Medium Priority';
      case TaskPriority.high:
        return 'High Priority';
    }
  }

  Color get color {
    switch (this) {
      case TaskPriority.low:
        return AppColors.secondary;
      case TaskPriority.medium:
        return AppColors.tertiary;
      case TaskPriority.high:
        return AppColors.error;
    }
  }
}

class Task {
  final int? id;
  final String title;
  final String description;
  final DateTime dueDate;
  final String dueTime;
  final TaskPriority priority;
  final String category;
  final bool isCompleted;
  final bool isAllDay;
  final bool reminder;
  final int reminderMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Subtask> subtasks;

  Task({
    this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.dueTime,
    required this.priority,
    required this.category,
    this.isCompleted = false,
    this.isAllDay = false,
    this.reminder = false,
    this.reminderMinutes = 0,
    required this.createdAt,
    required this.updatedAt,
    this.subtasks = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
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
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map, {List<Subtask>? subtasks}) {
    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      dueDate: DateTime.parse(map['dueDate']),
      dueTime: map['dueTime'],
      priority: TaskPriority.values[map['priority']],
      category: map['category'],
      isCompleted: map['isCompleted'] == 1,
      isAllDay: map['isAllDay'] == 1,
      reminder: map['reminder'] == 1,
      reminderMinutes: map['reminderMinutes'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      subtasks: subtasks ?? [],
    );
  }

  Task copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? dueDate,
    String? dueTime,
    TaskPriority? priority,
    String? category,
    bool? isCompleted,
    bool? isAllDay,
    bool? reminder,
    int? reminderMinutes,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Subtask>? subtasks,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      dueTime: dueTime ?? this.dueTime,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      isCompleted: isCompleted ?? this.isCompleted,
      isAllDay: isAllDay ?? this.isAllDay,
      reminder: reminder ?? this.reminder,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      subtasks: subtasks ?? this.subtasks,
    );
  }
}

class Subtask {
  final int? id;
  final int taskId;
  final String title;
  final bool isCompleted;

  Subtask({
    this.id,
    required this.taskId,
    required this.title,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taskId': taskId,
      'title': title,
      'isCompleted': isCompleted ? 1 : 0,
    };
  }

  factory Subtask.fromMap(Map<String, dynamic> map) {
    return Subtask(
      id: map['id'],
      taskId: map['taskId'],
      title: map['title'],
      isCompleted: map['isCompleted'] == 1,
    );
  }

  Subtask copyWith({
    int? id,
    int? taskId,
    String? title,
    bool? isCompleted,
  }) {
    return Subtask(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
