import '../../../core/errors/app_exception.dart';
import '../domain/shared_list.dart';
import '../domain/shared_list_repository.dart';

final class UnconfiguredSharedListRepository implements SharedListRepository {
  const UnconfiguredSharedListRepository();

  @override
  Future<List<SharedList>> fetchMyLists() async {
    throw const ConfigurationException(
      'Liste deposu yapılandırılmadı; SUPABASE_URL ve SUPABASE_ANON_KEY gerekiyor.',
    );
  }

  @override
  Future<SharedList> createList({required String title}) async {
    throw const ConfigurationException(
      'Liste deposu yapılandırılmadı; SUPABASE_URL ve SUPABASE_ANON_KEY gerekiyor.',
    );
  }
}
