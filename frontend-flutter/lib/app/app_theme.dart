import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skribble/skribble.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../providers/theme_provider.dart';

/// 应用全局可热切换的 UI 组件库皮肤。
enum AppUiSkin {
  welkui(
    code: 'welkui',
    name: 'WelkUI 漫画风',
    subtitle: '硬核粗描边与漫画硬阴影组件体系',
  ),
  skribble(
    code: 'skribble',
    name: 'Skribble 手绘风',
    subtitle: 'skribble.dev 手绘素描线稿与暖纸墨迹组件库',
  );

  const AppUiSkin({
    required this.code,
    required this.name,
    required this.subtitle,
  });

  final String code;
  final String name;
  final String subtitle;

  static AppUiSkin fromCode(String? raw) {
    if (raw == 'skribble') return AppUiSkin.skribble;
    return AppUiSkin.welkui;
  }
}

@immutable
class AppThemePreset {
  const AppThemePreset({
    required this.key,
    required this.name,
    required this.hex,
    required this.color,
    required this.hoverColor,
  });

  final String key;
  final String name;
  final String hex;
  final Color color;
  final Color hoverColor;
}

class AppTheme {
  AppTheme._();

  static const List<String> cjkFontFallback = <String>[
    'PingFang SC',
    'Noto Sans SC',
    'Microsoft YaHei',
    'Hiragino Sans GB',
    'sans-serif',
  ];

  static const Color lightCanvas = Color(0xFFF4F1E8);
  static const Color darkCanvas = Color(0xFF1F1F22);
  static const Color skribbleLightCanvas = Color(0xFFFBF8F1);
  static const Color skribbleDarkCanvas = Color(0xFF1C1A1E);

  static const List<AppThemePreset> presets = <AppThemePreset>[
    AppThemePreset(
      key: 'sky',
      name: '天青漫画',
      hex: '#67C6FF',
      color: Color(0xFF67C6FF),
      hoverColor: Color(0xFF4BB6FA),
    ),
    AppThemePreset(
      key: 'comic-yellow',
      name: '元气暖黄',
      hex: '#FFDA57',
      color: Color(0xFFFFDA57),
      hoverColor: Color(0xFFF3C83D),
    ),
    AppThemePreset(
      key: 'mint',
      name: '青岚薄荷',
      hex: '#8DDD9B',
      color: Color(0xFF8DDD9B),
      hoverColor: Color(0xFF69C97B),
    ),
    AppThemePreset(
      key: 'coral',
      name: '活力暖橙',
      hex: '#FFB366',
      color: Color(0xFFFFB366),
      hoverColor: Color(0xFFFF9933),
    ),
    AppThemePreset(
      key: 'lavender',
      name: '丁香淡紫',
      hex: '#C5A3FF',
      color: Color(0xFFC5A3FF),
      hoverColor: Color(0xFFAF85FA),
    ),
  ];

  static Color parseHexColor(String hex, {Color fallback = const Color(0xFF67C6FF)}) {
    var cleaned = hex.trim().replaceAll('#', '');
    if (cleaned.length == 3) {
      cleaned = cleaned.split('').map((c) => '$c$c').join();
    }
    if (cleaned.length != 6) return fallback;
    final parsed = int.tryParse('FF$cleaned', radix: 16);
    if (parsed == null) return fallback;
    return Color(parsed);
  }

  static String toHex(Color color) {
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#${(r + g + b).toUpperCase()}';
  }

  static Color darken(Color color, [double amount = 0.08]) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.15, 0.92))
        .toColor();
  }

  static WelkThemeData buildWelkTheme({
    required bool isDark,
    required Color accent,
  }) {
    return WelkThemeData(
      darkMode: isDark,
      paper: const Color(0xFFFFFDF5),
      muted: const Color(0xFFEFEDE5),
      ink: const Color(0xFF242424),
      darkPaper: const Color(0xFF2B2B2F),
      darkMuted: const Color(0xFF3A3A40),
      darkInk: const Color(0xFFF5F5F5),
      darkOutline: const Color(0xFF0E0E10),
      darkShadow: const Color(0xFF0A0A0C),
      accent: accent,
      accentHover: darken(accent, 0.08),
      info: const Color(0xFF82CAFF),
      infoHover: const Color(0xFF5BB5F5),
      success: const Color(0xFF8DDD9B),
      successHover: const Color(0xFF69C97B),
      warning: const Color(0xFFFFB366),
      warningHover: const Color(0xFFFF9933),
      error: const Color(0xFFFF8A80),
      errorHover: const Color(0xFFF27066),
      focus: const Color(0xFF2563EB),
      borderWidth: 2,
      buttonShadowOffset: const Offset(3, 3),
      cardShadowOffset: const Offset(3, 3),
      switchShadowOffset: const Offset(2, 2),
    );
  }

  static WiredThemeData buildSkribbleTheme({
    required bool isDark,
    required Color accent,
  }) {
    final ink = isDark ? const Color(0xFFF5EFE6) : const Color(0xFF1F1B24);
    final paper = isDark ? const Color(0xFF28252C) : const Color(0xFFFFFDF8);
    final disabled = isDark ? const Color(0xFF9F98A8) : const Color(0xFF6B6574);
    return WiredThemeData(
      borderColor: ink,
      textColor: ink,
      disabledTextColor: disabled,
      fillColor: paper,
      markerColor: accent,
      strokeWidth: 2.2,
      roughnessLevel: WiredRoughness.playful,
      // 显式指定 CJK 优先字体，避免查找未捆绑的 skribble_font_recursive 资源
      fontFamily: cjkFontFallback.first,
    );
  }

  static ThemeData buildMaterialTheme({
    required bool isDark,
    required WelkThemeData welk,
    bool isSkribble = false,
  }) {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final bg = isSkribble
        ? (isDark ? skribbleDarkCanvas : skribbleLightCanvas)
        : (isDark ? darkCanvas : lightCanvas);
    final ink = isDark ? welk.darkInk : welk.ink;
    final paper = isSkribble
        ? (isDark ? const Color(0xFF28252C) : const Color(0xFFFFFDF8))
        : (isDark ? welk.darkPaper : welk.paper);

    final baseText = ThemeData(brightness: brightness).textTheme.apply(
          bodyColor: ink,
          displayColor: ink,
          fontFamilyFallback: cjkFontFallback,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      canvasColor: paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: welk.accent,
        brightness: brightness,
        surface: paper,
      ),
      fontFamilyFallback: cjkFontFallback,
      textTheme: baseText,
      appBarTheme: AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
      ),
      dividerColor: isDark ? const Color(0xFF45454C) : const Color(0xFFE2DED2),
    );
  }

  static bool isSkribble(BuildContext context, {bool listen = true}) {
    try {
      return Provider.of<ThemeProvider>(context, listen: listen).isSkribble;
    } catch (_) {
      return false;
    }
  }

  static Color pageBackground(BuildContext context) {
    final isDark = WelkTheme.of(context).resolveDarkMode(context);
    if (isSkribble(context)) {
      return isDark ? skribbleDarkCanvas : skribbleLightCanvas;
    }
    return isDark ? darkCanvas : lightCanvas;
  }

  static Color mutedText(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    return colors.ink.withValues(alpha: colors.isDark ? 0.68 : 0.62);
  }
}
