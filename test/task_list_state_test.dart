import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/features/tasks/domain/entities/task.dart';
import 'package:taskflow/features/tasks/presentation/providers/task_provider.dart';

Task _task(
  int id, {
  required DateTime due,
  bool done = false,
  DateTime? completedAt,
  String title = 'Task',
  bool allDay = false,
}) => Task(
  id: id,
  title: '$title $id',
  description: '',
  dueDate: due,
  dueTime: '',
  priority: TaskPriority.medium,
  category: 'Work',
  isCompleted: done,
  isAllDay: allDay,
  completedAt: completedAt,
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 1),
);

void main() {
  final now = DateTime(2026, 9, 28, 12); // a Monday

  test('taskById returns null instead of throwing', () {
    final state = TaskListState(tasks: [_task(1, due: now)]);
    expect(state.taskById(1)?.id, 1);
    expect(state.taskById(99), isNull);
  });

  test('filters use the same rules as their counters', () {
    final state = TaskListState(
      tasks: [
        _task(1, due: DateTime(2026, 9, 28, 18)), // today, upcoming
        _task(2, due: DateTime(2026, 9, 30)), // upcoming
        _task(3, due: DateTime(2026, 9, 30), done: true), // completed
        _task(4, due: DateTime(2026, 9, 20)), // overdue
      ],
    );
    expect(state.countFor(TaskFilter.all, now), 4);
    expect(state.countFor(TaskFilter.today, now), 1);
    expect(state.countFor(TaskFilter.upcoming, now), 2);
    expect(state.countFor(TaskFilter.completed, now), 1);
  });

  test('all-day tasks are due at the end of their day', () {
    final task = _task(1, due: DateTime(2026, 9, 28), allDay: true);
    expect(task.isOverdue(now), isFalse);
    expect(task.isOverdue(DateTime(2026, 9, 29, 0, 1)), isTrue);
  });

  test('stats: on-time percentage, streak and weekly breakdown', () {
    final state = TaskListState(
      tasks: [
        // Completed today, before its deadline.
        _task(
          1,
          due: DateTime(2026, 9, 28, 18),
          done: true,
          completedAt: DateTime(2026, 9, 28, 9),
        ),
        // Completed yesterday (Sunday, previous week), late.
        _task(
          2,
          due: DateTime(2026, 9, 26),
          done: true,
          completedAt: DateTime(2026, 9, 27, 9),
        ),
        _task(3, due: DateTime(2026, 10, 1)),
      ],
    );
    final stats = state.computeStats(now);
    expect(stats.tasksCompleted, 2);
    expect(stats.totalTasks, 3);
    expect(stats.onTimePercentage, 0.5);
    expect(stats.currentStreak, 2);
    expect(stats.weeklyCompletions, [1, 0, 0, 0, 0, 0, 0]);
  });

  test('search matches title, description and category', () {
    final state = TaskListState(
      tasks: [
        _task(1, due: now, title: 'Write report'),
        _task(2, due: now, title: 'Buy milk'),
      ],
      searchQuery: 'report',
    );
    expect(state.filteredTasks.map((t) => t.id), [1]);
  });

  test('copyWith can clear completedAt', () {
    final task = _task(1, due: now, done: true, completedAt: now);
    final reopened = task.copyWith(isCompleted: false, clearCompletedAt: true);
    expect(reopened.completedAt, isNull);
    expect(reopened.isCompleted, isFalse);
  });

  test('taskPriorityFromIndex is safe for bad data', () {
    expect(taskPriorityFromIndex(null), TaskPriority.medium);
    expect(taskPriorityFromIndex(7), TaskPriority.medium);
    expect(taskPriorityFromIndex(2), TaskPriority.high);
  });
}
