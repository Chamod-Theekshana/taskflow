import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';
import '../datasources/task_local_data_source.dart';
import '../models/task_model.dart';

class TaskRepositoryImpl implements TaskRepository {
  final TaskLocalDataSource localDataSource;

  TaskRepositoryImpl(this.localDataSource);

  @override
  Future<int> insertTask(Task task) {
    return localDataSource.insertTask(TaskModel.fromEntity(task));
  }

  @override
  Future<List<Task>> getAllTasks() async {
    return await localDataSource.getAllTasks();
  }

  @override
  Future<Task?> getTaskById(int id) async {
    return await localDataSource.getTaskById(id);
  }

  @override
  Future<List<Task>> getTasksByDate(DateTime date) async {
    return await localDataSource.getTasksByDate(date);
  }

  @override
  Future<List<Task>> getCompletedTasks() async {
    return await localDataSource.getCompletedTasks();
  }

  @override
  Future<List<Task>> getUpcomingTasks() async {
    return await localDataSource.getUpcomingTasks();
  }

  @override
  Future<int> updateTask(Task task) {
    return localDataSource.updateTask(TaskModel.fromEntity(task));
  }

  @override
  Future<int> deleteTask(int id) {
    return localDataSource.deleteTask(id);
  }

  @override
  Future<int> insertSubtask(Subtask subtask) {
    return localDataSource.insertSubtask(SubtaskModel.fromEntity(subtask));
  }

  @override
  Future<List<Subtask>> getSubtasksByTaskId(int taskId) async {
    return await localDataSource.getSubtasksByTaskId(taskId);
  }

  @override
  Future<int> updateSubtask(Subtask subtask) {
    return localDataSource.updateSubtask(SubtaskModel.fromEntity(subtask));
  }

  @override
  Future<int> deleteSubtask(int id) {
    return localDataSource.deleteSubtask(id);
  }
}