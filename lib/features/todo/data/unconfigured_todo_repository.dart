import '../../../core/errors/app_exception.dart';
import '../domain/todo_item.dart';
import '../domain/todo_repository.dart';

final class UnconfiguredTodoRepository implements TodoRepository {
  const UnconfiguredTodoRepository();

  @override
  Future<List<TodoItem>> fetchTodos({required String listId}) async {
    throw const ConfigurationException(
      'Todo deposu yapılandırılmadı; SUPABASE_URL ve SUPABASE_ANON_KEY gerekiyor.',
    );
  }

  @override
  Future<void> addTodo({
    required String listId,
    required String title,
  }) async {
    throw const ConfigurationException(
      'Todo deposu yapılandırılmadı; SUPABASE_URL ve SUPABASE_ANON_KEY gerekiyor.',
    );
  }

  @override
  Future<void> setCompleted({
    required String todoId,
    required bool completed,
  }) async {
    throw const ConfigurationException(
      'Todo deposu yapılandırılmadı; SUPABASE_URL ve SUPABASE_ANON_KEY gerekiyor.',
    );
  }

  @override
  Future<void> deleteTodo({required String todoId}) async {
    throw const ConfigurationException(
      'Todo deposu yapılandırılmadı; SUPABASE_URL ve SUPABASE_ANON_KEY gerekiyor.',
    );
  }
}
