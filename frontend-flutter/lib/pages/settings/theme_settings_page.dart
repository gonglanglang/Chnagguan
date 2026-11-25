import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:skribble/skribble.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../../app/app_theme.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/ggl_comic_panel.dart';
import '../../widgets/ggl_feedback.dart';
import '../../widgets/ggl_skin_widgets.dart';

class ThemeSettingsPage extends StatefulWidget {
  const ThemeSettingsPage({super.key});

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  String _customHex = '';

  @override
  void initState() {
    super.initState();
    _customHex = context.read<ThemeProvider>().accentHex;
  }

  Future<void> _openCustomColorDrawer() async {
    final theme = context.read<ThemeProvider>();
    _customHex = theme.accentHex;
    await showGglBottomSheet<void>(
      context: context,
      title: '自定义主题强调色',
      closeLabel: '关闭',
      builder: (drawerCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final previewColor = AppTheme.parseHexColor(
              _customHex,
              fallback: theme.accentColor,
            );
            final isForui = AppTheme.isForui(ctx);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: previewColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isForui
                              ? FTheme.of(ctx).colors.border
                              : WelkTheme.of(ctx).resolveColors(ctx).outline,
                          width: isForui ? 1 : 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GglInput(
                        label: '十六进制色值',
                        value: _customHex,
                        placeholder: '例如: #67C6FF 或 #FFDA57',
                        onChanged: (v) => setModalState(() => _customHex = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GglBlockButton(
                  label: '应用主题色',
                  onPressed: () async {
                    final regex = RegExp(r'^#?([0-9A-Fa-f]{6}|[0-9A-Fa-f]{3})$');
                    if (!regex.hasMatch(_customHex.trim())) {
                      GglFeedback.error(context, '请输入有效的十六进制颜色值');
                      return;
                    }
                    await theme.setCustomHex(_customHex);
                    if (drawerCtx.mounted) Navigator.of(drawerCtx).pop();
                    if (mounted) {
                      GglFeedback.success(context, '自定义主题色已应用');
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleReset() async {
    final theme = context.read<ThemeProvider>();
    final server = theme.serverDefaultTheme;
    final defaultDesc = server != null
        ? '「${AppUiSkin.fromCode(server.uiSkin).name} · ${server.themeName} · ${server.darkMode ? '暗黑' : '浅色'}」'
        : '默认的 WelkUI 天青漫画浅色皮肤';
    final ok = await GglFeedback.confirm(
      context,
      title: '重置为默认主题',
      content: '确定要恢复系统配置的$defaultDesc吗？',
      yesText: '确认重置',
      noText: '取消',
    );
    if (!ok || !mounted) return;
    await theme.resetToDefault();
    if (mounted) {
      GglFeedback.success(context, '已恢复默认皮肤与主题');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final theme = context.watch<ThemeProvider>();
    final isSkribble = theme.isSkribble;
    final isForui = theme.isForui;
    final textColor = isForui ? FTheme.of(context).colors.foreground : colors.ink;
    final serverDefault = theme.serverDefaultTheme;

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: const GglAppBar(
        title: '主题与皮肤设置',
        showBack: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          if (serverDefault != null) ...[
            GglComicPanel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: isForui ? FTheme.of(context).colors.primary : colors.ink,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '当前默认主题：${AppUiSkin.fromCode(serverDefault.uiSkin).name} · '
                      '${serverDefault.themeName} · ${serverDefault.darkMode ? '暗黑' : '浅色'}'
                      '（下次重新进入应用将自动以此为准）',
                      style: TextStyle(
                        color: AppTheme.mutedText(context),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // 1. UI 组件皮肤切换（即刻重渲染整套 UI 库组件）
          const GglSectionLabel(
            title: 'UI 组件皮肤（点击即刻切换）',
            padding: EdgeInsets.fromLTRB(4, 4, 4, 10),
          ),
          for (var i = 0; i < AppUiSkin.values.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _SkinSelectorCard(
              skin: AppUiSkin.values[i],
              selected: theme.uiSkin == AppUiSkin.values[i],
              onTap: () async {
                final target = AppUiSkin.values[i];
                await theme.setUiSkin(target);
                if (context.mounted) {
                  GglFeedback.success(
                    context,
                    '已切换为「${target.name}」UI 组件皮肤',
                  );
                }
              },
            ),
          ],

          // 2. 外观明暗模式
          const GglSectionLabel(title: '外观模式'),
          GglComicPanel(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isForui
                            ? '暗黑极简模式'
                            : (isSkribble ? '暗色手绘模式' : '暗黑漫画模式'),
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        theme.isDarkMode
                            ? (isForui ? 'Forui 深灰护眼暗色画布' : '夜间护眼暗色纸面')
                            : (isForui
                                ? 'Forui 清爽浅色卡片与柔和 1px 边框'
                                : (isSkribble
                                    ? 'Skribble 暖白素描手绘纸'
                                    : '经典明亮漫画暖纸')),
                        style: TextStyle(
                          color: AppTheme.mutedText(context),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GglSwitch(
                  value: theme.isDarkMode,
                  label: theme.isDarkMode ? '已开' : '已关',
                  onChanged: (v) async {
                    await theme.setDarkMode(v);
                    if (context.mounted) {
                      GglFeedback.success(
                        context,
                        '已切换到${v ? '暗黑' : '浅色'}模式',
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          // 3. 主题强调色
          GglSectionLabel(
            title: isForui
                ? 'Forui 现代主题强调色'
                : (isSkribble ? 'Skribble 马克笔强调色' : 'WelkUI 漫画主题色'),
          ),
          GglComicPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final preset in AppTheme.presets)
                      GglPillChip(
                        label: preset.name,
                        selected: theme.accentHex.toUpperCase() ==
                            preset.hex.toUpperCase(),
                        selectedColor: preset.color,
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: preset.color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isForui
                                  ? FTheme.of(context).colors.border
                                  : colors.outline,
                              width: isForui ? 1 : 1.4,
                            ),
                          ),
                        ),
                        onTap: () async {
                          await theme.selectPreset(preset);
                          if (context.mounted) {
                            GglFeedback.success(
                              context,
                              '已切换为「${preset.name}」',
                            );
                          }
                        },
                      ),
                  ],
                ),
                const GglDivider(verticalPadding: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: theme.accentColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isForui
                                    ? FTheme.of(context).colors.border
                                    : colors.outline,
                                width: isForui ? 1 : 1.8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '当前色值：${theme.accentName} (${theme.accentHex})',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 13.2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GglButton(
                      label: '自定义',
                      variant: WelkButtonVariant.secondary,
                      onPressed: _openCustomColorDrawer,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 4. 当前皮肤 UI 组件实时预览
          GglSectionLabel(
            title: isForui
                ? 'Forui (shadcn/ui) 组件实时预览'
                : (isSkribble ? 'Skribble 手绘组件实时预览' : 'WelkUI 组件实时预览'),
          ),
          GglComicPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    GglButton(
                      label: isForui
                          ? 'Forui 主按钮'
                          : (isSkribble ? '手绘主按钮' : '漫画主按钮'),
                      onPressed: () {},
                    ),
                    GglButton(
                      label: '次按钮',
                      variant: WelkButtonVariant.secondary,
                      onPressed: () {},
                    ),
                    GglStatusTag(
                      label: isForui
                          ? 'Forui 皮肤'
                          : (isSkribble ? 'Skribble 皮肤' : 'WelkUI 皮肤'),
                      variant: WelkBadgeVariant.success,
                    ),
                  ],
                ),
                const GglDivider(verticalPadding: 12),
                const GglProgressBar(percent: 0.72),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GglBlockButton(
            label: '恢复系统默认皮肤与主题',
            variant: WelkButtonVariant.secondary,
            onPressed: _handleReset,
          ),
        ],
      ),
    );
  }
}

class _SkinSelectorCard extends StatelessWidget {
  const _SkinSelectorCard({
    required this.skin,
    required this.selected,
    required this.onTap,
  });

  final AppUiSkin skin;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final isAppForui = AppTheme.isForui(context);
    final fColors = FTheme.of(context).colors;
    final wiredPreview = AppTheme.buildSkribbleTheme(
      isDark: colors.isDark,
      accent: colors.accent,
    );

    final Widget previewVisual = switch (skin) {
      AppUiSkin.forui => Container(
          width: 96,
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: colors.isDark ? const Color(0xFF141417) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: colors.isDark
                  ? const Color(0xFF27272A)
                  : const Color(0xFFE4E4E7),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 6,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: colors.isDark
                            ? const Color(0xFF3F3F46)
                            : const Color(0xFFE4E4E7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: 0.72,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colors.accent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      width: 34,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.isDark
                            ? const Color(0xFF27272A)
                            : const Color(0xFFF4F4F5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      AppUiSkin.skribble => WiredThemeScope(
          data: wiredPreview,
          child: Container(
            width: 96,
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: RoughBoxDecoration(
              drawConfig: wiredPreview.drawConfig,
              shape: RoughBoxShape.roundedRectangle,
              borderRadius: BorderRadius.circular(8),
              borderStyle: RoughDrawingStyle(
                width: 1.8,
                color: wiredPreview.borderColor,
              ),
              fillStyle: RoughDrawingStyle(color: wiredPreview.fillColor),
              filler: SolidFiller(FillerConfig.build()),
            ),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: RoughBoxDecoration(
                    drawConfig: wiredPreview.drawConfig,
                    shape: RoughBoxShape.circle,
                    borderStyle: RoughDrawingStyle(
                      width: 1.5,
                      color: wiredPreview.borderColor,
                    ),
                    fillStyle: RoughDrawingStyle(
                      color: wiredPreview.markerColor,
                    ),
                    filler: SolidFiller(FillerConfig.build()),
                  ),
                ),
                const SizedBox(width: 7),
                const Expanded(
                  child: WiredProgress(value: 0.65, height: 11),
                ),
              ],
            ),
          ),
        ),
      AppUiSkin.welkui => Container(
          width: 96,
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: colors.paper,
            borderRadius: GglComicPanel.defaultComicRadius,
            border: Border.all(color: colors.outline, width: 2),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                offset: const Offset(2.5, 2.5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: colors.outline, width: 1.5),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: colors.muted,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: colors.outline, width: 1.4),
                  ),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: 0.65,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.accent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    };

    return GglComicPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      borderColor: selected
          ? (isAppForui ? fColors.primary : colors.accent)
          : null,
      child: Row(
        children: [
          previewVisual,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        skin.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isAppForui ? fColors.foreground : colors.ink,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (selected)
                      const GglStatusTag(
                        label: '当前使用',
                        variant: WelkBadgeVariant.success,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  skin.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.mutedText(context),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
