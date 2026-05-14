import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthException, AuthUser;

import '../../../app/app_scope.dart';
import '../../../app/theme/app_theme_preset.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/shared_list.dart';
import '../domain/todo_item.dart';
import 'list_detail_screen.dart';
import 'list_settings_dialog.dart';

// AppColors — tema renk erişimi için kısayol (deprecated: artık _c(context) kullanıyoruz).
// Diğer dosyalar hâlâ bunu import edebilir; dinamik hale getirildi.
// ignore: avoid_classes_with_only_static_members
abstract final class AppColors {
  static Color bg = const Color(0xFFF0F7FF);
  static Color card = Colors.white;
  static Color accent = const Color(0xFF2563EB);
  static Color textPrimary = const Color(0xFF0F172A);
  static Color textSecondary = const Color(0xFF64748B);
  static Color divider = const Color(0xFFE2E8F0);

  static void updateFrom(AppThemePreset p) {
    bg = p.bg;
    card = p.card;
    accent = p.accent;
    textPrimary = p.textPrimary;
    textSecondary = p.textSecondary;
    divider = p.divider;
  }
}

// ---------------------------------------------------------------------------
// Ana ekran
// ---------------------------------------------------------------------------

class ListsOverview extends StatefulWidget {
  const ListsOverview({
    required this.displayName,
    required this.onSettingsTap,
    super.key,
  });

  final String displayName;
  final VoidCallback onSettingsTap;

  @override
  State<ListsOverview> createState() => _ListsOverviewState();
}

final class _ListsOverviewState extends State<ListsOverview> {
  bool _busy = false;
  String? _error;

  List<SharedList> _lists = <SharedList>[];

  /// listId → o listeye ait todo'lar (tek kaynaktan yönetilir).
  Map<String, List<TodoItem>> _todosMap = <String, List<TodoItem>>{};

  /// Her listenin kaç satır göstereceği (satır sayısı = 1..8).
  final Map<String, int> _rowCounts = <String, int>{};

  static const int _defaultRows = 4;

