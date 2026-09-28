import '../../../../core/utils/date_time_utils.dart';

/// Categories every account starts with. Users can add their own tags.
const kBuiltInCategories = ['Work', 'Personal', 'Health', 'Shopping'];

enum TaskPriority {
  low('Low', 'Casual'),
  medium('Medium', 'Normal'),
  high('High', 'Urgent');

  const TaskPriority(this.label, this.mood);

  final String label;

  /// Second line on the priority picker ("Casual", "Normal", "Urgent").
  final String mood;
}

/// Stored values can be missing or out of range in old rows.
TaskPriority taskPriorityFromIndex(int? index) {
  if (index == null || index < 0 || index >= TaskPriority.values.length) {
    return TaskPriority.medium;
  }
  return TaskPriority.values[index];
}

enum RepeatRule { none, daily, weekdays, weekly, monthly }

RepeatRule repeatRuleFromName(String? name) => RepeatRule.values.firstWhere(
  (rule) => rule.name == name,
  orElse: () => RepeatRule.none,
);

extension RepeatRuleText on RepeatRule {
  String describe(DateTime anchor) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return switch (this) {
      RepeatRule.none => 'Does not repeat',
      RepeatRule.daily => 'Every day',
      RepeatRule.weekdays => 'Every weekday',
      RepeatRule.weekly => 'Every ${weekdays[anchor.weekday - 1]}',
      RepeatRule.monthly => 'Monthly on the ${ordinal(anchor.day)}',
    };
  }

  /// The first occurrence after [date], keeping the time of day.
  DateTime next(DateTime date) {
    switch (this) {
      case RepeatRule.none:
        return date;
      case RepeatRule.daily:
        return addDays(date, 1);
      case RepeatRule.weekdays:
        var next = addDays(date, 1);
        while (next.weekday == DateTime.saturday ||
            next.weekday == DateTime.sunday) {
          next = addDays(next, 1);
        }
        return next;
      case RepeatRule.weekly:
        return addDays(date, 7);
      case RepeatRule.monthly:
        final month = date.month + 1;
        final year = date.year + (month > 12 ? 1 : 0);
        final m = month > 12 ? 1 : month;
        final day = date.day.clamp(1, daysInMonth(year, m));
        return DateTime(year, m, day, date.hour, date.minute);
    }
  }
}

class Task {
  final int? id;
  final String? userId;
  final String title;
  final String description;

  /// Due day; for timed tasks the time of day is included too.
  final DateTime dueDate;

  /// Display form of the due time, e.g. `02:00 PM`. Empty for all-day tasks.
  final String dueTime;
  final TaskPriority priority;
  final String category;
  final bool isCompleted;
  final bool isAllDay;
  final bool reminder;
  final int reminderMinutes;
  final RepeatRule repeat;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Subtask> subtasks;

  const Task({
    this.id,
    this.userId,
    required this.title,
    this.description = '',
    required this.dueDate,
    this.dueTime = '',
    this.priority = TaskPriority.medium,
    this.category = '',
    this.isCompleted = false,
    this.isAllDay = false,
    this.reminder = false,
    this.reminderMinutes = 15,
    this.repeat = RepeatRule.none,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    this.subtasks = const [],
  });

  /// When the task is actually due. All-day tasks run until the end of
  /// their day.
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

  /// Rows completed before `completedAt` existed fall back to `updatedAt`.
  DateTime? get effectiveCompletedAt =>
      isCompleted ? (completedAt ?? updatedAt) : null;

  int get completedSubtasks => subtasks.where((s) => s.isCompleted).length;

  /// The follow-up task for a repeating task, due on the first occurrence
  /// that isn't already in the past.
  Task? nextOccurrence(DateTime now) {
    if (repeat == RepeatRule.none) return null;
    var due = repeat.next(dueDate);
    while (copyWith(dueDate: due).deadline.isBefore(now)) {
      due = repeat.next(due);
    }
    return Task(
      userId: userId,
      title: title,
      description: description,
      dueDate: due,
      dueTime: dueTime,
      priority: priority,
      category: category,
      isAllDay: isAllDay,
      reminder: reminder,
      reminderMinutes: reminderMinutes,
      repeat: repeat,
      createdAt: now,
      updatedAt: now,
      subtasks: [for (final s in subtasks) Subtask(taskId: 0, title: s.title)],
    );
  }

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
    RepeatRule? repeat,
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
      repeat: repeat ?? this.repeat,
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

  const Subtask({
    this.id,
    required this.taskId,
    required this.title,
    this.isCompleted = false,
  });

  Subtask copyWith({bool? isCompleted}) => Subtask(
    id: id,
    taskId: taskId,
    title: title,
    isCompleted: isCompleted ?? this.isCompleted,
  );
}
