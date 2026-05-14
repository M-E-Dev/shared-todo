import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../../core/errors/app_exception.dart';
import '../domain/todo_item.dart';
import '../domain/todo_repository.dart';

final class SupabaseTodoRepository implements TodoRepository {
  SupabaseClient get _client => Supabase.instance.client;

  String _requireUid() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) {
      throw const AuthException('Oturum yok.');
    }
    return uid;
  }

  @override
  Future<List<TodoItem>> fetchTodos({required String listId}) async {
    _requireUid();
    try {
      final raw = await _client
          .from('todos')
          .select()
          .eq('list_id', listId)
          .order('sort_order', ascending: true)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(raw as List<dynamic>)
          .map(TodoItem.fromJson)
          .toList();
    } on PostgrestException catch (e) {
      throw AuthException('Görevler yüklenemedi (${e.message})');
    }
  }

  @override
  Future<List<TodoItem>> fetchTodosWithDueDate() async {
    _requireUid();
    try {
      final raw = await _client
          .from('todos')
          .select()
          .not('due_date', 'is', null)
          .order('due_date', ascending: true);
      return List<Map<String, dynamic>>.from(raw as List<dynamic>)
          .map(TodoItem.fromJson)
          .toList();
    } on PostgrestException catch (e) {
      throw AuthException('Takvim görevi yüklenemedi (${e.message})');
    }
  }

  @override
  Future<void> addTodo({
    required String listId,
    required String title,
    DateTime? dueDate,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw const AuthException('Görev başlığı boş olamaz.');
    }
    _requireUid();
    try {
      final payload = <String, dynamic>{
        'list_id': listId,
        'title': trimmed,
        'completed': false,
        'sort_order': 0,
      };
      if (dueDate != null) {
        payload['due_date'] =
            '${dueDate.year.toString().padLeft(4, '0')}-'
            '${dueDate.month.toString().padLeft(2, '0')}-'
            '${dueDate.day.toString().padLeft(2, '0')}';
      }
      await _client.from('todos').insert(payload);
    } on PostgrestException catch (e) {
      // Şema önbelleği due_date sütununu tanımıyorsa tarihsiz tekrar dene.
      if (e.message.contains('due_date') && dueDate != null) {
        try {
          await _client.from('todos').insert(<String, dynamic>{
            'list_id': listId,
            'title': trimmed,
            'completed': false,
            'sort_order': 0,
          });
          return;
        } on PostgrestException catch (e2) {
          throw AuthException(
            'Görev eklenemedi (${e2.message}). '
            'Migration 005\'i Supabase SQL Editor\'da çalıştırın.',
          );
        }
      }
      throw AuthException('Görev eklenemedi (${e.message})');
    }
  }

  @override
  Future<void> setCompleted({
    required String todoId,
    required bool completed,
  }) async {
    _requireUid();
    try {
      await _client
          .from('todos')
          .update({'completed': completed}).eq('id', todoId);
    } on PostgrestException catch (e) {
      throw AuthException('Görev güncellenemedi (${e.message})');
    }
  }

  @override
  Future<void> deleteTodo({required String todoId}) async {
    _requireUid();
    try {
      await _client.from('todos').delete().eq('id', todoId);
    } on PostgrestException catch (e) {
      throw AuthException('Görev silinemedi (${e.message})');
    }
  }
}
