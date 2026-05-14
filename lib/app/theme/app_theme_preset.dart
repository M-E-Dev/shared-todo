import 'package:flutter/material.dart';

/// Renk teması verisi (hem light hem dark destekler).
@immutable
final class AppThemePreset {
  const AppThemePreset({
    required this.id,
    required this.name,
    required this.emoji,
    required this.bg,
    required this.card,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.brightness,
  });

  final String id;
  final String name;
  final String emoji;
  final Color bg;
  final Color card;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final Brightness brightness;

  bool get isDark => brightness == Brightness.dark;

  ThemeData get themeData => ThemeData(
        useMaterial3: true,
        brightness: brightness,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme(
          brightness: brightness,
          primary: accent,
          onPrimary: Colors.white,
          secondary: accent,
          onSecondary: Colors.white,
          error: const Color(0xFFDC2626),
          onError: Colors.white,
          surface: card,
          onSurface: textPrimary,
        ),
        cardColor: card,
        dividerColor: divider,
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: card,
          indicatorColor: accent.withValues(alpha: 0.15),
          iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> s) {
            if (s.contains(WidgetState.selected)) {
              return IconThemeData(color: accent);
            }
            return IconThemeData(color: textSecondary);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((Set<WidgetState> s) {
            if (s.contains(WidgetState.selected)) {
              return TextStyle(
                color: accent,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              );
            }
            return TextStyle(color: textSecondary, fontSize: 12);
          }),
        ),
      );

  // ---------------------------------------------------------------------------
  // Presetler
  // ---------------------------------------------------------------------------

  static const AppThemePreset skyBlue = AppThemePreset(
    id: 'sky_blue',
    name: 'Gökyüzü',
    emoji: '🔵',
    bg: Color(0xFFF0F7FF),
    card: Colors.white,
    accent: Color(0xFF2563EB),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    divider: Color(0xFFE2E8F0),
    brightness: Brightness.light,
  );

  static const AppThemePreset mint = AppThemePreset(
    id: 'mint',
    name: 'Nane',
    emoji: '🟢',
    bg: Color(0xFFF0FDF4),
    card: Colors.white,
    accent: Color(0xFF16A34A),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    divider: Color(0xFFDCFCE7),
    brightness: Brightness.light,
  );

  static const AppThemePreset lavender = AppThemePreset(
    id: 'lavender',
    name: 'Lavanta',
    emoji: '🟣',
    bg: Color(0xFFFAF5FF),
    card: Colors.white,
    accent: Color(0xFF7C3AED),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    divider: Color(0xFFEDE9FE),
    brightness: Brightness.light,
  );

  static const AppThemePreset peach = AppThemePreset(
    id: 'peach',
    name: 'Şeftali',
    emoji: '🟠',
    bg: Color(0xFFFFF7ED),
    card: Colors.white,
    accent: Color(0xFFEA580C),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    divider: Color(0xFFFFEDD5),
    brightness: Brightness.light,
  );

  static const AppThemePreset rose = AppThemePreset(
    id: 'rose',
    name: 'Gül',
    emoji: '🌸',
    bg: Color(0xFFFFF1F2),
    card: Colors.white,
    accent: Color(0xFFE11D48),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    divider: Color(0xFFFFE4E6),
    brightness: Brightness.light,
  );

  static const AppThemePreset teal = AppThemePreset(
    id: 'teal',
    name: 'Deniz',
    emoji: '🩵',
    bg: Color(0xFFF0FDFA),
    card: Colors.white,
    accent: Color(0xFF0D9488),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    divider: Color(0xFFCCFBF1),
    brightness: Brightness.light,
  );

  static const AppThemePreset darkBlue = AppThemePreset(
    id: 'dark_blue',
    name: 'Gece Mavisi',
    emoji: '🌙',
    bg: Color(0xFF0F172A),
    card: Color(0xFF1E293B),
    accent: Color(0xFF60A5FA),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    divider: Color(0xFF334155),
    brightness: Brightness.dark,
  );

  static const AppThemePreset darkGreen = AppThemePreset(
    id: 'dark_green',
    name: 'Orman',
    emoji: '🌲',
    bg: Color(0xFF052E16),
    card: Color(0xFF14532D),
    accent: Color(0xFF4ADE80),
    textPrimary: Color(0xFFF0FDF4),
    textSecondary: Color(0xFF86EFAC),
    divider: Color(0xFF166534),
    brightness: Brightness.dark,
  );

  static const AppThemePreset darkPurple = AppThemePreset(
    id: 'dark_purple',
    name: 'Mor Gece',
    emoji: '🔮',
    bg: Color(0xFF1A0B2E),
    card: Color(0xFF2D1B47),
    accent: Color(0xFFA855F7),
    textPrimary: Color(0xFFFAF5FF),
    textSecondary: Color(0xFFD8B4FE),
    divider: Color(0xFF4C1D95),
    brightness: Brightness.dark,
  );

  static const List<AppThemePreset> all = <AppThemePreset>[
    skyBlue,
    mint,
    lavender,
    peach,
    rose,
    teal,
    darkBlue,
    darkGreen,
    darkPurple,
  ];

  @override
  bool operator ==(Object other) =>
      other is AppThemePreset && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
