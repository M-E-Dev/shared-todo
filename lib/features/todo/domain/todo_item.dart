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
    this.dueDate,
  });

  final String id;
  final String listId;
  final String title;
  final bool completed;
  final int sortOrder;
  final DateTime createdAt;

  /// Opsiyonel son tarih (sadece tarih, saat yok).
  final DateTime? dueDate;

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'] as String,
      listId: json['list_id'] as String,
      title: json['title'] as String,
      completed: json['completed'] as bool,
      sortOrder: (json['sort_order'] as num).toInt(),
      createdAt: _parseUtc(json['created_at']),
      dueDate: _parseDate(json['due_date']),
    );
  }

  static DateTime _parseUtc(Object? raw) {
    if (raw is String) {
      return DateTime.tryParse(raw)?.toUtc() ?? DateTime.now().toUtc();
    }
    if (raw is DateTime) {
      return raw.toUtc();
    }
    return DateTime.now().toUtc();
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is String) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  TodoItem copyWith({
    String? id,
    String? listId,
    String? title,
    bool? completed,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? dueDate,
    bool clearDueDate = false,
  }) {
    return TodoItem(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
    );
  }

  /// Gün farkı (bugün = 0, yarın = 1, dün = -1).
  int? get dueDaysFromNow {
    final d = dueDate;
    if (d == null) {
      return null;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(d.year, d.month, d.day);
    return due.difference(today).inDays;
  }

  @override
  bool operator ==(Object other) {
    return other is TodoItem &&
        other.id == id &&
        other.listId == listId &&
        other.title == title &&
        other.completed == completed &&
        other.sortOrder == sortOrder &&
        other.createdAt == createdAt &&
        other.dueDate == dueDate;
  }

  @override
  int get hashCode =>
      Object.hash(id, listId, title, completed, sortOrder, createdAt, dueDate);
}
