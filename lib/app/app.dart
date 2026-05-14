import 'package:flutter/material.dart';

import '../core/config/env_config.dart';
import '../features/auth/presentation/auth_notifier.dart';
import '../features/todo/domain/shared_list_repository.dart';
import '../features/todo/domain/todo_repository.dart';
import '../features/todo/presentation/todo_workspace.dart';
import 'app_scope.dart';
import 'theme/app_theme.dart';

/// Kök widget: tema + [AppScope] + oturum dinleyicisi.
class SharedTodoApp extends StatelessWidget {
  const SharedTodoApp({
    required this.envConfig,
    required this.authNotifier,
    required this.sharedListRepository,
    required this.todoRepository,
    super.key,
  });

  final EnvConfig envConfig;
  final AuthNotifier authNotifier;
  final SharedListRepository sharedListRepository;
  final TodoRepository todoRepository;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      envConfig: envConfig,
      authNotifier: authNotifier,
      sharedListRepository: sharedListRepository,
      todoRepository: todoRepository,
      child: ListenableBuilder(
        listenable: authNotifier,
        builder: (context, _) {
          return MaterialApp(
            title: 'Shared Todo',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.system,
            home: const _StarterHome(),
          );
        },
      ),
    );
  }
}

class _StarterHome extends StatefulWidget {
  const _StarterHome();

  @override
  State<_StarterHome> createState() => _StarterHomeState();
}

final class _StarterHomeState extends State<_StarterHome> {
  final TextEditingController _nameController = TextEditingController();
  bool _savingName = false;
  String? _nameError;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _retrySignIn(AppScope scope) async {
    setState(() {
      _nameError = null;
    });
    await scope.authNotifier.ensureSupabaseAnonymousSession();
    if (mounted) setState(() {});
  }

  Future<void> _saveDisplayName(AuthNotifier notifier) async {
    final trimmed = _nameController.text.trim();
    if (trimmed.isEmpty) {
      setState(() => _nameError = 'Görünen ad boş olamaz.');
      return;
    }
    setState(() {
      _nameError = null;
      _savingName = true;
    });
    try {
      await notifier.setDisplayName(trimmed);
    } on Exception catch (_) {
      if (mounted) {
        setState(() => _nameError = 'Kaydedilemedi; tekrar dene.');
      }
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.read(context);
    final cfg = scope.envConfig;
    final auth = scope.authNotifier;
    final user = auth.user;

    final statusText = !cfg.hasSupabaseCredentials
        ? 'Backend: yapılandırılmadı (--dart-define ile SUPABASE_URL ve SUPABASE_ANON_KEY verin).'
        : auth.sessionError != null
            ? auth.sessionError!
            : user == null
                ? 'Oturum açılıyor…'
                : null;

    final loggedIn = user;

    if (cfg.hasSupabaseCredentials &&
        loggedIn != null &&
        auth.sessionError == null &&
        loggedIn.hasDisplayName) {
      return Scaffold(
        appBar: AppBar(title: const Text('Shared Todo')),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Merhaba, ${loggedIn.displayName}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              const Expanded(child: TodoWorkspace()),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Shared Todo')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'MVP için iskelet: liste ve görevler sırada.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              if (statusText != null) ...[
                Text(
                  statusText,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (!cfg.hasSupabaseCredentials ||
                    auth.sessionError != null) ...[
                  const SizedBox(height: 16),
                  if (cfg.hasSupabaseCredentials && auth.sessionError != null)
                    FilledButton.icon(
                      onPressed: auth.user == null
                          ? () => _retrySignIn(scope)
                          : null,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tekrar dene'),
                    ),
                ],
              ],
              if (cfg.hasSupabaseCredentials &&
                  user != null &&
                  auth.sessionError == null) ...[
                const SizedBox(height: 24),
                if (!user.hasDisplayName) ...[
                  Text(
                    'Görünen adını yaz (liste paylaşımında böyle görünürsün).',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Görünen ad',
                      hintText: 'ör. Ayşe',
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _saveDisplayName(auth),
                  ),
                  if (_nameError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _nameError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _savingName ? null : () => _saveDisplayName(auth),
                    child: _savingName
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Kaydet'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
