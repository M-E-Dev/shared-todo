import 'shared_list.dart';
import 'todo_item.dart';

/// Tamamlanmamış görevlerde aciliyet (düşük = daha üstte).
int todoUrgencyRank(TodoItem item) {
  if (item.completed) {
    return 100;
  }
  final int? days = item.dueDaysFromNow;
  if (days == null) {
    return 50;
  }
  if (days < 0) {
    return 0;
  }
  if (days <= 2) {
    return 1;
  }
  if (days <= 7) {
    return 2;
  }
  return 3;
}

int _compareBySortDirection(
  TodoItem a,
  TodoItem b,
  ListSortDirection dir,
) {
  switch (dir) {
    case ListSortDirection.newestFirst:
      return b.createdAt.compareTo(a.createdAt);
    case ListSortDirection.oldestFirst:
      return a.createdAt.compareTo(b.createdAt);
    case ListSortDirection.titleAsc:
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }
}

/// Önce aciliyet, aynı aciliyet grubunda kullanıcı sıralaması.
List<TodoItem> sortTodosByUrgencyThenDirection(
  List<TodoItem> raw,
  ListSortDirection dir,
) {
  final List<TodoItem> copy = List<TodoItem>.from(raw);
  copy.sort((TodoItem a, TodoItem b) {
    final int urgency = todoUrgencyRank(a).compareTo(todoUrgencyRank(b));
    if (urgency != 0) {
      return urgency;
    }
    return _compareBySortDirection(a, b, dir);
  });
  return copy;
}
