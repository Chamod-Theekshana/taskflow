import 'package:flutter/material.dart';

import '../../../../core/utils/date_time_utils.dart';

enum TaskPriority { low, medium, high }

/// Safe conversion from a stored index (the value may be missing or out of
/// range in old / hand-edited data).
TaskPriority taskPriorityFromIndex(int? index) {
  if (index == null || index < 0 || index >= TaskPriority.values.length) {
    return TaskPriority.medium;
  }
  return TaskPriority.values[index];
}

extension TaskPriorityExtension on TaskPriority {
  /// `Low`, `Medium`, `High`
  String get label {
    switch (this) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
    }
  }

  String get displayName => '$label Priority';

  Color get color {
    switch (this) {
      case TaskPriority.low:
        return const Color(0xFF006C49);
      case TaskPriority.medium:
        return const Color(0xFF825100);
      case TaskPriority.high:
        return const Color(0xFFBA1A1A);
    }
  }
}

class Task {
  final int? id;

  /// Owner of the task. Tasks are private to the account that created them.
  final String? userId;
  final String title;
  final String description;

  /// Due day. For timed tasks the time of day is included as well.
  final DateTime dueDate;

  /// Display string of the due time, e.g. `02:00 PM`. Empty for all-day tasks.
  final String dueTime;
  final TaskPriority priority;
  final String category;
  final bool isCompleted;
  final bool isAllDay;
  final bool reminder;
  final int reminderMinutes;

  /// When the task was marked complete (null while open).
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Subtask> subtasks;

  Task({
    this.id,
    this.userId,
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
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    this.subtasks = const [],
  });

  /// The moment the task is actually due. All-day tasks are due at the end
  /// of their day; timed tasks at their time (falling back to the time stored
  /// in [dueTime] for rows written by older versions of the app).
  DateTime get deadline {
    if (isAllDay) {
      return DateTime(dueDate.year, dueDate.month, dueDate.day, 23, 59, 59);
    }
    final time = parseTimeOfDay(dueTime);
    if (time != null) return combineDateAndTime(dueDate, time);
    return dueDate;
  }

  bool isOverdue([DateTime? now]) =>
      !isCompleted && deadline.isBefore(now ?? DateTime.now());

  /// Completion time used for statistics. Rows completed before
  /// `completedAt` existed fall back to their last update time.
  DateTime? get effectiveCompletedAt =>
      isCompleted ? (completedAt ?? updatedAt) : null;

  Task copyWith({
    int? id,
    String? userId,
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
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Subtask>? subtasks,
  }) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
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
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
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

  Subtask copyWith({int? id, int? taskId, String? title, bool? isCompleted}) {
    return Subtask(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
