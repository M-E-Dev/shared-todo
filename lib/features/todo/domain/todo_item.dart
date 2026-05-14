import 'package:flutter/foundation.dart';

/// `public.todos` satırının domain karşılığı.
@immutable
final class TodoItem {
  const TodoItem({
    required this.id,
    required this.listId,
    required this.title,
    required this.completed,
    required this.sortOrder,
    required this.createdAt,
  });

  final String id;
  final String listId;
  final String title;
  final bool completed;
  final int sortOrder;
  final DateTime createdAt;

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'] as String,
      listId: json['list_id'] as String,
      title: json['title'] as String,
      completed: json['completed'] as bool,
      sortOrder: (json['sort_order'] as num).toInt(),
      createdAt: SharedTimestamp.parseUtc(json['created_at']),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TodoItem &&
        other.id == id &&
        other.listId == listId &&
        other.title == title &&
        other.completed == completed &&
        other.sortOrder == sortOrder &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode =>
      Object.hash(id, listId, title, completed, sortOrder, createdAt);
}

@immutable
abstract final class SharedTimestamp {
  const SharedTimestamp._();

  static DateTime parseUtc(Object? raw) {
    if (raw is String) {
      return DateTime.tryParse(raw)?.toUtc() ?? DateTime.now().toUtc();
    }
    if (raw is DateTime) {
      return raw.toUtc();
    }
    return DateTime.now().toUtc();
  }
}
