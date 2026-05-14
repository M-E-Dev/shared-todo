import '../../../core/errors/app_exception.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

/// Supabase yapılandırılmadan çalışır; prod öncesi geliştirme ve test için.
final class UnconfiguredAuthRepository implements AuthRepository {
  const UnconfiguredAuthRepository();

  @override
  Stream<void> authStateChanges() async* {}

  @override
  Future<AuthUser?> currentUser() async => null;

  @override
  Future<AuthUser> signInAnonymously() async {
    throw const ConfigurationException(
      'Supabase yapılandırılmadı. dart-define ile SUPABASE_URL ve SUPABASE_ANON_KEY verin.',
    );
  }

  @override
  Future<void> setDisplayName(String displayName) async {
    throw const ConfigurationException(
      'Supabase yapılandırılmadı; görünen ad kaydedilemez.',
    );
  }
}
