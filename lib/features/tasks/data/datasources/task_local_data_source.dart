import 'package:sqflite/sqflite.dart';

import '../../../../core/error/failures.dart';
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

/// SQLite implementation. Every query is scoped to [userId] so accounts on
/// the same device never see each other's tasks.
class TaskLocalDataSourceImpl implements TaskLocalDataSource {
  final Database db;
  final String? userId;

  TaskLocalDataSourceImpl(this.db, this.userId);

  bool _legacyRowsClaimed = false;

  static const _ownedSubtask =
      'taskId IN (SELECT id FROM tasks WHERE userId = ?)';

  String _requireUser() {
    final id = userId;
    if (id == null) throw const DatabaseFailure('You are not signed in.');
    return id;
  }

  /// Tasks created by app versions before per-user storage have no owner.
  /// They are adopted by the first account that loads its tasks, so nothing
  /// the user already entered disappears after upgrading.
  Future<void> _claimLegacyRows(String uid) async {
    if (_legacyRowsClaimed) return;
    await db.update('tasks', {'userId': uid}, where: 'userId IS NULL');
    _legacyRowsClaimed = true;
  }

  Future<Map<int, List<SubtaskModel>>> _subtasksByTask(
    String uid, {
    int? onlyTaskId,
  }) async {
    final rows = await db.query(
      'subtasks',
      where: onlyTaskId == null ? _ownedSubtask : 'taskId = ? AND $_ownedSubtask',
      whereArgs: onlyTaskId == null ? [uid] : [onlyTaskId, uid],
      orderBy: 'id ASC',
    );
    final result = <int, List<SubtaskModel>>{};
    for (final row in rows) {
      final subtask = SubtaskModel.fromMap(row);
      result.putIfAbsent(subtask.taskId, () => []).add(subtask);
    }
    return result;
  }

  Future<List<TaskModel>> _queryTasks({
    String? where,
    List<Object?> whereArgs = const [],
    String orderBy = 'dueDate ASC, id ASC',
    int? onlyTaskId,
  }) async {
    final uid = userId;
    if (uid == null) return [];
    await _claimLegacyRows(uid);

    final rows = await db.query(
      'tasks',
      where: where == null ? 'userId = ?' : 'userId = ? AND ($where)',
      whereArgs: [uid, ...whereArgs],
      orderBy: orderBy,
    );
    if (rows.isEmpty) return [];

    final subtasks = await _subtasksByTask(uid, onlyTaskId: onlyTaskId);
    return rows.map((row) {
      final id = row['id'] as int;
      return TaskModel.fromMap(row, subtasks: subtasks[id] ?? const []);
    }).toList();
  }

  @override
  Future<int> insertTask(TaskModel task) async {
    final uid = _requireUser();
    return db.transaction((txn) async {
      final values = task.toMap()..['userId'] = uid;
      final id = await txn.insert('tasks', values);
      for (final subtask in task.subtasks) {
        await txn.insert(
          'subtasks',
          SubtaskModel(
            taskId: id,
            title: subtask.title,
            isCompleted: subtask.isCompleted,
          ).toMap(),
        );
      }
      return id;
    });
  }

  @override
  Future<List<TaskModel>> getAllTasks() => _queryTasks();

  @override
  Future<TaskModel?> getTaskById(int id) async {
    final result = await _queryTasks(
      where: 'id = ?',
      whereArgs: [id],
      onlyTaskId: id,
    );
    return result.isEmpty ? null : result.first;
  }

  @override
  Future<List<TaskModel>> getTasksByDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = DateTime(date.year, date.month, date.day + 1);
    return _queryTasks(
      where: 'dueDate >= ? AND dueDate < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
    );
  }

  @override
  Future<List<TaskModel>> getCompletedTasks() =>
      _queryTasks(where: 'isCompleted = 1', orderBy: 'completedAt DESC');

  @override
  Future<List<TaskModel>> getUpcomingTasks() => _queryTasks(
    where: 'dueDate > ? AND isCompleted = 0',
    whereArgs: [DateTime.now().toIso8601String()],
  );

  @override
  Future<int> updateTask(TaskModel task) async {
    final uid = _requireUser();
    final id = task.id;
    if (id == null) {
      throw const DatabaseFailure('Cannot update a task that was not saved.');
    }
    final values = task.toMap()..['userId'] = uid;
    return db.update(
      'tasks',
      values,
      where: 'id = ? AND userId = ?',
      whereArgs: [id, uid],
    );
  }

  @override
  Future<int> deleteTask(int id) async {
    final uid = _requireUser();
    return db.transaction((txn) async {
      // Explicit delete in addition to ON DELETE CASCADE, for databases that
      // were created while foreign keys were disabled.
      await txn.delete(
        'subtasks',
        where: 'taskId = ? AND $_ownedSubtask',
        whereArgs: [id, uid],
      );
      return txn.delete(
        'tasks',
        where: 'id = ? AND userId = ?',
        whereArgs: [id, uid],
      );
    });
  }

  @override
  Future<int> insertSubtask(SubtaskModel subtask) async {
    final uid = _requireUser();
    final owner = await db.query(
      'tasks',
      columns: ['id'],
      where: 'id = ? AND userId = ?',
      whereArgs: [subtask.taskId, uid],
    );
    if (owner.isEmpty) {
      throw const DatabaseFailure('This task no longer exists.');
    }
    return db.insert('subtasks', subtask.toMap());
  }

  @override
  Future<List<SubtaskModel>> getSubtasksByTaskId(int taskId) async {
    final uid = userId;
    if (uid == null) return [];
    final rows = await db.query(
      'subtasks',
      where: 'taskId = ? AND $_ownedSubtask',
      whereArgs: [taskId, uid],
      orderBy: 'id ASC',
    );
    return rows.map(SubtaskModel.fromMap).toList();
  }

  @override
  Future<int> updateSubtask(SubtaskModel subtask) async {
    final uid = _requireUser();
    return db.update(
      'subtasks',
      subtask.toMap(),
      where: 'id = ? AND $_ownedSubtask',
      whereArgs: [subtask.id, uid],
    );
  }

  @override
  Future<int> deleteSubtask(int id) async {
    final uid = _requireUser();
    return db.delete(
      'subtasks',
      where: 'id = ? AND $_ownedSubtask',
      whereArgs: [id, uid],
    );
  }
}
