import 'package:flutter/material.dart';

import '../core/config/env_config.dart';
import '../features/auth/presentation/auth_notifier.dart';
import 'app_scope.dart';
import 'theme/app_theme.dart';

/// Kök widget: tema + [AppScope] + oturum dinleyicisi.
class SharedTodoApp extends StatelessWidget {
  const SharedTodoApp({
    required this.envConfig,
    required this.authNotifier,
    super.key,
  });

  final EnvConfig envConfig;
  final AuthNotifier authNotifier;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      envConfig: envConfig,
      authNotifier: authNotifier,
      child: ListenableBuilder(
        listenable: authNotifier,
        builder: (context, _) {
          return MaterialApp(
            title: 'Shared Todo',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.system,
            home: const _PlaceholderHome(),
          );
        },
      ),
    );
  }
}

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.read(context);
    final cfg = scope.envConfig;
    final user = scope.authNotifier.user;

    final status = !cfg.hasSupabaseCredentials
        ? 'Backend: yapılandırılmadı (SUPABASE_* dart-define).'
        : user == null
            ? 'Oturum yok — anonim giriş akışı eklenecek.'
            : 'Oturum: ${user.hasDisplayName ? user.displayName : user.id.substring(0, 8)}…';

    return Scaffold(
      appBar: AppBar(title: const Text('Shared Todo')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'İskelet hazır.\n'
                'Flutter kurulumundan sonra: flutter pub get',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(
                status,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
