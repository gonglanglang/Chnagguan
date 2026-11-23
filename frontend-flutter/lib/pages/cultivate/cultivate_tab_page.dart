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
import '../video_detail/video_detail_page.dart';

class CultivateTabPage extends StatefulWidget {
  const CultivateTabPage({super.key, required this.refreshSignal});

  final ValueListenable<int> refreshSignal;

  @override
  State<CultivateTabPage> createState() => _CultivateTabPageState();
}

class _CultivateTabPageState extends State<CultivateTabPage> {
  final PageController _featuredController = PageController(
    viewportFraction: 0.88,
  );
  final ScrollController _scrollController = ScrollController();

  String _selectedRealm = '';
  bool _loading = true;
  int _pageNum = 1;
  static const int _pageSize = 12;
  int _total = 0;
  List<VideoSeriesItem> _list = const [];
  List<VideoSeriesItem> _featuredList = const [];
  int _featuredIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal.addListener(_onRefreshSignal);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAll());
  }

  @override
  void dispose() {
    widget.refreshSignal.removeListener(_onRefreshSignal);
    _scrollController.dispose();
    _featuredController.dispose();
    super.dispose();
  }

  void _onRefreshSignal() {
    if (mounted) unawaited(_refreshAll());
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 160) {
      if (!_loading && _list.length < _total) {
        _pageNum++;
        unawaited(_fetchSeries(false));
      }
    }
  }

  Future<void> _refreshAll() async {
    unawaited(context.read<UserProvider>().loadHomeSummary().catchError((_) =>
        HomeSummary(
          guestModeEnabled: true,
          appNotice: '',
          grades: GradeItem.fallbacks,
          realms: RealmItem.defaults,
        )));
    if (_selectedRealm.isNotEmpty) {
      unawaited(_fetchFeatured());
    }
    await _fetchSeries(true);
  }

  Future<void> _fetchFeatured() async {
    try {
      final res = await context
          .read<GuoguanlaApi>()
          .getVideoSeriesPage(pageNum: 1, pageSize: 5);
      if (mounted) {
        setState(() {
          _featuredList = res.records;
          if (_featuredIndex >= _featuredList.length) _featuredIndex = 0;
        });
      }
    } catch (_) {
      // Ignore secondary fetch error
    }
  }

  Future<void> _fetchSeries(bool reset) async {
    if (reset) _pageNum = 1;
    setState(() => _loading = true);
    try {
      final res = await context.read<GuoguanlaApi>().getVideoSeriesPage(
            realmCode: _selectedRealm.isEmpty ? null : _selectedRealm,
            pageNum: _pageNum,
            pageSize: _pageSize,
          );
      if (!mounted) return;
      setState(() {
        _total = res.total;
        _list = reset ? res.records : [..._list, ...res.records];
        if (_selectedRealm.isEmpty && reset) {
          _featuredList = res.records.take(5).toList();
          if (_featuredIndex >= _featuredList.length) _featuredIndex = 0;
        }
      });
    } catch (e) {
      if (mounted) {
        GglFeedback.error(context, friendlyErrorMessage(e, '加载教学视频失败'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectRealm(String code) {
    setState(() {
      _selectedRealm = code;
      _list = const [];
    });
    unawaited(_fetchSeries(true));
  }

  Future<void> _openCourseDrawer(VideoSeriesItem series) async {
    final api = context.read<GuoguanlaApi>();
    var drawerLoading = true;
    var lessons = <VideoLessonItem>[];
    var selectedLessonId = 0;
    var startedFetch = false;

    await showWelkDrawer<void>(
      context: context,
      position: WelkDrawerPosition.bottom,
      closeOnTapOutside: true,
      builder: (drawerCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            if (!startedFetch) {
              startedFetch = true;
              api.getVideoSeriesDetail(series.id).then((detail) {
                if (!ctx.mounted) return;
                setModalState(() {
                  lessons = detail.lessons;
                  selectedLessonId =
                      lessons.isNotEmpty ? lessons.first.id : 0;
                  drawerLoading = false;
                });
              }).catchError((Object e) {
                if (!ctx.mounted) return;
                setModalState(() => drawerLoading = false);
                if (mounted) {
                  GglFeedback.error(
                    context,
                    friendlyErrorMessage(e, '加载课程目录失败'),
                  );
                }
              });
            }

            final colors = WelkTheme.of(ctx).resolveColors(ctx);
            return WelkDrawer(
              title: Text(series.title),
              closeLabel: '关闭',
              onClose: () => Navigator.of(drawerCtx).pop(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${series.realmName.isNotEmpty ? series.realmName : '综合课程'} · 共 ${lessons.isNotEmpty ? lessons.length : series.lessonCount} 节',
                    style: TextStyle(
                      color: AppTheme.mutedText(ctx),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (drawerLoading) ...[
                    const GglSkeletonBox(width: double.infinity, height: 42),
                    const SizedBox(height: 8),
                    const GglSkeletonBox(width: double.infinity, height: 42),
                    const SizedBox(height: 8),
                    const GglSkeletonBox(width: double.infinity, height: 42),
                  ] else if (lessons.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colors.muted,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.outline, width: 1.5),
                      ),
                      child: Text(
                        '该课程暂未添加课时，点击下方按钮可查看课程简介',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.mutedText(ctx),
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    for (var i = 0; i < lessons.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GglComicPanel(
                          color: selectedLessonId == lessons[i].id
                              ? colors.accent.withValues(
                                  alpha: colors.isDark ? 0.28 : 0.38,
                                )
                              : colors.paper,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          shadowOffset: const Offset(2, 2),
                          onTap: () => setModalState(
                            () => selectedLessonId = lessons[i].id,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.play_circle_outline_rounded,
                                size: 18,
                                color: colors.ink,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '第 ${i + 1} 节 · ${lessons[i].title}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.ink,
                                    fontSize: 14,
                                    fontWeight: selectedLessonId == lessons[i].id
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                FormatUtils.formatDuration(
                                    lessons[i].durationSec),
                                style: TextStyle(
                                  color: AppTheme.mutedText(ctx),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  const SizedBox(height: 12),
                  GglBlockButton(
                    label: '开始学习',
                    size: WelkButtonSize.large,
                    onPressed: () {
                      Navigator.of(drawerCtx).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => VideoDetailPage(
                            seriesId: series.id,
                            initialLessonId:
                                selectedLessonId > 0 ? selectedLessonId : null,
                          ),
                        ),
                      );
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

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final realms = context.watch<UserProvider>().realms;
    final showInitialSkeleton =
        _loading && _list.isEmpty && _featuredList.isEmpty;

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: const WelkAppBar(
        title: '修炼课堂',
        layout: WelkAppBarLayout.comicStrip,
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 28),
          children: [
            if (showInitialSkeleton) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    GglSectionLabel(title: '本周精选'),
                    GglCardSkeleton(lines: 2, showMedia: true),
                    GglSectionLabel(title: '全部课程'),
                    GglCardSkeleton(lines: 2),
                    SizedBox(height: 10),
                    GglCardSkeleton(lines: 2),
                  ],
                ),
              ),
            ] else ...[
              // Featured Carousel
              if (_featuredList.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: GglSectionLabel(title: '本周精选'),
                ),
                SizedBox(
                  height: 236,
                  child: PageView.builder(
                    controller: _featuredController,
                    itemCount: _featuredList.length,
                    onPageChanged: (idx) =>
                        setState(() => _featuredIndex = idx),
                    itemBuilder: (context, idx) {
                      final item = _featuredList[idx];
                      return Padding(
                        padding: const EdgeInsets.only(right: 12, bottom: 6),
                        child: GglComicPanel(
                          padding: EdgeInsets.zero,
                          onTap: () => _openCourseDrawer(item),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (item.coverImageUrl.isNotEmpty)
                                      Image.network(
                                        item.coverImageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            _CoursePlaceholder(colors: colors),
                                      )
                                    else
                                      _CoursePlaceholder(colors: colors),
                                    Positioned(
                                      right: 10,
                                      bottom: 8,
                                      child: GglStatusTag(
                                        label: '${item.lessonCount} 课时',
                                        variant: WelkBadgeVariant.defaultStyle,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.ink,
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${item.realmName.isNotEmpty ? item.realmName : '专题课程'} · ${item.intro.isNotEmpty ? item.intro : '名师精讲 · 配套讲义'}',
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
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_featuredList.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _featuredList.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: i == _featuredIndex ? 20 : 7,
                            height: 7,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: i == _featuredIndex
                                  ? colors.accent
                                  : colors.muted,
                              borderRadius: BorderRadius.circular(4),
                              border:
                                  Border.all(color: colors.outline, width: 1.2),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],

              // All courses section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const GglSectionLabel(title: '全部课程'),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GglPillChip(
                              label: '全部',
                              selected: _selectedRealm.isEmpty,
                              onTap: () => _selectRealm(''),
                            ),
                          ),
                          for (final r in realms)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GglPillChip(
                                label: r.realmName,
                                selected: _selectedRealm == r.realmCode,
                                onTap: () => _selectRealm(r.realmCode),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_loading && _list.isEmpty) ...[
                      const GglCardSkeleton(lines: 2),
                      const SizedBox(height: 10),
                      const GglCardSkeleton(lines: 2),
                    ] else if (_list.isEmpty)
                      GglComicPanel(
                        padding: const EdgeInsets.symmetric(
                          vertical: 42,
                          horizontal: 20,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.video_library_outlined,
                              size: 38,
                              color: AppTheme.mutedText(context),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '暂无教学课程',
                              style: TextStyle(
                                color: colors.ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '切换其他境界查看，或等待教研老师上传新课',
                              style: TextStyle(
                                color: AppTheme.mutedText(context),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      for (final item in _list)
                        GglComicPanel(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          shadowOffset: const Offset(2, 2),
                          onTap: () => _openCourseDrawer(item),
                          child: Row(
                            children: [
                              Container(
                                width: 108,
                                height: 70,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: colors.outline,
                                    width: 1.6,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: item.coverImageUrl.isNotEmpty
                                    ? Image.network(
                                        item.coverImageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            _CoursePlaceholder(colors: colors),
                                      )
                                    : _CoursePlaceholder(colors: colors),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.ink,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Text(
                                          item.realmName.isNotEmpty
                                              ? item.realmName
                                              : '全境界',
                                          style: TextStyle(
                                            color: AppTheme.mutedText(context),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const GglStatusTag(
                                          label: '讲师笔记',
                                          variant: WelkBadgeVariant.success,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '${item.lessonCount} 节 · ${item.intro.isNotEmpty ? item.intro : '名师讲解 · 点击选集'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppTheme.mutedText(context),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Center(
                          child: Text(
                            _loading
                                ? '正在加载更多课程...'
                                : '已显示全部 $_total 门课程',
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
            ],
          ],
        ),
      ),
    );
  }
}

class _CoursePlaceholder extends StatelessWidget {
  const _CoursePlaceholder({required this.colors});

  final WelkColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.accent.withValues(alpha: 0.3),
      alignment: Alignment.center,
      child: Icon(
        Icons.play_circle_outline_rounded,
        size: 32,
        color: colors.ink,
      ),
    );
  }
}
