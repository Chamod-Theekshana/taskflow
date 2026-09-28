import '../entities/task.dart';

abstract class TaskRepository {
  Future<List<Task>> getAllTasks();
  Future<Task?> getTaskById(int id);
  Future<int> insertTask(Task task);
  Future<void> updateTask(Task task);
  Future<void> deleteTask(int id);
  Future<int> insertSubtask(Subtask subtask);
  Future<void> updateSubtask(Subtask subtask);
  Future<void> deleteSubtask(int id);
}
