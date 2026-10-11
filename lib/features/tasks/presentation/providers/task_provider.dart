import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/sync/data_change_bus.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/task_local_data_source.dart';
import '../../data/repositories/task_repository_impl.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';

enum TaskFilter { all, today, upcoming, completed }

enum TaskSort {
  dueDate('Due date'),
  priority('Priority'),
  recent('Recently added');

  const TaskSort(this.label);
  final String label;
}

class TaskListState {
  final List<Task> tasks;
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;
  final TaskFilter filter;
  final TaskSort sort;
  final TaskPriority? priorityFilter;
  final String? categoryFilter;

  const TaskListState({
    this.tasks = const [],
    this.isLoading = false,
    this.errorMessage,
    this.searchQuery = '',
    this.filter = TaskFilter.all,
    this.sort = TaskSort.dueDate,
    this.priorityFilter,
    this.categoryFilter,
  });

  TaskListState copyWith({
    List<Task>? tasks,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? searchQuery,
    TaskFilter? filter,
    TaskSort? sort,
    TaskPriority? Function()? priorityFilter,
    String? Function()? categoryFilter,
  }) {
    return TaskListState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      searchQuery: searchQuery ?? this.searchQuery,
      filter: filter ?? this.filter,
      sort: sort ?? this.sort,
      priorityFilter: priorityFilter != null
          ? priorityFilter()
          : this.priorityFilter,
      categoryFilter: categoryFilter != null
          ? categoryFilter()
          : this.categoryFilter,
    );
  }

  Task? taskById(int id) {
    for (final task in tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  Task? taskByUuid(String uuid) {
    for (final task in tasks) {
      if (task.uuid == uuid) return task;
    }
    return null;
  }

  bool get hasRefinements =>
      priorityFilter != null ||
      categoryFilter != null ||
      sort != TaskSort.dueDate;

  /// Today also shows anything overdue - that is work for today as well.
  static bool matchesFilter(Task task, TaskFilter filter, DateTime now) {
    return switch (filter) {
      TaskFilter.all => true,
      TaskFilter.today => isSameDate(task.dueDate, now) || task.isOverdue(now),
      TaskFilter.upcoming =>
        !task.isCompleted && dateOnly(task.dueDate).isAfter(dateOnly(now)),
      TaskFilter.completed => task.isCompleted,
    };
  }

  static bool matchesQuery(Task task, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return task.title.toLowerCase().contains(q) ||
        task.description.toLowerCase().contains(q) ||
        task.category.toLowerCase().contains(q) ||
        task.subtasks.any((s) => s.title.toLowerCase().contains(q));
  }

  int countFor(TaskFilter filter, [DateTime? now]) {
    final current = now ?? DateTime.now();
    return tasks.where((t) => matchesFilter(t, filter, current)).length;
  }

  /// What the task list shows: filter, search and refinements applied.
  /// Open tasks come first, finished ones last.
  List<Task> visibleTasks([DateTime? now]) {
    final current = now ?? DateTime.now();
    final result = tasks.where((t) {
      if (!matchesFilter(t, filter, current)) return false;
      if (priorityFilter != null && t.priority != priorityFilter) return false;
      if (categoryFilter != null &&
          t.category.toLowerCase() != categoryFilter!.toLowerCase()) {
        return false;
      }
      return matchesQuery(t, searchQuery);
    }).toList();
    return sortTasks(result, sort);
  }

  static List<Task> sortTasks(List<Task> tasks, TaskSort sort) {
    int compareOpen(Task a, Task b) {
      switch (sort) {
        case TaskSort.dueDate:
          return a.deadline.compareTo(b.deadline);
        case TaskSort.priority:
          final byPriority = b.priority.index.compareTo(a.priority.index);
          return byPriority != 0
              ? byPriority
              : a.deadline.compareTo(b.deadline);
        case TaskSort.recent:
          return b.createdAt.compareTo(a.createdAt);
      }
    }

    return [...tasks]..sort((a, b) {
      if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
      if (a.isCompleted) {
        return b.effectiveCompletedAt!.compareTo(a.effectiveCompletedAt!);
      }
      return compareOpen(a, b);
    });
  }

  List<Task> tasksOn(DateTime day) {
    final result = tasks.where((t) => isSameDate(t.dueDate, day)).toList()
      ..sort((a, b) {
        if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
        return a.deadline.compareTo(b.deadline);
      });
    return result;
  }

  List<String> get usedCategories {
    final seen = <String>{};
    final result = <String>[];
    for (final task in tasks) {
      final name = task.category.trim();
      if (name.isNotEmpty && seen.add(name.toLowerCase())) result.add(name);
    }
    return result..sort();
  }
}

final taskLocalDataSourceProvider = Provider<TaskLocalDataSource>(
  (ref) => TaskLocalDataSource(ref.watch(databaseProvider)),
);

/// Rebuilt when the signed-in account changes, which reloads the list.
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final userId = ref.watch(authProvider.select((auth) => auth.value?.id));
  final bus = ref.watch(dataChangeBusProvider);
  return TaskRepositoryImpl(
    ref.watch(taskLocalDataSourceProvider),
    userId,
    onLocalChange: () => bus.localChanged(DataScope.tasks),
  );
});

