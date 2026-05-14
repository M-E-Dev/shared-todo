import 'package:flutter/widgets.dart';

import '../core/config/env_config.dart';
import '../features/auth/presentation/auth_notifier.dart';
import '../features/todo/domain/shared_list_repository.dart';
import '../features/todo/domain/todo_repository.dart';

/// Bağımlılıklara [BuildContext] üzerinden erişim (Riverpod/Provider olmadan).
final class AppScope extends InheritedWidget {
  const AppScope({
    required this.envConfig,
    required this.authNotifier,
    required this.sharedListRepository,
    required this.todoRepository,
    required super.child,
    super.key,
  });

  final EnvConfig envConfig;
  final AuthNotifier authNotifier;
  final SharedListRepository sharedListRepository;
  final TodoRepository todoRepository;

  static AppScope read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope üst ağaçta tanımlı olmalı.');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) {
    return envConfig != oldWidget.envConfig ||
        authNotifier != oldWidget.authNotifier ||
        sharedListRepository != oldWidget.sharedListRepository ||
        todoRepository != oldWidget.todoRepository;
  }
}
