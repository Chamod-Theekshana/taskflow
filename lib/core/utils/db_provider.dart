import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

Future<Database> openAppDatabase() => DBProvider.instance.database;

class DBProvider {
  static final DBProvider instance = DBProvider._();
  DBProvider._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'taskflow.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id TEXT PRIMARY KEY,
            full_name TEXT NOT NULL,
            email TEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
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
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE subtasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            taskId INTEGER NOT NULL,
            title TEXT NOT NULL,
            isCompleted INTEGER DEFAULT 0,
            FOREIGN KEY (taskId) REFERENCES tasks(id) ON DELETE CASCADE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS tasks (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
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
      },
    );
  }
}
