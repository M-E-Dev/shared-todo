import 'package:flutter/widgets.dart';

import '../config/env_config.dart';
import '../../app/theme/app_theme_notifier.dart';
import '../../features/auth/data/auth_repository_factory.dart';
import '../../features/auth/presentation/auth_notifier.dart';
import '../../features/todo/domain/shared_list_repository.dart';
import '../../features/todo/domain/todo_repository.dart';
import '../../features/todo/data/todo_data_factory.dart';
import 'supabase_bootstrap.dart';

/// Uygulama açılış sırası: binding → env → Supabase → auth deposu → ilk oturum okuma.
final class AppBootstrapResult {
  const AppBootstrapResult({
    required this.envConfig,
    required this.authNotifier,
    required this.sharedListRepository,
    required this.todoRepository,
    required this.themeNotifier,
  });

  final EnvConfig envConfig;
  final AuthNotifier authNotifier;
  final SharedListRepository sharedListRepository;
  final TodoRepository todoRepository;
  final AppThemeNotifier themeNotifier;
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

  if (env.hasSupabaseCredentials) {
    await authNotifier.ensureSupabaseAnonymousSession();
  }

  final todoStores = createTodoStores(
    supabaseConfigured: env.hasSupabaseCredentials,
  );

  final AppThemeNotifier themeNotifier = await AppThemeNotifier.load();

  return AppBootstrapResult(
    envConfig: env,
    authNotifier: authNotifier,
    sharedListRepository: todoStores.sharedListRepository,
    todoRepository: todoStores.todoRepository,
    themeNotifier: themeNotifier,
  );
}