  int _rowsFor(String id) => _rowCounts[id] ?? _defaultRows;

  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
      _subscribeRealtime();
    });
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Veri yükleme — tüm liste + todo verisi tek yerden
  // -----------------------------------------------------------------------

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final scope = AppScope.read(context);
      final lists = await scope.sharedListRepository.fetchMyLists();
      if (!mounted) {
        return;
      }

      // Tüm listeler için todo'ları paralel çek.
      final List<List<TodoItem>> results = await Future.wait(
        lists.map(
          (SharedList l) =>
              scope.todoRepository.fetchTodos(listId: l.id),
        ),
      );

      if (!mounted) {
        return;
      }

      final map = <String, List<TodoItem>>{};
      for (int i = 0; i < lists.length; i++) {
        map[lists[i].id] = _sorted(results[i], lists[i].sortDirection);
      }

      setState(() {
        _lists = lists;
        _todosMap = map;
      });
    } on AppException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _error = e.message);
    } on Object catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  List<TodoItem> _sorted(List<TodoItem> raw, ListSortDirection dir) {
    final copy = List<TodoItem>.from(raw);
    switch (dir) {
      case ListSortDirection.newestFirst:
        copy.sort(
          (TodoItem a, TodoItem b) => b.createdAt.compareTo(a.createdAt),
        );
      case ListSortDirection.oldestFirst:
        copy.sort(
          (TodoItem a, TodoItem b) => a.createdAt.compareTo(b.createdAt),
        );
      case ListSortDirection.titleAsc:
        copy.sort(
          (TodoItem a, TodoItem b) =>
              a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
    }
    return copy;
  }

  // -----------------------------------------------------------------------
  // Supabase Realtime — tek kanal, lists + todos dinle
  // -----------------------------------------------------------------------

  void _subscribeRealtime() {
    try {
      _realtimeChannel = Supabase.instance.client
          .channel('overview_all')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'lists',
            callback: (PostgresChangePayload _) {
              if (mounted) {
                unawaited(_refresh());
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'todos',
            callback: (PostgresChangePayload _) {
              if (mounted) {
                unawaited(_refresh());
              }
            },
          )
          .subscribe();
    } on Object catch (_) {
      // Realtime opsiyonel; bağlantı yoksa sessizce geç.
    }
  }

  // -----------------------------------------------------------------------
  // Eylemler
  // -----------------------------------------------------------------------

  Future<void> _createList() async {
    final ctrl = TextEditingController();
    String? name;
    try {
      name = await showDialog<String>(
        context: context,
        builder: (BuildContext ctx) => _CreateListDialog(controller: ctrl),
      );
    } finally {
      ctrl.dispose();
    }
    if (name == null || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await AppScope.read(context).sharedListRepository.createList(
            title: name.isEmpty ? 'Yeni liste' : name,
          );
      if (!mounted) {
        return;
      }
      await _refresh();
    } on AppException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openSettings(SharedList list) async {
    final updated = await showDialog<SharedList>(
      context: context,
      builder: (_) => ListSettingsDialog(list: list),
    );
    if (updated == null || !mounted) {
      return;
    }
    await _refresh();
  }

  void _openDetail(SharedList list) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => ListDetailScreen(
              list: list,
              onListUpdated: (SharedList _) {
                if (mounted) {
                  unawaited(_refresh());
                }
              },
            ),
          ),
        )
        .then((_) {
      if (mounted) {
        unawaited(_refresh());
      }
    });
  }

  void _showRowPicker(SharedList list) {
    int current = _rowsFor(list.id);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext ctx2, StateSetter setS) {
            return _RowPickerSheet(
              title: list.title,
              value: current,
              onChanged: (int v) => setS(() => current = v),
              onApply: () {
                setState(() => _rowCounts[list.id] = current);
                Navigator.of(ctx2).pop();
              },
              onCancel: () => Navigator.of(ctx2).pop(),
            );
          },
        );
      },
    );
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final c = AppScope.read(context).themeNotifier.current;
    AppColors.updateFrom(c);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _Header(
                  displayName: widget.displayName,
                  busy: _busy,
                  listCount: _lists.length,
                  onSettings: widget.onSettingsTap,
                  c: c,
                ),
                if (_error != null)
                  _ErrorBanner(message: _error!, onRetry: _refresh, c: c),
                Expanded(
                  child: _busy && _lists.isEmpty
                      ? Center(
                          child: CircularProgressIndicator(color: c.accent),
                        )
                      : _lists.isEmpty
                          ? _EmptyState(onCreate: _createList, c: c)
                          : RefreshIndicator(
                              color: c.accent,
                              onRefresh: _refresh,
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 100),
                                itemCount: _lists.length,
                                itemBuilder: (BuildContext ctx, int i) {
                                  final SharedList list = _lists[i];
                                  final List<TodoItem> todos =
                                      _todosMap[list.id] ?? <TodoItem>[];
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 14),
                                    child: _ListCard(
                                      key: ValueKey<String>(list.id),
                                      list: list,
                                      todos: todos,
                                      rowCount: _rowsFor(list.id),
                                      c: c,
                                      onTap: () => _openDetail(list),
                                      onSettings: () => _openSettings(list),
                                      onLongPress: () =>
                                          _showRowPicker(list),
                                    ),
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
            // Compact FAB — sağ alt
            Positioned(
              right: 16,
              bottom: 16,
              child: _CompactFab(
                busy: _busy,
                accent: c.accent,
                onCreate: _createList,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({
    required this.displayName,
    required this.busy,
    required this.listCount,
    required this.onSettings,
    required this.c,
  });

  final String displayName;
  final bool busy;
  final int listCount;
  final VoidCallback onSettings;
  final AppThemePreset c;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 10),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[c.accent, Color.lerp(c.accent, Colors.blue, 0.4)!],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.checklist_rtl_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Merhaba, $displayName',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  listCount == 0 ? 'Henüz liste yok' : '$listCount liste',
                  style: TextStyle(color: c.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          if (busy)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: c.accent,
              ),
            ),
          IconButton(
            icon: Icon(Icons.settings_rounded, color: c.textSecondary, size: 22),
            onPressed: onSettings,
            tooltip: 'Ayarlar',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compact genişleyen FAB
// ---------------------------------------------------------------------------

class _CompactFab extends StatefulWidget {
  const _CompactFab({
    required this.busy,
    required this.accent,
    required this.onCreate,
  });

  final bool busy;
  final Color accent;
  final VoidCallback onCreate;

  @override
  State<_CompactFab> createState() => _CompactFabState();
}

final class _CompactFabState extends State<_CompactFab> {
  bool _expanded = false;
  Timer? _collapseTimer;

  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }

  void _onTap() {
    if (widget.busy) {
      return;
    }
    if (_expanded) {
      _collapseTimer?.cancel();
      setState(() => _expanded = false);
      widget.onCreate();
      return;
    }
    setState(() => _expanded = true);
    _collapseTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() => _expanded = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOut,
        height: 48,
        width: _expanded ? 148.0 : 48.0,
        decoration: BoxDecoration(
          color: widget.busy
              ? widget.accent.withValues(alpha: 0.5)
              : widget.accent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: widget.accent.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(width: 4),
            const Icon(Icons.add_rounded, color: Colors.white, size: 24),
            if (_expanded) ...<Widget>[
              const SizedBox(width: 6),
              const Text(
                'Yeni liste',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 12),
            ] else
              const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Liste kartı — todo'lar dışarıdan geliyor (saf görüntü widget'ı)
// ---------------------------------------------------------------------------

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.list,
    required this.todos,
    required this.rowCount,
    required this.c,
    required this.onTap,
    required this.onSettings,
    required this.onLongPress,
    super.key,
  });

  final SharedList list;
  final List<TodoItem> todos;
  final int rowCount;
  final AppThemePreset c;
  final VoidCallback onTap;
  final VoidCallback onSettings;
  final VoidCallback onLongPress;

  // Bir satır yüksekliği
  static const double _rowH = 40.0;
  static const double _headerH = 48.0;
  static const double _footerH = 34.0;

  double get _totalHeight => _headerH + rowCount * _rowH + _footerH;

  @override
  Widget build(BuildContext context) {
    final Color accent = list.color;
    final int done = todos.where((TodoItem t) => t.completed).length;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        height: _totalHeight,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: accent.withValues(alpha: 0.10),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
            const BoxShadow(
              color: Color(0x08000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Renkli üst çizgi
            Container(height: 4, color: accent),
            // Başlık
            SizedBox(
              height: _headerH - 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        list.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (todos.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$done/${todos.length}',
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.tune_rounded,
                        color: AppColors.textSecondary.withValues(alpha: 0.6),
                        size: 17,
                      ),
                      onPressed: onSettings,
                      padding: const EdgeInsets.all(6),
                      constraints:
                          const BoxConstraints(minWidth: 30, minHeight: 30),
                      tooltip: 'Ayarlar',
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.divider),
            // Todo satırları — tam yükseklikte kaydırılabilir
            Expanded(
              child: todos.isEmpty
                  ? Center(
                      child: Text(
                        'Görev yok — dokun ekle',
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      itemCount: todos.length,
                      itemBuilder: (BuildContext ctx, int i) {
                        return _MiniTodoRow(
                          item: todos[i],
                          accent: accent,
                          height: _rowH,
                        );
                      },
                    ),
            ),
            // Alt çubuk
            Container(
              height: _footerH,
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.open_in_new_rounded,
                    size: 11,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Detay',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.straighten_rounded,
                    size: 11,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Bas & boyutlandır',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.sort_rounded,
                    size: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    list.sortDirection.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mini todo satırı
// ---------------------------------------------------------------------------

class _MiniTodoRow extends StatelessWidget {
  const _MiniTodoRow({
    required this.item,
    required this.accent,
    required this.height,
  });

  final TodoItem item;
  final Color accent;
  final double height;

  Color? _dueBg() {
    if (item.completed || item.dueDate == null) {
      return null;
    }
    final int days = item.dueDaysFromNow ?? 99;
    if (days <= 2) {
      return const Color(0xFFDC2626).withValues(alpha: 0.08);
    }
    if (days <= 7) {
      return const Color(0xFFD97706).withValues(alpha: 0.08);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final Color? bg = _dueBg();

    return Container(
      height: height,
      color: bg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.completed
                    ? accent.withValues(alpha: 0.9)
                    : Colors.transparent,
                border: Border.all(
                  color: item.completed
                      ? accent
                      : AppColors.textSecondary.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: item.completed
                  ? const Icon(Icons.check, color: Colors.white, size: 10)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: item.completed
                      ? AppColors.textSecondary.withValues(alpha: 0.45)
                      : AppColors.textPrimary,
                  decoration: item.completed
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
            ),
            // Son tarih varsa küçük ikon
            if (item.dueDate != null && !item.completed) ...<Widget>[
              const SizedBox(width: 4),
              Icon(
                Icons.event_rounded,
                size: 12,
                color: (item.dueDaysFromNow ?? 99) <= 2
                    ? const Color(0xFFDC2626)
                    : (item.dueDaysFromNow ?? 99) <= 7
                        ? const Color(0xFFD97706)
                        : AppColors.textSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Satır sayısı seçici (adım adım)
// ---------------------------------------------------------------------------

class _RowPickerSheet extends StatelessWidget {
  const _RowPickerSheet({
    required this.title,
    required this.value,
    required this.onChanged,
    required this.onApply,
    required this.onCancel,
  });

  final String title;
  final int value;
  final ValueChanged<int> onChanged;
  final VoidCallback onApply;
  final VoidCallback onCancel;

  static const int _min = 2;
  static const int _max = 8;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.table_rows_rounded,
                color: AppColors.accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '"$title" — gösterilecek satır',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$value satır',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Adım adım seçici
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List<Widget>.generate(_max - _min + 1, (int i) {
              final int n = _min + i;
              final bool selected = n == value;
              return GestureDetector(
                onTap: () => onChanged(n),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accent
                        : AppColors.accent.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? AppColors.accent
                          : AppColors.divider,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$n',
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Min $_min satır',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'Max $_max satır',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Vazgeç'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onApply,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Uygula'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Yeni liste diyaloğu
// ---------------------------------------------------------------------------

class _CreateListDialog extends StatelessWidget {
  const _CreateListDialog({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Row(
        children: <Widget>[
          Icon(Icons.playlist_add_rounded, color: AppColors.accent),
          SizedBox(width: 8),
          Text('Yeni liste'),
        ],
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'ör. Alışveriş',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.accent),
          ),
        ),
        onSubmitted: (String v) =>
            Navigator.of(context).pop(v.trim()),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Vazgeç',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(controller.text.trim()),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Oluştur'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hata banner
// ---------------------------------------------------------------------------

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFED7D7)),
        ),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.error_outline,
              color: Color(0xFFE53E3E),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFFE53E3E),
                  fontSize: 13,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Boş durum
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF2563EB), Color(0xFF0EA5E9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.checklist_rtl_rounded,
                size: 36,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Henüz listen yok',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Alttaki + Yeni liste butonuna dokun.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
