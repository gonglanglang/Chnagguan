import 'package:flutter/material.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../app/app_theme.dart';
import '../core/storage/app_storage.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider(this._storage)
      : _isDarkMode = _storage.isDarkMode,
        _accentHex = _storage.themeHex,
        _accentName = _storage.themeName;

  final AppStorage _storage;
  bool _isDarkMode;
  String _accentHex;
  String _accentName;

  bool get isDarkMode => _isDarkMode;
  String get accentHex => _accentHex;
  String get accentName => _accentName;
  Color get accentColor => AppTheme.parseHexColor(_accentHex);

  WelkThemeData get welkTheme => AppTheme.buildWelkTheme(
        isDark: _isDarkMode,
        accent: accentColor,
      );

  ThemeData get materialTheme => AppTheme.buildMaterialTheme(
        isDark: _isDarkMode,
        welk: welkTheme,
      );

  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;
    _isDarkMode = value;
    await _storage.setDarkMode(value);
    notifyListeners();
  }

  Future<void> toggleDarkMode() => setDarkMode(!_isDarkMode);

  Future<void> selectPreset(AppThemePreset preset) async {
    _accentHex = preset.hex;
    _accentName = preset.name;
    await _storage.setThemeColor(hex: preset.hex, name: preset.name);
    notifyListeners();
  }

  Future<void> setCustomHex(String hex) async {
    var normalized = hex.trim().toUpperCase();
    if (!normalized.startsWith('#')) {
      normalized = '#$normalized';
    }
    if (normalized.length == 4) {
      normalized =
          '#${normalized[1]}${normalized[1]}${normalized[2]}${normalized[2]}${normalized[3]}${normalized[3]}';
    }
    _accentHex = normalized;
    _accentName = '自定义';
    await _storage.setThemeColor(hex: normalized, name: _accentName);
    notifyListeners();
  }

  Future<void> resetToDefault() async {
    final preset = AppTheme.presets.first;
    _isDarkMode = false;
    _accentHex = preset.hex;
    _accentName = preset.name;
    await _storage.setDarkMode(false);
    await _storage.setThemeColor(hex: preset.hex, name: preset.name);
    notifyListeners();
  }
}
