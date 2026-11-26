import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../../app/app_theme.dart';
import '../../providers/user_provider.dart';
import '../../widgets/ggl_comic_panel.dart';
import '../../widgets/ggl_skeleton.dart';
import '../../widgets/ggl_skin_widgets.dart';

class LevelsPage extends StatefulWidget {
  const LevelsPage({super.key});

  @override
  State<LevelsPage> createState() => _LevelsPageState();
}

class _LevelsPageState extends State<LevelsPage> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>();
    if (user.homeSummary == null) {
      _loading = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      await context.read<UserProvider>().loadHomeSummary();
    } catch (_) {
      // Keep fallback realms
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final ink = AppTheme.inkColor(context);
    final accent = AppTheme.accentColor(context);
    final onAccent = AppTheme.onAccentColor(context);
    final isForui = AppTheme.isForui(context);
    final user = context.watch<UserProvider>();
    final current = user.currentRealm;
    final realms = user.realms;

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: const GglAppBar(
        title: '学习阶段体系',
        showBack: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            if (_loading) ...[
              const GglCardSkeleton(lines: 2),
              const SizedBox(height: 12),
              for (var i = 0; i < 4; i++) ...[
                const GglCardSkeleton(lines: 3),
                const SizedBox(height: 12),
              ],
            ] else ...[
              // Current stage banner
              GglComicPanel(
                color: accent,
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: AppTheme.insetBoxDecoration(
                        context,
                        color: AppTheme.surfaceColor(context),
                        radius: 12,
                      ),
                      child: Icon(
                        Icons.school_rounded,
                        color: ink,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '当前学习阶段：${current.realmName}',
                            style: TextStyle(
                              color: onAccent,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '全年级自由练习，完成当前阶段指定关卡后可参加阶段升级测评',
                            style: TextStyle(
                              color: onAccent.withValues(alpha: 0.85),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const GglSectionLabel(title: '初一至高三学习阶段'),
              for (final item in realms) ...[
                GglComicPanel(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: AppTheme.insetBoxDecoration(
                              context,
                              color: item.isCurrent
                                  ? accent
                                  : item.isLower
                                      ? (isForui
                                          ? const Color(0xFF10B981)
                                          : colors.success)
                                      : AppTheme.mutedSurfaceColor(context),
                              borderColor: isForui &&
                                      (item.isCurrent || item.isLower)
                                  ? (item.isCurrent
                                      ? accent
                                      : const Color(0xFF10B981))
                                  : null,
                              radius: 9,
                            ),
                            child: item.isCurrent
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: onAccent,
                                  )
                                : Text(
                                    '${item.realmOrder}',
                                    style: TextStyle(
                                      color: item.isLower && isForui
                                          ? Colors.white
                                          : ink,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.realmName,
                                  style: TextStyle(
                                    color: ink,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  item.difficultyLabel,
                                  style: TextStyle(
                                    color: AppTheme.mutedText(context),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (item.isCurrent)
                            const GglStatusTag(
                              label: '当前阶段',
                              variant: WelkBadgeVariant.defaultStyle,
                            )
                          else if (item.isLower)
                            const GglStatusTag(
                              label: '已完成 · 可回刷',
                              variant: WelkBadgeVariant.success,
                            )
                          else
                            const GglStatusTag(
                              label: '自由练习',
                              variant: WelkBadgeVariant.info,
                            ),
                        ],
                      ),
                      if (item.description.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          item.description,
                          style: TextStyle(
                            color: AppTheme.mutedText(context),
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                      if (item.realmOrder < 6) ...[
                        const SizedBox(height: 10),
                        const GglDivider(verticalPadding: 0),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            Text(
                              '阶段升级测评：随机抽取 ${item.examQuestionCount} 题 · ${item.examPassScore} 分及格',
                              style: TextStyle(
                                color: AppTheme.mutedText(context),
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              item.unlockGates > 0
                                  ? '完成本阶段 ${item.unlockGates} 关解锁'
                                  : '本阶段全通后解锁',
                              style: TextStyle(
                                color: ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
