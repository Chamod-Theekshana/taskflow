import 'package:flutter/material.dart';
import '../models/task.dart';
import '../data/database_helper.dart';

enum TaskFilter { all, today, upcoming, completed }

class TaskProvider extends ChangeNotifier {
  List<Task> _tasks = [];
  TaskFilter _currentFilter = TaskFilter.all;
  String _searchQuery = '';
  bool _isLoading = false;

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<Task> get tasks => _tasks;
  TaskFilter get currentFilter => _currentFilter;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;

  List<Task> get filteredTasks {
    List<Task> result = _tasks;

    if (_searchQuery.isNotEmpty) {
      result = result.where((t) => 
        t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (t.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_currentFilter) {
      case TaskFilter.today:
        result = result.where((t) {
          if (t.isCompleted) return false;
          if (t.dueDate == null) return false;
          final d = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
          return d.isAtSameMomentAs(today);
        }).toList();
        break;
      case TaskFilter.upcoming:
        result = result.where((t) {
          if (t.isCompleted) return false;
          if (t.dueDate == null) return false;
          final d = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
          return d.isAfter(today);
        }).toList();
        break;
      case TaskFilter.completed:
        result = result.where((t) => t.isCompleted).toList();
        break;
      case TaskFilter.all:
      default:
        break;
    }
    
    result.sort((a, b) {
      if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
      if (a.dueDate != null && b.dueDate != null) {
        return a.dueDate!.compareTo(b.dueDate!);
      }
      if (a.dueDate != null) return -1;
      if (b.dueDate != null) return 1;
      return a.priority.index.compareTo(b.priority.index);
    });

    return result;
  }

  Future<void> loadTasks() async {
    _isLoading = true;
    notifyListeners();

    _tasks = await _dbHelper.getAllTasks();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addTask(Task task) async {
    await _dbHelper.insertTask(task);
    await loadTasks();
  }

  Future<void> updateTask(Task task) async {
    await _dbHelper.updateTask(task);
    await loadTasks();
  }

  Future<void> deleteTask(int id) async {
    await _dbHelper.deleteTask(id);
    await loadTasks();
  }

  Future<void> toggleTaskComplete(int id) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index >= 0) {
      final task = _tasks[index];
      final updatedTask = task.copyWith(isCompleted: !task.isCompleted);
      await updateTask(updatedTask);
    }
  }

  void setFilter(TaskFilter filter) {
    _currentFilter = filter;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<Task> getTasksByDate(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    return _tasks.where((t) {
      if (t.dueDate == null) return false;
      final d = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
      return d.isAtSameMomentAs(target);
    }).toList();
  }

  Future<Task?> getTaskById(int id) async {
    return await _dbHelper.getTaskById(id);
  }

  Future<void> addSubtask(Subtask subtask) async {
    await _dbHelper.insertSubtask(subtask);
    await loadTasks();
  }

  Future<void> toggleSubtask(int subtaskId, int taskId) async {
    final task = await _dbHelper.getTaskById(taskId);
    if (task != null) {
      final subtask = task.subtasks.firstWhere((s) => s.id == subtaskId);
      final updated = subtask.copyWith(isCompleted: !subtask.isCompleted);
      await _dbHelper.updateSubtask(updated);
      await loadTasks();
    }
  }

  Future<void> deleteSubtask(int id, int taskId) async {
    await _dbHelper.deleteSubtask(id);
    await loadTasks();
  }

    Task? getTaskByIdSync(int id) {
    try {
      return _tasks.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  int get totalTasks => _tasks.length;
  int get completedTasksCount => _tasks.where((t) => t.isCompleted).length;
  
  int get todayTasksCount {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _tasks.where((t) {
      if (t.isCompleted) return false;
      if (t.dueDate == null) return false;
      final d = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
      return d.isAtSameMomentAs(today);
    }).length;
  }

  int get upcomingTasksCount {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _tasks.where((t) {
      if (t.isCompleted) return false;
      if (t.dueDate == null) return false;
      final d = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
      return d.isAfter(today);
    }).length;
  }

  int get completionPercentage {
    if (totalTasks == 0) return 0;
    return ((completedTasksCount / totalTasks) * 100).round();
  }

  int get highPriorityTodayCount {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _tasks.where((t) {
      if (t.isCompleted) return false;
      if (t.priority != TaskPriority.high) return false;
      if (t.dueDate == null) return false;
      final d = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
      return d.isAtSameMomentAs(today);
    }).length;
  }

  Map<String, int> get weeklyStats {
    return {
      'Mon': 4,
      'Tue': 6,
      'Wed': 3,
      'Thu': 7,
      'Fri': 5,
      'Sat': 2,
      'Sun': 1,
    };
  }

  int get onTimePercentage => 85;
  int get currentStreak => 12;
}



