import 'package:flutter/material.dart';

/// Renk teması — hem light hem dark destekler.
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
  bool get isCustom => id == 'custom';

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

  /// Aksanı verilen renge göre türetilmiş açık tema oluştur.
  factory AppThemePreset.lightFromAccent(Color accent) {
    final HSLColor hsl = HSLColor.fromColor(accent);
    return AppThemePreset(
      id: 'custom',
      name: 'Özel',
      emoji: '🎨',
      bg: hsl.withLightness(0.97).withSaturation(0.30).toColor(),
      card: Colors.white,
      accent: accent,
      textPrimary: const Color(0xFF0F172A),
      textSecondary: const Color(0xFF64748B),
      divider: hsl.withLightness(0.90).withSaturation(0.25).toColor(),
      brightness: Brightness.light,
    );
  }

  /// Aksanı verilen renge göre türetilmiş koyu tema oluştur.
  factory AppThemePreset.darkFromAccent(Color accent) {
    final HSLColor hsl = HSLColor.fromColor(accent);
    return AppThemePreset(
      id: 'custom',
      name: 'Özel (Koyu)',
      emoji: '🎨',
      bg: hsl.withLightness(0.08).withSaturation(0.40).toColor(),
      card: hsl.withLightness(0.14).withSaturation(0.30).toColor(),
      accent: accent,
      textPrimary: const Color(0xFFF1F5F9),
      textSecondary: const Color(0xFF94A3B8),
      divider: hsl.withLightness(0.22).withSaturation(0.20).toColor(),
      brightness: Brightness.dark,
    );
  }

  // ---------------------------------------------------------------------------
  // Hazır presetler — kategorilere ayrılmış
  // ---------------------------------------------------------------------------

  // Açık tonlar — soft ve ferah
  static const AppThemePreset skyBlue = AppThemePreset(
    id: 'sky_blue', name: 'Gökyüzü', emoji: '🔵',
    bg: Color(0xFFF0F7FF), card: Colors.white, accent: Color(0xFF2563EB),
    textPrimary: Color(0xFF0F172A), textSecondary: Color(0xFF64748B),
    divider: Color(0xFFE2E8F0), brightness: Brightness.light,
  );

  static const AppThemePreset navy = AppThemePreset(
    id: 'navy', name: 'Lacivert', emoji: '⚓',
    bg: Color(0xFFEEF2FF), card: Colors.white, accent: Color(0xFF1E3A8A),
    textPrimary: Color(0xFF0F172A), textSecondary: Color(0xFF475569),
    divider: Color(0xFFE0E7FF), brightness: Brightness.light,
  );

  static const AppThemePreset mint = AppThemePreset(
    id: 'mint', name: 'Nane', emoji: '🌿',
    bg: Color(0xFFF0FDF4), card: Colors.white, accent: Color(0xFF16A34A),
    textPrimary: Color(0xFF0F172A), textSecondary: Color(0xFF64748B),
    divider: Color(0xFFDCFCE7), brightness: Brightness.light,
  );

  static const AppThemePreset emerald = AppThemePreset(
    id: 'emerald', name: 'Zümrüt', emoji: '💚',
    bg: Color(0xFFECFDF5), card: Colors.white, accent: Color(0xFF059669),
    textPrimary: Color(0xFF064E3B), textSecondary: Color(0xFF6B7280),
    divider: Color(0xFFD1FAE5), brightness: Brightness.light,
  );

  static const AppThemePreset rose = AppThemePreset(
    id: 'rose', name: 'Gül', emoji: '🌹',
    bg: Color(0xFFFFF1F2), card: Colors.white, accent: Color(0xFFE11D48),
    textPrimary: Color(0xFF0F172A), textSecondary: Color(0xFF64748B),
    divider: Color(0xFFFFE4E6), brightness: Brightness.light,
  );

  static const AppThemePreset pink = AppThemePreset(
    id: 'pink', name: 'Pembe', emoji: '🌸',
    bg: Color(0xFFFDF2F8), card: Colors.white, accent: Color(0xFFDB2777),
    textPrimary: Color(0xFF0F172A), textSecondary: Color(0xFF64748B),
    divider: Color(0xFFFCE7F3), brightness: Brightness.light,
  );

  static const AppThemePreset lavender = AppThemePreset(
    id: 'lavender', name: 'Lavanta', emoji: '💜',
    bg: Color(0xFFFAF5FF), card: Colors.white, accent: Color(0xFF7C3AED),
    textPrimary: Color(0xFF0F172A), textSecondary: Color(0xFF64748B),
    divider: Color(0xFFEDE9FE), brightness: Brightness.light,
  );

  static const AppThemePreset peach = AppThemePreset(
    id: 'peach', name: 'Şeftali', emoji: '🍑',
    bg: Color(0xFFFFF7ED), card: Colors.white, accent: Color(0xFFEA580C),
    textPrimary: Color(0xFF0F172A), textSecondary: Color(0xFF64748B),
    divider: Color(0xFFFFEDD5), brightness: Brightness.light,
  );

  static const AppThemePreset coral = AppThemePreset(
    id: 'coral', name: 'Mercan', emoji: '🐠',
    bg: Color(0xFFFFF5F5), card: Colors.white, accent: Color(0xFFF43F5E),
    textPrimary: Color(0xFF0F172A), textSecondary: Color(0xFF64748B),
    divider: Color(0xFFFFE4E6), brightness: Brightness.light,
  );

  static const AppThemePreset teal = AppThemePreset(
    id: 'teal', name: 'Deniz', emoji: '🩵',
    bg: Color(0xFFF0FDFA), card: Colors.white, accent: Color(0xFF0D9488),
    textPrimary: Color(0xFF0F172A), textSecondary: Color(0xFF64748B),
    divider: Color(0xFFCCFBF1), brightness: Brightness.light,
  );

  static const AppThemePreset sand = AppThemePreset(
    id: 'sand', name: 'Kum', emoji: '🏜️',
    bg: Color(0xFFFEFCE8), card: Colors.white, accent: Color(0xFFCA8A04),
    textPrimary: Color(0xFF1C1917), textSecondary: Color(0xFF78716C),
    divider: Color(0xFFFEF3C7), brightness: Brightness.light,
  );

  static const AppThemePreset slate = AppThemePreset(
    id: 'slate', name: 'Sade', emoji: '⚪',
    bg: Color(0xFFF8FAFC), card: Colors.white, accent: Color(0xFF475569),
    textPrimary: Color(0xFF0F172A), textSecondary: Color(0xFF64748B),
    divider: Color(0xFFE2E8F0), brightness: Brightness.light,
  );

  // Koyu tonlar — derin ve doygun
  static const AppThemePreset darkBlue = AppThemePreset(
    id: 'dark_blue', name: 'Gece Mavisi', emoji: '🌙',
    bg: Color(0xFF0F172A), card: Color(0xFF1E293B), accent: Color(0xFF60A5FA),
    textPrimary: Color(0xFFF1F5F9), textSecondary: Color(0xFF94A3B8),
    divider: Color(0xFF334155), brightness: Brightness.dark,
  );

  static const AppThemePreset darkNavy = AppThemePreset(
    id: 'dark_navy', name: 'Derin Lacivert', emoji: '🌌',
    bg: Color(0xFF0C1222), card: Color(0xFF131A2E), accent: Color(0xFF818CF8),
    textPrimary: Color(0xFFE0E7FF), textSecondary: Color(0xFF94A3B8),
    divider: Color(0xFF1E293B), brightness: Brightness.dark,
  );

  static const AppThemePreset darkGreen = AppThemePreset(
    id: 'dark_green', name: 'Orman', emoji: '🌲',
    bg: Color(0xFF052E16), card: Color(0xFF14532D), accent: Color(0xFF4ADE80),
    textPrimary: Color(0xFFF0FDF4), textSecondary: Color(0xFF86EFAC),
    divider: Color(0xFF166534), brightness: Brightness.dark,
  );

  static const AppThemePreset darkPurple = AppThemePreset(
    id: 'dark_purple', name: 'Mor Gece', emoji: '🔮',
    bg: Color(0xFF1A0B2E), card: Color(0xFF2D1B47), accent: Color(0xFFA855F7),
    textPrimary: Color(0xFFFAF5FF), textSecondary: Color(0xFFD8B4FE),
    divider: Color(0xFF4C1D95), brightness: Brightness.dark,
  );

  static const AppThemePreset darkRose = AppThemePreset(
    id: 'dark_rose', name: 'Gül Gecesi', emoji: '🌹',
    bg: Color(0xFF1A0B0F), card: Color(0xFF2D1218), accent: Color(0xFFFB7185),
    textPrimary: Color(0xFFFFE4E6), textSecondary: Color(0xFFFDA4AF),
    divider: Color(0xFF4C0519), brightness: Brightness.dark,
  );

  static const AppThemePreset darkSlate = AppThemePreset(
    id: 'dark_slate', name: 'Karbon', emoji: '⬛',
    bg: Color(0xFF0F0F12), card: Color(0xFF1A1A20), accent: Color(0xFF94A3B8),
    textPrimary: Color(0xFFF1F5F9), textSecondary: Color(0xFF94A3B8),
    divider: Color(0xFF2A2A33), brightness: Brightness.dark,
  );

  static const AppThemePreset darkTeal = AppThemePreset(
    id: 'dark_teal', name: 'Derin Deniz', emoji: '🌊',
    bg: Color(0xFF042F2E), card: Color(0xFF134E4A), accent: Color(0xFF2DD4BF),
    textPrimary: Color(0xFFF0FDFA), textSecondary: Color(0xFF99F6E4),
    divider: Color(0xFF115E59), brightness: Brightness.dark,
  );

  // Tüm hazır temalar
  static const List<AppThemePreset> all = <AppThemePreset>[
    // light
    skyBlue, navy, mint, emerald, rose, pink, lavender, peach, coral, teal,
    sand, slate,
    // dark
    darkBlue, darkNavy, darkGreen, darkPurple, darkRose, darkSlate, darkTeal,
  ];

  static AppThemePreset? byId(String id) {
    for (final AppThemePreset p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is AppThemePreset &&
      other.id == id &&
      other.accent == accent &&
      other.brightness == brightness;

  @override
  int get hashCode => Object.hash(id, accent, brightness);
}
