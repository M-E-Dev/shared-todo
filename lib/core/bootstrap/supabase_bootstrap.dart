import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env_config.dart';

/// Supabase istemcisini başlatır. [EnvConfig] içinde URL/anon key yoksa sessizce çıkar.
Future<void> initSupabase(EnvConfig env) async {
  if (!env.hasSupabaseCredentials) {
    return;
  }

  await Supabase.initialize(
    url: env.supabaseUrl,
    anonKey: env.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
}
