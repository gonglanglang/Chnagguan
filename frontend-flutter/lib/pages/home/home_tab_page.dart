import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../../app/app_theme.dart';
import '../../core/cache/global_cache.dart';
import '../../core/utils/format_utils.dart';
import '../../models/models.dart';
import '../../providers/theme_provider.dart';
import '../../providers/update_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/guoguanla_api.dart';
import '../../widgets/ggl_comic_panel.dart';
import '../../widgets/ggl_feedback.dart';
import '../../widgets/ggl_skeleton.dart';
import '../../widgets/ggl_skin_widgets.dart';
import '../../widgets/grade_promotion_helper.dart';
import '../../widgets/home_banner_carousel.dart';
import '../../widgets/home_top_nav_bar.dart';
import '../chapter_map/chapter_map_page.dart';
import '../grade_chapters/grade_chapters_page.dart';
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
  List<ChapterCard> _gradeChapters = const [];
  String _loadedGradeCode = '';
  bool _loadingSummary = true;
  bool _loadingGradeChapters = false;
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

  Future<void> _fetchCurrentGradeChapters(String gradeCode) async {
    if (gradeCode.isEmpty) return;
    if (mounted) setState(() => _loadingGradeChapters = true);
    try {
      final api = context.read<GuoguanlaApi>();
      final user = context.read<UserProvider>();
      final res = await api.getChaptersByGrade(
        gradeCode,
        guestPassedIds: user.activeGuestIds,
      );
      if (!mounted) return;
      setState(() {
        _gradeChapters = res;
        _loadedGradeCode = gradeCode;
      });
    } catch (_) {
      // Keep previous chapters if transient error
    } finally {
      if (mounted) setState(() => _loadingGradeChapters = false);
    }
  }

  Future<void> _refreshPage() async {
    final user = context.read<UserProvider>();
    if (user.homeSummary == null && mounted) {
      setState(() => _loadingSummary = true);
    }
    try {
      await user.loadHomeSummary();
      final serverTheme = user.homeSummary?.defaultTheme;
      if (serverTheme != null && mounted) {
        unawaited(
          context.read<ThemeProvider>().applyServerDefaultTheme(
                serverTheme,
                isAppLaunch: false,
              ),
        );
      }
    } catch (_) {
      // Keep cached summary
    } finally {
      if (mounted) setState(() => _loadingSummary = false);
    }

    if (!mounted) return;
    final activeGradeCode = user.currentGrade.gradeCode;
    await _fetchCurrentGradeChapters(activeGradeCode);

    if (mounted) {
      unawaited(_maybeShowVersionAnnouncement());
    }
  }

  static const String _defaultNoticeText =
      '1. 全年级同步闯关：初一至高三 51 章 204 关自由开放练习，支持基础关 → 下一关 → 下一章 → 跨年级连续闯关；\n'
      '2. 精绘数学矢量配图：526 道几何、函数、统计与立体几何题目均配有清晰矢量图，点击可全屏缩放；\n'
      '3. AI 智能手写画板：支持拍照与手写识题，自动矢量重绘几何配图并提供思路引导、过程诊断与解题核对；\n'
      '4. 错题本高效巩固：闯关错题自动收录，重做答对即标记掌握并移出，支持 A4 排版导出 Word 分享微信。';

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

    await _showAnnouncementDialog(noticeText);
  }

  String _resolveNoticeText(UserProvider user) {
    if (user.appNotice.trim().isNotEmpty) {
      return user.appNotice.trim();
    }
    return _defaultNoticeText;
  }

  List<String> _parseNoticePoints(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const <String>[];
    final byLines = trimmed
        .split(RegExp(r'\r?\n'))
        .map((line) => line
            .replaceFirst(RegExp(r'^(?:[-*•]|\d+[.、)）])\s*'), '')
            .trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (byLines.length > 1) return byLines;

    final bySemicolon = trimmed
        .split(RegExp(r'[；;]+'))
        .map((s) => s.replaceFirst(RegExp(r'^\d+[.、)）]\s*'), '').trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return bySemicolon.isNotEmpty ? bySemicolon : <String>[trimmed];
  }

  String _noticePreviewLine(String raw) {
    final points = _parseNoticePoints(raw);
    return points.isNotEmpty ? points.first : raw.trim();
  }

  Future<void> _showAnnouncementDialog(String noticeText) async {
    final points = _parseNoticePoints(noticeText);
    final version = context.read<UpdateProvider>().currentVersion;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        final ink = AppTheme.inkColor(dialogCtx);
        final muted = AppTheme.mutedText(dialogCtx);
        final accent = AppTheme.accentColor(dialogCtx);
        final onAccent = AppTheme.onAccentColor(dialogCtx);
        final surface = AppTheme.surfaceColor(dialogCtx);
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
            child: GglComicPanel(
              color: surface,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: AppTheme.insetBoxDecoration(
                          dialogCtx,
                          color: accent,
                          borderColor:
                              AppTheme.isForui(dialogCtx) ? accent : null,
                          radius: 10,
                        ),
                        child: Icon(
                          Icons.campaign_rounded,
                          size: 20,
                          color: onAccent,
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
                                  '学习公告',
                                  style: TextStyle(
                                    color: ink,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GglStatusTag(
                                  label: 'v$version',
                                  variant: WelkBadgeVariant.info,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '云篆科技工作室 · 过关啦教研公告',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: muted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const GglDivider(verticalPadding: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < points.length; i++)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: i == points.length - 1 ? 0 : 10,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    margin: const EdgeInsets.only(top: 1),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        color: accent,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      points[i],
                                      style: TextStyle(
                                        color: ink.withValues(alpha: 0.9),
                                        fontSize: 13.5,
                                        height: 1.55,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.mutedSurfaceColor(dialogCtx),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.verified_outlined,
                                  size: 15,
                                  color: muted,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '深圳市龙华区云篆科技工作室持续维护更新，祝你学习进步！',
                                    style: TextStyle(
                                      color: muted,
                                      fontSize: 11.5,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GglBlockButton(
                    label: '我知道了',
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  ChapterCard? get _activeChapter {
    if (_gradeChapters.isEmpty) return null;
    for (final c in _gradeChapters) {
      if (c.passedCount > 0 && c.passedCount < c.totalGates) return c;
    }
    for (final c in _gradeChapters) {
      if (c.passedCount < c.totalGates) return c;
    }
    return _gradeChapters.last;
  }

  int get _activeChapterSeq {
    final active = _activeChapter;
    if (active == null) return 1;
    final idx = _gradeChapters.indexWhere((c) => c.id == active.id);
    return idx >= 0 ? idx + 1 : 1;
  }

  String _activeGateSubtitle(ChapterCard ch) {
    if (ch.totalGates > 0 && ch.passedCount >= ch.totalGates) {
      return '本章共 ${ch.totalGates} 关已全部通关';
    }
    if (ch.passedCount > 0) {
      return '进度：第 ${ch.passedCount + 1}/${ch.totalGates} 关 · 继续攻克本章';
    }
    return ch.description.isNotEmpty
        ? ch.description
        : '第 1/${ch.totalGates} 关 · 点击开启本章节闯关';
  }

  Future<void> _openGradeChapters(GradeItem grade) async {
    final user = context.read<UserProvider>();
    final realm = user.findRealmByGradeCode(grade.gradeCode);
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

  Future<void> _handleContinuePractice(GradeItem currentGrade) async {
    final ch = _activeChapter;
    if (ch == null) {
      await _openGradeChapters(currentGrade);
      return;
    }
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
      await _openChapterMap(ch, _activeChapterSeq);
    }
  }

  Future<void> _handlePromoteNextGrade(
    GradeItem currentGrade,
    RealmItem nextRealm,
  ) async {
    final user = context.read<UserProvider>();
    final nextGrade = user.findGradeByCode(nextRealm.gradeCode) ??
        GradeItem(
          gradeCode: nextRealm.gradeCode,
          gradeName: nextRealm.realmName,
          icon: '',
          chapterCount: nextRealm.chapterCount,
        );
    final promoted = await GradePromotionHelper.confirmAndPromoteGrade(
      context,
      currentGradeName: currentGrade.gradeName,
      nextGradeCode: nextGrade.gradeCode,
      nextGradeName: nextGrade.gradeName,
    );
    if (promoted && mounted) {
      await _refreshPage();
    }
  }

  Future<void> _startAdvanceExam() async {
    final user = context.read<UserProvider>();
    if (!user.isAuthenticated) {
      GglFeedback.warning(context, '请先登录后参加阶段升级测评');
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

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final user = context.watch<UserProvider>();
    final currentRealm = user.currentRealm;
    final currentGrade = user.currentGrade;
    final nextRealm = user.nextRealm;
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
        : '同学';
    final greeting = '${FormatUtils.greetingPrefix(DateTime.now())}，$displayName';
    final noticeText = _resolveNoticeText(user);
    final noticePreview = _noticePreviewLine(noticeText);
    final ink = AppTheme.inkColor(context);
    final muted = AppTheme.mutedText(context);
    final surface = AppTheme.surfaceColor(context);
    final accent = AppTheme.accentColor(context);

    final chaptersReady = _loadedGradeCode == currentGrade.gradeCode &&
        _gradeChapters.isNotEmpty;
    final gradePassedGates = chaptersReady
        ? _gradeChapters.fold<int>(0, (sum, c) => sum + c.passedCount)
        : currentRealm.passedGateCount;
    final gradeTotalGates = chaptersReady
        ? _gradeChapters.fold<int>(0, (sum, c) => sum + c.totalGates)
        : (currentRealm.gateCount > 0
            ? currentRealm.gateCount
            : currentGrade.chapterCount * 4);
    final gradePassedChapters = chaptersReady
        ? _gradeChapters
            .where((c) => c.totalGates > 0 && c.passedCount >= c.totalGates)
            .length
        : 0;
    final gradeTotalChapters =
        chaptersReady ? _gradeChapters.length : currentGrade.chapterCount;
    final gradeAllCleared =
        gradeTotalGates > 0 && gradePassedGates >= gradeTotalGates;
    final gradePct = gradeTotalGates > 0
        ? (gradePassedGates / gradeTotalGates).clamp(0.0, 1.0)
        : 0.0;
    final activeChapter = _activeChapter;

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: HomeTopNavBar(
        onGradeChanged: (_) => _refreshPage(),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPage,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
          children: [
            if (showSummarySkeleton) ...[
              const AspectRatio(
                aspectRatio: 16 / 6.2,
                child: GglSkeletonBox(width: double.infinity, height: 130),
              ),
              const SizedBox(height: 10),
              const GglCardSkeleton(lines: 2),
              const SizedBox(height: 10),
              const GglCardSkeleton(lines: 3),
              const SizedBox(height: 10),
              const GglCardSkeleton(lines: 4),
            ] else ...[
              // 1. 师资力量顶部轮播图
              if (user.banners.isNotEmpty) ...[
                HomeBannerCarousel(banners: user.banners),
                const SizedBox(height: 10),
              ],

              // 2. 单行学习公告条（不占过多主空间）
              GglComicPanel(
                color: colors.warning
                    .withValues(alpha: colors.isDark ? 0.2 : 0.24),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                shadowOffset: const Offset(1.5, 1.5),
                onTap: () => unawaited(_showAnnouncementDialog(noticeText)),
                child: Row(
                  children: [
                    Icon(Icons.campaign_rounded, size: 16, color: ink),
                    const SizedBox(width: 6),
                    const GglStatusTag(
                      label: '学习公告',
                      variant: WelkBadgeVariant.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        noticePreview,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ink,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 16, color: ink),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 3. AI 智能手写画板（置顶位于闯关模块上方）
              GglComicPanel(
                color: Color.alphaBlend(
                  accent.withValues(
                    alpha: AppTheme.isForui(context)
                        ? (colors.isDark ? 0.14 : 0.08)
                        : (colors.isDark ? 0.22 : 0.16),
                  ),
                  surface,
                ),
                padding: const EdgeInsets.all(12),
                onTap: () => _openSmartBoard(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: AppTheme.insetBoxDecoration(
                            context,
                            color: accent,
                            borderColor:
                                AppTheme.isForui(context) ? accent : null,
                            radius: 9,
                          ),
                          child: Icon(
                            Icons.draw_rounded,
                            size: 18,
                            color: AppTheme.onAccentColor(context),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'AI 智能手写画板',
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: ink,
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const GglStatusTag(
                                    label: 'AI 辅导',
                                    variant: WelkBadgeVariant.success,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '拍照/手写识题 · AI 思路引导与板书解题',
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: muted,
                                  fontSize: 12,
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
                          child: GglBlockButton(
                            label: '拍照识题',
                            icon: Icons.photo_camera_rounded,
                            size: WelkButtonSize.small,
                            variant: WelkButtonVariant.primary,
                            onPressed: () =>
                                _openSmartBoard(autoCapture: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GglBlockButton(
                            label: '打开画板',
                            icon: Icons.edit_rounded,
                            size: WelkButtonSize.small,
                            variant: WelkButtonVariant.secondary,
                            onPressed: () => _openSmartBoard(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 4. 当前年级闯关模块（单行紧凑标题 + 关卡信息）
              _buildCurrentGradeChallengeModule(
                context: context,
                colors: colors,
                greeting: greeting,
                totalPassed: totalPassed,
                totalGates: totalGates,
                currentGrade: currentGrade,
                currentRealm: currentRealm,
                nextRealm: nextRealm,
                gradePassedGates: gradePassedGates,
                gradeTotalGates: gradeTotalGates,
                gradePassedChapters: gradePassedChapters,
                gradeTotalChapters: gradeTotalChapters,
                gradePct: gradePct,
                gradeAllCleared: gradeAllCleared,
                activeChapter: activeChapter,
              ),

              // 5. 阶段升级测评提醒
              if (currentRealm.examEligible) ...[
                const SizedBox(height: 10),
                GglComicPanel(
                  color: colors.success
                      .withValues(alpha: colors.isDark ? 0.22 : 0.32),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  shadowOffset: const Offset(1.5, 1.5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${currentRealm.realmName}已达标，可参加升级测评',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ink,
                            fontSize: 12.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GglButton(
                        label: '去测评',
                        compact: true,
                        variant: WelkButtonVariant.success,
                        onPressed: _startAdvanceExam,
                      ),
                    ],
                  ),
                ),
              ],

              // 6. 底部紧凑提示
              const SizedBox(height: 8),
              GestureDetector(
                onTap: currentRealm.examEligible
                    ? () => unawaited(_startAdvanceExam())
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    currentRealm.examEligible
                        ? '${currentRealm.realmName}已满足升级条件，点击参加阶段测评'
                        : '$greeting · 全学段已过 $totalPassed/$totalGates 关',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 11.8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentGradeChallengeModule({
    required BuildContext context,
    required WelkColors colors,
    required String greeting,
    required int totalPassed,
    required int totalGates,
    required GradeItem currentGrade,
    required RealmItem currentRealm,
    required RealmItem? nextRealm,
    required int gradePassedGates,
    required int gradeTotalGates,
    required int gradePassedChapters,
    required int gradeTotalChapters,
    required double gradePct,
    required bool gradeAllCleared,
    required ChapterCard? activeChapter,
  }) {
    final ink = AppTheme.inkColor(context);
    final muted = AppTheme.mutedText(context);
    final accent = AppTheme.accentColor(context);
    final surface = AppTheme.surfaceColor(context);
    final pctInt = (gradePct * 100).round().clamp(0, 100);

    return GglComicPanel(
      color: surface,
      padding: const EdgeInsets.all(12),
      onTap: () => unawaited(_openGradeChapters(currentGrade)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 模块标题行（标题为当前年级，单行绝不换行）
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: AppTheme.insetBoxDecoration(
                  context,
                  color: gradeAllCleared ? colors.success : accent,
                  borderColor: AppTheme.isForui(context)
                      ? (gradeAllCleared ? colors.success : accent)
                      : null,
                  radius: 10,
                ),
                child: Icon(
                  gradeAllCleared
                      ? Icons.emoji_events_rounded
                      : Icons.flag_rounded,
                  size: 19,
                  color: gradeAllCleared
                      ? colors.onFill(colors.success)
                      : AppTheme.onAccentColor(context),
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
                          currentGrade.gradeName,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                            fontFamilyFallback: AppTheme.cjkFontFallback,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GglStatusTag(
                          label: gradeAllCleared ? '已通关' : '数学闯关',
                          variant: gradeAllCleared
                              ? WelkBadgeVariant.success
                              : WelkBadgeVariant.defaultStyle,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$gradeTotalChapters 章 $gradeTotalGates 关 · 已过 $gradePassedGates 关',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '全部关卡',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 17, color: accent),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 年级总进度条
          Row(
            children: [
              Expanded(
                child: GglProgressBar(
                  percent: gradePct,
                  height: 9,
                  fillColor: gradeAllCleared ? colors.success : null,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$pctInt%',
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: ink,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 关卡详情内容区
          if (_loadingGradeChapters && activeChapter == null)
            const GglSkeletonBox(width: double.infinity, height: 68)
          else if (gradeAllCleared) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: AppTheme.insetBoxDecoration(
                context,
                color: colors.success.withValues(
                  alpha: colors.isDark ? 0.16 : 0.18,
                ),
                radius: 9,
              ),
              child: Row(
                children: [
                  Icon(Icons.workspace_premium_rounded, color: ink, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      nextRealm != null
                          ? '${currentGrade.gradeName}已全部通关，可晋级${nextRealm.realmName}！'
                          : '${currentGrade.gradeName}已全部通关，随时可回刷巩固！',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GglBlockButton(
                    label: '回顾本年级',
                    variant: WelkButtonVariant.secondary,
                    size: WelkButtonSize.small,
                    onPressed: () => unawaited(_openGradeChapters(currentGrade)),
                  ),
                ),
                if (nextRealm != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: GglBlockButton(
                      label: '晋级${nextRealm.realmName}',
                      icon: Icons.rocket_launch_rounded,
                      variant: WelkButtonVariant.success,
                      size: WelkButtonSize.small,
                      onPressed: () => unawaited(
                        _handlePromoteNextGrade(currentGrade, nextRealm),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: AppTheme.insetBoxDecoration(
                context,
                color: AppTheme.mutedSurfaceColor(context),
                radius: 9,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GglStatusTag(
                        label: activeChapter != null
                            ? '第$_activeChapterSeq章'
                            : '待开启',
                        variant: WelkBadgeVariant.info,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          activeChapter?.name ?? '${currentGrade.gradeName}章节闯关',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (activeChapter != null)
                        Text(
                          '${activeChapter.passedCount}/${activeChapter.totalGates}关',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: muted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    activeChapter != null
                        ? _activeGateSubtitle(activeChapter)
                        : '已通 $gradePassedChapters/$gradeTotalChapters 章 · 点击进入闯关',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                  if (activeChapter != null && activeChapter.totalGates > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (var i = 0; i < activeChapter.totalGates; i++) ...[
                          if (i > 0) const SizedBox(width: 5),
                          Expanded(
                            child: _GateMiniChip(
                              gateNo: i + 1,
                              passed: i < activeChapter.passedCount,
                              active: i == activeChapter.passedCount,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GglBlockButton(
                    label: '章节地图',
                    icon: Icons.map_outlined,
                    variant: WelkButtonVariant.secondary,
                    size: WelkButtonSize.small,
                    onPressed: () => unawaited(_openGradeChapters(currentGrade)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GglBlockButton(
                    label: gradePassedGates > 0 ? '继续闯关' : '开始闯关',
                    icon: Icons.play_arrow_rounded,
                    variant: WelkButtonVariant.primary,
                    size: WelkButtonSize.small,
                    onPressed: () =>
                        unawaited(_handleContinuePractice(currentGrade)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _GateMiniChip extends StatelessWidget {
  const _GateMiniChip({
    required this.gateNo,
    required this.passed,
    required this.active,
  });

  final int gateNo;
  final bool passed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final accent = AppTheme.accentColor(context);
    final ink = AppTheme.inkColor(context);
    final muted = AppTheme.mutedText(context);
    final bg = passed
        ? colors.success
        : active
            ? accent
            : AppTheme.surfaceColor(context);
    final fg = passed
        ? colors.onFill(colors.success)
        : active
            ? AppTheme.onAccentColor(context)
            : muted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: AppTheme.insetBoxDecoration(
        context,
        color: bg,
        borderColor:
            AppTheme.isForui(context) && (passed || active) ? bg : null,
        radius: 7,
        width: AppTheme.isForui(context) ? 1 : 1.3,
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              passed
                  ? Icons.check_rounded
                  : active
                      ? Icons.bolt_rounded
                      : Icons.lock_open_rounded,
              size: 11,
              color: fg,
            ),
            const SizedBox(width: 2),
            Text(
              '第$gateNo关',
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: passed || active ? fg : ink,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
