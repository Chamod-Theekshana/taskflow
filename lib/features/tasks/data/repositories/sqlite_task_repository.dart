import 'package:sqflite/sqflite.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';
import '../models/task_model.dart';

/// Tasks stored in SQLite. Every query is scoped to [userId], so accounts on
/// the same device never see each other's tasks.
class SqliteTaskRepository implements TaskRepository {
  final Database db;
  final String? userId;

  SqliteTaskRepository(this.db, this.userId);

  static const _ownedSubtask =
      'taskId IN (SELECT id FROM tasks WHERE userId = ?)';

  bool _legacyRowsClaimed = false;

  String _requireUser() {
    final id = userId;
    if (id == null) throw const DatabaseFailure('You are not signed in.');
    return id;
  }

  /// Rows written before tasks had an owner are adopted by the first account
  /// that loads its list, so nothing disappears after an upgrade.
  Future<void> _claimLegacyRows(String uid) async {
    if (_legacyRowsClaimed) return;
    await db.update('tasks', {'userId': uid}, where: 'userId IS NULL');
    _legacyRowsClaimed = true;
  }

  Future<List<Task>> _query({
    String? where,
    List<Object?> args = const [],
  }) async {
    final uid = userId;
    if (uid == null) return [];
    await _claimLegacyRows(uid);

    final rows = await db.query(
      'tasks',
      where: where == null ? 'userId = ?' : 'userId = ? AND ($where)',
      whereArgs: [uid, ...args],
      orderBy: 'dueDate ASC, id ASC',
    );
    if (rows.isEmpty) return [];

    final subtaskRows = await db.query(
      'subtasks',
      where: _ownedSubtask,
      whereArgs: [uid],
      orderBy: 'id ASC',
    );
    final subtasks = <int, List<Subtask>>{};
    for (final row in subtaskRows) {
      final subtask = SubtaskRow.fromMap(row);
      subtasks.putIfAbsent(subtask.taskId, () => []).add(subtask);
    }

    return [
      for (final row in rows)
        TaskRow.fromMap(row, subtasks: subtasks[row['id'] as int] ?? const []),
    ];
  }

  @override
  Future<List<Task>> getAllTasks() => _query();

  @override
  Future<Task?> getTaskById(int id) async {
    final result = await _query(where: 'id = ?', args: [id]);
    return result.isEmpty ? null : result.first;
  }

  @override
  Future<int> insertTask(Task task) {
    final uid = _requireUser();
    return db.transaction((txn) async {
      final id = await txn.insert(
        'tasks',
        TaskRow.toMap(task)..['userId'] = uid,
      );
      for (final subtask in task.subtasks) {
        await txn.insert('subtasks', {
          'taskId': id,
          'title': subtask.title,
          'isCompleted': subtask.isCompleted ? 1 : 0,
        });
      }
      return id;
    });
  }

  @override
  Future<void> updateTask(Task task) async {
    final uid = _requireUser();
    final id = task.id;
    if (id == null) {
      throw const DatabaseFailure('This task has not been saved yet.');
    }
    await db.update(
      'tasks',
      TaskRow.toMap(task)..['userId'] = uid,
      where: 'id = ? AND userId = ?',
      whereArgs: [id, uid],
    );
  }

  @override
  Future<void> deleteTask(int id) async {
    final uid = _requireUser();
    await db.transaction((txn) async {
      // Explicit, for databases created while foreign keys were off.
      await txn.delete(
        'subtasks',
        where: 'taskId = ? AND $_ownedSubtask',
        whereArgs: [id, uid],
      );
      await txn.delete(
        'tasks',
        where: 'id = ? AND userId = ?',
        whereArgs: [id, uid],
      );
    });
  }

  @override
  Future<int> insertSubtask(Subtask subtask) async {
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
    return db.insert('subtasks', SubtaskRow.toMap(subtask));
  }

  @override
  Future<void> updateSubtask(Subtask subtask) async {
    final uid = _requireUser();
    await db.update(
      'subtasks',
      SubtaskRow.toMap(subtask),
      where: 'id = ? AND $_ownedSubtask',
      whereArgs: [subtask.id, uid],
    );
  }

  @override
  Future<void> deleteSubtask(int id) async {
    final uid = _requireUser();
    await db.delete(
      'subtasks',
      where: 'id = ? AND $_ownedSubtask',
      whereArgs: [id, uid],
    );
  }
}
