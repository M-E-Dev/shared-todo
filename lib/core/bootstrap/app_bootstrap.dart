import 'package:flutter/widgets.dart';

import '../config/env_config.dart';
import '../../features/auth/data/auth_repository_factory.dart';
import '../../features/auth/presentation/auth_notifier.dart';
import 'supabase_bootstrap.dart';

/// Uygulama açılış sırası: binding → env → Supabase → auth deposu → ilk oturum okuma.
final class AppBootstrapResult {
  const AppBootstrapResult({
    required this.envConfig,
    required this.authNotifier,
  });

  final EnvConfig envConfig;
  final AuthNotifier authNotifier;
}

Future<AppBootstrapResult> bootstrapApp({
  EnvConfig? envConfig,
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  final env = envConfig ?? EnvConfig.fromEnvironment();
  await initSupabase(env);

  final authNotifier = AuthNotifier(
    createAuthRepository(
      supabaseConfigured: env.hasSupabaseCredentials,
    ),
  );

  await authNotifier.hydrate();

  return AppBootstrapResult(envConfig: env, authNotifier: authNotifier);
}
