import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthException, AuthUser;

import '../../../app/app_scope.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme_preset.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/shared_list.dart';
import '../domain/todo_item.dart';
import 'list_detail_screen.dart';
import 'list_settings_dialog.dart';

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

  // Bildirim rozeti: kullanıcı listeyi en son açtığında kaç todo vardı.
  // Refresh sonrası fark > 0 ise kırmızı rozet gösterilir.
  final Map<String, int> _lastSeenCounts = <String, int>{};

  /// listId → kullanıcı görmediği yeni todo sayısı.
  Map<String, int> get _pendingBadges {
    final Map<String, int> result = <String, int>{};
    for (final SharedList list in _lists) {
      final int current = _todosMap[list.id]?.length ?? 0;
      if (!_lastSeenCounts.containsKey(list.id)) {
        continue; // İlk yüklemede rozet yok
      }
      final int diff = current - (_lastSeenCounts[list.id] ?? current);
      if (diff > 0) {
        result[list.id] = diff;
      }
    }
    return result;
  }

  RealtimeChannel? _realtimeChannel;

  // Realtime burst koruması ve yarış kilidi.
  Timer? _refreshDebounce;
  bool _refreshInFlight = false;
  bool _pendingRefresh = false;

  // Sadece belirli listelerin todo'larını tazelemek için bekleyen kümeleme.
  Timer? _partialReloadDebounce;
  final Set<String> _pendingListIds = <String>{};

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
    _refreshDebounce?.cancel();
    _partialReloadDebounce?.cancel();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Veri yükleme — tüm liste + todo verisi tek yerden
  // -----------------------------------------------------------------------

  /// Realtime/UI tarafından tetiklenen debounce'lu tam refresh.
  void _scheduleFullRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 300), () {
      if (_refreshInFlight) {
        _pendingRefresh = true;
      } else {
        unawaited(_refresh());
      }
    });
  }

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }
    if (_refreshInFlight) {
      _pendingRefresh = true;
      return;
    }
    _refreshInFlight = true;
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

      // Rozet: bilinen listeler için son görülen değeri koru, yeniler için "görülmüş" say.
      final Map<String, int> nextSeen = <String, int>{};
      for (final SharedList l in lists) {
        nextSeen[l.id] = _lastSeenCounts[l.id] ?? (map[l.id]?.length ?? 0);
      }
      _lastSeenCounts
        ..clear()
        ..addAll(nextSeen);

      setState(() {
        _lists = lists;
        _todosMap = map;
        _busy = false;
      });
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _busy = false;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _busy = false;
        });
      }
    } finally {
      _refreshInFlight = false;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        _scheduleFullRefresh();
      }
    }
  }

  /// Tek bir listenin todo'larını yeniden çek (tam refresh yapmadan).
  void _scheduleListReload(String listId) {
    _pendingListIds.add(listId);
    _partialReloadDebounce?.cancel();
    _partialReloadDebounce = Timer(const Duration(milliseconds: 250), () {
      final Set<String> ids = Set<String>.from(_pendingListIds);
      _pendingListIds.clear();
      unawaited(_reloadListsTodos(ids));
    });
  }

  Future<void> _reloadListsTodos(Set<String> listIds) async {
    if (!mounted || listIds.isEmpty) {
      return;
    }
    try {
      final scope = AppScope.read(context);
      // Listede artık yok olan id'leri atla (silinmiş olabilir → full refresh yapacağız).
      final Set<String> existing = listIds
          .where((String id) => _lists.any((SharedList l) => l.id == id))
          .toSet();
      if (existing.isEmpty) {
        _scheduleFullRefresh();
        return;
      }
      final List<MapEntry<String, List<TodoItem>>> results = await Future.wait(
        existing.map(
          (String id) async => MapEntry<String, List<TodoItem>>(
            id,
            await scope.todoRepository.fetchTodos(listId: id),
          ),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        for (final MapEntry<String, List<TodoItem>> e in results) {
          final SharedList? list = _lists.cast<SharedList?>().firstWhere(
                (SharedList? l) => l?.id == e.key,
                orElse: () => null,
              );
          if (list != null) {
            _todosMap[e.key] = _sorted(e.value, list.sortDirection);
          }
        }
      });
    } on AppException catch (_) {
      // Realtime tetikli — sessizce geç; bir sonraki refresh düzeltir.
    } on Object catch (_) {
      // sessiz
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
              // Liste meta/ekleme/silme değişimi → debounced full refresh.
              if (mounted) {
                _scheduleFullRefresh();
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'todos',
            callback: (PostgresChangePayload payload) {
              if (!mounted) {
                return;
              }
              // Sadece etkilenen listeyi yeniden yükle (N+1 yerine 1 sorgu).
              final String? listId = _listIdFromPayload(payload);
              if (listId == null) {
                _scheduleFullRefresh();
              } else {
                _scheduleListReload(listId);
              }
            },
          )
          .subscribe();
    } on Object catch (_) {
      // Realtime opsiyonel; bağlantı yoksa sessizce geç.
    }
  }

  String? _listIdFromPayload(PostgresChangePayload payload) {
    final Map<String, dynamic> newRow = payload.newRecord;
    if (newRow.isNotEmpty && newRow['list_id'] is String) {
      return newRow['list_id'] as String;
    }
    final Map<String, dynamic> oldRow = payload.oldRecord;
    if (oldRow.isNotEmpty && oldRow['list_id'] is String) {
      return oldRow['list_id'] as String;
    }
    return null;
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
    // Kaç yeni todo bekliyor?
    final int pendingCount = _pendingBadges[list.id] ?? 0;
    // Rozeti temizle: şu anki sayıyı "görüldü" olarak işaretle.
    setState(() {
      _lastSeenCounts[list.id] = _todosMap[list.id]?.length ?? 0;
    });

    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => ListDetailScreen(
              list: list,
              pendingNotifyCount: pendingCount,
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
                                      badgeCount: _pendingBadges[list.id] ?? 0,
                                      c: c,
                                      cardOpacity: AppScope.read(context)
                                          .themeNotifier
                                          .effectiveCardOpacity,
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
              Text(
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
    required this.badgeCount,
    required this.c,
    required this.cardOpacity,
    required this.onTap,
    required this.onSettings,
    required this.onLongPress,
    super.key,
  });

  final SharedList list;
  final List<TodoItem> todos;
  final int rowCount;
  final int badgeCount; // 0 = rozet yok
  final AppThemePreset c;
  final double cardOpacity; // 0.30 - 1.0
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
          color: c.card.withValues(alpha: cardOpacity),
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
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Bildirim rozeti
                    if (badgeCount > 0)
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '+$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
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
                        color: c.textSecondary.withValues(alpha: 0.6),
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
            Divider(height: 1, thickness: 1, color: c.divider),
            // Todo satırları — tam yükseklikte kaydırılabilir
            Expanded(
              child: todos.isEmpty
                  ? Center(
                      child: Text(
                        'Görev yok — dokun ekle',
                        style: TextStyle(
                          color: c.textSecondary.withValues(alpha: 0.6),
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
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.divider)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.open_in_new_rounded,
                    size: 11,
                    color: c.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Detay',
                    style: TextStyle(
                      fontSize: 11,
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.straighten_rounded,
                    size: 11,
                    color: c.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Bas & boyutlandır',
                    style: TextStyle(
                      fontSize: 11,
                      color: c.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.sort_rounded,
                    size: 11,
                    color: c.textSecondary.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    list.sortDirection.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: c.textSecondary.withValues(alpha: 0.6),
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
    final c = AppScope.read(context).themeNotifier.current;
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
                      : c.textSecondary.withValues(alpha: 0.35),
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
                      ? c.textSecondary.withValues(alpha: 0.45)
                      : c.textPrimary,
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
    final c = AppScope.read(context).themeNotifier.current;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.table_rows_rounded,
                color: c.accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '"$title" — gösterilecek satır',
                  style: TextStyle(
                    color: c.textPrimary,
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
                  style: TextStyle(
                    color: c.accent,
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
                          : c.divider,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Min $_min satır',
                style: TextStyle(
                  fontSize: 11,
                  color: c.textSecondary,
                ),
              ),
              Text(
                'Max $_max satır',
                style: TextStyle(
                  fontSize: 11,
                  color: c.textSecondary,
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
                    side: BorderSide(color: c.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Vazgeç'),
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
    final c = AppScope.read(context).themeNotifier.current;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: <Widget>[
          Icon(Icons.playlist_add_rounded, color: c.accent),
          const SizedBox(width: 8),
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
  const _ErrorBanner({
    required this.message,
    required this.onRetry,
    required this.c,
  });

  final String message;
  final VoidCallback onRetry;
  final AppThemePreset c;

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
                style: TextStyle(
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
  const _EmptyState({required this.onCreate, required this.c});

  final VoidCallback onCreate;
  final AppThemePreset c;

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
                gradient: LinearGradient(
                  colors: <Color>[
                    c.accent,
                    Color.lerp(c.accent, Colors.blue, 0.4)!,
                  ],
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
            Text(
              'Henüz listen yok',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Alttaki + Yeni liste butonuna dokun.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textSecondary,
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
