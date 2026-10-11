import '../../../../core/error/failures.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';
import '../datasources/task_local_data_source.dart';

/// Offline-first: every call goes to SQLite, then [onLocalChange] asks the
/// sync engine to push the change when it can.
class TaskRepositoryImpl implements TaskRepository {
  TaskRepositoryImpl(
    this._local,
    this._userId, {
    required void Function() onLocalChange,
  }) : _onLocalChange = onLocalChange;

  final TaskLocalDataSource _local;
  final String? _userId;
  final void Function() _onLocalChange;

  String _requireUser() {
    final id = _userId;
    if (id == null) throw const DatabaseFailure('You are not signed in.');
    return id;
  }

  Future<T> _write<T>(Future<T> Function(String userId) change) async {
    final result = await change(_requireUser());
    _onLocalChange();
    return result;
  }

  @override
  Future<List<Task>> getAllTasks() async {
    final userId = _userId;
    return userId == null ? const [] : _local.getAll(userId);
  }

  @override
  Future<Task?> getTaskById(int id) async {
    final userId = _userId;
    return userId == null ? null : _local.getById(userId, id);
  }

  @override
  Future<int> insertTask(Task task) =>
      _write((userId) => _local.insert(userId, task));

  @override
  Future<void> updateTask(Task task) =>
      _write((userId) => _local.update(userId, task));

  @override
  Future<void> deleteTask(int id) =>
      _write((userId) => _local.markDeleted(userId, id, DateTime.now()));

  @override
  Future<int> insertSubtask(Subtask subtask) =>
      _write((userId) => _local.insertSubtask(userId, subtask, DateTime.now()));

  @override
  Future<void> updateSubtask(Subtask subtask) =>
      _write((userId) => _local.updateSubtask(userId, subtask, DateTime.now()));

  @override
  Future<void> deleteSubtask(int id) =>
      _write((userId) => _local.deleteSubtask(userId, id, DateTime.now()));
}
