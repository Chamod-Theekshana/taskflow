import 'package:flutter/material.dart' show TimeOfDay;

import '../../../../core/utils/date_time_utils.dart';
import '../../domain/entities/task.dart';

DateTime? _parseDate(Object? value) =>
    value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;

/// SQLite row <-> [Task].
abstract final class TaskRow {
  static Task fromMap(Map<String, Object?> map, {List<Subtask>? subtasks}) {
    final now = DateTime.now();
    return Task(
      id: map['id'] as int?,
      uuid: map['uuid'] as String?,
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
  /// insert and it's never overwritten on update; the owner and sync columns
  /// are set by the data source.
  static Map<String, Object?> toMap(Task task) => {
    'uuid': task.uuid,
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
    uuid: map['uuid'] as String?,
    taskId: map['taskId'] as int,
    title: map['title'] as String? ?? '',
    isCompleted: (map['isCompleted'] as int? ?? 0) == 1,
  );

  static Map<String, Object?> toMap(Subtask subtask, {int position = 0}) => {
    'uuid': subtask.uuid,
    'taskId': subtask.taskId,
    'title': subtask.title,
    'isCompleted': subtask.isCompleted ? 1 : 0,
    'position': position,
  };
}

/// Millisecond precision: what the server stores, so timestamps compare
/// equal after a round trip.
String _utc(DateTime time) => DateTime.fromMillisecondsSinceEpoch(
  time.millisecondsSinceEpoch,
  isUtc: true,
).toIso8601String();

/// Keeps text within what the server accepts (it rejects longer values),
/// without cutting an emoji (a surrogate pair) in half.
String _clip(String text, int max) {
  if (text.length <= max) return text;
  var end = max;
  final unit = text.codeUnitAt(end - 1);
  if (unit >= 0xD800 && unit <= 0xDBFF) end--;
  return text.substring(0, end);
}

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// API JSON <-> [Task] (the `SyncTask` / `Task` schemas of the server).
///
/// The server stores the calendar day, the time of day and the time zone.
/// Timed tasks come back as the same instant in this device's zone, so a
/// 2 PM meeting set in Colombo shows as 9:30 AM in London. All-day tasks keep
/// their calendar day.
abstract final class TaskDto {
  static Map<String, dynamic> toJson(Task task, {required String timezone}) {
    final due = task.dueDate;
    final time = task.isAllDay
        ? null
        : (parseTimeOfDay(task.dueTime) ??
              TimeOfDay(hour: due.hour, minute: due.minute));
    final completedAt = task.isCompleted
        ? (task.completedAt ?? task.updatedAt)
        : null;
    return {
      'id': task.uuid,
      'title': task.title.trim().isEmpty
          ? 'Untitled'
          : _clip(task.title.trim(), 200),
      'description': _clip(task.description, 20000),
      'dueDate': _day(due),
      'dueTime': time == null ? null : formatTime24(time),
      'isAllDay': task.isAllDay,
      'timezone': timezone,
      'priority': task.priority.name,
      'category': _clip(task.category.trim(), 100),
      'isCompleted': task.isCompleted,
      'completedAt': completedAt == null ? null : _utc(completedAt),
      'reminder': task.reminder,
      'reminderMinutes': task.reminderMinutes.clamp(0, 10080),
      'repeat': task.repeat.name,
      'subtasks': [
        for (final s in task.subtasks)
          if (s.title.trim().isNotEmpty)
            {
              if (s.uuid != null) 'id': s.uuid,
              'title': _clip(s.title.trim(), 200),
              'isCompleted': s.isCompleted,
            },
      ],
      'createdAt': _utc(task.createdAt),
      'updatedAt': _utc(task.updatedAt),
    };
  }

  /// A task from the server, plus its deletion time for tombstones.
  static ({Task task, DateTime? deletedAt}) fromJson(Map<String, dynamic> json) {
    final isAllDay = json['isAllDay'] == true;
    final dueAt =
        DateTime.tryParse(json['dueAt'] as String? ?? '')?.toLocal() ??
        DateTime.now();

    final DateTime dueDate;
    final String dueTime;
    if (isAllDay) {
      final day = DateTime.tryParse(json['dueDate'] as String? ?? '') ?? dueAt;
      dueDate = DateTime(day.year, day.month, day.day);
      dueTime = '';
    } else {
      dueDate = dueAt;
      dueTime = formatTimeOfDay(
        TimeOfDay(hour: dueAt.hour, minute: dueAt.minute),
      );
    }

    DateTime? instant(String key) =>
        DateTime.tryParse(json[key] as String? ?? '')?.toLocal();

    final priority = TaskPriority.values.firstWhere(
      (p) => p.name == json['priority'],
      orElse: () => TaskPriority.medium,
    );
    final subtasks = <Subtask>[
      for (final item in (json['subtasks'] as List? ?? const []))
        if (item is Map)
          Subtask(
            uuid: item['id'] as String?,
            taskId: 0,
            title: '${item['title'] ?? ''}',
            isCompleted: item['isCompleted'] == true,
          ),
    ];
    final now = DateTime.now();

    return (
      task: Task(
        uuid: json['id'] as String,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        dueDate: dueDate,
        dueTime: dueTime,
        isAllDay: isAllDay,
        priority: priority,
        category: json['category'] as String? ?? '',
        isCompleted: json['isCompleted'] == true,
        completedAt: instant('completedAt'),
        reminder: json['reminder'] == true,
        reminderMinutes: (json['reminderMinutes'] as num?)?.toInt() ?? 15,
        repeat: repeatRuleFromName(json['repeat'] as String?),
        createdAt: instant('createdAt') ?? now,
        updatedAt: instant('updatedAt') ?? now,
        subtasks: subtasks,
      ),
      deletedAt: instant('deletedAt'),
    );
  }
}
