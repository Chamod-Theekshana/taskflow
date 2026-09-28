import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Schema history:
/// 1 - users
/// 2 - tasks, subtasks
/// 3 - tasks.userId, tasks.completedAt, indexes, foreign keys
/// 4 - tasks.repeatRule
const _schemaVersion = 4;

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
      await _createIndexes(db);
      await db.execute(
        'DELETE FROM subtasks WHERE taskId NOT IN (SELECT id FROM tasks)',
      );
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
      updatedAt TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS subtasks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      taskId INTEGER NOT NULL,
      title TEXT NOT NULL,
      isCompleted INTEGER DEFAULT 0,
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
