import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/uuid.dart';
import '../../domain/entities/task.dart';
import '../models/task_model.dart';

/// A task waiting to be pushed to the server.
typedef PendingTask = ({
  Task task,
  DateTime? deletedAt,

  /// The stored `updatedAt`, to tell whether the row changed during the push.
  String stamp,
});

/// Tasks in SQLite, the app's source of truth while it runs.
///
/// Every query is scoped to a user, so accounts on the same device never see
/// each other's tasks. Writes mark the row as pending; the sync engine pushes
/// pending rows and marks them synced. Deletions leave a tombstone until the
/// server has them.
class TaskLocalDataSource {
  TaskLocalDataSource(this.db);

  final Database db;

  static const _ownedSubtask =
      'taskId IN (SELECT id FROM tasks WHERE userId = ?)';

  // ------------------------------------------------------------------ reads

  Future<List<Task>> getAll(String userId) =>
      _query(userId, where: 'deletedAt IS NULL');

  Future<Task?> getById(String userId, int id) async {
    final rows = await _query(
      userId,
      where: 'id = ? AND deletedAt IS NULL',
      args: [id],
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<int?> idForUuid(String userId, String uuid) async {
    final rows = await db.query(
      'tasks',
      columns: ['id'],
      where: 'userId = ? AND uuid = ? AND deletedAt IS NULL',
      whereArgs: [userId, uuid],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  Future<List<Task>> _query(
    String userId, {
    required String where,
    List<Object?> args = const [],
  }) async {
    final rows = await db.query(
      'tasks',
      where: 'userId = ? AND ($where)',
      whereArgs: [userId, ...args],
      orderBy: 'dueDate ASC, id ASC',
    );
    if (rows.isEmpty) return [];
    final subtasks = await _subtasksByTask(
      db,
      rows.map((r) => r['id'] as int).toList(),
    );
    return [
      for (final row in rows)
        TaskRow.fromMap(row, subtasks: subtasks[row['id'] as int] ?? const []),
    ];
  }

  Future<Map<int, List<Subtask>>> _subtasksByTask(
    DatabaseExecutor ex,
    List<int> taskIds,
  ) async {
    final result = <int, List<Subtask>>{};
    // SQLite limits bound variables; go in chunks.
    for (var i = 0; i < taskIds.length; i += 500) {
      final end = i + 500 < taskIds.length ? i + 500 : taskIds.length;
      final chunk = taskIds.sublist(i, end);
      final marks = List.filled(chunk.length, '?').join(',');
      final rows = await ex.query(
        'subtasks',
        where: 'taskId IN ($marks)',
        whereArgs: chunk,
        orderBy: 'position ASC, id ASC',
      );
      for (final row in rows) {
        final subtask = SubtaskRow.fromMap(row);
        result.putIfAbsent(subtask.taskId, () => []).add(subtask);
      }
    }
    return result;
  }

  // ----------------------------------------------------------------- writes

  Future<int> insert(String userId, Task task) {
    return db.transaction((txn) async {
      final id = await txn.insert('tasks', {
        ...TaskRow.toMap(task.copyWith(uuid: task.uuid ?? newUuid())),
        'userId': userId,
        'syncState': SyncState.pending,
        'deletedAt': null,
      });
      await _insertSubtasks(txn, id, task.subtasks);
      return id;
    });
  }

  Future<void> update(String userId, Task task) async {
    final id = task.id;
    if (id == null) {
      throw const DatabaseFailure('This task has not been saved yet.');
    }
    final values = TaskRow.toMap(task)..remove('uuid');
    await db.update(
      'tasks',
      {...values, 'syncState': SyncState.pending},
      where: 'id = ? AND userId = ? AND deletedAt IS NULL',
      whereArgs: [id, userId],
    );
  }

  /// Leaves a tombstone so the deletion reaches the server and other devices.
  Future<void> markDeleted(String userId, int id, DateTime at) async {
    final stamp = at.toIso8601String();
    await db.update(
      'tasks',
      {'deletedAt': stamp, 'updatedAt': stamp, 'syncState': SyncState.pending},
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
    );
  }

  Future<int> insertSubtask(String userId, Subtask subtask, DateTime now) {
    return db.transaction((txn) async {
      await _requireOwner(txn, userId, subtask.taskId);
      final last = await txn.rawQuery(
        'SELECT COALESCE(MAX(position), -1) AS p FROM subtasks WHERE taskId = ?',
        [subtask.taskId],
      );
      final position = ((last.first['p'] as int?) ?? -1) + 1;
      final id = await txn.insert(
        'subtasks',
        SubtaskRow.toMap(
          Subtask(
            uuid: subtask.uuid ?? newUuid(),
            taskId: subtask.taskId,
            title: subtask.title,
            isCompleted: subtask.isCompleted,
          ),
          position: position,
        ),
      );
      await _touch(txn, subtask.taskId, now);
      return id;
    });
  }

  Future<void> updateSubtask(String userId, Subtask subtask, DateTime now) {
    return db.transaction((txn) async {
      final count = await txn.update(
        'subtasks',
        {'title': subtask.title, 'isCompleted': subtask.isCompleted ? 1 : 0},
        where: 'id = ? AND $_ownedSubtask',
        whereArgs: [subtask.id, userId],
      );
      if (count > 0) await _touch(txn, subtask.taskId, now);
    });
  }

  Future<void> deleteSubtask(String userId, int id, DateTime now) {
    return db.transaction((txn) async {
      final rows = await txn.query(
        'subtasks',
        columns: ['taskId'],
        where: 'id = ? AND $_ownedSubtask',
        whereArgs: [id, userId],
      );
      if (rows.isEmpty) return;
      await txn.delete('subtasks', where: 'id = ?', whereArgs: [id]);
      await _touch(txn, rows.first['taskId'] as int, now);
    });
  }

  /// A subtask change is a change of its task (the unit that syncs).
  Future<void> _touch(Transaction txn, int taskId, DateTime now) {
    return txn.update(
      'tasks',
      {'updatedAt': now.toIso8601String(), 'syncState': SyncState.pending},
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  Future<void> _requireOwner(
    DatabaseExecutor ex,
    String userId,
    int taskId,
  ) async {
    final owner = await ex.query(
      'tasks',
      columns: ['id'],
      where: 'id = ? AND userId = ? AND deletedAt IS NULL',
      whereArgs: [taskId, userId],
    );
    if (owner.isEmpty) {
      throw const DatabaseFailure('This task no longer exists.');
    }
  }

  Future<void> _insertSubtasks(
    Transaction txn,
    int taskId,
    List<Subtask> subtasks,
  ) async {
    for (var i = 0; i < subtasks.length; i++) {
      final s = subtasks[i];
      await txn.insert(
        'subtasks',
        SubtaskRow.toMap(
          Subtask(
            uuid: s.uuid ?? newUuid(),
            taskId: taskId,
            title: s.title,
            isCompleted: s.isCompleted,
          ),
          position: i,
        ),
      );
    }
  }

  // ------------------------------------------------------------------- sync

  /// Tasks from the offline-only versions of the app: rows without an owner,
  /// and rows of a local account with the same email, join this account (and
  /// get uploaded). The old local account and its password hash are removed.
  Future<void> adoptLegacyRows(String userId, String email) {
    return db.transaction((txn) async {
      await txn.update(
        'tasks',
        {'userId': userId, 'syncState': SyncState.pending},
        where: 'userId IS NULL',
      );
      final legacy = await txn.query(
        'users',
        columns: ['id'],
        where: 'lower(email) = ?',
        whereArgs: [email.trim().toLowerCase()],
      );
      for (final row in legacy) {
        final oldId = row['id'] as String;
        if (oldId == userId) continue;
        await txn.update(
          'tasks',
          {'userId': userId, 'syncState': SyncState.pending},
          where: 'userId = ?',
          whereArgs: [oldId],
        );
        await txn.delete('users', where: 'id = ?', whereArgs: [oldId]);
      }
    });
  }

  Future<bool> hasPending(String userId) async {
    final rows = await db.query(
      'tasks',
      columns: ['id'],
      where: 'userId = ? AND syncState = ?',
      whereArgs: [userId, SyncState.pending],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Oldest pending changes first, tombstones included.
  Future<List<PendingTask>> pending(String userId, {int limit = 100}) async {
    final rows = await db.query(
      'tasks',
      where: 'userId = ? AND syncState = ?',
      whereArgs: [userId, SyncState.pending],
      orderBy: 'updatedAt ASC, id ASC',
      limit: limit,
    );
    if (rows.isEmpty) return [];
    final subtasks = await _subtasksByTask(
      db,
      rows.map((r) => r['id'] as int).toList(),
    );
    return [
      for (final row in rows)
        (
          task: TaskRow.fromMap(
            row,
            subtasks: subtasks[row['id'] as int] ?? const [],
          ),
          deletedAt: DateTime.tryParse(row['deletedAt'] as String? ?? ''),
          stamp: row['updatedAt'] as String,
        ),
    ];
  }

  /// Marks a pushed change as synced, unless the row changed meanwhile.
  /// Pushed tombstones are removed for good.
  Future<void> markPushed(String userId, PendingTask change) async {
    final uuid = change.task.uuid;
    if (uuid == null) return;
    await db.transaction((txn) async {
      if (change.deletedAt != null) {
        await txn.delete(
          'subtasks',
          where: 'taskId IN (SELECT id FROM tasks WHERE uuid = ? AND userId = ?)',
          whereArgs: [uuid, userId],
        );
        await txn.delete(
          'tasks',
          where:
              'uuid = ? AND userId = ? AND deletedAt IS NOT NULL AND updatedAt = ?',
          whereArgs: [uuid, userId, change.stamp],
        );
        return;
      }
      await txn.update(
        'tasks',
        {'syncState': SyncState.synced},
        where: 'uuid = ? AND userId = ? AND updatedAt = ?',
        whereArgs: [uuid, userId, change.stamp],
      );
    });
  }

  /// Applies tasks pulled from the server. A local change that is newer and
  /// not pushed yet wins (last write wins). Returns how many rows changed.
  Future<int> applyRemote(
    String userId,
    List<({Task task, DateTime? deletedAt})> items,
  ) {
    return db.transaction((txn) async {
      var changed = 0;
      for (final item in items) {
        final remote = item.task;
        final local = await txn.query(
          'tasks',
          columns: ['id', 'syncState', 'updatedAt', 'userId'],
          where: 'uuid = ?',
          whereArgs: [remote.uuid],
          limit: 1,
        );
        final row = local.isEmpty ? null : local.first;
        if (row != null && row['userId'] != userId) continue;

        // The echo of a change this device pushed itself: nothing to do.
        // (Re-writing it would also give its subtasks new local ids.)
        if (row != null &&
            item.deletedAt == null &&
            row['syncState'] == SyncState.synced) {
          final localTime = DateTime.tryParse(row['updatedAt'] as String? ?? '');
          if (localTime?.millisecondsSinceEpoch ==
              remote.updatedAt.millisecondsSinceEpoch) {
            continue;
          }
        }

        if (row != null && row['syncState'] == SyncState.pending) {
          final localTime = DateTime.tryParse(row['updatedAt'] as String? ?? '');
          final remoteTime = item.deletedAt ?? remote.updatedAt;
          if (localTime != null &&
              localTime.millisecondsSinceEpoch >
                  remoteTime.millisecondsSinceEpoch) {
            continue;
          }
        }

        if (item.deletedAt != null) {
          if (row == null) continue;
          await txn.delete('subtasks', where: 'taskId = ?', whereArgs: [row['id']]);
          await txn.delete('tasks', where: 'id = ?', whereArgs: [row['id']]);
          changed++;
          continue;
        }

        final values = {
          ...TaskRow.toMap(remote),
          'userId': userId,
          'syncState': SyncState.synced,
          'deletedAt': null,
        };
        final int localId;
        if (row == null) {
          localId = await txn.insert('tasks', values);
        } else {
          localId = row['id'] as int;
          await txn.update('tasks', values, where: 'id = ?', whereArgs: [localId]);
          await txn.delete('subtasks', where: 'taskId = ?', whereArgs: [localId]);
        }
        await _insertSubtasks(txn, localId, remote.subtasks);
        changed++;
      }
      return changed;
    });
  }
}
