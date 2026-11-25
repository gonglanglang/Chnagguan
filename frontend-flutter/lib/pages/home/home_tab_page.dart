import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../../app/app_theme.dart';
import '../../core/cache/global_cache.dart';
import '../../core/utils/format_utils.dart';
import '../../models/models.dart';
import '../../providers/update_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/guoguanla_api.dart';
import '../../widgets/ggl_comic_panel.dart';
import '../../widgets/ggl_feedback.dart';
import '../../widgets/ggl_skeleton.dart';
import '../chapter_map/chapter_map_page.dart';
import '../grade_chapters/grade_chapters_page.dart';
import '../levels/levels_page.dart';
import '../login/login_page.dart';
import '../quiz/quiz_page.dart';
import '../smart_board/smart_board_page.dart';

class HomeTabPage extends StatefulWidget {
  const HomeTabPage({super.key, required this.refreshSignal});

  final ValueListenable<int> refreshSignal;

  @override
  State<HomeTabPage> createState() => _HomeTabPageState();
}

class _HomeTabPageState extends State<HomeTabPage> {
  List<ChapterCard> _heroChapters = const [];
  bool _loadingSummary = true;
  bool _loadingHero = false;
  bool _announcementCheckedInSession = false;

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

  Future<void> _fetchHeroChapters(String realmCode) async {
    if (mounted) setState(() => _loadingHero = true);
    try {
      final api = context.read<GuoguanlaApi>();
      final user = context.read<UserProvider>();
      final res = await api.getChaptersByRealm(
        realmCode,
        guestPassedIds: user.activeGuestIds,
      );
      if (!mounted) return;
      setState(() => _heroChapters = res);
    } catch (_) {
      // Keep previous hero chapters if transient error
    } finally {
      if (mounted) setState(() => _loadingHero = false);
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
    final activeRealm = user.currentRealm.realmCode;
    await _fetchHeroChapters(activeRealm);

    if (mounted) {
      unawaited(_maybeShowVersionAnnouncement());
    }
  }

  Future<void> _maybeShowVersionAnnouncement() async {
    if (_announcementCheckedInSession || !mounted) return;
    final user = context.read<UserProvider>();
    final cache = context.read<GlobalCache>();
    final update = context.read<UpdateProvider>();

    final local = await update.loadLocalVersion();
    if (!mounted) return;

    final versionKey = '${local.version}+${local.versionCode}';
    await cache.syncInstalledAppVersion(versionKey);

    final noticeText = _resolveNoticeText(user);
    if (noticeText.isEmpty || update.visible) return;
    if (!cache.shouldAutoShowAnnouncement(versionKey)) {
      _announcementCheckedInSession = true;
      return;
    }

    _announcementCheckedInSession = true;
    await cache.markAnnouncementShown(versionKey);
    if (!mounted) return;

    await GglFeedback.alert(
      context,
      title: '修炼公告',
      content: noticeText,
      buttonText: '我知道了',
    );
  }

  String _resolveNoticeText(UserProvider user) {
    final currentRealm = user.currentRealm;
    if (user.appNotice.trim().isNotEmpty) {
      return user.appNotice.trim();
    }
    if (currentRealm.examEligible) {
      return '恭喜！你在${currentRealm.realmName}已达晋升条件，点击立即参加进阶考核';
    }
    return '全境界 51 章题库开放自由练习，完成本境指定关卡可参加进阶考核';
  }

  ChapterCard? get _heroChapter {
    if (_heroChapters.isEmpty) return null;
    for (final c in _heroChapters) {
      if (c.passedCount > 0 && c.passedCount < c.totalGates) return c;
    }
    for (final c in _heroChapters) {
      if (c.passedCount < c.totalGates) return c;
    }
    return _heroChapters.first;
  }

  int get _heroChapterSeq {
    final hero = _heroChapter;
    if (hero == null) return 1;
    final idx = _heroChapters.indexWhere((c) => c.id == hero.id);
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

  RealmItem? _findRealmForGrade(UserProvider user, String gradeCode) {
    for (final r in user.realms) {
      if (r.gradeCode == gradeCode) return r;
    }
    return null;
  }

  GradeItem _findGradeForRealm(UserProvider user, RealmItem realm) {
    for (final g in user.grades) {
      if (g.gradeCode == realm.gradeCode) return g;
    }
    return GradeItem(
      gradeCode: realm.gradeCode,
      gradeName: realm.realmName,
      icon: '',
      chapterCount: realm.chapterCount,
    );
  }

  Future<void> _openGradeChapters(GradeItem grade) async {
    final user = context.read<UserProvider>();
    final realm = _findRealmForGrade(user, grade.gradeCode);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GradeChaptersPage(grade: grade, realm: realm),
      ),
    );
    if (mounted) await _refreshPage();
  }

