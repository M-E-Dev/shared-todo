/// Uygulama genelinde tek tip hata taşıyıcısı; üst katman mesaj/i18n'e çevirir.
sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Supabase veya dart-define eksik.
final class ConfigurationException extends AppException {
  const ConfigurationException(super.message);
}

/// Oturum / kimlik doğrulama.
final class AuthException extends AppException {
  const AuthException(super.message);
}
