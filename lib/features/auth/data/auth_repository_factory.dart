import '../domain/auth_repository.dart';
import 'supabase_auth_repository.dart';
import 'unconfigured_auth_repository.dart';

AuthRepository createAuthRepository({
  required bool supabaseConfigured,
}) {
  if (!supabaseConfigured) {
    return const UnconfiguredAuthRepository();
  }
  return SupabaseAuthRepository();
}