  Future<void> _openSmartBoard({bool autoCapture = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SmartBoardPage(autoOpenCapture: autoCapture),
      ),
    );
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
                    final grade = _findGradeForRealm(user, realm);
                    unawaited(_openGradeChapters(grade));
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
    final grades = user.grades;
    final showSummarySkeleton = _loadingSummary && user.homeSummary == null;

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
    final noticeText = _resolveNoticeText(user);

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
              const SizedBox(height: 12),
              const GglCardSkeleton(lines: 3),
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: 94,
                ),
                itemCount: 6,
                itemBuilder: (_, _) => const GglCardSkeleton(lines: 1),
              ),
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

              // Notice strip
              GglComicPanel(
                color: colors.warning
                    .withValues(alpha: colors.isDark ? 0.2 : 0.35),
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
                      buttonText: '我知道了',
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
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: colors.ink,
                    ),
                  ],
                ),
              ),

              // AI Smart Handwriting Board Feature Card (v2.0 Major Feature)
              const SizedBox(height: 12),
              GglComicPanel(
                color: Color.alphaBlend(
                  colors.accent.withValues(alpha: colors.isDark ? 0.22 : 0.16),
                  colors.paper,
                ),
                padding: const EdgeInsets.all(14),
                onTap: () => _openSmartBoard(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: colors.accent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: colors.outline,
                              width: 1.8,
                            ),
                          ),
                          child: Icon(
                            Icons.draw_rounded,
                            size: 20,
                            color: colors.onFill(colors.accent),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'AI 智能手写画板',
                                    style: TextStyle(
                                      color: colors.ink,
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const GglStatusTag(
                                    label: 'v2.0 新功能',
                                    variant: WelkBadgeVariant.success,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '拍照识题入画板 · AI 思路与解题过程直接板书绘制',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.mutedText(context),
                                  fontSize: 12.2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: WelkButton(
                            size: WelkButtonSize.small,
                            variant: WelkButtonVariant.primary,
                            onPressed: () =>
                                _openSmartBoard(autoCapture: true),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.photo_camera_rounded, size: 15),
                                SizedBox(width: 5),
                                Text('拍照识题'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: WelkButton(
                            size: WelkButtonSize.small,
                            variant: WelkButtonVariant.secondary,
                            onPressed: () => _openSmartBoard(),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_rounded, size: 15),
                                SizedBox(width: 5),
                                Text('打开画板'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 3-Column Grade Selector Grid (Above Continue Practice Module)
              const GglSectionLabel(
                title: '选择年级',
                trailing: Text(
                  '点击进入年级章节',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: 98,
                ),
                itemCount: grades.length,
                itemBuilder: (context, idx) {
                  final grade = grades[idx];
                  final realm = _findRealmForGrade(user, grade.gradeCode);
                  final isCurrent = realm?.isCurrent ??
                      (grade.gradeCode == currentRealm.gradeCode);
                  return _GradeGridTile(
                    grade: grade,
                    realmName: realm?.realmName ?? '',
                    isCurrent: isCurrent,
                    onTap: () => _openGradeChapters(grade),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Continue Practice Hero Comic Card
              if (_loadingHero && hero == null)
                const GglCardSkeleton(lines: 4)
              else if (hero != null) ...[
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

              // Exam eligible quick action banner (if ready)
              if (currentRealm.examEligible) ...[
                GglComicPanel(
                  color: colors.success
                      .withValues(alpha: colors.isDark ? 0.22 : 0.35),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shadowOffset: const Offset(2, 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${currentRealm.realmName}已达标，可参加境界进阶考核',
                          style: TextStyle(
                            color: colors.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      WelkButton(
                        size: WelkButtonSize.small,
                        variant: WelkButtonVariant.success,
                        onPressed: _startAdvanceExam,
                        child: const Text('去考核'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Bottom exam tip
              GestureDetector(
                onTap: _openSystemDrawer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    currentRealm.examEligible
                        ? '${currentRealm.realmName}已满足进阶条件，点击查看学习体系并考核晋升'
                        : '全年级题库已自由开放 · 本境再过 ${currentRealm.examRemainingGates > 0 ? currentRealm.examRemainingGates : 0} 关可解锁进阶考核',
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

class _GradeGridTile extends StatelessWidget {
  const _GradeGridTile({
    required this.grade,
    required this.realmName,
    required this.isCurrent,
    required this.onTap,
  });

  final GradeItem grade;
  final String realmName;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final tileColor = isCurrent
        ? Color.alphaBlend(
            colors.accent.withValues(alpha: colors.isDark ? 0.20 : 0.18),
            colors.paper,
          )
        : colors.paper;

    return GglComicPanel(
      color: tileColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      shadowOffset: const Offset(2, 2),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (realmName.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isCurrent ? colors.accent : colors.muted,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: colors.outline, width: 1.2),
              ),
              child: Text(
                isCurrent ? '$realmName · 本境' : realmName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isCurrent
                      ? colors.onFill(colors.accent)
                      : AppTheme.mutedText(context),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            grade.gradeName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${grade.chapterCount} 章',
            style: TextStyle(
              color: AppTheme.mutedText(context),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
