import '../../../../core/utils/db_provider.dart';
import '../models/task_model.dart';

abstract class TaskLocalDataSource {
  Future<int> insertTask(TaskModel task);
  Future<List<TaskModel>> getAllTasks();
  Future<TaskModel?> getTaskById(int id);
  Future<List<TaskModel>> getTasksByDate(DateTime date);
  Future<List<TaskModel>> getCompletedTasks();
  Future<List<TaskModel>> getUpcomingTasks();
  Future<int> updateTask(TaskModel task);
  Future<int> deleteTask(int id);
  Future<int> insertSubtask(SubtaskModel subtask);
  Future<List<SubtaskModel>> getSubtasksByTaskId(int taskId);
  Future<int> updateSubtask(SubtaskModel subtask);
  Future<int> deleteSubtask(int id);
}

class TaskLocalDataSourceImpl implements TaskLocalDataSource {
  final DBProvider dbProvider;

  TaskLocalDataSourceImpl(this.dbProvider);

  @override
  Future<int> insertTask(TaskModel task) async {
    final db = await dbProvider.database;
    final id = await db.insert('tasks', task.toMap());
    for (var subtask in task.subtasks) {
      final subtaskToInsert = SubtaskModel(
        taskId: id,
        title: subtask.title,
        isCompleted: subtask.isCompleted,
      );
      await insertSubtask(subtaskToInsert);
    }
    return id;
  }

  @override
  Future<List<TaskModel>> getAllTasks() async {
    final db = await dbProvider.database;
    final result = await db.query('tasks');
    List<TaskModel> tasks = [];
    for (var map in result) {
      final subtasks = await getSubtasksByTaskId(map['id'] as int);
      tasks.add(TaskModel.fromMap(map, subtasks: subtasks));
    }
    return tasks;
  }

  @override
  Future<TaskModel?> getTaskById(int id) async {
    final db = await dbProvider.database;
    final result = await db.query('tasks', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty) {
      final subtasks = await getSubtasksByTaskId(id);
      return TaskModel.fromMap(result.first, subtasks: subtasks);
    }
    return null;
  }

  @override
  Future<List<TaskModel>> getTasksByDate(DateTime date) async {
    final db = await dbProvider.database;
    final startOfDay = DateTime(date.year, date.month, date.day).toIso8601String();
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();

    final result = await db.query('tasks',
        where: 'dueDate >= ? AND dueDate <= ?',
        whereArgs: [startOfDay, endOfDay]);

    List<TaskModel> tasks = [];
    for (var map in result) {
      final subtasks = await getSubtasksByTaskId(map['id'] as int);
      tasks.add(TaskModel.fromMap(map, subtasks: subtasks));
    }
    return tasks;
  }

  @override
  Future<List<TaskModel>> getCompletedTasks() async {
    final db = await dbProvider.database;
    final result = await db.query('tasks', where: 'isCompleted = ?', whereArgs: [1]);
    List<TaskModel> tasks = [];
    for (var map in result) {
      final subtasks = await getSubtasksByTaskId(map['id'] as int);
      tasks.add(TaskModel.fromMap(map, subtasks: subtasks));
    }
    return tasks;
  }

  @override
  Future<List<TaskModel>> getUpcomingTasks() async {
    final db = await dbProvider.database;
    final now = DateTime.now().toIso8601String();
    final result = await db.query('tasks',
        where: 'dueDate > ? AND isCompleted = ?',
        whereArgs: [now, 0],
        orderBy: 'dueDate ASC');
    List<TaskModel> tasks = [];
    for (var map in result) {
      final subtasks = await getSubtasksByTaskId(map['id'] as int);
      tasks.add(TaskModel.fromMap(map, subtasks: subtasks));
    }
    return tasks;
  }

  @override
  Future<int> updateTask(TaskModel task) async {
    final db = await dbProvider.database;
    return await db.update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
  }

  @override
  Future<int> deleteTask(int id) async {
    final db = await dbProvider.database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> insertSubtask(SubtaskModel subtask) async {
    final db = await dbProvider.database;
    return await db.insert('subtasks', subtask.toMap());
  }

  @override
  Future<List<SubtaskModel>> getSubtasksByTaskId(int taskId) async {
    final db = await dbProvider.database;
    final result = await db.query('subtasks', where: 'taskId = ?', whereArgs: [taskId]);
    return result.map((map) => SubtaskModel.fromMap(map)).toList();
  }

  @override
  Future<int> updateSubtask(SubtaskModel subtask) async {
    final db = await dbProvider.database;
    return await db.update('subtasks', subtask.toMap(), where: 'id = ?', whereArgs: [subtask.id]);
  }

  @override
  Future<int> deleteSubtask(int id) async {
    final db = await dbProvider.database;
    return await db.delete('subtasks', where: 'id = ?', whereArgs: [id]);
  }
}