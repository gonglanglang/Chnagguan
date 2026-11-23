import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../../app/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/format_utils.dart';
import '../../models/models.dart';
import '../../providers/user_provider.dart';
import '../../services/guoguanla_api.dart';
import '../../widgets/ggl_comic_panel.dart';
import '../../widgets/ggl_feedback.dart';
import '../../widgets/ggl_skeleton.dart';
import '../chapter_map/chapter_map_page.dart';
import '../levels/levels_page.dart';
import '../login/login_page.dart';
import '../quiz/quiz_page.dart';

class HomeTabPage extends StatefulWidget {
  const HomeTabPage({super.key, required this.refreshSignal});

  final ValueListenable<int> refreshSignal;

  @override
  State<HomeTabPage> createState() => _HomeTabPageState();
}

class _HomeTabPageState extends State<HomeTabPage> {
  String _viewingRealmCode = 'lianqi';
  bool _manualRealmSelected = false;
  String _lastKnownUserRealmCode = 'lianqi';
  String _lastLoadedChaptersRealm = '';
  List<ChapterCard> _chapters = const [];
  List<ChapterCard> _heroChapters = const [];
  bool _loadingSummary = true;
  bool _loadingChapters = false;

  @override
  void initState() {
    super.initState();
    _loadingSummary = context.read<UserProvider>().homeSummary == null;
    widget.refreshSignal.addListener(_onRefreshSignal);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPage());
  }

  @override
  void dispose() {
    widget.refreshSignal.removeListener(_onRefreshSignal);
    super.dispose();
  }

  void _onRefreshSignal() {
    if (mounted) unawaited(_refreshPage());
  }

  Future<void> _fetchChapters(String realmCode) async {
    setState(() => _loadingChapters = true);
    try {
      final api = context.read<GuoguanlaApi>();
      final user = context.read<UserProvider>();
      final res = await api.getChaptersByRealm(
        realmCode,
        guestPassedIds: user.activeGuestIds,
      );
      if (!mounted) return;
      setState(() {
        _chapters = res;
        _lastLoadedChaptersRealm = realmCode;
        if (realmCode == user.currentRealm.realmCode) {
          _heroChapters = res;
        }
      });
    } catch (e) {
      if (mounted) {
        GglFeedback.error(context, friendlyErrorMessage(e, '加载章节失败'));
      }
    } finally {
      if (mounted) setState(() => _loadingChapters = false);
    }
  }

  Future<void> _refreshPage() async {
    final user = context.read<UserProvider>();
    if (user.homeSummary == null && mounted) {
      setState(() => _loadingSummary = true);
    }
    try {
      await user.loadHomeSummary();
    } catch (_) {
      // Keep cached summary
    } finally {
      if (mounted) setState(() => _loadingSummary = false);
    }

    if (!mounted) return;
    final active = user.currentRealm.realmCode;
    if (!_manualRealmSelected || _lastKnownUserRealmCode != active) {
      _viewingRealmCode = active;
      _manualRealmSelected = false;
    }
    _lastKnownUserRealmCode = active;

    await _fetchChapters(_viewingRealmCode);
    if (mounted && _viewingRealmCode != active) {
      try {
        final heroRes = await context.read<GuoguanlaApi>().getChaptersByRealm(
              active,
              guestPassedIds: user.activeGuestIds,
            );
        if (mounted) setState(() => _heroChapters = heroRes);
      } catch (_) {
        // Ignore secondary hero fetch error
      }
    }
  }

  RealmItem _viewingRealm(UserProvider user) {
    for (final r in user.realms) {
      if (r.realmCode == _viewingRealmCode) return r;
    }
    return user.currentRealm;
  }

  List<ChapterCard> get _activeHeroSource =>
      _heroChapters.isNotEmpty ? _heroChapters : _chapters;

  ChapterCard? get _heroChapter {
    final list = _activeHeroSource;
    if (list.isEmpty) return null;
    for (final c in list) {
      if (c.passedCount > 0 && c.passedCount < c.totalGates) return c;
    }
    for (final c in list) {
      if (c.passedCount < c.totalGates) return c;
    }
    return list.first;
  }

  int get _heroChapterSeq {
    final hero = _heroChapter;
    if (hero == null) return 1;
    final idx = _activeHeroSource.indexWhere((c) => c.id == hero.id);
    return idx >= 0 ? idx + 1 : 1;
  }

  String _heroSubtitle(ChapterCard ch) {
    if (ch.totalGates > 0 && ch.passedCount >= ch.totalGates) {
      return '${ch.realmName} · 本章已全部通关';
    }
    if (ch.passedCount > 0) {
      final tail = ch.description.isNotEmpty ? ch.description : ch.realmName;
      return '上次停在第 ${ch.passedCount + 1} 关 · $tail';
    }
    return ch.description.isNotEmpty
        ? ch.description
        : '${ch.realmName} · 共 ${ch.totalGates} 关等你挑战';
  }

  Future<void> _openChapterMap(ChapterCard chapter, int seq) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChapterMapPage(
          chapterId: chapter.id,
          chapterSeq: seq,
          chapterName: chapter.name,
          chapterDesc: chapter.description,
          realmName: chapter.realmName,
        ),
      ),
    );
    if (mounted) await _refreshPage();
  }

  Future<void> _handleContinuePractice() async {
    final ch = _heroChapter;
    if (ch == null) return;
    final user = context.read<UserProvider>();
    try {
      final gateList = await context.read<GuoguanlaApi>().getGatesByChapter(
            ch.id,
            guestPassedIds: user.activeGuestIds,
          );
      GateCard? playable;
      for (final g in gateList) {
        if (!g.passed && !g.locked && !g.empty) {
          playable = g;
          break;
        }
      }
      playable ??= gateList.cast<GateCard?>().firstWhere(
            (g) => g != null && !g.locked && !g.empty,
            orElse: () => null,
          );
      if (playable != null && mounted) {
        if (!user.isAuthenticated && !user.guestModeEnabled) {
          GglFeedback.warning(context, '请先登录后开始闯关');
          await Navigator.of(context).push(
            MaterialPageRoute<bool>(builder: (_) => const LoginPage()),
          );
          return;
        }
        final offset = gateList.any((g) => g.gateIndex == 0) ? 1 : 0;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => QuizPage(
              mode: QuizMode.gate,
              gateId: playable!.id,
              gateSeq: playable.gateIndex + offset,
            ),
          ),
        );
        if (mounted) await _refreshPage();
        return;
      }
    } catch (_) {
      // Fallback to chapter map
    }
    if (mounted) {
      await _openChapterMap(ch, _heroChapterSeq);
    }
  }

  Future<void> _startAdvanceExam() async {
    final user = context.read<UserProvider>();
    if (!user.isAuthenticated) {
      GglFeedback.warning(context, '请先登录后参加境界进阶考核');
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(builder: (_) => const LoginPage()),
      );
      if (ok != true || !mounted) return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const QuizPage(mode: QuizMode.advanceExam),
      ),
    );
    if (mounted) await _refreshPage();
  }

  void _selectRealmTab(RealmItem realm) {
    final currentCode = context.read<UserProvider>().currentRealm.realmCode;
    setState(() {
      _viewingRealmCode = realm.realmCode;
      _manualRealmSelected = realm.realmCode != currentCode;
    });
    unawaited(_fetchChapters(realm.realmCode));
  }

  Future<void> _openSystemDrawer() async {
    final user = context.read<UserProvider>();
    final currentRealm = user.currentRealm;

    await showWelkDrawer<void>(
      context: context,
      position: WelkDrawerPosition.bottom,
      closeOnTapOutside: true,
      builder: (drawerCtx) => WelkDrawer(
        title: const Text('学习体系 · 六大修仙境界'),
        closeLabel: '关闭',
        onClose: () => Navigator.of(drawerCtx).pop(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '共 ${user.realms.length} 大境界，全阶段课程与章节题库自由开放学习；完成本境指定关卡后可发起进阶考核晋升。',
              style: TextStyle(
                color: AppTheme.mutedText(drawerCtx),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            for (final realm in user.realms)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GglComicPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shadowOffset: const Offset(2, 2),
                  onTap: () {
                    Navigator.of(drawerCtx).pop();
                    _selectRealmTab(realm);
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${realm.realmName} · ${FormatUtils.shortDifficultyLabel(realm.difficultyLabel)}',
                              style: TextStyle(
                                color: WelkTheme.of(drawerCtx)
                                    .resolveColors(drawerCtx)
                                    .ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              realm.description.isNotEmpty
                                  ? realm.description
                                  : '共 ${realm.chapterCount} 章 ${realm.gateCount} 关',
                              style: TextStyle(
                                color: AppTheme.mutedText(drawerCtx),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GglStatusTag(
                        label: realm.isCurrent
                            ? '修炼中'
                            : realm.isLower
                                ? '已通过'
                                : '自由开放',
                        variant: realm.isCurrent
                            ? WelkBadgeVariant.defaultStyle
                            : realm.isLower
                                ? WelkBadgeVariant.success
                                : WelkBadgeVariant.info,
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            if (currentRealm.examEligible)
              GglBlockButton(
                label: '参加${currentRealm.realmName}进阶考核',
                onPressed: () {
                  Navigator.of(drawerCtx).pop();
                  unawaited(_startAdvanceExam());
                },
              )
            else
              GglBlockButton(
                label: '查看境界详情与进阶规则',
                variant: WelkButtonVariant.secondary,
                onPressed: () {
                  Navigator.of(drawerCtx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LevelsPage(),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final user = context.watch<UserProvider>();
    final currentRealm = user.currentRealm;
    final viewingRealm = _viewingRealm(user);
    final isSuppressed = viewingRealm.realmOrder < currentRealm.realmOrder;
    final showSummarySkeleton = _loadingSummary && user.homeSummary == null;
    final showChapterSkeleton = _loadingChapters &&
        (_chapters.isEmpty || _lastLoadedChaptersRealm != _viewingRealmCode);

    final totalPassed = user.isAuthenticated && user.userInfo != null
        ? user.userInfo!.passedGateCount
        : user.realms.fold<int>(0, (acc, r) => acc + r.passedGateCount);
    final totalGatesSum =
        user.realms.fold<int>(0, (acc, r) => acc + r.gateCount);
    final totalGates = totalGatesSum > 0
        ? totalGatesSum
        : (currentRealm.gateCount > 0 ? currentRealm.gateCount : 204);

    final displayName = (user.userInfo?.nickname.isNotEmpty ?? false)
        ? user.userInfo!.nickname
        : (user.isAuthenticated ? '道友' : '同学');
    final greeting = '${FormatUtils.greetingPrefix(DateTime.now())}，$displayName';

    final noticeText = user.appNotice.trim().isNotEmpty
        ? user.appNotice.trim()
        : currentRealm.examEligible
            ? '恭喜！你在${currentRealm.realmName}已达晋升条件，点击立即参加进阶考核'
            : '全境界 51 章题库开放自由练习，完成本境指定关卡可参加进阶考核';

    final hero = _heroChapter;
    final heroPct = (hero != null && hero.totalGates > 0)
        ? ((hero.passedCount / hero.totalGates) * 100).round().clamp(0, 100)
        : 0;

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: WelkAppBar(
        title: '过关啦',
        layout: WelkAppBarLayout.comicStrip,
        automaticallyImplyLeading: false,
        actions: [
          WelkIconButton(
            icon: const Icon(Icons.layers_rounded),
            label: '学习体系',
            onPressed: _openSystemDrawer,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPage,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            if (showSummarySkeleton) ...[
              const GglCardSkeleton(lines: 2),
              const SizedBox(height: 14),
              const GglCardSkeleton(lines: 4),
              const SizedBox(height: 14),
              const GglCardSkeleton(lines: 4),
            ] else ...[
              // Greeting Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting,
                          style: TextStyle(
                            color: colors.ink,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '当前境界',
                              style: TextStyle(
                                color: AppTheme.mutedText(context),
                                fontSize: 13,
                              ),
                            ),
                            GglStatusTag(
                              label: currentRealm.realmName,
                              variant: WelkBadgeVariant.defaultStyle,
                            ),
                            Text(
                              '· 已过 $totalPassed/$totalGates 关',
                              style: TextStyle(
                                color: AppTheme.mutedText(context),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  WelkButton(
                    size: WelkButtonSize.small,
                    variant: WelkButtonVariant.secondary,
                    onPressed: _openSystemDrawer,
                    child: const Text('学习体系'),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Continue Practice Hero Comic Card
              if (hero != null) ...[
                GglComicPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '继续修炼',
                            style: TextStyle(
                              color: colors.ink,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          GglStatusTag(
                            label: '第 $_heroChapterSeq 章',
                            variant: WelkBadgeVariant.defaultStyle,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        hero.name,
                        style: TextStyle(
                          color: colors.ink,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _heroSubtitle(hero),
                        style: TextStyle(
                          color: AppTheme.mutedText(context),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: GglProgressBar(percent: heroPct / 100),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$heroPct%',
                            style: TextStyle(
                              color: colors.ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const WelkDivider(variant: WelkDividerVariant.dashed),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          WelkButton(
                            size: WelkButtonSize.small,
                            variant: WelkButtonVariant.secondary,
                            onPressed: () =>
                                _openChapterMap(hero, _heroChapterSeq),
                            child: const Text('查看地图'),
                          ),
                          const SizedBox(width: 10),
                          WelkButton(
                            size: WelkButtonSize.small,
                            variant: WelkButtonVariant.primary,
                            onPressed: _handleContinuePractice,
                            child: const Text('继续闯关'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Notice strip
              GglComicPanel(
                color: colors.warning.withValues(alpha: colors.isDark ? 0.2 : 0.35),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shadowOffset: const Offset(2, 2),
                onTap: () {
                  if (currentRealm.examEligible) {
                    unawaited(_startAdvanceExam());
                  } else {
                    GglFeedback.alert(
                      context,
                      title: '修炼公告',
                      content: noticeText,
                    );
                  }
                },
                child: Row(
                  children: [
                    Icon(
                      Icons.campaign_rounded,
                      size: 18,
                      color: colors.ink,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        noticeText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const GglSectionLabel(title: '章节闯关'),

              // Horizontal 6-Realm Selector
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    for (final realm in user.realms)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GglPillChip(
                          label: realm.realmName,
                          selected: _viewingRealmCode == realm.realmCode,
                          onTap: () => _selectRealmTab(realm),
                        ),
                      ),
                  ],
                ),
              ),

              // Suppressed or exam-eligible banner
              if (isSuppressed || currentRealm.examEligible) ...[
                GglComicPanel(
                  color: colors.info.withValues(alpha: colors.isDark ? 0.2 : 0.3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shadowOffset: const Offset(2, 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          isSuppressed
                              ? '高境压制 · 正在重温${viewingRealm.realmName}内容，全章节自由开放'
                              : '${currentRealm.realmName}已达标，可参加境界进阶考核',
                          style: TextStyle(
                            color: colors.ink,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (currentRealm.examEligible && !isSuppressed) ...[
                        const SizedBox(width: 8),
                        WelkButton(
                          size: WelkButtonSize.small,
                          variant: WelkButtonVariant.success,
                          onPressed: _startAdvanceExam,
                          child: const Text('去考核'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Chapter list
              if (showChapterSkeleton)
                for (var i = 0; i < 4; i++) ...[
                  const GglCardSkeleton(lines: 2),
                  const SizedBox(height: 10),
                ]
              else if (_chapters.isEmpty)
                GglComicPanel(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.menu_book_outlined,
                        size: 36,
                        color: AppTheme.mutedText(context),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '该境界暂未配置章节',
                        style: TextStyle(color: AppTheme.mutedText(context)),
                      ),
                    ],
                  ),
                )
              else
                for (var idx = 0; idx < _chapters.length; idx++)
                  _ChapterRowCard(
                    chapter: _chapters[idx],
                    seq: idx + 1,
                    onTap: () => _openChapterMap(_chapters[idx], idx + 1),
                  ),

              // Bottom exam tip
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _openSystemDrawer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    currentRealm.examEligible
                        ? '${currentRealm.realmName}已满足进阶条件，点击查看学习体系并考核晋升'
                        : '全境界题库已自由开放 · 本境再过 ${currentRealm.examRemainingGates > 0 ? currentRealm.examRemainingGates : 0} 关可解锁进阶考核',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.mutedText(context),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChapterRowCard extends StatelessWidget {
  const _ChapterRowCard({
    required this.chapter,
    required this.seq,
    required this.onTap,
  });

  final ChapterCard chapter;
  final int seq;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final isDone =
        chapter.totalGates > 0 && chapter.passedCount >= chapter.totalGates;
    final isInProgress = !isDone && chapter.passedCount > 0;

    final badgeFill = isDone
        ? colors.success
        : isInProgress
            ? colors.accent
            : colors.muted;
    final statusLabel = isDone
        ? '已通关'
        : isInProgress
            ? '进行中'
            : '未开始';
    final statusVariant = isDone
        ? WelkBadgeVariant.success
        : isInProgress
            ? WelkBadgeVariant.defaultStyle
            : WelkBadgeVariant.info;

    return GglComicPanel(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      shadowOffset: const Offset(2, 2),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: badgeFill,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colors.outline,
                width: colors.borderWidth,
              ),
            ),
            child: Text(
              FormatUtils.padTwo(seq),
              style: TextStyle(
                color: colors.onFill(badgeFill),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chapter.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  chapter.description.isNotEmpty
                      ? chapter.description
                      : '四关精讲精练，循序夯实基础',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.mutedText(context),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GglStatusTag(
                label: statusLabel,
                variant: statusVariant,
                neutral: !isDone && !isInProgress,
              ),
              const SizedBox(height: 4),
              Text(
                '${chapter.passedCount}/${chapter.totalGates}',
                style: TextStyle(
                  color: AppTheme.mutedText(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppTheme.mutedText(context),
          ),
        ],
      ),
    );
  }
}
