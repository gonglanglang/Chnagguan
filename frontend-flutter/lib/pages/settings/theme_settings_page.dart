import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../../app/app_theme.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/ggl_comic_panel.dart';
import '../../widgets/ggl_feedback.dart';

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
    await showWelkDrawer<void>(
      context: context,
      position: WelkDrawerPosition.bottom,
      closeOnTapOutside: true,
      builder: (drawerCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final previewColor = AppTheme.parseHexColor(
              _customHex,
              fallback: theme.accentColor,
            );
            return WelkDrawer(
              title: const Text('自定义漫画主题色'),
              closeLabel: '关闭',
              onClose: () => Navigator.of(drawerCtx).pop(),
              child: Column(
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
                            color: WelkTheme.of(ctx)
                                .resolveColors(ctx)
                                .outline,
                            width: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: WelkInput(
                          label: '十六进制色值',
                          value: _customHex,
                          placeholder: '例如: #67C6FF 或 #FFDA57',
                          onChanged: (v) =>
                              setModalState(() => _customHex = v),
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
              ),
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
      content: '确定要恢复默认的天青漫画浅色主题吗？',
      yesText: '确认重置',
      noText: '取消',
    );
    if (!ok || !mounted) return;
    await context.read<ThemeProvider>().resetToDefault();
    if (mounted) {
      GglFeedback.success(context, '已重置为默认主题');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: WelkAppBar(
        title: '主题设置',
        centerTitle: true,
        layout: WelkAppBarLayout.comicStrip,
        leading: WelkIconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          label: '返回',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          const GglSectionLabel(
            title: '外观模式',
            padding: EdgeInsets.fromLTRB(4, 4, 4, 10),
          ),
          GglComicPanel(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '暗黑漫画模式',
                      style: TextStyle(
                        color: colors.ink,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      theme.isDarkMode ? '夜间护眼暗色画纸' : '经典明亮漫画暖纸',
                      style: TextStyle(
                        color: AppTheme.mutedText(context),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
                WelkSwitch(
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

          const GglSectionLabel(title: 'WelkUI 漫画主题色'),
          GglComicPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final preset in AppTheme.presets)
                      GestureDetector(
                        onTap: () async {
                          await theme.selectPreset(preset);
                          if (context.mounted) {
                            GglFeedback.success(
                              context,
                              '已切换为「${preset.name}」',
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: preset.color,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: colors.outline,
                              width: theme.accentHex.toUpperCase() ==
                                      preset.hex.toUpperCase()
                                  ? 3
                                  : 1.8,
                            ),
                            boxShadow: theme.accentHex.toUpperCase() ==
                                    preset.hex.toUpperCase()
                                ? [
                                    BoxShadow(
                                      color: colors.shadow,
                                      offset: const Offset(3, 3),
                                    ),
                                  ]
                                : const [],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (theme.accentHex.toUpperCase() ==
                                  preset.hex.toUpperCase())
                                const Padding(
                                  padding: EdgeInsets.only(right: 4),
                                  child: Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: Color(0xFF242424),
                                  ),
                                ),
                              Text(
                                preset.name,
                                style: const TextStyle(
                                  color: Color(0xFF242424),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: WelkDivider(variant: WelkDividerVariant.dashed),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: theme.accentColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.outline, width: 2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '当前色值：${theme.accentName} (${theme.accentHex})',
                          style: TextStyle(
                            color: colors.ink,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    WelkButton(
                      size: WelkButtonSize.small,
                      variant: WelkButtonVariant.secondary,
                      onPressed: _openCustomColorDrawer,
                      child: const Text('自定义'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const GglSectionLabel(title: 'WelkUI 组件实时预览'),
          GglComicPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    WelkButton(
                      size: WelkButtonSize.small,
                      onPressed: () {},
                      child: const Text('漫画主按钮'),
                    ),
                    const WelkBadge(child: Text('修仙徽章')),
                    const GglStatusTag(
                      label: '已通关',
                      variant: WelkBadgeVariant.success,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const GglProgressBar(percent: 0.72),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GglBlockButton(
            label: '重置为默认主题',
            variant: WelkButtonVariant.secondary,
            onPressed: _handleReset,
          ),
        ],
      ),
    );
  }
}
