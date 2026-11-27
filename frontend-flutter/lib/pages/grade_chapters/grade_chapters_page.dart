import 'dart:async';

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
import '../../widgets/ggl_skin_widgets.dart';
import '../../widgets/grade_promotion_helper.dart';
import '../chapter_map/chapter_map_page.dart';
import '../login/login_page.dart';
import '../quiz/quiz_page.dart';

class GradeChaptersPage extends StatefulWidget {
  const GradeChaptersPage({
    super.key,
    required this.grade,
    this.realm,
  });

  final GradeItem grade;
  final RealmItem? realm;

  @override
  State<GradeChaptersPage> createState() => _GradeChaptersPageState();
}

class _GradeChaptersPageState extends State<GradeChaptersPage> {
  bool _loading = true;
  List<ChapterCard> _chapters = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchChapters());
  }

  Future<void> _fetchChapters() async {
    setState(() => _loading = true);
    try {
      final api = context.read<GuoguanlaApi>();
      final user = context.read<UserProvider>();
      final res = await api.getChaptersByGrade(
        widget.grade.gradeCode,
        guestPassedIds: user.activeGuestIds,
      );
      if (!mounted) return;
      setState(() => _chapters = res);
    } catch (e) {
      if (mounted) {
        GglFeedback.error(context, friendlyErrorMessage(e, '加载年级章节失败'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  RealmItem? _resolveRealm(UserProvider user) {
    for (final r in user.realms) {
      if (r.gradeCode == widget.grade.gradeCode) return r;
    }
    return widget.realm;
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
    if (mounted) {
      unawaited(context.read<UserProvider>().loadHomeSummary().catchError((_) =>
          HomeSummary(
            guestModeEnabled: true,
            appNotice: '',
            grades: GradeItem.fallbacks,
            realms: RealmItem.defaults,
          )));
      await _fetchChapters();
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
    if (mounted) {
      await _fetchChapters();
    }
  }

  GradeItem? _findNextGrade(UserProvider user) {
    final grades = user.grades;
    final idx = grades.indexWhere((g) => g.gradeCode == widget.grade.gradeCode);
    if (idx >= 0 && idx + 1 < grades.length) {
      return grades[idx + 1];
    }
    return null;
  }

  Future<void> _promoteToNextGrade(GradeItem nextGrade) async {
    final promoted = await GradePromotionHelper.confirmAndPromoteGrade(
      context,
      currentGradeName: widget.grade.gradeName,
      nextGradeCode: nextGrade.gradeCode,
      nextGradeName: nextGrade.gradeName,
    );
    if (!promoted || !mounted) return;
    final nextRealm = context.read<UserProvider>().findRealmByGradeCode(
          nextGrade.gradeCode,
        );
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GradeChaptersPage(grade: nextGrade, realm: nextRealm),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final user = context.watch<UserProvider>();
    final currentRealm = user.currentRealm;
    final matchedRealm = _resolveRealm(user);
    final isSuppressed = matchedRealm != null &&
        matchedRealm.realmOrder < currentRealm.realmOrder;
    final canExamHere = matchedRealm != null &&
        matchedRealm.isCurrent &&
        currentRealm.examEligible;

    final passedGates = _chapters.fold<int>(0, (sum, c) => sum + c.passedCount);
    final totalGates = _chapters.fold<int>(0, (sum, c) => sum + c.totalGates);
    final passedChapters = _chapters
        .where((c) => c.totalGates > 0 && c.passedCount >= c.totalGates)
        .length;
    final pct = totalGates > 0 ? (passedGates / totalGates).clamp(0.0, 1.0) : 0.0;
    final allCleared = totalGates > 0 && passedGates >= totalGates;
    final nextGrade = _findNextGrade(user);

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: GglAppBar(
        title: '${widget.grade.gradeName} · 章节闯关',
        showBack: true,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchChapters,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            // Grade overview comic card
            GglComicPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  widget.grade.gradeName,
                                  style: TextStyle(
                                    color: colors.ink,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (matchedRealm != null)
                                  GglStatusTag(
                                    label: matchedRealm.isCurrent
                                        ? '当前阶段'
                                        : isSuppressed
                                            ? '回刷巩固'
                                            : '自由刷题',
                                    variant: matchedRealm.isCurrent
                                        ? WelkBadgeVariant.defaultStyle
                                        : WelkBadgeVariant.info,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              matchedRealm != null &&
                                      matchedRealm.description.isNotEmpty
                                  ? matchedRealm.description
                                  : '共 ${_chapters.isNotEmpty ? _chapters.length : widget.grade.chapterCount} 个章节，点击章节进入闯关地图',
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
                          Text(
                            '$passedGates/$totalGates',
                            style: TextStyle(
                              color: colors.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '已通 $passedChapters/${_chapters.length} 章',
                            style: TextStyle(
                              color: AppTheme.mutedText(context),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GglProgressBar(percent: pct),
                ],
              ),
            ),

            if (allCleared && nextGrade != null) ...[
              const SizedBox(height: 12),
              GglComicPanel(
                color: colors.success.withValues(
                  alpha: colors.isDark ? 0.22 : 0.28,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                shadowOffset: const Offset(2, 2),
                child: Row(
                  children: [
                    Icon(
                      Icons.workspace_premium_rounded,
                      color: AppTheme.inkColor(context),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.grade.gradeName}全部 $totalGates 关已闯完！',
                            style: TextStyle(
                              color: AppTheme.inkColor(context),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '准备进入${nextGrade.gradeName}开启新关卡',
                            style: TextStyle(
                              color: AppTheme.mutedText(context),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GglButton(
                      label: '晋级${nextGrade.gradeName}',
                      variant: WelkButtonVariant.success,
                      onPressed: () => unawaited(_promoteToNextGrade(nextGrade)),
                    ),
                  ],
                ),
              ),
            ],

            if (isSuppressed || canExamHere) ...[
              const SizedBox(height: 12),
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
                            ? '回刷巩固 · 正在重温${widget.grade.gradeName}内容，全章节自由开放练习'
                            : '${currentRealm.realmName}阶段已达晋升条件，可参加阶段升级测评',
                        style: TextStyle(
                          color: AppTheme.inkColor(context),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (canExamHere) ...[
                      const SizedBox(width: 8),
                      GglButton(
                        label: '去测评',
                        variant: WelkButtonVariant.success,
                        onPressed: _startAdvanceExam,
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const GglSectionLabel(title: '选择章节'),

            // 2-column chapters grid
            if (_loading && _chapters.isEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 158,
                ),
                itemCount: 6,
                itemBuilder: (_, _) => const GglCardSkeleton(lines: 2),
              )
            else if (_chapters.isEmpty)
              GglComicPanel(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Column(
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 38,
                      color: AppTheme.mutedText(context),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.grade.gradeName}暂未配置章节',
                      style: TextStyle(color: AppTheme.mutedText(context)),
                    ),
                  ],
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 174,
                ),
                itemCount: _chapters.length,
                itemBuilder: (context, idx) {
                  final chapter = _chapters[idx];
                  return _ChapterGridCard(
                    chapter: chapter,
                    seq: idx + 1,
                    onTap: () => _openChapterMap(chapter, idx + 1),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ChapterGridCard extends StatelessWidget {
  const _ChapterGridCard({
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
    final ink = AppTheme.inkColor(context);
    final isForui = AppTheme.isForui(context);
    final isDone =
        chapter.totalGates > 0 && chapter.passedCount >= chapter.totalGates;
    final isInProgress = !isDone && chapter.passedCount > 0;
    final pct = chapter.totalGates > 0
        ? (chapter.passedCount / chapter.totalGates).clamp(0.0, 1.0)
        : 0.0;

    final badgeFill = isDone
        ? (isForui ? const Color(0xFF10B981) : colors.success)
        : isInProgress
            ? AppTheme.accentColor(context)
            : AppTheme.mutedSurfaceColor(context);
    final badgeFg = isDone
        ? (isForui ? Colors.white : colors.onFill(colors.success))
        : isInProgress
            ? AppTheme.onAccentColor(context)
            : AppTheme.mutedText(context);
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
      padding: const EdgeInsets.all(12),
      shadowOffset: const Offset(2.5, 2.5),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: AppTheme.insetBoxDecoration(
                  context,
                  color: badgeFill,
                  borderColor:
                      isForui && (isDone || isInProgress) ? badgeFill : null,
                  radius: 8,
                  width: isForui ? 1 : 1.6,
                ),
                child: Text(
                  FormatUtils.padTwo(seq),
                  style: TextStyle(
                    color: badgeFg,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              GglStatusTag(
                label: statusLabel,
                variant: statusVariant,
                neutral: !isDone && !isInProgress,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            chapter.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ink,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          if (chapter.description.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              chapter.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.mutedText(context),
                fontSize: 11.5,
              ),
            ),
          ],
          const Spacer(),
          GglProgressBar(percent: pct, height: 7),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${chapter.passedCount}/${chapter.totalGates} 关',
                style: TextStyle(
                  color: AppTheme.mutedText(context),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: ink,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
