import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/shared_list.dart';
import '../domain/todo_item.dart';
import 'list_settings_dialog.dart';
import '../../../app/theme/app_colors.dart';

/// Tek listenin detay ekranı: görevler, sıralama, bildirim prompt.
class ListDetailScreen extends StatefulWidget {
  const ListDetailScreen({
    required this.list,
    required this.onListUpdated,
    this.pendingNotifyCount = 0,
    super.key,
  });

  final SharedList list;
  final ValueChanged<SharedList> onListUpdated;

  /// Ana ekrandan geçilen: kullanıcı son ziyaretten bu yana kaç yeni todo birikmiş.
  final int pendingNotifyCount;

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

final class _ListDetailScreenState extends State<ListDetailScreen> {
  late SharedList _list;
  List<TodoItem> _items = <TodoItem>[];
  bool _busy = false;
  final TextEditingController _addCtrl = TextEditingController();
  DateTime? _selectedDueDate;

  int _pendingNotifyCount = 0;
  Timer? _notifyDebounce;

  @override
  void initState() {
    super.initState();
    _list = widget.list;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _reload();
      // Biriken bildirimler varsa, yükleme bittikten sonra sor.
      if (mounted && widget.pendingNotifyCount > 0) {
        _showNotifyPrompt(widget.pendingNotifyCount, fromBadge: true);
      }
    });
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    _notifyDebounce?.cancel();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      builder: (BuildContext ctx, Widget? child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.accent,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedDueDate = picked);
    }
  }

  void _clearDueDate() => setState(() => _selectedDueDate = null);

  List<TodoItem> _sorted(List<TodoItem> raw) {
    final copy = List<TodoItem>.from(raw);
    switch (_list.sortDirection) {
      case ListSortDirection.newestFirst:
        copy.sort((TodoItem a, TodoItem b) => b.createdAt.compareTo(a.createdAt));
      case ListSortDirection.oldestFirst:
        copy.sort((TodoItem a, TodoItem b) => a.createdAt.compareTo(b.createdAt));
      case ListSortDirection.titleAsc:
        copy.sort(
          (TodoItem a, TodoItem b) =>
              a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
    }
    return copy;
  }

  Future<void> _reload() async {
    if (!mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final raw = await AppScope.read(context)
          .todoRepository
          .fetchTodos(listId: _list.id);
      if (!mounted) {
        return;
      }
      setState(() => _items = _sorted(raw));
    } on AppException catch (e) {
      if (!mounted) {
        return;
      }
      _showSnack(e.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _addTodo() async {
    final title = _addCtrl.text.trim();
    if (title.isEmpty) {
      return;
    }
    try {
      await AppScope.read(context).todoRepository.addTodo(
            listId: _list.id,
            title: title,
            dueDate: _selectedDueDate,
          );
      _addCtrl.clear();
      setState(() => _selectedDueDate = null);
      _pendingNotifyCount++;
      await _reload();
      _scheduleNotifyPrompt();
    } on AppException catch (e) {
      if (!mounted) {
        return;
      }
      _showSnack(e.message);
    }
  }

  void _scheduleNotifyPrompt() {
    _notifyDebounce?.cancel();
    _notifyDebounce = Timer(const Duration(seconds: 3), () {
      if (!mounted || _pendingNotifyCount == 0) {
        return;
      }
      _showNotifyPrompt(_pendingNotifyCount);
      _pendingNotifyCount = 0;
    });
  }

  /// [fromBadge] = true ise rozetten tetiklendi (başkası ekledi mesajı göster).
  /// [fromBadge] = false ise bizzat bu kullanıcı ekledi.
  /// [isReminder] = true ise "hatırlatma" modunda açıldı.
  void _showNotifyPrompt(
    int count, {
    bool fromBadge = false,
    bool isReminder = false,
  }) {
    final String text;
    if (isReminder) {
      text = 'Tüm liste üyelerine hatırlatma gönderilsin mi?';
    } else if (fromBadge) {
      text = count == 1
          ? 'Listede 1 yeni görev var. Diğer üyelere bildirim gönderilsin mi?'
          : 'Listede $count yeni görev var. Diğer üyelere bildirim gönderilsin mi?';
    } else {
      text = count == 1
          ? '1 yeni görev eklendi.'
          : '$count yeni görev eklendi.';
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      builder: (BuildContext ctx) {
        return _NotifySheet(
          message: text,
          sendLabel: isReminder ? 'Hatırlatma gönder' : 'Bildirim gönder',
          onSend: () {
            Navigator.of(ctx).pop();
            _showSnack(
              isReminder ? 'Hatırlatma gönderildi ✓' : 'Bildirim gönderildi ✓',
            );
          },
          onSkip: () => Navigator.of(ctx).pop(),
        );
      },
    );
  }

  Future<void> _toggle(TodoItem item, bool completed) async {
    try {
      await AppScope.read(context)
          .todoRepository
          .setCompleted(todoId: item.id, completed: completed);
      await _reload();
    } on AppException catch (e) {
      if (!mounted) {
        return;
      }
      _showSnack(e.message);
    }
  }

  Future<void> _delete(TodoItem item) async {
    try {
      await AppScope.read(context)
          .todoRepository
          .deleteTodo(todoId: item.id);
      await _reload();
    } on AppException catch (e) {
      if (!mounted) {
        return;
      }
      _showSnack(e.message);
    }
  }

  Future<void> _openSettings() async {
    final updated = await showDialog<SharedList>(
      context: context,
      builder: (_) => ListSettingsDialog(list: _list),
    );
    if (updated == null || !mounted) {
      return;
    }
    setState(() {
      _list = updated;
      _items = _sorted(_items);
    });
    widget.onListUpdated(updated);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = _list.color;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              AppColors.bg,
              Color.lerp(AppColors.bg, accent, 0.06)!,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColors.textPrimary,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        _list.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Sıralama göstergesi
                    _SortChip(
                      label: _list.sortDirection.label,
                      onTap: _openSettings,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.tune_rounded,
                        color: AppColors.textSecondary,
                      ),
                      tooltip: 'Ayarlar',
                      onPressed: _openSettings,
                    ),
                    // Üç nokta menüsü — hatırlatma vb.
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: AppColors.textSecondary,
                      ),
                      onSelected: (String value) {
                        if (value == 'remind') {
                          _showNotifyPrompt(0, isReminder: true);
                        }
                      },
                      itemBuilder: (_) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'remind',
                          child: Row(
                            children: <Widget>[
                              Icon(
                                Icons.notifications_active_outlined,
                                size: 18,
                              ),
                              SizedBox(width: 10),
                              Text('Tüm üyelere hatırlat'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Görev ekleme
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _GlassInputRow(
                  controller: _addCtrl,
                  busy: _busy,
                  accent: accent,
                  selectedDueDate: _selectedDueDate,
                  onAdd: _addTodo,
                  onPickDate: _pickDueDate,
                  onClearDate: _clearDueDate,
                ),
              ),
              const SizedBox(height: 12),
              // Liste
              Expanded(
                child: _busy && _items.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : RefreshIndicator(
                        onRefresh: _reload,
                        child: _items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const <Widget>[
                        SizedBox(height: 80),
                        Center(
                          child: Text(
                            'Bu listede henüz görev yok.\nYukarıdan ekleyebilirsin.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 80),
                                itemCount: _items.length,
                                itemBuilder:
                                    (BuildContext context, int index) {
                                  final TodoItem item = _items[index];
                                  return _TodoTile(
                                    key: ValueKey<String>(item.id),
                                    item: item,
                                    accent: accent,
                                    busy: _busy,
                                    onToggle: _toggle,
                                    onDelete: _delete,
                                  );
                                },
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Alt bileşenler
// ---------------------------------------------------------------------------

class _SortChip extends StatelessWidget {
  const _SortChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.sort,
              size: 14,
              color: AppColors.accent,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassInputRow extends StatelessWidget {
  const _GlassInputRow({
    required this.controller,
    required this.busy,
    required this.accent,
    required this.onAdd,
    required this.onPickDate,
    required this.onClearDate,
    this.selectedDueDate,
  });

  final TextEditingController controller;
  final bool busy;
  final Color accent;
  final DateTime? selectedDueDate;
  final VoidCallback onAdd;
  final VoidCallback onPickDate;
  final VoidCallback onClearDate;

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Yeni görev ekle…',
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              // Tarih seçici butonu
              IconButton(
                icon: Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: selectedDueDate != null
                      ? accent
                      : AppColors.textSecondary.withValues(alpha: 0.5),
                ),
                tooltip: 'Son tarih seç',
                onPressed: onPickDate,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: busy ? null : onAdd,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Ekle'),
              ),
            ],
          ),
          // Seçili tarih chip'i
          if (selectedDueDate != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.event_rounded,
                          size: 13,
                          color: accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _fmtDate(selectedDueDate!),
                          style: TextStyle(
                            fontSize: 12,
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: onClearDate,
                          child: Icon(
                            Icons.close_rounded,
                            size: 13,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TodoTile extends StatelessWidget {
  const _TodoTile({
    required this.item,
    required this.accent,
    required this.busy,
    required this.onToggle,
    required this.onDelete,
    super.key,
  });

  final TodoItem item;
  final Color accent;
  final bool busy;
  final Future<void> Function(TodoItem, bool) onToggle;
  final Future<void> Function(TodoItem) onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey<String>('d_${item.id}'),
        direction: DismissDirection.endToStart,
        background: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            color: Colors.red.withValues(alpha: 0.7),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
        ),
        onDismissed: (_) => unawaited(onDelete(item)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: CheckboxListTile(
                value: item.completed,
                onChanged: busy
                    ? null
                    : (bool? v) => unawaited(onToggle(item, v ?? false)),
                activeColor: accent,
                checkColor: Colors.white,
                title: Text(
                  item.title,
                  style: TextStyle(
                    color: item.completed
                        ? AppColors.textSecondary.withValues(alpha: 0.5)
                        : AppColors.textPrimary,
                    decoration: item.completed
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                subtitle: item.dueDate != null
                    ? _DueDateBadge(item: item, accent: accent)
                    : null,
                dense: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Due date badge
// ---------------------------------------------------------------------------

class _DueDateBadge extends StatelessWidget {
  const _DueDateBadge({required this.item, required this.accent});

  final TodoItem item;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final int? days = item.dueDaysFromNow;
    final Color badgeColor = days == null
        ? AppColors.textSecondary
        : days < 0
            ? const Color(0xFFDC2626)
            : days <= 2
                ? const Color(0xFFEA580C)
                : days <= 7
                    ? const Color(0xFFD97706)
                    : AppColors.textSecondary;

    final String label = days == null
        ? ''
        : days < 0
            ? '${(-days)} gün geçti'
            : days == 0
                ? 'Bugün'
                : days == 1
                    ? 'Yarın'
                    : '$days gün kaldı';

    final d = item.dueDate!;
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.event_rounded, size: 12, color: badgeColor),
        const SizedBox(width: 3),
        Text(
          '$dateStr · $label',
          style: TextStyle(
            fontSize: 11,
            color: badgeColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Bildirim bottom sheet.
class _NotifySheet extends StatelessWidget {
  const _NotifySheet({
    required this.message,
    required this.onSend,
    required this.onSkip,
    this.sendLabel = 'Bildirim gönder',
  });

  final String message;
  final VoidCallback onSend;
  final VoidCallback onSkip;
  final String sendLabel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Icon(
              Icons.notifications_outlined,
              color: AppColors.accent,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'Diğer üyelere bildirim gönderilsin mi?',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSkip,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.divider),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Geç'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onSend,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text(sendLabel),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
