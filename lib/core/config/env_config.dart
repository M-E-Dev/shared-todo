import 'package:flutter/foundation.dart';

/// Çalışma ortamı sabitleri (`dart-define`). Secret repoda tutulmaz.
@immutable
final class EnvConfig {
  const EnvConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  factory EnvConfig.fromEnvironment() {
    return const EnvConfig(
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
    );
  }

  /// Test ve yerel deneme için boş yapılandırma.
  static const unset = EnvConfig(supabaseUrl: '', supabaseAnonKey: '');

  final String supabaseUrl;
  final String supabaseAnonKey;

  bool get hasSupabaseCredentials =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  @override
  bool operator ==(Object other) {
    return other is EnvConfig &&
        other.supabaseUrl == supabaseUrl &&
        other.supabaseAnonKey == supabaseAnonKey;
  }

  @override
  int get hashCode => Object.hash(supabaseUrl, supabaseAnonKey);
}
