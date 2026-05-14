import 'package:flutter/material.dart';

import '../core/config/env_config.dart';
import '../features/auth/domain/auth_user.dart';
import '../features/auth/presentation/auth_notifier.dart';
import '../features/settings/settings_sheet.dart';
import '../features/todo/domain/shared_list_repository.dart';
import '../features/todo/domain/todo_repository.dart';
import '../features/todo/presentation/calendar_screen.dart';
import '../features/todo/presentation/lists_overview.dart';
import 'app_scope.dart';
import 'theme/app_theme_notifier.dart';
import 'theme/app_theme_preset.dart';

class SharedTodoApp extends StatelessWidget {
  const SharedTodoApp({
    required this.envConfig,
    required this.authNotifier,
    required this.sharedListRepository,
    required this.todoRepository,
    required this.themeNotifier,
    super.key,
  });

  final EnvConfig envConfig;
  final AuthNotifier authNotifier;
  final SharedListRepository sharedListRepository;
  final TodoRepository todoRepository;
  final AppThemeNotifier themeNotifier;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[authNotifier, themeNotifier]),
      builder: (BuildContext context, _) {
        return AppScope(
          envConfig: envConfig,
          authNotifier: authNotifier,
          sharedListRepository: sharedListRepository,
          todoRepository: todoRepository,
          themeNotifier: themeNotifier,
          child: MaterialApp(
            title: 'Shared Todo',
            debugShowCheckedModeBanner: false,
            theme: themeNotifier.current.themeData,
            home: const _RootGate(),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Root gate: oturum durumuna göre giriş ekranı ya da ana kabuk
// ---------------------------------------------------------------------------

class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

final class _RootGateState extends State<_RootGate> {
  final TextEditingController _nameCtrl = TextEditingController();
  bool _savingName = false;
  String? _nameError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _retrySignIn() async {
    setState(() => _nameError = null);
    await AppScope.read(context).authNotifier.ensureSupabaseAnonymousSession();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveName(AuthNotifier auth) async {
    final trimmed = _nameCtrl.text.trim();
    if (trimmed.isEmpty) {
      setState(() => _nameError = 'Görünen ad boş olamaz.');
      return;
    }
    setState(() {
      _nameError = null;
      _savingName = true;
    });
    try {
      await auth.setDisplayName(trimmed);
    } on Exception catch (_) {
      if (mounted) {
        setState(() => _nameError = 'Kaydedilemedi; tekrar dene.');
      }
    } finally {
      if (mounted) {
        setState(() => _savingName = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.read(context);
    final cfg = scope.envConfig;
    final auth = scope.authNotifier;
    final user = auth.user;
    final c = scope.themeNotifier.current;

    if (cfg.hasSupabaseCredentials &&
        user != null &&
        auth.sessionError == null &&
        user.hasDisplayName) {
      return _HomeShell(displayName: user.displayName!);
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[c.bg, Color.lerp(c.bg, c.accent, 0.06)!],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: _LoginCard(
                c: c,
                cfg: cfg,
                auth: auth,
                user: user,
                nameCtrl: _nameCtrl,
                savingName: _savingName,
                nameError: _nameError,
                onRetry: _retrySignIn,
                onSaveName: () => _saveName(auth),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ana kabuk: PageView (Listeler ↔ Takvim) + NavigationBar
// ---------------------------------------------------------------------------

class _HomeShell extends StatefulWidget {
  const _HomeShell({required this.displayName});

  final String displayName;

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

final class _HomeShellState extends State<_HomeShell> {
  final PageController _pageCtrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _goTo(int idx) {
    _pageCtrl.animateToPage(
      idx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SettingsSheet(
        themeNotifier: AppScope.read(context).themeNotifier,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.read(context).themeNotifier.current;
    return Scaffold(
      backgroundColor: c.bg,
      // Sağ üst ayarlar butonu eklemek için AppBar kullanmıyoruz;
      // her sayfa kendi başlığını yönetiyor. Ayarlar ListsOverview'dan açılır.
      body: PageView(
        controller: _pageCtrl,
        onPageChanged: (int p) => setState(() => _page = p),
        children: <Widget>[
          ListsOverview(
            displayName: widget.displayName,
            onSettingsTap: _showSettings,
          ),
          const CalendarScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _page,
        onDestinationSelected: _goTo,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.checklist_rtl_outlined),
            selectedIcon: Icon(Icons.checklist_rtl_rounded),
            label: 'Listeler',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Takvim',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Giriş kartı
// ---------------------------------------------------------------------------

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.c,
    required this.cfg,
    required this.auth,
    required this.user,
    required this.nameCtrl,
    required this.savingName,
    required this.nameError,
    required this.onRetry,
    required this.onSaveName,
  });

  final AppThemePreset c;
  final EnvConfig cfg;
  final AuthNotifier auth;
  final AuthUser? user;
  final TextEditingController nameCtrl;
  final bool savingName;
  final String? nameError;
  final VoidCallback onRetry;
  final VoidCallback onSaveName;

  @override
  Widget build(BuildContext context) {
    final bool hasError =
        !cfg.hasSupabaseCredentials || auth.sessionError != null;
    final bool loading =
        cfg.hasSupabaseCredentials &&
        auth.sessionError == null &&
        user == null;
    final bool askName =
        cfg.hasSupabaseCredentials &&
        auth.sessionError == null &&
        user != null;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.divider),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[c.accent, Color.lerp(c.accent, Colors.blue, 0.3)!],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.checklist_rtl_rounded,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Shared Todo',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ortak listelerini yönet',
            style: TextStyle(color: c.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 28),
          if (hasError) ...<Widget>[
            Text(
              !cfg.hasSupabaseCredentials
                  ? 'Backend yapılandırılmadı.\n(--dart-define SUPABASE_URL ve SUPABASE_ANON_KEY)'
                  : auth.sessionError ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
            if (cfg.hasSupabaseCredentials) ...<Widget>[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar dene'),
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                ),
              ),
            ],
          ],
          if (loading) CircularProgressIndicator(color: c.accent),
          if (askName) ...<Widget>[
            Text(
              'Görünen adın ne olsun?',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ortak listelerde bu isimle görünürsün.',
              style: TextStyle(color: c.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: TextStyle(color: c.textPrimary),
              decoration: InputDecoration(
                hintText: 'ör. Ayşe',
                hintStyle: TextStyle(color: c.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.accent),
                ),
                errorText: nameError,
              ),
              onSubmitted: (_) => onSaveName(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: savingName ? null : onSaveName,
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: savingName
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Devam et'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
