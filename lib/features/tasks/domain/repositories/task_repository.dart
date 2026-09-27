import '../entities/task.dart';

abstract class TaskRepository {
  Future<int> insertTask(Task task);
  Future<List<Task>> getAllTasks();
  Future<Task?> getTaskById(int id);
  Future<List<Task>> getTasksByDate(DateTime date);
  Future<List<Task>> getCompletedTasks();
  Future<List<Task>> getUpcomingTasks();
  Future<int> updateTask(Task task);
  Future<int> deleteTask(int id);
  Future<int> insertSubtask(Subtask subtask);
  Future<List<Subtask>> getSubtasksByTaskId(int taskId);
  Future<int> updateSubtask(Subtask subtask);
  Future<int> deleteSubtask(int id);
}