import 'package:flutter/material.dart';
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
                          color: WelkTheme.of(ctx).resolveColors(ctx).outline,
                          width: 2,
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
    final ok = await GglFeedback.confirm(
      context,
      title: '重置为默认主题',
      content: '确定要恢复默认的 WelkUI 天青漫画浅色皮肤吗？',
      yesText: '确认重置',
      noText: '取消',
    );
    if (!ok || !mounted) return;
    await context.read<ThemeProvider>().resetToDefault();
    if (mounted) {
      GglFeedback.success(context, '已重置为默认皮肤与主题');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final theme = context.watch<ThemeProvider>();
    final isSkribble = theme.isSkribble;

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: const GglAppBar(
        title: '主题与皮肤设置',
        showBack: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          // 1. UI 组件皮肤切换（即刻重渲染整套 UI 库组件）
          const GglSectionLabel(
            title: 'UI 组件皮肤（点击即刻切换）',
            padding: EdgeInsets.fromLTRB(4, 4, 4, 10),
          ),
          Row(
            children: [
              for (var i = 0; i < AppUiSkin.values.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: _SkinSelectorCard(
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
                ),
              ],
            ],
          ),

          // 2. 外观明暗模式
          const GglSectionLabel(title: '外观模式'),
          GglComicPanel(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSkribble ? '暗色手绘模式' : '暗黑漫画模式',
                      style: TextStyle(
                        color: colors.ink,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      theme.isDarkMode
                          ? '夜间护眼暗色纸面'
                          : (isSkribble ? 'Skribble 暖白素描手绘纸' : '经典明亮漫画暖纸'),
                      style: TextStyle(
                        color: AppTheme.mutedText(context),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
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
            title: isSkribble ? 'Skribble 马克笔强调色' : 'WelkUI 漫画主题色',
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
                            border: Border.all(color: colors.outline, width: 1.4),
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
                              border: Border.all(color: colors.outline, width: 1.8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '当前色值：${theme.accentName} (${theme.accentHex})',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.ink,
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
            title: isSkribble ? 'Skribble 手绘组件实时预览' : 'WelkUI 组件实时预览',
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
                      label: isSkribble ? '手绘主按钮' : '漫画主按钮',
                      onPressed: () {},
                    ),
                    GglButton(
                      label: '次按钮',
                      variant: WelkButtonVariant.secondary,
                      onPressed: () {},
                    ),
                    GglStatusTag(
                      label: isSkribble ? 'Skribble 皮肤' : 'WelkUI 皮肤',
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
            label: '重置为默认皮肤与主题',
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
    final isSkribbleCard = skin == AppUiSkin.skribble;
    final wiredPreview = AppTheme.buildSkribbleTheme(
      isDark: colors.isDark,
      accent: colors.accent,
    );

    final Widget previewVisual = isSkribbleCard
        ? WiredThemeScope(
            data: wiredPreview,
            child: Container(
              height: 44,
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
                    width: 18,
                    height: 18,
                    decoration: RoughBoxDecoration(
                      drawConfig: wiredPreview.drawConfig,
                      shape: RoughBoxShape.circle,
                      borderStyle: RoughDrawingStyle(
                        width: 1.6,
                        color: wiredPreview.borderColor,
                      ),
                      fillStyle: RoughDrawingStyle(
                        color: wiredPreview.markerColor,
                      ),
                      filler: SolidFiller(FillerConfig.build()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: WiredProgress(value: 0.65, height: 12),
                  ),
                ],
              ),
            ),
          )
        : Container(
            height: 44,
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
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: colors.outline, width: 1.6),
                  ),
                ),
                const SizedBox(width: 8),
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
          );

    return GglComicPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      borderColor: selected ? colors.accent : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          previewVisual,
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  skin.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (selected)
                const GglStatusTag(
                  label: '使用中',
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
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
