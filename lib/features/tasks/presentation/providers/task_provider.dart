import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/task_local_data_source.dart';
import '../../data/repositories/task_repository_impl.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';

enum TaskFilter { all, today, upcoming, completed }

class TaskStats {
  final int tasksCompleted;
  final int totalTasks;
  final double onTimePercentage;

  /// Consecutive days (ending today, or yesterday if nothing was finished
  /// yet today) on which at least one task was completed.
  final int currentStreak;

  /// Completed tasks per day of the current week, Monday first.
  final List<int> weeklyCompletions;

  const TaskStats({
    this.tasksCompleted = 0,
    this.totalTasks = 0,
    this.onTimePercentage = 0.0,
    this.currentStreak = 0,
    this.weeklyCompletions = const [0, 0, 0, 0, 0, 0, 0],
  });

  int get completedThisWeek => weeklyCompletions.fold(0, (a, b) => a + b);
}

class TaskListState {
  final List<Task> tasks;
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;
  final TaskFilter filter;

  const TaskListState({
    this.tasks = const [],
    this.isLoading = false,
    this.errorMessage,
    this.searchQuery = '',
    this.filter = TaskFilter.all,
  });

  TaskListState copyWith({
    List<Task>? tasks,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? searchQuery,
    TaskFilter? filter,
  }) => TaskListState(
    tasks: tasks ?? this.tasks,
    isLoading: isLoading ?? this.isLoading,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    searchQuery: searchQuery ?? this.searchQuery,
    filter: filter ?? this.filter,
  );

  Task? taskById(int id) {
    for (final task in tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  static bool matchesFilter(Task task, TaskFilter filter, DateTime now) {
    switch (filter) {
      case TaskFilter.all:
        return true;
      case TaskFilter.completed:
        return task.isCompleted;
      case TaskFilter.upcoming:
        return !task.isCompleted && task.deadline.isAfter(now);
      case TaskFilter.today:
        return isSameDate(task.dueDate, now);
    }
  }

  int countFor(TaskFilter filter, [DateTime? now]) {
    final current = now ?? DateTime.now();
    return tasks.where((t) => matchesFilter(t, filter, current)).length;
  }

  /// Tasks for the active filter and search query. Open tasks come first
  /// (soonest deadline first), completed tasks last.
  List<Task> get filteredTasks {
    final now = DateTime.now();
    final query = searchQuery.trim().toLowerCase();
    final result = tasks.where((t) {
      if (!matchesFilter(t, filter, now)) return false;
      if (query.isEmpty) return true;
      return t.title.toLowerCase().contains(query) ||
          t.description.toLowerCase().contains(query) ||
          t.category.toLowerCase().contains(query);
    }).toList();

    result.sort((a, b) {
      if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
      return a.deadline.compareTo(b.deadline);
    });
    return result;
  }

  List<Task> tasksOn(DateTime day) {
    final result = tasks.where((t) => isSameDate(t.dueDate, day)).toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));
    return result;
  }

  double get completionPercentage {
    if (tasks.isEmpty) return 0.0;
    return tasks.where((t) => t.isCompleted).length / tasks.length;
  }

  TaskStats get stats => computeStats(DateTime.now());

  TaskStats computeStats(DateTime now) {
    final completed = tasks.where((t) => t.isCompleted).toList();

    var onTime = 0;
    final completionDays = <DateTime>{};
    for (final t in completed) {
      final doneAt = t.effectiveCompletedAt!;
      if (!doneAt.isAfter(t.deadline)) onTime++;
      completionDays.add(dateOnly(doneAt));
    }

    // Streak: walk back day by day from today (or yesterday).
    final today = dateOnly(now);
    var day = completionDays.contains(today)
        ? today
        : DateTime(today.year, today.month, today.day - 1);
    var streak = 0;
    while (completionDays.contains(day)) {
      streak++;
      day = DateTime(day.year, day.month, day.day - 1);
    }

    // Weekly breakdown, Monday..Sunday of the current week.
    final monday = DateTime(today.year, today.month, today.day - (today.weekday - 1));
    final weekly = List<int>.filled(7, 0);
    for (final t in completed) {
      final doneDay = dateOnly(t.effectiveCompletedAt!);
      final index = daysBetween(monday, doneDay);
      if (index >= 0 && index < 7) weekly[index]++;
    }

    return TaskStats(
      tasksCompleted: completed.length,
      totalTasks: tasks.length,
      onTimePercentage: completed.isEmpty ? 0.0 : onTime / completed.length,
      currentStreak: streak,
      weeklyCompletions: weekly,
    );
  }
}

