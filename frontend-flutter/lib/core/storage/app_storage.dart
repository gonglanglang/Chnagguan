import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/models.dart';

class AppStorage {
  AppStorage._(this._prefs);

  final SharedPreferences _prefs;

  static const String _kAccessToken = 'ggl_access_token';
  static const String _kUserProfile = 'ggl_user_profile';
  static const String _kGuestPassedIds = 'ggl_guest_passed_ids';
  static const String _kRememberedAccount = 'ggl_remembered_account';
  static const String _kDarkMode = 'ggl_dark_mode';
  static const String _kThemeHex = 'ggl_theme_hex';
  static const String _kThemeName = 'ggl_theme_name';
  static const String _kCustomApiBaseUrl = 'ggl_custom_api_base_url';

  static const Set<String> _preservedOnCacheClear = <String>{
    _kAccessToken,
    _kUserProfile,
    _kGuestPassedIds,
    _kRememberedAccount,
    _kDarkMode,
    _kThemeHex,
    _kThemeName,
    _kCustomApiBaseUrl,
  };

  static Future<AppStorage> init() async {
    final prefs = await SharedPreferences.getInstance();
    return AppStorage._(prefs);
  }

  String get accessToken => _prefs.getString(_kAccessToken) ?? '';

  Future<void> setAccessToken(String token) async {
    if (token.isEmpty) {
      await _prefs.remove(_kAccessToken);
    } else {
      await _prefs.setString(_kAccessToken, token);
    }
  }

  AppUserProfile? get cachedProfile {
    final raw = _prefs.getString(_kUserProfile);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AppUserProfile.fromJson(decoded);
      }
    } catch (_) {
      // Ignore corrupt cache
    }
    return null;
  }

  Future<void> setCachedProfile(AppUserProfile? profile) async {
    if (profile == null) {
      await _prefs.remove(_kUserProfile);
    } else {
      await _prefs.setString(_kUserProfile, jsonEncode(profile.toJson()));
    }
  }

  List<int> get guestPassedIds {
    final raw = _prefs.getStringList(_kGuestPassedIds);
    if (raw == null) return <int>[];
    return raw.map(int.tryParse).whereType<int>().toSet().toList()..sort();
  }

  Future<List<int>> saveGuestPassedIds(List<int> ids) async {
    final unique = ids.toSet().toList()..sort();
    await _prefs.setStringList(
      _kGuestPassedIds,
      unique.map((e) => e.toString()).toList(),
    );
    return unique;
  }

  Future<void> clearGuestPassedIds() => _prefs.remove(_kGuestPassedIds);

  String get rememberedAccount => _prefs.getString(_kRememberedAccount) ?? '';

  Future<void> setRememberedAccount(String account) async {
    if (account.trim().isEmpty) {
      await _prefs.remove(_kRememberedAccount);
    } else {
      await _prefs.setString(_kRememberedAccount, account.trim());
    }
  }

  bool get isDarkMode => _prefs.getBool(_kDarkMode) ?? false;

  Future<void> setDarkMode(bool value) => _prefs.setBool(_kDarkMode, value);

  String get themeHex => _prefs.getString(_kThemeHex) ?? '#67C6FF';

  String get themeName => _prefs.getString(_kThemeName) ?? '天青漫画';

  Future<void> setThemeColor({required String hex, required String name}) async {
    await _prefs.setString(_kThemeHex, hex);
    await _prefs.setString(_kThemeName, name);
  }

  String? get customApiBaseUrl {
    final v = _prefs.getString(_kCustomApiBaseUrl);
    return (v != null && v.trim().isNotEmpty) ? v.trim() : null;
  }

  Future<void> setCustomApiBaseUrl(String? url) async {
    if (url == null || url.trim().isEmpty) {
      await _prefs.remove(_kCustomApiBaseUrl);
    } else {
      await _prefs.setString(_kCustomApiBaseUrl, url.trim());
    }
  }

  int estimateCacheBytes() {
    var total = 0;
    for (final key in _prefs.getKeys()) {
      final value = _prefs.get(key);
      total += key.length * 2;
      if (value is String) {
        total += value.length * 2;
      } else if (value is List<String>) {
        for (final item in value) {
          total += item.length * 2;
        }
      } else {
        total += 8;
      }
    }
    return total;
  }

  Future<void> clearTemporaryCache() async {
    for (final key in _prefs.getKeys().toList()) {
      if (!_preservedOnCacheClear.contains(key)) {
        await _prefs.remove(key);
      }
    }
  }
}
