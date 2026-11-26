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
      final orderedRealms =
          user.realms.isNotEmpty ? user.realms : RealmItem.defaults;
      final startIdx =
          orderedRealms.indexWhere((r) => r.realmCode == realmCode);
      final candidateCodes = <String>[
        realmCode,
        if (startIdx >= 0)
          for (var i = startIdx + 1; i < orderedRealms.length; i++)
            orderedRealms[i].realmCode,
      ];

      List<ChapterCard> chosen = const [];
      for (final code in candidateCodes) {
        final res = await api.getChaptersByRealm(
          code,
          guestPassedIds: user.activeGuestIds,
        );
        if (chosen.isEmpty && res.isNotEmpty) {
          chosen = res;
        }
        final hasUnfinished = res.any(
          (c) => c.totalGates > 0 && c.passedCount < c.totalGates,
        );
        if (hasUnfinished) {
          chosen = res;
          break;
        }
      }
      if (!mounted) return;
      setState(() => _heroChapters = chosen);
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
    final activeRealm = user.currentRealm.realmCode;
    await _fetchHeroChapters(activeRealm);

    if (mounted) {
      unawaited(_maybeShowVersionAnnouncement());
    }
  }

  static const String _defaultNoticeText =
      '1. 全年级同步闯关：初一至高三 51 章 204 关自由开放练习，支持基础关 → 下一关 → 下一章 → 跨年级连续闯关；\n'
      '2. 精绘数学矢量配图：526 道几何、函数、统计与立体几何题目均配有清晰矢量图，点击可全屏缩放；\n'
      '3. AI 智能手写画板：支持拍照与手写识题，自动矢量重绘几何配图并提供思路引导、过程诊断与解题核对；\n'
      '4. 错题本高效巩固：闯关错题自动收录，重做答对即标记掌握并移出。';

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
        : '同学';
    final greeting = '${FormatUtils.greetingPrefix(DateTime.now())}，$displayName';
    final noticeText = _resolveNoticeText(user);
    final noticePreview = _noticePreviewLine(noticeText);
    final ink = AppTheme.inkColor(context);
    final surface = AppTheme.surfaceColor(context);
    final accent = AppTheme.accentColor(context);

    final hero = _heroChapter;
    final heroPct = (hero != null && hero.totalGates > 0)
        ? ((hero.passedCount / hero.totalGates) * 100).round().clamp(0, 100)
        : 0;

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: const GglAppBar(
        title: '过关啦',
        centerTitle: false,
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
              // Greeting Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ink,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '当前阶段',
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
              const SizedBox(height: 14),

              // Notice strip
              GglComicPanel(
                color: colors.warning
                    .withValues(alpha: colors.isDark ? 0.2 : 0.24),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shadowOffset: const Offset(2, 2),
                onTap: () => unawaited(_showAnnouncementDialog(noticeText)),
                child: Row(
                  children: [
                    Icon(
                      Icons.campaign_rounded,
                      size: 18,
                      color: ink,
                    ),
                    const SizedBox(width: 8),
                    const GglStatusTag(
                      label: '学习公告',
                      variant: WelkBadgeVariant.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        noticePreview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: ink,
                    ),
                  ],
                ),
              ),

              // AI Smart Handwriting Board Feature Card (v2.0 Major Feature)
              const SizedBox(height: 12),
              GglComicPanel(
                color: Color.alphaBlend(
                  accent.withValues(
                    alpha: AppTheme.isForui(context)
                        ? (colors.isDark ? 0.14 : 0.08)
                        : (colors.isDark ? 0.22 : 0.16),
                  ),
                  surface,
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
                          decoration: AppTheme.insetBoxDecoration(
                            context,
                            color: accent,
                            borderColor: AppTheme.isForui(context)
                                ? accent
                                : null,
                          ),
                          child: Icon(
                            Icons.draw_rounded,
                            size: 20,
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
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: ink,
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w900,
                                      ),
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
                  mainAxisExtent: 108,
                ),
                itemCount: grades.length,
                itemBuilder: (context, idx) {
                  final grade = grades[idx];
                  final realm = _findRealmForGrade(user, grade.gradeCode);
                  final isCurrent = realm?.isCurrent ??
                      (grade.gradeCode == currentRealm.gradeCode);
                  final allPassed = realm != null &&
                      realm.gateCount > 0 &&
                      realm.passedGateCount >= realm.gateCount;
                  final statusText = isCurrent
                      ? '当前阶段'
                      : allPassed
                          ? '已通关'
                          : (realm != null && realm.passedGateCount > 0)
                              ? '已过 ${realm.passedGateCount} 关'
                              : '自由刷题';
                  return _GradeGridTile(
                    grade: grade,
                    statusLabel: statusText,
                    isCurrent: isCurrent,
                    isPassed: allPassed,
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
                            '继续学习',
                            style: TextStyle(
                              color: ink,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          GglStatusTag(
                            label: '${hero.realmName} · 第 $_heroChapterSeq 章',
                            variant: WelkBadgeVariant.defaultStyle,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        hero.name,
                        style: TextStyle(
                          color: ink,
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
                              color: ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const GglDivider(verticalPadding: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GglButton(
                            label: '查看地图',
                            variant: WelkButtonVariant.secondary,
                            onPressed: () =>
                                _openChapterMap(hero, _heroChapterSeq),
                          ),
                          const SizedBox(width: 10),
                          GglButton(
                            label: '继续闯关',
                            variant: WelkButtonVariant.primary,
                            onPressed: _handleContinuePractice,
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
                          '${currentRealm.realmName}阶段已达标，可参加阶段升级测评',
                          style: TextStyle(
                            color: ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GglButton(
                        label: '去测评',
                        variant: WelkButtonVariant.success,
                        onPressed: _startAdvanceExam,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Bottom exam tip
              GestureDetector(
                onTap: currentRealm.examEligible
                    ? () => unawaited(_startAdvanceExam())
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    currentRealm.examEligible
                        ? '${currentRealm.realmName}阶段已满足升级条件，点击立即参加阶段升级测评'
                        : '全年级题库已自由开放 · 当前阶段再过 ${currentRealm.examRemainingGates > 0 ? currentRealm.examRemainingGates : 0} 关可解锁阶段升级测评',
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
    required this.statusLabel,
    required this.isCurrent,
    required this.isPassed,
    required this.onTap,
  });

  final GradeItem grade;
  final String statusLabel;
  final bool isCurrent;
  final bool isPassed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final surface = AppTheme.surfaceColor(context);
    final accent = AppTheme.accentColor(context);
    final ink = AppTheme.inkColor(context);
    final isForui = AppTheme.isForui(context);
    final tileColor = isCurrent
        ? Color.alphaBlend(
            accent.withValues(
              alpha: isForui
                  ? (colors.isDark ? 0.16 : 0.10)
                  : (colors.isDark ? 0.20 : 0.18),
            ),
            surface,
          )
        : surface;

    final pillBg = isCurrent
        ? accent
        : isPassed
            ? colors.success
            : AppTheme.mutedSurfaceColor(context);
    final pillFg = isCurrent
        ? AppTheme.onAccentColor(context)
        : isPassed
            ? colors.onFill(colors.success)
            : AppTheme.mutedText(context);

    return GglComicPanel(
      color: tileColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      shadowOffset: const Offset(2, 2),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: AppTheme.insetBoxDecoration(
              context,
              color: pillBg,
              borderColor: isForui && (isCurrent || isPassed)
                  ? pillBg
                  : null,
              radius: 6,
              width: isForui ? 1 : 1.2,
            ),
            child: Text(
              statusLabel,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: pillFg,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            grade.gradeName,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${grade.chapterCount} 章',
            maxLines: 1,
            softWrap: false,
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