/// Repository for the signed-in account. Rebuilt whenever the user changes,
/// which in turn reloads [taskListProvider].
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final db = ref.watch(dbProviderProvider);
  final userId = ref.watch(authProvider.select((auth) => auth.value?.id));
  return TaskRepositoryImpl(TaskLocalDataSourceImpl(db, userId));
});

final taskListProvider = NotifierProvider<TaskListNotifier, TaskListState>(
  TaskListNotifier.new,
);

class TaskListNotifier extends Notifier<TaskListState> {
  late TaskRepository _repository;

  /// Incremented on every (re)build, e.g. when another account signs in, so
  /// results of a load started for the previous account are discarded.
  int _generation = 0;

  @override
  TaskListState build() {
    _repository = ref.watch(taskRepositoryProvider);
    _generation++;
    // `state` cannot be read or written until build() has returned, so the
    // first load is scheduled instead of being started synchronously here.
    // (Starting it here threw "uninitialized provider" and the task list
    // never loaded.)
    Future.microtask(_loadTasks);
    return const TaskListState(isLoading: true);
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  Future<void> _loadTasks() async {
    final generation = _generation;
    if (!_isCurrent(generation)) return;
    final repository = _repository;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final tasks = await repository.getAllTasks();
      if (!_isCurrent(generation)) return;
      state = state.copyWith(tasks: tasks, isLoading: false, clearError: true);
    } catch (e) {
      if (!_isCurrent(generation)) return;
      state = state.copyWith(isLoading: false, errorMessage: describeError(e));
    }
  }

  Future<void> refresh() => _loadTasks();

  void setSearchQuery(String query) =>
      state = state.copyWith(searchQuery: query);

  void setFilter(TaskFilter filter) => state = state.copyWith(filter: filter);

  Future<int> addTask(Task task) async {
    final id = await _repository.insertTask(task);
    await _loadTasks();
    return id;
  }

  Future<void> updateTask(Task task) async {
    await _repository.updateTask(task.copyWith(updatedAt: DateTime.now()));
    await _loadTasks();
  }

  /// Marks a task complete / reopens it and records when it was completed.
  Future<void> toggleComplete(Task task) async {
    final now = DateTime.now();
    final updated = task.isCompleted
        ? task.copyWith(isCompleted: false, clearCompletedAt: true)
        : task.copyWith(isCompleted: true, completedAt: now);
    await updateTask(updated);
  }

  Future<void> deleteTask(int id) async {
    await _repository.deleteTask(id);
    await _loadTasks();
  }

  Future<Task?> getTaskById(int id) async {
    return state.taskById(id) ?? await _repository.getTaskById(id);
  }

  Future<void> toggleSubtask(int taskId, int subtaskId) async {
    final task = state.taskById(taskId);
    if (task == null) return;
    Subtask? subtask;
    for (final s in task.subtasks) {
      if (s.id == subtaskId) subtask = s;
    }
    if (subtask == null) return;
    await _repository.updateSubtask(
      subtask.copyWith(isCompleted: !subtask.isCompleted),
    );
    await _loadTasks();
  }

  Future<void> addSubtask(Subtask subtask) async {
    await _repository.insertSubtask(subtask);
    await _loadTasks();
  }

  Future<void> deleteSubtask(int subtaskId) async {
    await _repository.deleteSubtask(subtaskId);
    await _loadTasks();
  }
}
