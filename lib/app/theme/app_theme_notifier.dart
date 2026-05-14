import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme_preset.dart';

/// Aktif tema + görünüm tercihleri; değişince UI yeniden çizilir ve disk'e yazılır.
final class AppThemeNotifier extends ChangeNotifier {
  AppThemeNotifier._({
    required SharedPreferences prefs,
    required AppThemePreset current,
    required double cardOpacity,
    required bool cardOpacityEnabled,
  })  : _prefs = prefs,
        _current = current,
        _cardOpacity = cardOpacity,
        _cardOpacityEnabled = cardOpacityEnabled;

  static const String _kPresetId = 'theme.preset_id';
  static const String _kCustomAccent = 'theme.custom_accent';
  static const String _kCustomBrightness = 'theme.custom_brightness';
  static const String _kCardOpacity = 'theme.card_opacity';
  static const String _kCardOpacityEnabled = 'theme.card_opacity_enabled';

  static const double defaultCardOpacity = 0.82;

  /// Disk'ten yükle veya varsayılana düş.
  static Future<AppThemeNotifier> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final String? presetId = prefs.getString(_kPresetId);
    AppThemePreset current = AppThemePreset.skyBlue;

    if (presetId == 'custom') {
      final int? accentValue = prefs.getInt(_kCustomAccent);
      final String? brightness = prefs.getString(_kCustomBrightness);
      if (accentValue != null) {
        final Color accent = Color(accentValue);
        current = brightness == 'dark'
            ? AppThemePreset.darkFromAccent(accent)
            : AppThemePreset.lightFromAccent(accent);
      }
    } else if (presetId != null) {
      current = AppThemePreset.byId(presetId) ?? AppThemePreset.skyBlue;
    }

    return AppThemeNotifier._(
      prefs: prefs,
      current: current,
      cardOpacity: prefs.getDouble(_kCardOpacity) ?? defaultCardOpacity,
      cardOpacityEnabled: prefs.getBool(_kCardOpacityEnabled) ?? true,
    );
  }

  final SharedPreferences _prefs;

  AppThemePreset _current;
  double _cardOpacity;
  bool _cardOpacityEnabled;

  AppThemePreset get current => _current;
  double get cardOpacity => _cardOpacity;
  bool get cardOpacityEnabled => _cardOpacityEnabled;

  /// Kart üzerine uygulanacak efektif opaklık (kapalıysa 1.0).
  double get effectiveCardOpacity =>
      _cardOpacityEnabled ? _cardOpacity : 1.0;

  Future<void> applyPreset(AppThemePreset preset) async {
    if (_current == preset) {
      return;
    }
    _current = preset;
    notifyListeners();
    await _prefs.setString(_kPresetId, preset.id);
    if (preset.isCustom) {
      await _prefs.setInt(_kCustomAccent, preset.accent.toARGB32());
      await _prefs.setString(
        _kCustomBrightness,
        preset.isDark ? 'dark' : 'light',
      );
    }
  }

  Future<void> applyCustomAccent(Color accent, {required bool dark}) async {
    final AppThemePreset built = dark
        ? AppThemePreset.darkFromAccent(accent)
        : AppThemePreset.lightFromAccent(accent);
    await applyPreset(built);
  }

  Future<void> setCardOpacity(double value) async {
    final double clamped = value.clamp(0.30, 1.0);
    if ((_cardOpacity - clamped).abs() < 0.001) {
      return;
    }
    _cardOpacity = clamped;
    notifyListeners();
    await _prefs.setDouble(_kCardOpacity, clamped);
  }

  Future<void> setCardOpacityEnabled(bool enabled) async {
    if (_cardOpacityEnabled == enabled) {
      return;
    }
    _cardOpacityEnabled = enabled;
    notifyListeners();
    await _prefs.setBool(_kCardOpacityEnabled, enabled);
  }
}
