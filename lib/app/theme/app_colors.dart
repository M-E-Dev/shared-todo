import 'package:flutter/material.dart';

/// Fallback / static renk sabitleri.
/// Dinamik tema için [AppThemePreset] kullanın; bu sınıf yalnızca
/// const bağlamları ve pushed route'lar için yedek olarak vardır.
abstract final class AppColors {
  static const Color bg = Color(0xFFF0F7FF);
  static const Color card = Colors.white;
  static const Color accent = Color(0xFF2563EB);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color divider = Color(0xFFE2E8F0);
}
