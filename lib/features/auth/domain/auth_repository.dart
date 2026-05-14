import 'auth_user.dart';

/// Kimlik katmanı soyutlaması; UI yalnızca bunu bilir (Supabase detayı data katmanında).
abstract interface class AuthRepository {
  /// Kalıcı oturum varsa döner; yoksa null.
  Future<AuthUser?> currentUser();

  /// Anonim oturum açar ve kullanıcıyı döner.
  Future<AuthUser> signInAnonymously();

  /// Oturum metadata güncellemesi (görünen ad).
  Future<void> setDisplayName(String displayName);

  /// Oturum değiştiğinde tetiklenir (dinleyici yeniden `currentUser` çekebilir).
  Stream<void> authStateChanges();
}
