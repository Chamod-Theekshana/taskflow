import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Opens (and creates / migrates) the single app database.
Future<Database> openAppDatabase() => DBProvider.instance.database;

class DBProvider {
  static final DBProvider instance = DBProvider._();
  DBProvider._();

  /// v1: users
  /// v2: + tasks, subtasks
  /// v3: + tasks.userId (tasks are private to each account),
  ///     + tasks.completedAt (real on-time / streak statistics),
  ///     + indexes, foreign keys enforced.
  static const int schemaVersion = 3;

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;
    final db = await _initDB();
    _database = db;
    return db;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'taskflow.db');
    return openDatabase(
      path,
      version: schemaVersion,
      // SQLite ignores FOREIGN KEY / ON DELETE CASCADE unless this pragma is
      // enabled on every connection. Without it deleting a task leaves its
      // subtasks behind forever.
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_tasks_user ON tasks(userId)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Every statement is idempotent, so running the full schema is safe
        // whatever version we are coming from. The old v1 -> v2 migration
        // forgot the `users` table, which made login impossible for
        // upgraded installs; this also repairs that.
        await _createSchema(db);
        await _ensureColumn(db, 'tasks', 'userId', 'TEXT');
        await _ensureColumn(db, 'tasks', 'completedAt', 'TEXT');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_tasks_user ON tasks(userId)',
        );
        // Clean up subtasks orphaned while foreign keys were not enforced.
        await db.execute(
          'DELETE FROM subtasks WHERE taskId NOT IN (SELECT id FROM tasks)',
        );
      },
    );
  }

  static Future<void> _createSchema(Database db) async {
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
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_subtasks_task ON subtasks(taskId)',
    );
  }

  static Future<void> _ensureColumn(
    Database db,
    String table,
    String column,
    String type,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((c) => c['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }
}
