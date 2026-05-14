import 'package:flutter_test/flutter_test.dart';

import 'package:shared_todo/app/app.dart';
import 'package:shared_todo/core/bootstrap/app_bootstrap.dart';
import 'package:shared_todo/core/config/env_config.dart';

void main() {
  testWidgets('App boots', (tester) async {
    final boot = await bootstrapApp(envConfig: EnvConfig.unset);
    addTearDown(boot.authNotifier.dispose);

    await tester.pumpWidget(
      SharedTodoApp(
        envConfig: boot.envConfig,
        authNotifier: boot.authNotifier,
      ),
    );
    expect(find.text('Shared Todo'), findsOneWidget);
    expect(find.textContaining('İskelet hazır'), findsOneWidget);
  });
}
