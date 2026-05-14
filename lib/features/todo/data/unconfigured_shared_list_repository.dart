import '../../../core/errors/app_exception.dart';
import '../domain/shared_list.dart';
import '../domain/shared_list_repository.dart';

final class UnconfiguredSharedListRepository implements SharedListRepository {
  const UnconfiguredSharedListRepository();

  Never _fail() => throw const ConfigurationException(
        'Liste deposu yapılandırılmadı; SUPABASE_URL ve SUPABASE_ANON_KEY gerekiyor.',
      );

  @override
  Future<List<SharedList>> fetchMyLists() async => _fail();

  @override
  Future<SharedList> createList({required String title}) async => _fail();

  @override
  Future<SharedList> updateListSettings({
    required String listId,
    String? title,
    String? colorHex,
    ListSortDirection? sortDirection,
  }) async =>
      _fail();
}
