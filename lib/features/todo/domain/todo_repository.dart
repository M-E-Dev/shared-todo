import 'todo_item.dart';

/// Bir listeye bağlı todo satırları (`public.todos`).
abstract interface class TodoRepository {
  Future<List<TodoItem>> fetchTodos({required String listId});

  /// Tüm listelerden due_date'i dolu todo'ları getirir (takvim için).
  Future<List<TodoItem>> fetchTodosWithDueDate();

  Future<void> addTodo({
    required String listId,
    required String title,
    DateTime? dueDate,
  });

  Future<void> setCompleted({
    required String todoId,
    required bool completed,
  });

  Future<void> deleteTodo({required String todoId});
}
