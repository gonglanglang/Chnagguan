import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  static const String appName = '过关啦';
  static const String fallbackVersion = '1.0.13';
  static const int fallbackVersionCode = 113;

  static const String prodOrigin = 'http://47.107.94.90';
  static const String localOrigin = 'http://localhost:8080';

  static const String _envApiBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Active base URL including `/api`, e.g. `http://localhost:8080/api`.
  static String get defaultApiBaseUrl {
    if (_envApiBase.trim().isNotEmpty) {
      return _normalizeBaseUrl(_envApiBase);
    }
    if (kIsWeb) {
      final host = Uri.base.host.toLowerCase();
      if (host == 'localhost' || host == '127.0.0.1') {
        return '$localOrigin/api';
      }
      if (Uri.base.hasScheme && Uri.base.host.isNotEmpty) {
        return '${Uri.base.origin}/api';
      }
      return '$localOrigin/api';
    }
    return kReleaseMode ? '$prodOrigin/api' : '$localOrigin/api';
  }

  static String get defaultOrigin {
    final base = defaultApiBaseUrl;
    if (base.endsWith('/api')) {
      return base.substring(0, base.length - 4);
    }
    return base;
  }

  static String resolveAbsoluteUrl(String? rawUrl, {String? customBaseUrl}) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return '';
    final url = rawUrl.trim();
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    final base = _normalizeBaseUrl(customBaseUrl ?? defaultApiBaseUrl);
    final origin = base.endsWith('/api')
        ? base.substring(0, base.length - 4)
        : base;
    return url.startsWith('/') ? '$origin$url' : '$origin/$url';
  }

  static String _normalizeBaseUrl(String raw) {
    var trimmed = raw.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}
