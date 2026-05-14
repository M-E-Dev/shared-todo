import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/shared_list.dart';

/// Renk ve sıralama ayarları diyaloğu.
class ListSettingsDialog extends StatefulWidget {
  const ListSettingsDialog({required this.list, super.key});

  final SharedList list;

  @override
  State<ListSettingsDialog> createState() => _ListSettingsDialogState();
}

final class _ListSettingsDialogState extends State<ListSettingsDialog> {
  late Color _selectedColor;
  late ListSortDirection _sortDir;
  late TextEditingController _titleCtrl;
  bool _saving = false;

  static const List<Color> _palette = <Color>[
    Color(0xFF2563EB), // blue-600
    Color(0xFF0EA5E9), // sky-500
    Color(0xFF06B6D4), // cyan-500
    Color(0xFF10B981), // emerald-500
    Color(0xFF22C55E), // green-500
    Color(0xFF84CC16), // lime-500
    Color(0xFFEAB308), // yellow-500
    Color(0xFFF97316), // orange-500
    Color(0xFFEF4444), // red-500
    Color(0xFFEC4899), // pink-500
    Color(0xFF8B5CF6), // violet-500
    Color(0xFF64748B), // slate-500
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.list.color;
    _sortDir = widget.list.sortDirection;
    _titleCtrl = TextEditingController(text: widget.list.title);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated =
          await AppScope.read(context).sharedListRepository.updateListSettings(
                listId: widget.list.id,
                title: _titleCtrl.text.trim(),
                colorHex: SharedList.colorToHex(_selectedColor),
                sortDirection: _sortDir,
              );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(updated);
    } on AppException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Liste ayarları'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Liste adı',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Renk', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _palette.map((Color c) {
                final bool selected = c == _selectedColor;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c,
                      border: Border.all(
                        color: selected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: selected
                          ? <BoxShadow>[
                              BoxShadow(
                                color: c.withValues(alpha: 0.7),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text('Sıralama', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...ListSortDirection.values.map((ListSortDirection d) {
              return InkWell(
                onTap: () => setState(() => _sortDir = d),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _sortDir == d,
                          shape: const CircleBorder(),
                          onChanged: (_) => setState(() => _sortDir = d),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(d.label),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Kaydet'),
        ),
      ],
    );
  }
}
