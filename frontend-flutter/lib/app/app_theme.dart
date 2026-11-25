import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
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
  ),
  forui(
    code: 'forui',
    name: 'Forui 现代极简',
    subtitle: 'forui.dev shadcn/ui 风格，1px 细腻边框与通透现代排版',
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
    final normalized = raw?.trim().toLowerCase();
    if (normalized == 'skribble') return AppUiSkin.skribble;
    if (normalized == 'forui') return AppUiSkin.forui;
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
  static const Color foruiLightCanvas = Color(0xFFFAFAFA);
  static const Color foruiDarkCanvas = Color(0xFF09090B);

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

  static FThemeData buildForuiTheme({
    required bool isDark,
    required Color accent,
  }) {
    final base = isDark ? FColors.neutralDark : FColors.neutralLight;
    final primaryFg = accent.computeLuminance() > 0.52
        ? const Color(0xFF09090B)
        : const Color(0xFFFAFAFA);
    final fColors = FColors(
      brightness: base.brightness,
      systemOverlayStyle: base.systemOverlayStyle,
      barrier: base.barrier,
      background: isDark ? foruiDarkCanvas : foruiLightCanvas,
      foreground: base.foreground,
      primary: accent,
      primaryForeground: primaryFg,
      secondary: base.secondary,
      secondaryForeground: base.secondaryForeground,
      muted: base.muted,
      mutedForeground: base.mutedForeground,
      destructive: base.destructive,
      destructiveForeground: base.destructiveForeground,
      error: base.error,
      errorForeground: base.errorForeground,
      card: isDark ? const Color(0xFF141417) : const Color(0xFFFFFFFF),
      border: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
    );
    return FThemeData(
      touch: true,
      debugLabel: isDark ? 'Guoguanla Forui Dark' : 'Guoguanla Forui Light',
      colors: fColors,
    );
  }

  static ThemeData buildMaterialTheme({
    required bool isDark,
    required WelkThemeData welk,
    AppUiSkin uiSkin = AppUiSkin.welkui,
  }) {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final bg = switch (uiSkin) {
      AppUiSkin.forui => isDark ? foruiDarkCanvas : foruiLightCanvas,
      AppUiSkin.skribble => isDark ? skribbleDarkCanvas : skribbleLightCanvas,
      AppUiSkin.welkui => isDark ? darkCanvas : lightCanvas,
    };
    final ink = switch (uiSkin) {
      AppUiSkin.forui =>
        isDark ? const Color(0xFFFAFAFA) : const Color(0xFF09090B),
      _ => isDark ? welk.darkInk : welk.ink,
    };
    final paper = switch (uiSkin) {
      AppUiSkin.forui =>
        isDark ? const Color(0xFF141417) : const Color(0xFFFFFFFF),
      AppUiSkin.skribble =>
        isDark ? const Color(0xFF28252C) : const Color(0xFFFFFDF8),
      AppUiSkin.welkui => isDark ? welk.darkPaper : welk.paper,
    };

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
      dividerColor: uiSkin == AppUiSkin.forui
          ? (isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7))
          : (isDark ? const Color(0xFF45454C) : const Color(0xFFE2DED2)),
    );
  }

  static AppUiSkin uiSkinOf(BuildContext context, {bool listen = true}) {
    try {
      return Provider.of<ThemeProvider>(context, listen: listen).uiSkin;
    } catch (_) {
      return AppUiSkin.welkui;
    }
  }

  static bool isSkribble(BuildContext context, {bool listen = true}) {
    return uiSkinOf(context, listen: listen) == AppUiSkin.skribble;
  }

  static bool isForui(BuildContext context, {bool listen = true}) {
    return uiSkinOf(context, listen: listen) == AppUiSkin.forui;
  }

  static Color pageBackground(BuildContext context) {
    final isDark = WelkTheme.of(context).resolveDarkMode(context);
    final skin = uiSkinOf(context);
    return switch (skin) {
      AppUiSkin.forui => isDark ? foruiDarkCanvas : foruiLightCanvas,
      AppUiSkin.skribble => isDark ? skribbleDarkCanvas : skribbleLightCanvas,
      AppUiSkin.welkui => isDark ? darkCanvas : lightCanvas,
    };
  }

  static Color mutedText(BuildContext context) {
    if (isForui(context)) {
      return FTheme.of(context).colors.mutedForeground;
    }
    final colors = WelkTheme.of(context).resolveColors(context);
    return colors.ink.withValues(alpha: colors.isDark ? 0.68 : 0.62);
  }

  /// 供页眉/底栏/信息条等容器使用，在 Forui 下渲染现代 1px 柔和边框，在 WelkUI 下保留漫画粗描边。
  static BoxDecoration barDecoration(
    BuildContext context, {
    bool topBorder = false,
    bool bottomBorder = false,
  }) {
    if (isForui(context)) {
      final fColors = FTheme.of(context).colors;
      final side = BorderSide(color: fColors.border, width: 1);
      return BoxDecoration(
        color: fColors.card,
        border: Border(
          top: topBorder ? side : BorderSide.none,
          bottom: bottomBorder ? side : BorderSide.none,
        ),
      );
    }
    final colors = WelkTheme.of(context).resolveColors(context);
    final side = BorderSide(color: colors.outline, width: colors.borderWidth);
    return BoxDecoration(
      color: colors.paper,
      border: Border(
        top: topBorder ? side : BorderSide.none,
        bottom: bottomBorder ? side : BorderSide.none,
      ),
    );
  }
}
