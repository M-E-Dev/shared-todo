import 'package:flutter/foundation.dart';
import 'app_theme_preset.dart';

/// Aktif renk temasını tutar; değişince UI yeniden çizilir.
final class AppThemeNotifier extends ChangeNotifier {
  AppThemeNotifier([AppThemePreset initial = AppThemePreset.skyBlue])
      : _current = initial;

  AppThemePreset _current;

  AppThemePreset get current => _current;

  void apply(AppThemePreset preset) {
    if (_current == preset) {
      return;
    }
    _current = preset;
    notifyListeners();
  }
}
