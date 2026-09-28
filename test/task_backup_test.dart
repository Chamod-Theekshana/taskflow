import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/features/tasks/data/task_backup.dart';
import 'package:taskflow/features/tasks/domain/entities/task.dart';

void main() {
  final now = DateTime(2026, 9, 28, 10);

  test('a backup round-trips', () {
    final task = Task(
      id: 12,
      title: 'Plan sprint',
      description: 'Bring the roadmap',
      dueDate: DateTime(2026, 10, 1, 14),
      dueTime: '02:00 PM',
      priority: TaskPriority.high,
      category: 'Work',
      reminder: true,
      reminderMinutes: 30,
      repeat: RepeatRule.weekly,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 2),
      subtasks: const [
        Subtask(taskId: 12, title: 'Draft agenda', isCompleted: true),
      ],
    );

    final restored = TaskBackup.decode(TaskBackup.encode([task]), now: now);
    final copy = restored.single;
    expect(copy.id, isNull);
    expect(copy.title, task.title);
    expect(copy.description, task.description);
    expect(copy.dueDate, task.dueDate);
    expect(copy.dueTime, task.dueTime);
    expect(copy.priority, TaskPriority.high);
    expect(copy.reminderMinutes, 30);
    expect(copy.repeat, RepeatRule.weekly);
    expect(copy.createdAt, task.createdAt);
    expect(copy.subtasks.single.title, 'Draft agenda');
    expect(copy.subtasks.single.isCompleted, isTrue);
  });

  test('exports from the first version still import', () {
    const old = '''
[{"title": "Old task", "dueDate": "2026-09-01T09:00:00.000",
  "dueTime": "09:00 AM", "allDay": false, "priority": "Low",
  "category": "Home", "completed": true, "completedAt": null,
  "subtasks": [{"title": "step", "completed": false}]}]
''';
    final task = TaskBackup.decode(old, now: now).single;
    expect(task.priority, TaskPriority.low);
    expect(task.isCompleted, isTrue);
    expect(task.completedAt, now);
    expect(task.subtasks.single.title, 'step');
  });

  test('anything else is rejected with a friendly message', () {
    expect(() => TaskBackup.decode('hello'), throwsA(isA<Failure>()));
    expect(() => TaskBackup.decode('[]'), throwsA(isA<Failure>()));
    expect(() => TaskBackup.decode('{"a": 1}'), throwsA(isA<Failure>()));
  });
}
