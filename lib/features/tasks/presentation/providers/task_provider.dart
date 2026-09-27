import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';
import '../../data/datasources/task_local_data_source.dart';
import '../../data/repositories/task_repository_impl.dart';
import '../../../../core/utils/db_provider.dart';

enum TaskFilter { all, upcoming, completed, today }

class TaskStats {
  final int tasksCompleted;
  final int totalTasks;
  final double onTimePercentage;
  final int currentStreak;

  const TaskStats({
    this.tasksCompleted = 0,
    this.totalTasks = 0,
    this.onTimePercentage = 0.0,
    this.currentStreak = 0,
  });
}

class TaskListState {
  final List<Task> tasks;
  final bool isLoading;
  final String searchQuery;
  final TaskFilter filter;

  const TaskListState({
    this.tasks = const [],
    this.isLoading = false,
    this.searchQuery = '',
    this.filter = TaskFilter.all,
  });

  TaskListState copyWith({
    List<Task>? tasks,
    bool? isLoading,
    String? searchQuery,
    TaskFilter? filter,
  }) =>
      TaskListState(
        tasks: tasks ?? this.tasks,
        isLoading: isLoading ?? this.isLoading,
        searchQuery: searchQuery ?? this.searchQuery,
        filter: filter ?? this.filter,
      );

  List<Task> get filteredTasks {
    var filtered = tasks;
    final now = DateTime.now();
    switch (filter) {
      case TaskFilter.all:
        break;
      case TaskFilter.completed:
        filtered = filtered.where((t) => t.isCompleted).toList();
        break;
      case TaskFilter.upcoming:
        filtered = filtered.where((t) => t.dueDate.isAfter(now) && !t.isCompleted).toList();
        break;
      case TaskFilter.today:
        filtered = filtered.where((t) =>
          t.dueDate.year == now.year &&
          t.dueDate.month == now.month &&
          t.dueDate.day == now.day).toList();
        break;
    }
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      filtered = filtered.where((t) =>
        t.title.toLowerCase().contains(q) ||
        t.description.toLowerCase().contains(q)).toList();
    }
    return filtered;
  }

  double get completionPercentage {
    if (tasks.isEmpty) return 0.0;
    return tasks.where((t) => t.isCompleted).length / tasks.length;
  }

  TaskStats get stats {
    final completed = tasks.where((t) => t.isCompleted).toList();
    int onTime = 0;
    for (final t in completed) {
      if (!t.updatedAt.isAfter(t.dueDate)) onTime++;
    }
    return TaskStats(
      tasksCompleted: completed.length,
      totalTasks: tasks.length,
      onTimePercentage: completed.isEmpty ? 0.0 : onTime / completed.length,
    );
  }
}

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final dataSource = TaskLocalDataSourceImpl(DBProvider.instance);
  return TaskRepositoryImpl(dataSource);
});

final taskListProvider = NotifierProvider<TaskListNotifier, TaskListState>(TaskListNotifier.new);

class TaskListNotifier extends Notifier<TaskListState> {
  @override
  TaskListState build() {
    _loadTasks();
    return const TaskListState(isLoading: true);
  }

  Future<void> _loadTasks() async {
    state = state.copyWith(isLoading: true);
    final tasks = await ref.read(taskRepositoryProvider).getAllTasks();
    state = state.copyWith(tasks: tasks, isLoading: false);
  }

  Future<void> refresh() => _loadTasks();

  void setSearchQuery(String query) => state = state.copyWith(searchQuery: query);

  void setFilter(TaskFilter filter) => state = state.copyWith(filter: filter);

  Future<void> addTask(Task task) async {
    await ref.read(taskRepositoryProvider).insertTask(task);
    await _loadTasks();
  }

  Future<void> updateTask(Task task) async {
    await ref.read(taskRepositoryProvider).updateTask(task);
    await _loadTasks();
  }

  Future<void> deleteTask(int id) async {
    await ref.read(taskRepositoryProvider).deleteTask(id);
    await _loadTasks();
  }

  Future<Task?> getTaskById(int id) =>
      ref.read(taskRepositoryProvider).getTaskById(id);

  Future<void> toggleSubtask(int taskId, int subtaskId) async {
    final task = state.tasks.firstWhere((t) => t.id == taskId);
    final subtask = task.subtasks.firstWhere((s) => s.id == subtaskId);
    await ref.read(taskRepositoryProvider).updateSubtask(
          subtask.copyWith(isCompleted: !subtask.isCompleted));
    await _loadTasks();
  }

  Future<void> addSubtask(Subtask subtask) async {
    await ref.read(taskRepositoryProvider).insertSubtask(subtask);
    await _loadTasks();
  }
}
