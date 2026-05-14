import 'shared_list.dart';

/// Oturumdaki kullanıcının eriştiği ortak listeler (`public.lists` + RLS).
abstract interface class SharedListRepository {
  /// RLS yalnızca üyesi/oluşturucusu olunanları döndürür.
  Future<List<SharedList>> fetchMyLists();

  /// Liste oluşturur ve oluşturanı `list_members` içine ekler.
  Future<SharedList> createList({required String title});
}
