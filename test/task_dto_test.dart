import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/features/tasks/data/models/task_model.dart';
import 'package:taskflow/features/tasks/domain/entities/task.dart';

void main() {
  final timed = Task(
    uuid: '3f2b8c1e-5d7a-4c55-9f3e-8a1b2c3d4e5f',
    title: '  Plan sprint ',
    description: 'Bring the roadmap',
    dueDate: DateTime(2026, 10, 1, 14),
    dueTime: '02:00 PM',
    priority: TaskPriority.high,
    category: 'Work',
    reminder: true,
    reminderMinutes: 30,
    repeat: RepeatRule.weekly,
    createdAt: DateTime.utc(2026, 9, 1, 8, 0, 0, 123, 456),
    updatedAt: DateTime.utc(2026, 9, 2),
    subtasks: const [
      Subtask(taskId: 1, uuid: 'b1d4c1e2-0000-4000-8000-000000000001', title: 'Draft'),
      Subtask(taskId: 1, title: 'New step', isCompleted: true),
      Subtask(taskId: 1, title: '   '),
    ],
  );

  test('a task is sent the way the API expects it', () {
    final json = TaskDto.toJson(timed, timezone: 'Asia/Colombo');
    expect(json['id'], timed.uuid);
    expect(json['title'], 'Plan sprint');
    expect(json['dueDate'], '2026-10-01');
    expect(json['dueTime'], '14:00');
    expect(json['timezone'], 'Asia/Colombo');
    expect(json['priority'], 'high');
    expect(json['repeat'], 'weekly');
    expect(json['completedAt'], isNull);
    // Millisecond precision, UTC.
    expect(json['createdAt'], '2026-09-01T08:00:00.123Z');

    final subtasks = json['subtasks'] as List;
    expect(subtasks, hasLength(2)); // the blank one is dropped
    expect((subtasks[0] as Map)['id'], 'b1d4c1e2-0000-4000-8000-000000000001');
    expect((subtasks[1] as Map).containsKey('id'), isFalse);
  });

  test('long text is trimmed to the API limits without splitting an emoji', () {
    final json = TaskDto.toJson(
      timed.copyWith(title: '${'a' * 199}\u{1F600} and more'),
      timezone: 'UTC',
    );
    expect(json['title'], 'a' * 199);
  });

  test('all-day tasks have no time', () {
    final json = TaskDto.toJson(
      timed.copyWith(isAllDay: true, dueTime: ''),
      timezone: 'UTC',
    );
    expect(json['dueTime'], isNull);
    expect(json['isAllDay'], isTrue);
  });

  test('tasks from the server keep their instant in local time', () {
    final dueAt = DateTime.utc(2026, 10, 1, 8, 30);
    final parsed = TaskDto.fromJson({
      'id': 'a',
      'title': 'Call Sam',
      'description': '',
      'dueDate': '2026-10-01',
      'dueTime': '14:00',
      'isAllDay': false,
      'timezone': 'Asia/Colombo',
      'dueAt': dueAt.toIso8601String(),
      'priority': 'low',
      'category': '',
      'isCompleted': false,
      'completedAt': null,
      'reminder': false,
      'reminderMinutes': 15,
      'remindAt': null,
      'repeat': 'daily',
      'subtasks': [
        {'id': 's1', 'title': 'Find number', 'isCompleted': true, 'position': 0},
      ],
      'createdAt': '2026-09-29T07:00:00.000Z',
      'updatedAt': '2026-09-29T07:00:00.000Z',
      'deletedAt': null,
    });
    final task = parsed.task;
    final local = dueAt.toLocal();
    expect(task.dueDate, local);
    expect(task.dueTime.isNotEmpty, isTrue);
    expect(task.priority, TaskPriority.low);
    expect(task.repeat, RepeatRule.daily);
    expect(task.subtasks.single.uuid, 's1');
    expect(task.subtasks.single.isCompleted, isTrue);
    expect(parsed.deletedAt, isNull);
  });

  test('all-day tasks from the server keep their calendar day', () {
    final parsed = TaskDto.fromJson({
      'id': 'b',
      'title': 'Holiday',
      'dueDate': '2026-12-25',
      'isAllDay': true,
      'dueAt': '2026-12-25T18:29:59.000Z',
      'deletedAt': '2026-12-26T00:00:00.000Z',
    });
    expect(parsed.task.dueDate, DateTime(2026, 12, 25));
    expect(parsed.task.dueTime, '');
    expect(parsed.deletedAt, isNotNull);
  });
}
