import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:skribble/skribble.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../app/app_theme.dart';
import '../core/network/api_client.dart';
import '../models/models.dart';
import '../providers/user_provider.dart';
import 'ggl_comic_panel.dart';
import 'ggl_feedback.dart';
import 'ggl_skin_widgets.dart';

/// 首页独立顶部导航栏组件：
/// 左侧展示应用品牌，右侧展示当前年级阶段选择器，点击可随时切换年级阶段。
class HomeTopNavBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeTopNavBar({
    super.key,
    this.title = '过关啦',
    this.onGradeChanged,
    this.trailingActions = const <Widget>[],
  });

  final String title;
  final Future<void> Function(GradeItem grade)? onGradeChanged;
  final List<Widget> trailingActions;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  Future<void> _openGradePicker(BuildContext context) async {
    final user = context.read<UserProvider>();
    final grades = user.grades;
    final activeGradeCode = user.currentGrade.gradeCode;

    final selected = await showGglBottomSheet<GradeItem>(
      context: context,
      title: '切换当前年级阶段',
      builder: (sheetCtx) {
        final ink = AppTheme.inkColor(sheetCtx);
        final muted = AppTheme.mutedText(sheetCtx);
        final accent = AppTheme.accentColor(sheetCtx);
        final surface = AppTheme.surfaceColor(sheetCtx);
        final colors = WelkTheme.of(sheetCtx).resolveColors(sheetCtx);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '选择你当前所在或想重点攻克的年级，首页闯关模块将同步切换对应年级进度。',
              style: TextStyle(
                color: muted,
                fontSize: 12.5,
                height: 1.45,
                fontFamilyFallback: AppTheme.cjkFontFallback,
              ),
            ),
            const SizedBox(height: 12),
            for (final grade in grades) ...[
              Builder(
                builder: (itemCtx) {
                  final realm = user.findRealmByGradeCode(grade.gradeCode);
                  final isCurrent = grade.gradeCode == activeGradeCode;
                  final passed = realm?.passedGateCount ?? 0;
                  final total = realm?.gateCount ?? (grade.chapterCount * 4);
                  final allPassed = total > 0 && passed >= total;
                  final tileBg = isCurrent
                      ? Color.alphaBlend(
                          accent.withValues(alpha: colors.isDark ? 0.2 : 0.14),
                          surface,
                        )
                      : surface;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GglComicPanel(
                      color: tileBg,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shadowOffset: const Offset(2, 2),
                      onTap: () => Navigator.of(sheetCtx).pop(grade),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: AppTheme.insetBoxDecoration(
                              itemCtx,
                              color: isCurrent
                                  ? accent
                                  : allPassed
                                      ? colors.success
                                      : AppTheme.mutedSurfaceColor(itemCtx),
                              borderColor: AppTheme.isForui(itemCtx) &&
                                      (isCurrent || allPassed)
                                  ? (isCurrent ? accent : colors.success)
                                  : null,
                              radius: 10,
                            ),
                            child: Icon(
                              allPassed
                                  ? Icons.emoji_events_rounded
                                  : Icons.school_rounded,
                              size: 20,
                              color: isCurrent
                                  ? AppTheme.onAccentColor(itemCtx)
                                  : allPassed
                                      ? colors.onFill(colors.success)
                                      : ink,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      grade.gradeName,
                                      style: TextStyle(
                                        color: ink,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        fontFamilyFallback:
                                            AppTheme.cjkFontFallback,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (isCurrent)
                                      const GglStatusTag(
                                        label: '当前年级',
                                        variant: WelkBadgeVariant.defaultStyle,
                                      )
                                    else if (allPassed)
                                      const GglStatusTag(
                                        label: '已通关',
                                        variant: WelkBadgeVariant.success,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '共 ${grade.chapterCount} 章 · 已过 $passed/$total 关',
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 12.2,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            isCurrent
                                ? Icons.check_circle_rounded
                                : Icons.chevron_right_rounded,
                            size: 20,
                            color: isCurrent ? accent : muted,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        );
      },
    );

    if (selected == null || !context.mounted) return;
    if (selected.gradeCode == activeGradeCode) return;

    try {
      await user.switchGrade(selected.gradeCode);
      if (!context.mounted) return;
      GglFeedback.success(context, '已切换至 ${selected.gradeName} 学习阶段');
      if (onGradeChanged != null) {
        await onGradeChanged!(selected);
      }
    } catch (e) {
      if (context.mounted) {
        GglFeedback.error(context, friendlyErrorMessage(e, '切换年级失败，请重试'));
      }
    }
  }

  Widget _buildGradeTrigger(BuildContext context, String gradeName) {
    final isForui = AppTheme.isForui(context);
    final isSkribble = AppTheme.isSkribble(context);
    final accent = AppTheme.accentColor(context);
    final onAccent = AppTheme.onAccentColor(context);
    final ink = AppTheme.inkColor(context);
    final colors = WelkTheme.of(context).resolveColors(context);

    final inner = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.school_rounded,
          size: 15,
          color: isForui ? accent : onAccent,
        ),
        const SizedBox(width: 5),
        Text(
          gradeName,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: isForui ? ink : onAccent,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            height: 1.1,
            fontFamilyFallback: AppTheme.cjkFontFallback,
          ),
        ),
        const SizedBox(width: 2),
        Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 17,
          color: isForui ? AppTheme.mutedText(context) : onAccent,
        ),
      ],
    );

    if (isForui) {
      final fColors = FTheme.of(context).colors;
      return Semantics(
        button: true,
        label: '切换当前年级，当前为$gradeName',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => unawaited(_openGradePicker(context)),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: fColors.secondary,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: fColors.border, width: 1),
              ),
              child: inner,
            ),
          ),
        ),
      );
    }

    if (isSkribble) {
      final wired = WiredTheme.of(context);
      return Semantics(
        button: true,
        label: '切换当前年级，当前为$gradeName',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => unawaited(_openGradePicker(context)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: RoughBoxDecoration(
              drawConfig: wired.drawConfig,
              shape: RoughBoxShape.roundedRectangle,
              borderRadius: BorderRadius.circular(999),
              borderStyle: RoughDrawingStyle(
                width: wired.strokeWidth * 0.9,
                color: wired.borderColor,
              ),
              fillStyle: RoughDrawingStyle(color: wired.markerColor),
              filler: HachureFiller(FillerConfig.build(hachureGap: 2.8)),
            ),
            child: inner,
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: '切换当前年级，当前为$gradeName',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(_openGradePicker(context)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.outline, width: 1.8),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                offset: const Offset(2, 2),
                blurRadius: 0,
              ),
            ],
          ),
          child: inner,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final gradeName = user.currentGrade.gradeName;
    final isForui = AppTheme.isForui(context);
    final isSkribble = AppTheme.isSkribble(context);
    final colors = WelkTheme.of(context).resolveColors(context);
    final ink = AppTheme.inkColor(context);
    final accent = AppTheme.accentColor(context);

    final Color bg;
    final Border? bottomBorder;
    if (isForui) {
      final fColors = FTheme.of(context).colors;
      bg = fColors.card;
      bottomBorder = Border(bottom: BorderSide(color: fColors.border, width: 1));
    } else if (isSkribble) {
      final wired = WiredTheme.of(context);
      bg = wired.fillColor;
      bottomBorder = null;
    } else {
      bg = colors.paper;
      bottomBorder = Border(
        bottom: BorderSide(color: colors.outline, width: colors.borderWidth),
      );
    }

    final barContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: AppTheme.insetBoxDecoration(
              context,
              color: accent,
              borderColor: isForui ? accent : null,
              radius: 8,
            ),
            child: Icon(
              Icons.calculate_rounded,
              size: 18,
              color: AppTheme.onAccentColor(context),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    fontFamilyFallback: AppTheme.cjkFontFallback,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '人教版同步数学闯关',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.mutedText(context),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildGradeTrigger(context, gradeName),
          if (trailingActions.isNotEmpty) ...[
            const SizedBox(width: 6),
            ...trailingActions,
          ],
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(color: bg, border: bottomBorder),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: isSkribble ? 56 : 58, child: barContent),
            if (isSkribble) const WiredDivider(),
          ],
        ),
      ),
    );
  }
}