final taskListProvider = NotifierProvider<TaskListNotifier, TaskListState>(
  TaskListNotifier.new,
);

class TaskListNotifier extends Notifier<TaskListState> {
  late TaskRepository _repository;

  // Bumped on every rebuild (e.g. another account signs in) so a load that
  // was started for the previous account is thrown away.
  int _generation = 0;

  @override
  TaskListState build() {
    _repository = ref.watch(taskRepositoryProvider);
    _generation++;

    // Tasks pulled from the server (another device changed something).
    final pulled = ref
        .watch(dataChangeBusProvider)
        .remoteChanges
        .where((scope) => scope == DataScope.tasks)
        .listen((_) => _load());
    ref.onDispose(pulled.cancel);

    // `state` can't be touched until build() returns.
    Future.microtask(_load);
    return const TaskListState(isLoading: true);
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  Future<void> _load() async {
    final generation = _generation;
    if (!_isCurrent(generation)) return;
    try {
      final tasks = await _repository.getAllTasks();
      if (!_isCurrent(generation)) return;
      state = state.copyWith(tasks: tasks, isLoading: false, clearError: true);
    } catch (e) {
      if (!_isCurrent(generation)) return;
      state = state.copyWith(isLoading: false, errorMessage: describeError(e));
    }
  }

  /// Pull-to-refresh: syncs with the server, then reloads.
  Future<void> refresh() async {
    try {
      await ref.read(dataChangeBusProvider).syncNow();
    } catch (_) {
      // Offline: the local list is still correct.
    }
    await _load();
  }

  /// Shows [task] right away while it is being saved.
  void _replaceLocally(Task task) {
    state = state.copyWith(
      tasks: [for (final t in state.tasks) t.id == task.id ? task : t],
    );
  }

  void setSearchQuery(String query) =>
      state = state.copyWith(searchQuery: query);

  void setFilter(TaskFilter filter) => state = state.copyWith(filter: filter);

  void setRefinements({
    required TaskSort sort,
    required TaskPriority? priority,
    required String? category,
  }) {
    state = state.copyWith(
      sort: sort,
      priorityFilter: () => priority,
      categoryFilter: () => category,
    );
  }

  Future<int> addTask(Task task) async {
    final id = await _repository.insertTask(task);
    await _load();
    return id;
  }

  Future<void> updateTask(Task task) async {
    await _repository.updateTask(task.copyWith(updatedAt: DateTime.now()));
    await _load();
  }

  /// Completes or reopens [task]. Completing a repeating task also schedules
  /// its next occurrence; completing any task ticks off its subtasks.
  ///
  /// Returns the follow-up task when one was created.
  Future<Task?> toggleComplete(Task task) async {
    final now = DateTime.now();
    if (task.isCompleted) {
      final reopened = task.copyWith(
        isCompleted: false,
        clearCompletedAt: true,
        updatedAt: now,
      );
      _replaceLocally(reopened);
      try {
        await _repository.updateTask(reopened);
      } finally {
        await _load();
      }
      return null;
    }

    // The checkbox reacts at once; the database catches up right after.
    _replaceLocally(
      task.copyWith(
        isCompleted: true,
        completedAt: now,
        updatedAt: now,
        subtasks: [for (final s in task.subtasks) s.copyWith(isCompleted: true)],
      ),
    );
    try {
      await _repository.updateTask(
        task.copyWith(isCompleted: true, completedAt: now, updatedAt: now),
      );
      for (final subtask in task.subtasks.where((s) => !s.isCompleted)) {
        await _repository.updateSubtask(subtask.copyWith(isCompleted: true));
      }

      Task? follower = task.nextOccurrence(now);
      if (follower != null && _alreadyScheduled(follower)) follower = null;
      if (follower != null) await _repository.insertTask(follower);
      return follower;
    } finally {
      await _load();
    }
  }

  // Completing, reopening and completing again must not stack up copies.
  bool _alreadyScheduled(Task next) => state.tasks.any(
    (t) =>
        !t.isCompleted &&
        t.repeat == next.repeat &&
        t.title == next.title &&
        isSameDate(t.dueDate, next.dueDate),
  );

  Future<void> deleteTask(int id) async {
    state = state.copyWith(
      tasks: [for (final t in state.tasks) if (t.id != id) t],
    );
    try {
      await _repository.deleteTask(id);
    } finally {
      await _load();
    }
  }

  Future<Task?> getTaskById(int id) async {
    return state.taskById(id) ?? await _repository.getTaskById(id);
  }

  Future<void> toggleSubtask(Subtask subtask) async {
    final toggled = subtask.copyWith(isCompleted: !subtask.isCompleted);
    final parent = state.taskById(subtask.taskId);
    if (parent != null) {
      _replaceLocally(
        parent.copyWith(
          subtasks: [
            for (final s in parent.subtasks) s.id == subtask.id ? toggled : s,
          ],
        ),
      );
    }
    try {
      await _repository.updateSubtask(toggled);
    } finally {
      await _load();
    }
  }

  static const maxSubtasks = 50;

  Future<void> addSubtask(int taskId, String title) async {
    final parent = state.taskById(taskId);
    if (parent != null && parent.subtasks.length >= maxSubtasks) {
      throw const Failure('A task can have up to $maxSubtasks subtasks.');
    }
    await _repository.insertSubtask(Subtask(taskId: taskId, title: title));
    await _load();
  }

  Future<void> deleteSubtask(int subtaskId) async {
    state = state.copyWith(
      tasks: [
        for (final t in state.tasks)
          t.subtasks.any((s) => s.id == subtaskId)
              ? t.copyWith(
                  subtasks: [
                    for (final s in t.subtasks)
                      if (s.id != subtaskId) s,
                  ],
                )
              : t,
      ],
    );
    try {
      await _repository.deleteSubtask(subtaskId);
    } finally {
      await _load();
    }
  }

  /// Adds tasks from a backup, skipping ones that are already in the list.
  /// Returns how many were added.
  Future<int> importTasks(List<Task> incoming) async {
    String key(Task t) => '${t.title}|${t.dueDate.toIso8601String()}';
    final known = {for (final t in state.tasks) key(t)};
    var added = 0;
    for (final task in incoming) {
      if (!known.add(key(task))) continue;
      await _repository.insertTask(task);
      added++;
    }
    await _load();
    return added;
  }
}
