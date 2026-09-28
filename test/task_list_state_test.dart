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
  TaskPriority priority = TaskPriority.medium,
  String category = 'Work',
}) => Task(
  id: id,
  title: '$title $id',
  dueDate: due,
  priority: priority,
  category: category,
  isCompleted: done,
  isAllDay: allDay,
  completedAt: completedAt,
  createdAt: DateTime(2026, 9, 1, 0, id),
  updatedAt: DateTime(2026, 9, 1),
);

void main() {
  final now = DateTime(2026, 9, 28, 12); // a Monday

  test('taskById returns null instead of throwing', () {
    final state = TaskListState(tasks: [_task(1, due: now)]);
    expect(state.taskById(1)?.id, 1);
    expect(state.taskById(99), isNull);
  });

  test('filters and their counters agree', () {
    final state = TaskListState(
      tasks: [
        _task(1, due: DateTime(2026, 9, 28, 18)), // today
        _task(2, due: DateTime(2026, 9, 30)), // upcoming
        _task(3, due: DateTime(2026, 9, 30), done: true), // completed
        _task(4, due: DateTime(2026, 9, 20)), // overdue, shows under today
      ],
    );
    expect(state.countFor(TaskFilter.all, now), 4);
    expect(state.countFor(TaskFilter.today, now), 2);
    expect(state.countFor(TaskFilter.upcoming, now), 1);
    expect(state.countFor(TaskFilter.completed, now), 1);
  });

  test('all-day tasks are due at the end of their day', () {
    final task = _task(1, due: DateTime(2026, 9, 28), allDay: true);
    expect(task.isOverdue(now), isFalse);
    expect(task.isOverdue(DateTime(2026, 9, 29, 0, 1)), isTrue);
  });

  test('search matches title, notes, category and subtasks', () {
    final withSubtask = _task(
      3,
      due: now,
    ).copyWith(subtasks: const [Subtask(taskId: 3, title: 'Call the printer')]);
    final state = TaskListState(
      tasks: [
        _task(1, due: now, title: 'Write report'),
        _task(2, due: now, title: 'Buy milk', category: 'Shopping'),
        withSubtask,
      ],
    );
    List<int?> ids(String q) => state
        .copyWith(searchQuery: q)
        .visibleTasks(now)
        .map((t) => t.id)
        .toList();

    expect(ids('report'), [1]);
    expect(ids('shopping'), [2]);
    expect(ids('printer'), [3]);
  });

  test('refinements filter by priority and category, and sort', () {
    final state = TaskListState(
      tasks: [
        _task(1, due: DateTime(2026, 9, 29), priority: TaskPriority.low),
        _task(2, due: DateTime(2026, 9, 30), priority: TaskPriority.high),
        _task(3, due: DateTime(2026, 10, 1), category: 'Home'),
      ],
    );

    final byPriority = state.copyWith(sort: TaskSort.priority);
    expect(byPriority.visibleTasks(now).map((t) => t.id), [2, 3, 1]);

    final high = state.copyWith(priorityFilter: () => TaskPriority.high);
    expect(high.visibleTasks(now).map((t) => t.id), [2]);
    expect(high.hasRefinements, isTrue);

    final home = state.copyWith(categoryFilter: () => 'home');
    expect(home.visibleTasks(now).map((t) => t.id), [3]);
    expect(state.usedCategories, ['Home', 'Work']);
  });

  test('finished tasks sort after open ones', () {
    final state = TaskListState(
      tasks: [
        _task(1, due: DateTime(2026, 9, 29), done: true, completedAt: now),
        _task(2, due: DateTime(2026, 10, 5)),
      ],
    );
    expect(state.visibleTasks(now).map((t) => t.id), [2, 1]);
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
