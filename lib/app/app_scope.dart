import 'package:flutter/widgets.dart';

import '../core/config/env_config.dart';
import '../features/auth/presentation/auth_notifier.dart';
import '../features/todo/domain/shared_list_repository.dart';
import '../features/todo/domain/todo_repository.dart';
import 'theme/app_theme_notifier.dart';

/// Bağımlılıklara [BuildContext] üzerinden erişim.
final class AppScope extends InheritedWidget {
  const AppScope({
    required this.envConfig,
    required this.authNotifier,
    required this.sharedListRepository,
    required this.todoRepository,
    required this.themeNotifier,
    required super.child,
    super.key,
  });

  final EnvConfig envConfig;
  final AuthNotifier authNotifier;
  final SharedListRepository sharedListRepository;
  final TodoRepository todoRepository;
  final AppThemeNotifier themeNotifier;

  static AppScope read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope üst ağaçta tanımlı olmalı.');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope old) {
    return envConfig != old.envConfig ||
        authNotifier != old.authNotifier ||
        sharedListRepository != old.sharedListRepository ||
        todoRepository != old.todoRepository ||
        themeNotifier != old.themeNotifier;
  }
}
