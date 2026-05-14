import 'shared_list.dart';

/// Oturumdaki kullanıcının eriştiği ortak listeler (`public.lists` + RLS).
abstract interface class SharedListRepository {
  Future<List<SharedList>> fetchMyLists();

  Future<SharedList> createList({required String title});

  Future<SharedList> updateListSettings({
    required String listId,
    String? title,
    String? colorHex,
    ListSortDirection? sortDirection,
  });
}
