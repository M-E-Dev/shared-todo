import 'dart:async';
import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/todo_item.dart';
import 'lists_overview.dart' show AppColors;

/// Takvim ekranı: aylık görünüm + seçili güne ait todo'lar.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

final class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusMonth = DateTime.now();
  DateTime _selected = DateTime.now();
  List<TodoItem> _allTodos = <TodoItem>[];
  bool _loading = true;
  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) {
      return;
    }
    setState(() => _loading = true);
    try {
      final todos =
          await AppScope.read(context).todoRepository.fetchTodosWithDueDate();
      if (!mounted) {
        return;
      }
      setState(() => _allTodos = todos);
    } on AppException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(e.message)));
    } on Object catch (_) {
      // sessiz hata
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Yardımcılar
  // ---------------------------------------------------------------------------

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  List<TodoItem> _todosForDay(DateTime day) => _allTodos
      .where((TodoItem t) => t.dueDate != null && _sameDay(t.dueDate!, day))
      .toList();

  Set<int> _daysWithTodos(DateTime month) {
    final Set<int> days = <int>{};
    for (final TodoItem t in _allTodos) {
      final d = t.dueDate;
      if (d != null && _sameMonth(d, month)) {
        days.add(d.day);
      }
    }
    return days;
  }

  Color _dayDotColor(DateTime day) {
    final todos = _todosForDay(day);
    if (todos.isEmpty) {
      return Colors.transparent;
    }
    final bool anyOverdue = todos
        .any((TodoItem t) => (t.dueDaysFromNow ?? 0) < 0 && !t.completed);
    final bool anySoon = todos
        .any((TodoItem t) => (t.dueDaysFromNow ?? 99) <= 2 && !t.completed);
    if (anyOverdue || anySoon) {
      return const Color(0xFFDC2626);
    }
    final bool anyWeek = todos
        .any((TodoItem t) => (t.dueDaysFromNow ?? 99) <= 7 && !t.completed);
    if (anyWeek) {
      return const Color(0xFFD97706);
    }
    return AppColors.accent;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final selected = _todosForDay(_selected);
    final daysWithTodos = _daysWithTodos(_focusMonth);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Başlık
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[
                          Color(0xFF0EA5E9),
                          Color(0xFF10B981),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Takvim',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Son tarihi olan görevler',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_loading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: _load,
                      tooltip: 'Yenile',
                    ),
                ],
              ),
            ),

            // Ay navigasyonu
            _MonthNav(
              focusMonth: _focusMonth,
              onPrev: () => setState(() {
                _focusMonth = DateTime(
                  _focusMonth.year,
                  _focusMonth.month - 1,
                );
              }),
              onNext: () => setState(() {
                _focusMonth = DateTime(
                  _focusMonth.year,
                  _focusMonth.month + 1,
                );
              }),
            ),

            // Takvim ızgarası
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _CalendarGrid(
                focusMonth: _focusMonth,
                selected: _selected,
                daysWithTodos: daysWithTodos,
                dayDotColor: _dayDotColor,
                onDayTap: (DateTime d) => setState(() => _selected = d),
              ),
            ),

            const Divider(height: 1, color: AppColors.divider),

            // Seçili gün başlığı
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                _formatFullDate(_selected),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),

            // Seçili güne ait görevler
            Expanded(
              child: selected.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            Icons.event_available_rounded,
                            size: 40,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Bu gün için görev yok',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: selected.length,
                      itemBuilder: (BuildContext ctx, int i) {
                        return _CalTodoTile(item: selected[i]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFullDate(DateTime d) {
    const List<String> months = <String>[
      '',
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    const List<String> weekdays = <String>[
      '',
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar',
    ];
    return '${weekdays[d.weekday]}, ${d.day} ${months[d.month]} ${d.year}';
  }
}

// ---------------------------------------------------------------------------
// Ay navigasyon çubuğu
// ---------------------------------------------------------------------------

class _MonthNav extends StatelessWidget {
  const _MonthNav({
    required this.focusMonth,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime focusMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  static const List<String> _months = <String>[
    '',
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: AppColors.textSecondary,
            ),
            onPressed: onPrev,
          ),
          Expanded(
            child: Text(
              '${_months[focusMonth.month]} ${focusMonth.year}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Takvim ızgarası
// ---------------------------------------------------------------------------

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.focusMonth,
    required this.selected,
    required this.daysWithTodos,
    required this.dayDotColor,
    required this.onDayTap,
  });

  final DateTime focusMonth;
  final DateTime selected;
  final Set<int> daysWithTodos;
  final Color Function(DateTime) dayDotColor;
  final ValueChanged<DateTime> onDayTap;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final int daysInMonth =
        DateTime(focusMonth.year, focusMonth.month + 1, 0).day;
    final int firstWeekday =
        DateTime(focusMonth.year, focusMonth.month, 1).weekday; // 1=Mon
    final int leadingBlanks = firstWeekday - 1;
    final int totalCells =
        ((leadingBlanks + daysInMonth) / 7).ceil() * 7;

    const List<String> dayLabels = <String>[
      'Pzt',
      'Sal',
      'Çar',
      'Per',
      'Cum',
      'Cmt',
      'Paz',
    ];

    return Column(
      children: <Widget>[
        // Gün başlıkları
        Row(
          children: dayLabels.map((String d) {
            return Expanded(
              child: Text(
                d,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        // Gün hücreleri
        ...List<Widget>.generate(totalCells ~/ 7, (int row) {
          return Row(
            children: List<Widget>.generate(7, (int col) {
              final int cellIdx = row * 7 + col;
              final int dayNum = cellIdx - leadingBlanks + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return const Expanded(child: SizedBox(height: 40));
              }
              final DateTime day = DateTime(
                focusMonth.year,
                focusMonth.month,
                dayNum,
              );
              final bool isSelected = _sameDay(day, selected);
              final bool hasTodos = daysWithTodos.contains(dayNum);
              final bool isToday = _sameDay(day, DateTime.now());
              final Color dotColor =
                  hasTodos ? dayDotColor(day) : Colors.transparent;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onDayTap(day),
                  child: Container(
                    height: 40,
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accent
                          : isToday
                              ? AppColors.accent.withValues(alpha: 0.1)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          '$dayNum',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : isToday
                                    ? AppColors.accent
                                    : AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: isToday || isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (hasTodos)
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white70 : dotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Takvim todo satırı
// ---------------------------------------------------------------------------

class _CalTodoTile extends StatelessWidget {
  const _CalTodoTile({required this.item});

  final TodoItem item;

  @override
  Widget build(BuildContext context) {
    final int? days = item.dueDaysFromNow;
    final Color rowColor = item.completed
        ? Colors.transparent
        : days != null && days < 0
            ? const Color(0xFFDC2626).withValues(alpha: 0.07)
            : days != null && days <= 2
                ? const Color(0xFFEA580C).withValues(alpha: 0.07)
                : days != null && days <= 7
                    ? const Color(0xFFD97706).withValues(alpha: 0.07)
                    : Colors.transparent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: rowColor == Colors.transparent ? Colors.white : rowColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
          ),
        ],
      ),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: item.completed
                ? AppColors.accent.withValues(alpha: 0.8)
                : Colors.transparent,
            border: Border.all(
              color: item.completed
                  ? AppColors.accent
                  : AppColors.textSecondary.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: item.completed
              ? const Icon(Icons.check, color: Colors.white, size: 12)
              : null,
        ),
        title: Text(
          item.title,
          style: TextStyle(
            color: item.completed
                ? AppColors.textSecondary.withValues(alpha: 0.5)
                : AppColors.textPrimary,
            fontSize: 14,
            decoration:
                item.completed ? TextDecoration.lineThrough : TextDecoration.none,
          ),
        ),
        subtitle: days != null
            ? Text(
                days < 0
                    ? '${-days} gün geçti'
                    : days == 0
                        ? 'Bugün'
                        : days == 1
                            ? 'Yarın'
                            : '$days gün kaldı',
                style: TextStyle(
                  fontSize: 11,
                  color: item.completed
                      ? AppColors.textSecondary
                      : days <= 0
                          ? const Color(0xFFDC2626)
                          : days <= 2
                              ? const Color(0xFFEA580C)
                              : days <= 7
                                  ? const Color(0xFFD97706)
                                  : AppColors.textSecondary,
                ),
              )
            : null,
      ),
    );
  }
}
