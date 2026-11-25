import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:skribble/skribble.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../app/app_theme.dart';
import '../core/cache/global_cache.dart';
import '../models/models.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider(this._storage)
      : _serverDefaultTheme = _storage.serverDefaultTheme,
        _isDarkMode = _storage.serverDefaultTheme?.darkMode ?? _storage.isDarkMode,
        _accentHex = _storage.serverDefaultTheme?.themeHex ?? _storage.themeHex,
        _accentName =
            _storage.serverDefaultTheme?.themeName ?? _storage.themeName,
        _uiSkin = AppUiSkin.fromCode(
          _storage.serverDefaultTheme?.uiSkin ?? _storage.uiSkin,
        );

  final GlobalCache _storage;
  AppDefaultTheme? _serverDefaultTheme;
  bool _appliedServerDefaultInSession = false;
  String? _appliedServerVersion;

  bool _isDarkMode;
  String _accentHex;
  String _accentName;
  AppUiSkin _uiSkin;

  bool get isDarkMode => _isDarkMode;
  String get accentHex => _accentHex;
  String get accentName => _accentName;
  Color get accentColor => AppTheme.parseHexColor(_accentHex);
  AppUiSkin get uiSkin => _uiSkin;
  bool get isSkribble => _uiSkin == AppUiSkin.skribble;
  bool get isForui => _uiSkin == AppUiSkin.forui;
  AppDefaultTheme? get serverDefaultTheme => _serverDefaultTheme;

  WelkThemeData get welkTheme => AppTheme.buildWelkTheme(
        isDark: _isDarkMode,
        accent: accentColor,
      );

  WiredThemeData get skribbleTheme => AppTheme.buildSkribbleTheme(
        isDark: _isDarkMode,
        accent: accentColor,
      );

  FThemeData get foruiTheme => AppTheme.buildForuiTheme(
        isDark: _isDarkMode,
        accent: accentColor,
      );

  ThemeData get materialTheme => AppTheme.buildMaterialTheme(
        isDark: _isDarkMode,
        welk: welkTheme,
        uiSkin: _uiSkin,
      );

  /// 同步后台配置的默认主题：
  /// - 每次重新启动进入应用（[isAppLaunch] 或本会话首次同步）均以服务端默认主题为准；
  /// - 本会话期间若后台修改了默认主题导致版本号变化，也会同步生效；
  /// - 同一会话内版本号未变时保留用户在「主题设置」中的临时手动切换体验。
  Future<void> applyServerDefaultTheme(
    AppDefaultTheme serverTheme, {
    bool isAppLaunch = false,
  }) async {
    _serverDefaultTheme = serverTheme;
    await _storage.setServerDefaultTheme(serverTheme);

    final shouldApply = isAppLaunch ||
        !_appliedServerDefaultInSession ||
        (_appliedServerVersion != null &&
            _appliedServerVersion != serverTheme.version);

    if (!shouldApply) return;

    final nextSkin = AppUiSkin.fromCode(serverTheme.uiSkin);
    final nextHex = _normalizeHex(serverTheme.themeHex);
    final nextName = serverTheme.themeName.trim().isEmpty
        ? '默认主题'
        : serverTheme.themeName.trim();
    final nextDark = serverTheme.darkMode;

    final changed = _uiSkin != nextSkin ||
        _accentHex != nextHex ||
        _accentName != nextName ||
        _isDarkMode != nextDark;

    _uiSkin = nextSkin;
    _accentHex = nextHex;
    _accentName = nextName;
    _isDarkMode = nextDark;
    _appliedServerDefaultInSession = true;
    _appliedServerVersion = serverTheme.version;

    await _storage.setUiSkin(_uiSkin.code);
    await _storage.setThemeColor(hex: _accentHex, name: _accentName);
    await _storage.setDarkMode(_isDarkMode);

    if (changed) {
      notifyListeners();
    }
  }

  Future<void> setUiSkin(AppUiSkin skin) async {
    if (_uiSkin == skin) return;
    _uiSkin = skin;
    await _storage.setUiSkin(skin.code);
    notifyListeners();
  }

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
    final normalized = _normalizeHex(hex);
    _accentHex = normalized;
    _accentName = '自定义';
    await _storage.setThemeColor(hex: normalized, name: _accentName);
    notifyListeners();
  }

  Future<void> resetToDefault() async {
    final server = _serverDefaultTheme;
    if (server != null) {
      _uiSkin = AppUiSkin.fromCode(server.uiSkin);
      _accentHex = _normalizeHex(server.themeHex);
      _accentName = server.themeName.trim().isEmpty
          ? '默认主题'
          : server.themeName.trim();
      _isDarkMode = server.darkMode;
    } else {
      final preset = AppTheme.presets.first;
      _isDarkMode = false;
      _accentHex = preset.hex;
      _accentName = preset.name;
      _uiSkin = AppUiSkin.welkui;
    }
    await _storage.setDarkMode(_isDarkMode);
    await _storage.setThemeColor(hex: _accentHex, name: _accentName);
    await _storage.setUiSkin(_uiSkin.code);
    notifyListeners();
  }

  static String _normalizeHex(String hex) {
    var normalized = hex.trim().toUpperCase();
    if (!normalized.startsWith('#')) {
      normalized = '#$normalized';
    }
    if (normalized.length == 4) {
      normalized =
          '#${normalized[1]}${normalized[1]}${normalized[2]}${normalized[2]}${normalized[3]}${normalized[3]}';
    }
    if (!RegExp(r'^#[0-9A-F]{6}$').hasMatch(normalized)) {
      return AppTheme.presets.first.hex;
    }
    return normalized;
  }
}
