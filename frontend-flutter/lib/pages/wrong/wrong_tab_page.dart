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
import '../../widgets/ggl_skin_widgets.dart';
import '../../widgets/image_preview_page.dart';
import '../../widgets/math_text.dart';
import '../../widgets/question_figure_card.dart';
import '../login/login_page.dart';
import '../quiz/quiz_page.dart';

class WrongTabPage extends StatefulWidget {
  const WrongTabPage({super.key, required this.refreshSignal});

  final ValueListenable<int> refreshSignal;

  @override
  State<WrongTabPage> createState() => _WrongTabPageState();
}

class _WrongTabPageState extends State<WrongTabPage> {
  final ScrollController _scrollController = ScrollController();

  String _selectedFilter = 'all';
  int _pageNum = 1;
  static const int _pageSize = 20;
  int _total = 0;
  List<WrongQuestionItem> _list = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal.addListener(_onRefreshSignal);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshIfAuth());
  }

  @override
  void dispose() {
    widget.refreshSignal.removeListener(_onRefreshSignal);
    _scrollController.dispose();
    super.dispose();
  }

  void _onRefreshSignal() {
    if (mounted) unawaited(_refreshIfAuth());
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 160) {
      if (!_loading && _list.length < _total) {
        _pageNum++;
        unawaited(_fetchList(false));
      }
    }
  }

  Future<void> _refreshIfAuth() async {
    final user = context.read<UserProvider>();
    if (!user.isAuthenticated) {
      if (_list.isNotEmpty || _total != 0) {
        setState(() {
          _list = const [];
          _total = 0;
        });
      }
      return;
    }
    unawaited(user.loadHomeSummary().catchError((_) => HomeSummary(
          guestModeEnabled: true,
          appNotice: '',
          grades: GradeItem.fallbacks,
          realms: RealmItem.defaults,
        )));
    await _fetchList(true);
  }

  List<WrongQuestionItem> get _displayedList {
    if (_selectedFilter == 'high') {
      return _list.where((item) => item.wrongCount >= 2).toList();
    }
    return _list;
  }

  int get _displayedTotal =>
      _selectedFilter == 'high' ? _displayedList.length : _total;

  List<({String realmCode, String realmName, int count})> get _realmTags {
    final map = <String, ({String realmCode, String realmName, int count})>{};
    for (final item in _displayedList) {
      final code = item.realmCode.isNotEmpty ? item.realmCode : 'other';
      final prev = map[code];
      if (prev != null) {
        map[code] = (
          realmCode: code,
          realmName: prev.realmName,
          count: prev.count + 1,
        );
      } else {
        map[code] = (
          realmCode: code,
          realmName: item.realmName.isNotEmpty ? item.realmName : '综合',
          count: 1,
        );
      }
    }
    return map.values.toList();
  }

  Future<void> _fetchList(bool reset) async {
    final user = context.read<UserProvider>();
    if (!user.isAuthenticated) return;
    if (reset) _pageNum = 1;
    setState(() => _loading = true);
    final activeRealmCode =
        (_selectedFilter == 'all' || _selectedFilter == 'high')
            ? null
            : _selectedFilter;
    try {
      final res = await context.read<GuoguanlaApi>().getWrongPage(
            realmCode: activeRealmCode,
            pageNum: _pageNum,
            pageSize: _pageSize,
          );
      if (!mounted) return;
      setState(() {
        _total = res.total;
        _list = reset ? res.records : [..._list, ...res.records];
      });
      if (activeRealmCode == null) {
        user.setWrongCount(res.total);
      }
    } catch (e) {
      if (mounted) {
        GglFeedback.error(context, friendlyErrorMessage(e, '获取错题失败'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectFilter(String key) {
    final prevUsesApi = _selectedFilter != 'all' && _selectedFilter != 'high';
    final nextUsesApi = key != 'all' && key != 'high';
    setState(() => _selectedFilter = key);
    if (prevUsesApi || nextUsesApi || _list.isEmpty) {
      setState(() => _list = const []);
      unawaited(_fetchList(true));
    }
  }

  Future<void> _startRedo() async {
    if (_displayedTotal == 0) return;
    final activeRealmCode =
        (_selectedFilter == 'all' || _selectedFilter == 'high')
            ? null
            : _selectedFilter;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuizPage(
          mode: QuizMode.wrongRedo,
          realmCode: activeRealmCode,
        ),
      ),
    );
    if (mounted) await _refreshIfAuth();
  }

  Future<void> _markMastered(int id) async {
    final ok = await GglFeedback.confirm(
      context,
      title: '确认已掌握',
      content: '标记后将从当前错题本移除。',
      yesText: '已掌握',
      noText: '取消',
      variant: WelkDialogVariant.success,
    );
    if (!ok || !mounted) return;
    try {
      await context.read<GuoguanlaApi>().markWrongMastered(id);
      if (!mounted) return;
      GglFeedback.success(context, '已标为掌握');
      await _fetchList(true);
      if (mounted) unawaited(context.read<UserProvider>().refreshWrongCount());
    } catch (e) {
      if (mounted) {
        GglFeedback.error(context, friendlyErrorMessage(e, '操作失败'));
      }
    }
  }

  Future<void> _clearAll() async {
    if (_total == 0) return;
    final ok = await GglFeedback.confirm(
      context,
      title: '清空错题本',
      content: '确定清空所有待巩固错题记录吗？',
      yesText: '清空',
      noText: '取消',
      variant: WelkDialogVariant.error,
    );
    if (!ok || !mounted) return;
    try {
      await context.read<GuoguanlaApi>().clearWrongAll();
      if (!mounted) return;
      GglFeedback.success(context, '已清空错题本');
      await _fetchList(true);
      if (mounted) context.read<UserProvider>().setWrongCount(0);
    } catch (e) {
      if (mounted) {
        GglFeedback.error(context, friendlyErrorMessage(e, '清空失败'));
      }
    }
  }

  Future<void> _goLogin() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const LoginPage()),
    );
    if (ok == true && mounted) {
      await _refreshIfAuth();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final user = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: const GglAppBar(
        title: '错题本',
        centerTitle: false,
      ),
      body: Column(
        children: [
          if (user.isAuthenticated)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: colors.paper,
                border: Border(
                  bottom: BorderSide(
                    color: colors.outline,
                    width: colors.borderWidth,
                  ),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GglPillChip(
                        label: '全部',
                        selected: _selectedFilter == 'all',
                        onTap: () => _selectFilter('all'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GglPillChip(
                        label: '高频',
                        selected: _selectedFilter == 'high',
                        selectedColor: colors.error,
                        onTap: () => _selectFilter('high'),
                      ),
                    ),
                    for (final r in user.realms)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GglPillChip(
                          label: r.realmName,
                          selected: _selectedFilter == r.realmCode,
                          onTap: () => _selectFilter(r.realmCode),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshIfAuth,
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                children: [
                  if (!user.isAuthenticated)
                    GglComicPanel(
                      padding: const EdgeInsets.symmetric(
                        vertical: 40,
                        horizontal: 24,
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colors.accent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.outline,
                                width: colors.borderWidth,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.shadow,
                                  offset: const Offset(3, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.menu_book_rounded,
                              size: 32,
                              color: colors.onFill(colors.accent),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '登录后解锁专属错题本',
                            style: TextStyle(
                              color: colors.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '每次闯关与解答的错题将自动收录，支持分境界筛选、错题重做与掌握消错。',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.mutedText(context),
                              fontSize: 13.5,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 20),
                          GglButton(
                            label: '登录 / 注册',
                            size: WelkButtonSize.medium,
                            onPressed: _goLogin,
                          ),
                        ],
                      ),
                    )
                  else if (_loading && _list.isEmpty) ...[
                    const GglCardSkeleton(lines: 3),
                    const SizedBox(height: 12),
                    const GglCardSkeleton(lines: 4),
                    const SizedBox(height: 12),
                    const GglCardSkeleton(lines: 4),
                  ] else ...[
                    // Summary comic panel
                    GglComicPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '待巩固',
                                      style: TextStyle(
                                        color: AppTheme.mutedText(context),
                                        fontSize: 12.5,
                                      ),
                                    ),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          '$_displayedTotal',
                                          style: TextStyle(
                                            color: colors.ink,
                                            fontSize: 34,
                                            fontWeight: FontWeight.w800,
                                            height: 1.1,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '题',
                                          style: TextStyle(
                                            color: AppTheme.mutedText(context),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              GglButton(
                                label: '清空',
                                variant: WelkButtonVariant.secondary,
                                onPressed: _total == 0 ? null : _clearAll,
                              ),
                              const SizedBox(width: 8),
                              GglButton(
                                label: '错题重做',
                                variant: WelkButtonVariant.primary,
                                onPressed:
                                    _displayedTotal == 0 ? null : _startRedo,
                              ),
                            ],
                          ),
                          if (_realmTags.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final tag in _realmTags)
                                  GglStatusTag(
                                    label: '${tag.realmName} ${tag.count} 题',
                                    variant: WelkBadgeVariant.info,
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),
                          Text(
                            '重做答对将自动移出错题本，答错则累加错误次数',
                            style: TextStyle(
                              color: AppTheme.mutedText(context),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (_displayedList.isEmpty)
                      GglComicPanel(
                        padding: const EdgeInsets.symmetric(
                          vertical: 42,
                          horizontal: 20,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 40,
                              color: colors.successHover,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _selectedFilter == 'high'
                                  ? '暂无高频错题'
                                  : '当前暂无待巩固错题',
                              style: TextStyle(
                                color: colors.ink,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '继续保持！闯关答错的题目会自动收录到这里',
                              style: TextStyle(
                                color: AppTheme.mutedText(context),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      for (final item in _displayedList)
                        _WrongCard(
                          item: item,
                          onMaster: () => _markMastered(item.id),
                        ),
                      if (_loading)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Center(
                            child: Text(
                              '正在加载更多错题...',
                              style: TextStyle(
                                color: AppTheme.mutedText(context),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                      else if (_list.length >= _total && _total > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Center(
                            child: Text(
                              '已显示全部待巩固错题',
                              style: TextStyle(
                                color: AppTheme.mutedText(context),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WrongCard extends StatelessWidget {
  const _WrongCard({required this.item, required this.onMaster});

  final WrongQuestionItem item;
  final VoidCallback onMaster;

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);

    return GglComicPanel(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item.realmName} · ${item.chapterName} · ${item.gateName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.mutedText(context),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GglStatusTag(
                label: '错 ${item.wrongCount} 次',
                variant: item.wrongCount >= 2
                    ? WelkBadgeVariant.error
                    : WelkBadgeVariant.warning,
              ),
            ],
          ),
          const SizedBox(height: 10),
          MathText(
            item.stem,
            style: TextStyle(
              color: colors.ink,
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (item.diagram != null ||
              (item.imageUrl != null && item.imageUrl!.trim().isNotEmpty)) ...[
            const SizedBox(height: 10),
            QuestionFigureCard(
              diagram: item.diagram,
              imageUrl: item.imageUrl,
              compact: true,
            ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.muted,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.outline, width: 1.4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GglStatusTag(
                  label: '参考答案',
                  variant: WelkBadgeVariant.success,
                ),
                const SizedBox(height: 6),
                MathText(
                  item.formattedCorrectAnswer(),
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.analysis.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  MathText(
                    item.analysis,
                    style: TextStyle(
                      color: AppTheme.mutedText(context),
                      fontSize: 13.5,
                    ),
                  ),
                ],
                if (item.lastAnswerImageUrl != null &&
                    item.lastAnswerImageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => ImagePreviewPage.open(
                      context,
                      imageUrl: item.lastAnswerImageUrl!,
                      title: '手写作答预览',
                    ),
                    child: Container(
                      width: 110,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.outline, width: 1.5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(
                        item.lastAnswerImageUrl!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const GglDivider(verticalPadding: 11),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                FormatUtils.formatDateTimeShort(item.lastWrongAt),
                style: TextStyle(
                  color: AppTheme.mutedText(context),
                  fontSize: 12,
                ),
              ),
              GglButton(
                label: '标为已掌握',
                variant: WelkButtonVariant.success,
                onPressed: onMaster,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
