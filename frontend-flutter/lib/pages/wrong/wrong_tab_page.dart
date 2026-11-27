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
import 'wrong_export_preview_page.dart';

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

  String _currentFilterLabel(UserProvider user) {
    if (_selectedFilter == 'all') return '全部';
    if (_selectedFilter == 'high') return '高频';
    for (final r in user.realms) {
      if (r.realmCode == _selectedFilter) return r.realmName;
    }
    return '全部';
  }

  Future<void> _openExportPreview() async {
    if (_displayedTotal == 0) {
      GglFeedback.warning(context, '当前筛选下暂无可导出的错题');
      return;
    }
    final user = context.read<UserProvider>();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WrongExportPreviewPage(
          initialFilter: _selectedFilter,
          filterLabel: _currentFilterLabel(user),
          initialItems: _displayedList,
        ),
      ),
    );
  }

  void _openFilterSheet(UserProvider user) {
    final colors = WelkTheme.of(context).resolveColors(context);
    showGglBottomSheet<void>(
      context: context,
      title: '筛选错题',
      closeLabel: '完成',
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            GglPillChip(
              label: '全部',
              selected: _selectedFilter == 'all',
              onTap: () {
                _selectFilter('all');
                Navigator.of(sheetCtx).pop();
              },
            ),
            GglPillChip(
              label: '高频',
              selected: _selectedFilter == 'high',
              selectedColor: colors.error,
              onTap: () {
                _selectFilter('high');
                Navigator.of(sheetCtx).pop();
              },
            ),
            for (final r in user.realms)
              GglPillChip(
                label: r.realmName,
                selected: _selectedFilter == r.realmCode,
                onTap: () {
                  _selectFilter(r.realmCode);
                  Navigator.of(sheetCtx).pop();
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
    final titleText = !user.isAuthenticated
        ? '错题本'
        : _selectedFilter == 'all'
            ? (_displayedTotal > 0 ? '错题本 ($_displayedTotal)' : '错题本')
            : '错题本 · ${_currentFilterLabel(user)} ($_displayedTotal)';

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: GglAppBar(
        title: titleText,
        centerTitle: false,
        actions: user.isAuthenticated
            ? [
                GglIconButton(
                  icon: _selectedFilter == 'all'
                      ? Icons.filter_list_rounded
                      : Icons.filter_alt_rounded,
                  label: '筛选错题',
                  onPressed: () => _openFilterSheet(user),
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          // 顶部极简三按钮操作栏（省空间，直达核心动作）
          if (user.isAuthenticated)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: AppTheme.barDecoration(context, bottomBorder: true),
              child: Row(
                children: [
                  Expanded(
                    child: GglBlockButton(
                      label: '错题重做',
                      icon: Icons.refresh_rounded,
                      size: WelkButtonSize.small,
                      variant: WelkButtonVariant.primary,
                      onPressed: _displayedTotal == 0 ? null : _startRedo,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GglBlockButton(
                      label: '导出 Word',
                      icon: Icons.description_outlined,
                      size: WelkButtonSize.small,
                      variant: WelkButtonVariant.info,
                      onPressed:
                          _displayedTotal == 0 ? null : _openExportPreview,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GglButton(
                    label: '清空',
                    icon: Icons.delete_outline_rounded,
                    size: WelkButtonSize.small,
                    variant: WelkButtonVariant.secondary,
                    compact: true,
                    onPressed: _total == 0 ? null : _clearAll,
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshIfAuth,
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                children: [
                  if (!user.isAuthenticated)
                    GglComicPanel(
                      padding: const EdgeInsets.symmetric(
                        vertical: 36,
                        horizontal: 22,
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            alignment: Alignment.center,
                            decoration: AppTheme.badgeCircleDecoration(
                              context,
                              color: AppTheme.accentColor(context),
                            ),
                            child: Icon(
                              Icons.menu_book_rounded,
                              size: 30,
                              color: AppTheme.onAccentColor(context),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            '登录后解锁专属错题本',
                            style: TextStyle(
                              color: AppTheme.inkColor(context),
                              fontSize: 17.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '每次闯关与解答的错题将自动收录，支持错题重做、掌握消错及 A4 Word 导出。',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.mutedText(context),
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 18),
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
                    const SizedBox(height: 10),
                    const GglCardSkeleton(lines: 4),
                    const SizedBox(height: 10),
                    const GglCardSkeleton(lines: 4),
                  ] else if (_displayedList.isEmpty)
                    GglComicPanel(
                      padding: const EdgeInsets.symmetric(
                        vertical: 36,
                        horizontal: 20,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 38,
                            color: colors.successHover,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _selectedFilter == 'high'
                                ? '暂无高频错题'
                                : '当前暂无待巩固错题',
                            style: TextStyle(
                              color: colors.ink,
                              fontSize: 15,
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
    final ink = AppTheme.inkColor(context);

    return GglComicPanel(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GglStatusTag(
                label: item.displayTypeLabel,
                variant: item.isEssay
                    ? WelkBadgeVariant.info
                    : WelkBadgeVariant.defaultStyle,
                neutral: !item.isEssay,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${item.realmName} · ${item.chapterName} · ${item.gateName}',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.mutedText(context),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GglStatusTag(
                label: '错${item.wrongCount}次',
                variant: item.wrongCount >= 2
                    ? WelkBadgeVariant.error
                    : WelkBadgeVariant.warning,
              ),
            ],
          ),
          const SizedBox(height: 8),
          MathText(
            item.stem,
            style: TextStyle(
              color: ink,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (item.diagram != null ||
              (item.imageUrl != null && item.imageUrl!.trim().isNotEmpty)) ...[
            const SizedBox(height: 8),
            QuestionFigureCard(
              diagram: item.diagram,
              imageUrl: item.imageUrl,
              compact: true,
            ),
          ],
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: AppTheme.insetBoxDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const GglStatusTag(
                      label: '正解',
                      variant: WelkBadgeVariant.success,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: MathText(
                        item.formattedCorrectAnswer(),
                        style: TextStyle(
                          color: ink,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (item.analysis.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  MathText(
                    item.analysis,
                    style: TextStyle(
                      color: AppTheme.mutedText(context),
                      fontSize: 12.5,
                    ),
                  ),
                ],
                if (item.lastAnswerImageUrl != null &&
                    item.lastAnswerImageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => ImagePreviewPage.open(
                      context,
                      imageUrl: item.lastAnswerImageUrl!,
                      title: '手写作答预览',
                    ),
                    child: Container(
                      width: 96,
                      height: 68,
                      decoration: AppTheme.insetBoxDecoration(
                        context,
                        color: Colors.white,
                        radius: 8,
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
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                FormatUtils.formatDateTimeShort(item.lastWrongAt),
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: AppTheme.mutedText(context),
                  fontSize: 11.5,
                ),
              ),
              GglButton(
                label: '标为已掌握',
                compact: true,
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
