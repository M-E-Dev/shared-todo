import 'unconfigured_shared_list_repository.dart';
import 'unconfigured_todo_repository.dart';
import 'supabase_shared_list_repository.dart';
import 'supabase_todo_repository.dart';
import '../domain/shared_list_repository.dart';
import '../domain/todo_repository.dart';

final class TodoStores {
  const TodoStores({
    required this.sharedListRepository,
    required this.todoRepository,
  });

  final SharedListRepository sharedListRepository;
  final TodoRepository todoRepository;
}

TodoStores createTodoStores({
  required bool supabaseConfigured,
}) {
  if (!supabaseConfigured) {
    return const TodoStores(
      sharedListRepository: UnconfiguredSharedListRepository(),
      todoRepository: UnconfiguredTodoRepository(),
    );
  }

  return TodoStores(
    sharedListRepository: SupabaseSharedListRepository(),
    todoRepository: SupabaseTodoRepository(),
  );
}
