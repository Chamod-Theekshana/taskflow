import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/uuid.dart';

/// The local store. Tasks live here first (the app works offline) and are
/// replicated to the server by the sync engine.
///
/// Schema history:
/// 1 - users
/// 2 - tasks, subtasks
/// 3 - tasks.userId, tasks.completedAt, indexes, foreign keys
/// 4 - tasks.repeatRule
/// 5 - sync: tasks.uuid / syncState / deletedAt, subtasks.uuid / position.
///     The `users` table is only read once to adopt tasks of accounts from
///     the offline-only versions.
const _schemaVersion = 5;

/// `tasks.syncState` values.
abstract final class SyncState {
  static const synced = 0;
  static const pending = 1;
}

Future<Database> openAppDatabase() async {
  final path = join(await getDatabasesPath(), 'taskflow.db');
  return openDatabase(
    path,
    version: _schemaVersion,
    // SQLite ignores ON DELETE CASCADE unless this is on for the connection.
    onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    onCreate: (db, version) async {
      await _createTables(db);
      await _createIndexes(db);
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      // Every statement is idempotent, so the same steps work from any
      // older version (including v1 installs that never got a users table).
      await _createTables(db);
      await _addColumnIfMissing(db, 'tasks', 'userId', 'TEXT');
      await _addColumnIfMissing(db, 'tasks', 'completedAt', 'TEXT');
      await _addColumnIfMissing(db, 'tasks', 'repeatRule', 'TEXT');
      await _addColumnIfMissing(db, 'tasks', 'uuid', 'TEXT');
      // Everything created before sync existed still has to reach the server.
      await _addColumnIfMissing(
        db,
        'tasks',
        'syncState',
        'INTEGER DEFAULT ${SyncState.pending}',
      );
      await _addColumnIfMissing(db, 'tasks', 'deletedAt', 'TEXT');
      await _addColumnIfMissing(db, 'subtasks', 'uuid', 'TEXT');
      await _addColumnIfMissing(db, 'subtasks', 'position', 'INTEGER DEFAULT 0');
      await db.execute(
        'DELETE FROM subtasks WHERE taskId NOT IN (SELECT id FROM tasks)',
      );
      await _backfillUuids(db, 'tasks');
      await _backfillUuids(db, 'subtasks');
      await _createIndexes(db);
    },
  );
}

Future<void> _createTables(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      full_name TEXT NOT NULL,
      email TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS tasks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT,
      userId TEXT,
      title TEXT NOT NULL,
      description TEXT,
      dueDate TEXT NOT NULL,
      dueTime TEXT,
      priority INTEGER DEFAULT 1,
      category TEXT,
      isCompleted INTEGER DEFAULT 0,
      isAllDay INTEGER DEFAULT 0,
      reminder INTEGER DEFAULT 0,
      reminderMinutes INTEGER DEFAULT 0,
      repeatRule TEXT,
      completedAt TEXT,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL,
      syncState INTEGER DEFAULT ${SyncState.pending},
      deletedAt TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS subtasks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT,
      taskId INTEGER NOT NULL,
      title TEXT NOT NULL,
      isCompleted INTEGER DEFAULT 0,
      position INTEGER DEFAULT 0,
      FOREIGN KEY (taskId) REFERENCES tasks(id) ON DELETE CASCADE
    )
  ''');
}

// Separate from the tables: on an old install the indexed columns only exist
// after the upgrade has added them.
Future<void> _createIndexes(Database db) async {
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_tasks_user ON tasks(userId)',
  );
  await db.execute(
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_tasks_uuid ON tasks(uuid)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_tasks_sync ON tasks(userId, syncState)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_subtasks_task ON subtasks(taskId)',
  );
}

Future<void> _addColumnIfMissing(
  Database db,
  String table,
  String column,
  String type,
) async {
  final columns = await db.rawQuery('PRAGMA table_info($table)');
  if (columns.any((c) => c['name'] == column)) return;
  await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
}

Future<void> _backfillUuids(Database db, String table) async {
  final rows = await db.query(table, columns: ['id'], where: 'uuid IS NULL');
  if (rows.isEmpty) return;
  final batch = db.batch();
  for (final row in rows) {
    batch.update(
      table,
      {'uuid': newUuid()},
      where: 'id = ?',
      whereArgs: [row['id']],
    );
  }
  await batch.commit(noResult: true);
}
