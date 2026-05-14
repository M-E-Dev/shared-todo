import '../../../core/errors/app_exception.dart';
import '../domain/todo_item.dart';
import '../domain/todo_repository.dart';

final class UnconfiguredTodoRepository implements TodoRepository {
  const UnconfiguredTodoRepository();

  Never _fail() => throw const ConfigurationException(
        'Todo deposu yapılandırılmadı; SUPABASE_URL ve SUPABASE_ANON_KEY gerekiyor.',
      );

  @override
  Future<List<TodoItem>> fetchTodos({required String listId}) async => _fail();

  @override
  Future<List<TodoItem>> fetchTodosWithDueDate() async => _fail();

  @override
  Future<void> addTodo({
    required String listId,
    required String title,
    DateTime? dueDate,
  }) async =>
      _fail();

  @override
  Future<void> setCompleted({
    required String todoId,
    required bool completed,
  }) async =>
      _fail();

  @override
  Future<void> deleteTodo({required String todoId}) async => _fail();
}
