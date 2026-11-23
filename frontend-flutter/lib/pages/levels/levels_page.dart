import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../../app/app_theme.dart';
import '../../providers/user_provider.dart';
import '../../widgets/ggl_comic_panel.dart';
import '../../widgets/ggl_skeleton.dart';

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
    final user = context.watch<UserProvider>();
    final current = user.currentRealm;
    final realms = user.realms;

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: WelkAppBar(
        title: '修仙境界体系',
        centerTitle: true,
        layout: WelkAppBarLayout.comicStrip,
        leading: WelkIconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          label: '返回',
          onPressed: () => Navigator.of(context).pop(),
        ),
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
              // Current realm banner
              GglComicPanel(
                color: colors.accent,
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.paper,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colors.outline,
                          width: colors.borderWidth,
                        ),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: colors.ink,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '当前境界：${current.realmName}',
                            style: TextStyle(
                              color: colors.onFill(colors.accent),
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '全境界自由学习，完成本境要求后可参加进阶考核突破',
                            style: TextStyle(
                              color: colors
                                  .onFill(colors.accent)
                                  .withValues(alpha: 0.85),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const GglSectionLabel(title: '六大修仙境界'),
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
                            decoration: BoxDecoration(
                              color: item.isCurrent
                                  ? colors.accent
                                  : item.isLower
                                      ? colors.success
                                      : colors.muted,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: colors.outline,
                                width: colors.borderWidth,
                              ),
                            ),
                            child: item.isCurrent
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: colors.onFill(colors.accent),
                                  )
                                : Text(
                                    '${item.realmOrder}',
                                    style: TextStyle(
                                      color: colors.ink,
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
                                    color: colors.ink,
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
                              label: '当前境界',
                              variant: WelkBadgeVariant.defaultStyle,
                            )
                          else if (item.isLower)
                            const GglStatusTag(
                              label: '已突破 · 可压制',
                              variant: WelkBadgeVariant.success,
                            )
                          else
                            const GglStatusTag(
                              label: '可跨级学习',
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
                        const WelkDivider(variant: WelkDividerVariant.dashed),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            Text(
                              '进阶考核：随机抽取 ${item.examQuestionCount} 题 · ${item.examPassScore} 分及格',
                              style: TextStyle(
                                color: AppTheme.mutedText(context),
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              item.unlockGates > 0
                                  ? '过本境 ${item.unlockGates} 关解锁'
                                  : '本境全通后解锁',
                              style: TextStyle(
                                color: colors.ink,
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
