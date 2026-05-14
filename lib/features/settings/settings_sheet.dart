import 'package:flutter/material.dart';

import '../../app/theme/app_theme_notifier.dart';
import '../../app/theme/app_theme_preset.dart';

/// Genel ayarlar bottom sheet'i — 3 sekme: Hazır, Özel, Görünüm.
class SettingsSheet extends StatefulWidget {
  const SettingsSheet({required this.themeNotifier, super.key});

  final AppThemeNotifier themeNotifier;

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

final class _SettingsSheetState extends State<SettingsSheet>
    with TickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.themeNotifier,
      builder: (BuildContext context, _) {
        final AppThemePreset c = widget.themeNotifier.current;
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.6,
          expand: false,
          builder: (BuildContext _, ScrollController scrollCtrl) {
            return Container(
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: <Widget>[
                  _Header(c: c),
                  TabBar(
                    controller: _tabs,
                    labelColor: c.accent,
                    unselectedLabelColor: c.textSecondary,
                    indicatorColor: c.accent,
                    indicatorWeight: 2.5,
                    dividerColor: c.divider,
                    tabs: const <Tab>[
                      Tab(text: 'Hazır'),
                      Tab(text: 'Özel'),
                      Tab(text: 'Görünüm'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      children: <Widget>[
                        _PresetTab(
                          c: c,
                          themeNotifier: widget.themeNotifier,
                          scrollCtrl: scrollCtrl,
                        ),
                        _CustomTab(
                          c: c,
                          themeNotifier: widget.themeNotifier,
                          scrollCtrl: scrollCtrl,
                        ),
                        _AppearanceTab(
                          c: c,
                          themeNotifier: widget.themeNotifier,
                          scrollCtrl: scrollCtrl,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.c});

  final AppThemePreset c;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Column(
        children: <Widget>[
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: c.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Icon(Icons.settings_rounded, color: c.accent, size: 22),
              const SizedBox(width: 10),
              Text(
                'Ayarlar',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close, color: c.textSecondary, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1: Hazır temalar
// ---------------------------------------------------------------------------

class _PresetTab extends StatelessWidget {
  const _PresetTab({
    required this.c,
    required this.themeNotifier,
    required this.scrollCtrl,
  });

  final AppThemePreset c;
  final AppThemeNotifier themeNotifier;
  final ScrollController scrollCtrl;

  @override
  Widget build(BuildContext context) {
    final List<AppThemePreset> light = AppThemePreset.all
        .where((AppThemePreset p) => !p.isDark)
        .toList();
    final List<AppThemePreset> dark = AppThemePreset.all
        .where((AppThemePreset p) => p.isDark)
        .toList();

    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: <Widget>[
        _SectionLabel(text: 'Açık tonlar', c: c),
        const SizedBox(height: 10),
        _ThemeGrid(presets: light, current: c, themeNotifier: themeNotifier),
        const SizedBox(height: 20),
        _SectionLabel(text: 'Koyu tonlar', c: c),
        const SizedBox(height: 10),
        _ThemeGrid(presets: dark, current: c, themeNotifier: themeNotifier),
      ],
    );
  }
}

class _ThemeGrid extends StatelessWidget {
  const _ThemeGrid({
    required this.presets,
    required this.current,
    required this.themeNotifier,
  });

  final List<AppThemePreset> presets;
  final AppThemePreset current;
  final AppThemeNotifier themeNotifier;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: presets.map((AppThemePreset p) {
        final bool selected = p == current;
        return GestureDetector(
          onTap: () => themeNotifier.applyPreset(p),
          child: _PresetChip(preset: p, selected: selected, current: current),
        );
      }).toList(),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.preset,
    required this.selected,
    required this.current,
  });

  final AppThemePreset preset;
  final bool selected;
  final AppThemePreset current;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: selected
            ? preset.accent.withValues(alpha: 0.15)
            : preset.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? preset.accent : preset.divider,
          width: selected ? 2 : 1,
        ),
        boxShadow: selected
            ? <BoxShadow>[
                BoxShadow(
                  color: preset.accent.withValues(alpha: 0.25),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Renk önizleme: accent + card daireleri
          Stack(
            children: <Widget>[
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: preset.accent,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: preset.card,
                    border: Border.all(color: preset.divider, width: 1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Text(preset.emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            preset.name,
            style: TextStyle(
              color: preset.textPrimary,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          if (selected) ...<Widget>[
            const SizedBox(width: 6),
            Icon(
              Icons.check_circle_rounded,
              color: preset.accent,
              size: 16,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2: Özel renkler
// ---------------------------------------------------------------------------

class _CustomTab extends StatefulWidget {
  const _CustomTab({
    required this.c,
    required this.themeNotifier,
    required this.scrollCtrl,
  });

  final AppThemePreset c;
  final AppThemeNotifier themeNotifier;
  final ScrollController scrollCtrl;

  @override
  State<_CustomTab> createState() => _CustomTabState();
}

final class _CustomTabState extends State<_CustomTab> {
  late Color _picked;
  late bool _dark;

  // Hızlı erişim için zengin renk paleti.
  static const List<Color> _swatches = <Color>[
    Color(0xFFEF4444), // red
    Color(0xFFF97316), // orange
    Color(0xFFF59E0B), // amber
    Color(0xFFEAB308), // yellow
    Color(0xFF84CC16), // lime
    Color(0xFF22C55E), // green
    Color(0xFF10B981), // emerald
    Color(0xFF14B8A6), // teal
    Color(0xFF06B6D4), // cyan
    Color(0xFF0EA5E9), // sky
    Color(0xFF3B82F6), // blue
    Color(0xFF6366F1), // indigo
    Color(0xFF8B5CF6), // violet
    Color(0xFFA855F7), // purple
    Color(0xFFD946EF), // fuchsia
    Color(0xFFEC4899), // pink
    Color(0xFFF43F5E), // rose
    Color(0xFF1E3A8A), // navy
    Color(0xFF0F766E), // dark teal
    Color(0xFF4B5563), // gray
    Color(0xFF78350F), // brown
    Color(0xFF18181B), // black
  ];

  @override
  void initState() {
    super.initState();
    _picked = widget.c.isCustom ? widget.c.accent : const Color(0xFF8B5CF6);
    _dark = widget.c.isDark;
  }

  Future<void> _apply() async {
    await widget.themeNotifier.applyCustomAccent(_picked, dark: _dark);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return ListView(
      controller: widget.scrollCtrl,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: <Widget>[
        _SectionLabel(text: 'Ana renk', c: c),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _swatches.map((Color color) {
            final bool selected = color.toARGB32() == _picked.toARGB32();
            return GestureDetector(
              onTap: () => setState(() => _picked = color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(
                    color: selected ? c.textPrimary : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: selected
                      ? <BoxShadow>[
                          BoxShadow(
                            color: color.withValues(alpha: 0.45),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: selected
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        _SectionLabel(text: 'Arka plan', c: c),
        const SizedBox(height: 8),
        _ToggleRow(
          c: c,
          icon: _dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
          label: _dark ? 'Koyu mod' : 'Açık mod',
          value: _dark,
          onChanged: (bool v) => setState(() => _dark = v),
        ),
        const SizedBox(height: 24),
        // Önizleme
        _SectionLabel(text: 'Önizleme', c: c),
        const SizedBox(height: 10),
        _PreviewCard(accent: _picked, dark: _dark),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _apply,
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('Bu temayı uygula'),
            style: FilledButton.styleFrom(
              backgroundColor: _picked,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.accent, required this.dark});

  final Color accent;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final AppThemePreset p = dark
        ? AppThemePreset.darkFromAccent(accent)
        : AppThemePreset.lightFromAccent(accent);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.divider),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.divider),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: p.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Örnek liste',
                    style: TextStyle(
                      color: p.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '3 görev',
                    style: TextStyle(
                      color: p.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: p.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'A→Z',
                style: TextStyle(
                  color: p.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 3: Görünüm
// ---------------------------------------------------------------------------

class _AppearanceTab extends StatelessWidget {
  const _AppearanceTab({
    required this.c,
    required this.themeNotifier,
    required this.scrollCtrl,
  });

  final AppThemePreset c;
  final AppThemeNotifier themeNotifier;
  final ScrollController scrollCtrl;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: <Widget>[
        _SectionLabel(text: 'Liste kartları', c: c),
        const SizedBox(height: 8),
        _ToggleRow(
          c: c,
          icon: Icons.opacity_rounded,
          label: 'Şeffaflık efekti',
          subtitle: 'Liste kartları arkaplan üzerinde hafif şeffaf görünür.',
          value: themeNotifier.cardOpacityEnabled,
          onChanged: themeNotifier.setCardOpacityEnabled,
        ),
        if (themeNotifier.cardOpacityEnabled) ...<Widget>[
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Icon(
                Icons.water_drop_outlined,
                color: c.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Yoğunluk',
                style: TextStyle(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '%${(themeNotifier.cardOpacity * 100).round()}',
                style: TextStyle(
                  color: c.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: c.accent,
              thumbColor: c.accent,
              inactiveTrackColor: c.divider,
              overlayColor: c.accent.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: themeNotifier.cardOpacity,
              min: 0.30,
              max: 1.00,
              divisions: 14,
              label: '%${(themeNotifier.cardOpacity * 100).round()}',
              onChanged: themeNotifier.setCardOpacity,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Daha şeffaf',
                style: TextStyle(fontSize: 11, color: c.textSecondary),
              ),
              Text(
                'Daha opak',
                style: TextStyle(fontSize: 11, color: c.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Mini önizleme
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.divider),
            ),
            child: Center(
              child: Container(
                width: 160,
                height: 60,
                decoration: BoxDecoration(
                  color: c.card.withValues(
                    alpha: themeNotifier.effectiveCardOpacity,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.divider),
                ),
                child: Center(
                  child: Text(
                    'Kart önizleme',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Divider(color: c.divider, height: 1),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Icon(Icons.info_outline, color: c.textSecondary, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tüm tercihlerin cihazına kaydedilir.',
                style: TextStyle(color: c.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Ortak alt bileşenler
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.c});

  final String text;
  final AppThemePreset c;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: c.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.c,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final AppThemePreset c;
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.divider),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: c.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(color: c.textSecondary, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: c.accent,
          ),
        ],
      ),
    );
  }
}
