import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthUser, AuthException;

import '../../../core/errors/app_exception.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

/// Supabase Auth üzerinden anonim oturum ve görünen ad.
final class SupabaseAuthRepository implements AuthRepository {
  static const _displayNameKey = 'display_name';

  GoTrueClient get _auth => Supabase.instance.client.auth;

  @override
  Stream<void> authStateChanges() {
    return _auth.onAuthStateChange.map((_) {});
  }

  @override
  Future<AuthUser?> currentUser() async {
    final session = _auth.currentSession;
    final user = session?.user;
    if (user == null) return null;
    return _mapUser(user);
  }

  @override
  Future<AuthUser> signInAnonymously() async {
    try {
      final response = await _auth.signInAnonymously();
      final user = response.user;
      if (user == null) {
        throw const AuthException('Anonim oturum açılamadı.');
      }
      return _mapUser(user);
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Anonim oturum hatası: $e');
    }
  }

  @override
  Future<void> setDisplayName(String displayName) async {
    try {
      await _auth.updateUser(
        UserAttributes(data: {_displayNameKey: displayName}),
      );
    } catch (e) {
      throw AuthException('Görünen ad güncellenemedi: $e');
    }
  }

  AuthUser _mapUser(User user) {
    final meta = user.userMetadata;
    final name = meta != null ? meta[_displayNameKey] as String? : null;
    return AuthUser(id: user.id, displayName: name);
  }
}
