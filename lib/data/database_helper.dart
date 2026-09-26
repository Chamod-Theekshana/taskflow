import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task.dart';
import '../models/user.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('taskflow.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  fullName TEXT NOT NULL,
  email TEXT NOT NULL,
  avatarUrl TEXT NOT NULL,
  workspace TEXT NOT NULL,
  memberSince TEXT NOT NULL,
  plan TEXT NOT NULL
)
''');

    await db.execute('''
CREATE TABLE tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  dueDate TEXT NOT NULL,
  dueTime TEXT NOT NULL,
  priority INTEGER NOT NULL,
  category TEXT NOT NULL,
  isCompleted INTEGER NOT NULL,
  isAllDay INTEGER NOT NULL,
  reminder INTEGER NOT NULL,
  reminderMinutes INTEGER NOT NULL,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL
)
''');

    await db.execute('''
CREATE TABLE subtasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  taskId INTEGER NOT NULL,
  title TEXT NOT NULL,
  isCompleted INTEGER NOT NULL,
  FOREIGN KEY (taskId) REFERENCES tasks (id) ON DELETE CASCADE
)
''');

    await _seedData(db);
  }

  Future<void> _seedData(Database db) async {
    final now = DateTime.now();
    
    // Seed user
    await db.insert('users', {
      'fullName': 'John Doe',
      'email': 'john@example.com',
      'avatarUrl': 'https://example.com/avatar.png',
      'workspace': 'Personal',
      'memberSince': now.toIso8601String(),
      'plan': 'Pro Plan',
    });

    // Seed tasks
    final task1 = {
      'title': 'Finalize Q4 Product Roadmap',
      'description': 'Gather input from sales, support, and engineering teams to finalize the Q4 roadmap.',
      'dueDate': now.toIso8601String(),
      'dueTime': '2:00 PM',
      'priority': TaskPriority.high.index,
      'category': 'Strategy',
      'isCompleted': 0,
      'isAllDay': 0,
      'reminder': 1,
      'reminderMinutes': 15,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    final taskId1 = await db.insert('tasks', task1);

    await db.insert('subtasks', {
      'taskId': taskId1,
      'title': 'Review feedback tickets from Support',
      'isCompleted': 1,
    });
    await db.insert('subtasks', {
      'taskId': taskId1,
      'title': 'Prioritize Q4 core feature requests',
      'isCompleted': 1,
    });
    await db.insert('subtasks', {
      'taskId': taskId1,
      'title': 'Draft summary slides in Pitch deck',
      'isCompleted': 0,
    });
    await db.insert('subtasks', {
      'taskId': taskId1,
      'title': 'Get sign-off from tech lead',
      'isCompleted': 0,
    });

    await db.insert('tasks', {
      'title': 'Review design system components',
      'description': 'Review and approve the new design system components submitted by the design team.',
      'dueDate': now.toIso8601String(),
      'dueTime': '4:30 PM',
      'priority': TaskPriority.medium.index,
      'category': 'Design',
      'isCompleted': 0,
      'isAllDay': 0,
      'reminder': 0,
      'reminderMinutes': 0,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    });

    await db.insert('tasks', {
      'title': 'Weekly team sync & standup',
      'description': 'Weekly alignment with the entire team to discuss progress and blockers.',
      'dueDate': now.add(const Duration(days: 1)).toIso8601String(),
      'dueTime': '10:00 AM',
      'priority': TaskPriority.medium.index,
      'category': 'Meeting',
      'isCompleted': 0,
      'isAllDay': 0,
      'reminder': 1,
      'reminderMinutes': 10,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    });

    await db.insert('tasks', {
      'title': 'Order ergonomic desk accessories',
      'description': 'Order new mouse pad and standing desk mat for the home office.',
      'dueDate': now.add(const Duration(days: 2)).toIso8601String(),
      'dueTime': '1:00 PM',
      'priority': TaskPriority.low.index,
      'category': 'Personal',
      'isCompleted': 0,
      'isAllDay': 0,
      'reminder': 0,
      'reminderMinutes': 0,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    });

    await db.insert('tasks', {
      'title': 'Submit quarterly expense reports',
      'description': 'Compile and submit all receipts and expenses from the last quarter to finance.',
      'dueDate': now.subtract(const Duration(days: 1)).toIso8601String(),
      'dueTime': '5:00 PM',
      'priority': TaskPriority.high.index,
      'category': 'Finance',
      'isCompleted': 1,
      'isAllDay': 0,
      'reminder': 0,
      'reminderMinutes': 0,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    });
  }

  Future<int> insertTask(Task task) async {
    final db = await instance.database;
    final id = await db.insert('tasks', task.toMap());
    for (var subtask in task.subtasks) {
      await insertSubtask(subtask.copyWith(taskId: id));
    }
    return id;
  }

  Future<List<Task>> getAllTasks() async {
    final db = await instance.database;
    final result = await db.query('tasks');
    List<Task> tasks = [];
    for (var map in result) {
      final subtasks = await getSubtasksByTaskId(map['id'] as int);
      tasks.add(Task.fromMap(map, subtasks: subtasks));
    }
    return tasks;
  }

  Future<Task?> getTaskById(int id) async {
    final db = await instance.database;
    final result = await db.query('tasks', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty) {
      final subtasks = await getSubtasksByTaskId(id);
      return Task.fromMap(result.first, subtasks: subtasks);
    }
    return null;
  }

  Future<List<Task>> getTasksByDate(DateTime date) async {
    final db = await instance.database;
    final startOfDay = DateTime(date.year, date.month, date.day).toIso8601String();
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();
    
    final result = await db.query('tasks', 
      where: 'dueDate >= ? AND dueDate <= ?', 
      whereArgs: [startOfDay, endOfDay]);
      
    List<Task> tasks = [];
    for (var map in result) {
      final subtasks = await getSubtasksByTaskId(map['id'] as int);
      tasks.add(Task.fromMap(map, subtasks: subtasks));
    }
    return tasks;
  }

  Future<List<Task>> getCompletedTasks() async {
    final db = await instance.database;
    final result = await db.query('tasks', where: 'isCompleted = ?', whereArgs: [1]);
    List<Task> tasks = [];
    for (var map in result) {
      final subtasks = await getSubtasksByTaskId(map['id'] as int);
      tasks.add(Task.fromMap(map, subtasks: subtasks));
    }
    return tasks;
  }

  Future<List<Task>> getUpcomingTasks() async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    final result = await db.query('tasks', 
      where: 'dueDate > ? AND isCompleted = ?', 
      whereArgs: [now, 0],
      orderBy: 'dueDate ASC'
    );
    List<Task> tasks = [];
    for (var map in result) {
      final subtasks = await getSubtasksByTaskId(map['id'] as int);
      tasks.add(Task.fromMap(map, subtasks: subtasks));
    }
    return tasks;
  }

  Future<int> updateTask(Task task) async {
    final db = await instance.database;
    return await db.update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
  }

  Future<int> deleteTask(int id) async {
    final db = await instance.database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertSubtask(Subtask subtask) async {
    final db = await instance.database;
    return await db.insert('subtasks', subtask.toMap());
  }

  Future<List<Subtask>> getSubtasksByTaskId(int taskId) async {
    final db = await instance.database;
    final result = await db.query('subtasks', where: 'taskId = ?', whereArgs: [taskId]);
    return result.map((map) => Subtask.fromMap(map)).toList();
  }

  Future<int> updateSubtask(Subtask subtask) async {
    final db = await instance.database;
    return await db.update('subtasks', subtask.toMap(), where: 'id = ?', whereArgs: [subtask.id]);
  }

  Future<int> deleteSubtask(int id) async {
    final db = await instance.database;
    return await db.delete('subtasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertUser(User user) async {
    final db = await instance.database;
    return await db.insert('users', user.toMap());
  }

  Future<User?> getUser() async {
    final db = await instance.database;
    final result = await db.query('users', limit: 1);
    if (result.isNotEmpty) {
      return User.fromMap(result.first);
    }
    return null;
  }

  Future<int> updateUser(User user) async {
    final db = await instance.database;
    return await db.update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
  }

  Future<int> deleteUser(int id) async {
    final db = await instance.database;
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
