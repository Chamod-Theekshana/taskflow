import '../entities/task.dart';

/// Tasks of the signed-in user. Reads and writes are local and instant; the
/// data layer replicates them to the server in the background.
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
