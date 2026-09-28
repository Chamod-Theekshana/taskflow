import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/features/tasks/domain/entities/task.dart';

void main() {
  test('next occurrence keeps the time of day', () {
    final due = DateTime(2026, 9, 28, 14, 30); // Monday
    expect(RepeatRule.daily.next(due), DateTime(2026, 9, 29, 14, 30));
    expect(RepeatRule.weekly.next(due), DateTime(2026, 10, 5, 14, 30));
  });

  test('weekdays skip the weekend', () {
    final friday = DateTime(2026, 10, 2, 9);
    expect(RepeatRule.weekdays.next(friday), DateTime(2026, 10, 5, 9));
  });

  test('monthly clamps to the end of shorter months', () {
    expect(
      RepeatRule.monthly.next(DateTime(2026, 1, 31, 8)),
      DateTime(2026, 2, 28, 8),
    );
    expect(
      RepeatRule.monthly.next(DateTime(2026, 12, 15)),
      DateTime(2027, 1, 15),
    );
  });

  test('a late repeating task jumps to the next date that is not past', () {
    final task = Task(
      id: 1,
      title: 'Water the plants',
      dueDate: DateTime(2026, 9, 20, 18),
      dueTime: '06:00 PM',
      repeat: RepeatRule.daily,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
      subtasks: const [
        Subtask(id: 4, taskId: 1, title: 'Balcony', isCompleted: true),
      ],
    );
    final next = task.nextOccurrence(DateTime(2026, 9, 28, 10))!;
    expect(next.dueDate, DateTime(2026, 9, 28, 18));
    expect(next.id, isNull);
    expect(next.isCompleted, isFalse);
    expect(next.subtasks.single.isCompleted, isFalse);
  });

  test('tasks that do not repeat have no next occurrence', () {
    final task = Task(
      title: 'Once',
      dueDate: DateTime(2026, 9, 28),
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
    );
    expect(task.nextOccurrence(DateTime(2026, 9, 28)), isNull);
  });

  test('describe', () {
    final monday = DateTime(2026, 9, 28);
    expect(RepeatRule.none.describe(monday), 'Does not repeat');
    expect(RepeatRule.weekly.describe(monday), 'Every Monday');
    expect(RepeatRule.monthly.describe(monday), 'Monthly on the 28th');
    expect(repeatRuleFromName('bogus'), RepeatRule.none);
  });
}
