import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../../core/errors/app_exception.dart';
import '../domain/shared_list.dart';
import '../domain/shared_list_repository.dart';

final class SupabaseSharedListRepository implements SharedListRepository {
  SupabaseClient get _client => Supabase.instance.client;

  String _requireUid() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) {
      throw const AuthException('Oturum yok.');
    }
    return uid;
  }

  @override
  Future<List<SharedList>> fetchMyLists() async {
    _requireUid();
    try {
      final raw = await _client
          .from('lists')
          .select()
          .order('created_at', ascending: true);
      final rows = List<Map<String, dynamic>>.from(raw as List<dynamic>);
      return rows.map(SharedList.fromJson).toList();
    } on PostgrestException catch (e) {
      throw AuthException('Listeler yüklenemedi (${e.message})');
    }
  }

  @override
  Future<SharedList> createList({required String title}) async {
    final uid = _requireUid();
    try {
      final inserted = await _client
          .from('lists')
          .insert({
            'title': title.trim().isEmpty ? 'Yeni liste' : title.trim(),
            'created_by': uid,
          })
          .select()
          .single();

      await _client.from('list_members').insert({
        'list_id': inserted['id'] as String,
        'user_id': uid,
      });

      return SharedList.fromJson(Map<String, dynamic>.from(inserted));
    } on PostgrestException catch (e) {
      throw AuthException('Liste oluşturulamadı (${e.message})');
    }
  }

  @override
  Future<SharedList> updateListSettings({
    required String listId,
    String? title,
    String? colorHex,
    ListSortDirection? sortDirection,
  }) async {
    _requireUid();
    final updates = <String, dynamic>{};
    if (title != null) {
      updates['title'] = title.trim().isEmpty ? 'Liste' : title.trim();
    }
    if (colorHex != null) {
      updates['color'] = colorHex;
    }
    if (sortDirection != null) {
      updates['sort_direction'] = sortDirection.toJson();
    }
    if (updates.isEmpty) {
      throw const AuthException('Güncellenecek alan yok.');
    }
    try {
      final updated = await _client
          .from('lists')
          .update(updates)
          .eq('id', listId)
          .select()
          .single();
      return SharedList.fromJson(Map<String, dynamic>.from(updated));
    } on PostgrestException catch (e) {
      throw AuthException('Liste güncellenemedi (${e.message})');
    }
  }
}
