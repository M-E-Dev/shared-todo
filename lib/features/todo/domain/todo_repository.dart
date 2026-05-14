import 'todo_item.dart';

/// Bir listeye bağlı todo satırları (`public.todos`).
abstract interface class TodoRepository {
  Future<List<TodoItem>> fetchTodos({required String listId});

  Future<void> addTodo({required String listId, required String title});

  Future<void> setCompleted({
    required String todoId,
    required bool completed,
  });

  Future<void> deleteTodo({required String todoId});
}
