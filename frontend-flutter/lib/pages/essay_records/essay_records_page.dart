import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../../app/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/format_utils.dart';
import '../../models/models.dart';
import '../../services/guoguanla_api.dart';
import '../../widgets/ggl_comic_panel.dart';
import '../../widgets/ggl_feedback.dart';
import '../../widgets/ggl_skeleton.dart';
import '../../widgets/ggl_skin_widgets.dart';
import '../../widgets/image_preview_page.dart';
import '../../widgets/math_text.dart';
import '../../widgets/question_figure_card.dart';

class EssayRecordsPage extends StatefulWidget {
  const EssayRecordsPage({super.key});

  @override
  State<EssayRecordsPage> createState() => _EssayRecordsPageState();
}

class _EssayRecordsPageState extends State<EssayRecordsPage> {
  bool _loading = true;
  bool _clearing = false;
  int _pageNum = 1;
  int _total = 0;
  List<EssayAnswerRecord> _list = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchRecords(true));
  }

  Future<void> _fetchRecords(bool reset) async {
    if (reset) _pageNum = 1;
    setState(() => _loading = true);
    try {
      final res = await context.read<GuoguanlaApi>().getEssayAnswers(
            pageNum: _pageNum,
            pageSize: 10,
          );
      if (mounted) {
        setState(() {
          _total = res.total;
          _list = reset ? res.records : [..._list, ...res.records];
        });
      }
    } catch (e) {
      if (mounted) {
        GglFeedback.error(context, friendlyErrorMessage(e, '获取解答记录失败'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _list.length >= _total) return;
    _pageNum++;
    await _fetchRecords(false);
  }

  Future<void> _handleClearAll() async {
    if (_total == 0 || _clearing) return;
    final confirmed = await GglFeedback.confirm(
      context,
      title: '清空解答作答记录',
      content: '确定永久清空所有解答作答记录吗？清空后数据库将彻底删除，不可恢复。',
      yesText: '永久清空',
      noText: '取消',
      variant: WelkDialogVariant.error,
    );
    if (!confirmed || !mounted) return;

    setState(() => _clearing = true);
    try {
      await context.read<GuoguanlaApi>().clearEssayAnswers();
      if (mounted) {
        setState(() {
          _list = const [];
          _total = 0;
          _pageNum = 1;
        });
        GglFeedback.success(context, '已永久清空');
      }
    } catch (e) {
      if (mounted) {
        GglFeedback.error(context, friendlyErrorMessage(e, '清空失败'));
      }
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: const GglAppBar(
        title: '我的解答作答记录',
        showBack: true,
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchRecords(true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            if (_loading && _list.isEmpty) ...[
              const GglCardSkeleton(lines: 2),
              const SizedBox(height: 12),
              const GglCardSkeleton(lines: 3, showMedia: true),
              const SizedBox(height: 12),
              const GglCardSkeleton(lines: 3, showMedia: true),
            ] else ...[
              // Summary bar with permanent clear button
              GglComicPanel(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '共 $_total 条作答记录',
                            style: TextStyle(
                              color: colors.ink,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '清空后将从数据库永久删除且不可恢复',
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
                      label: _clearing ? '清空中...' : '清空',
                      variant: WelkButtonVariant.error,
                      onPressed:
                          _total == 0 || _clearing ? null : _handleClearAll,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (_list.isEmpty)
                GglComicPanel(
                  padding: const EdgeInsets.symmetric(
                    vertical: 42,
                    horizontal: 20,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.draw_outlined,
                        size: 40,
                        color: AppTheme.mutedText(context),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '暂无解答题手写作答记录',
                        style: TextStyle(
                          color: colors.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '快去挑战拓展关或压轴关的解答题吧！',
                        style: TextStyle(
                          color: AppTheme.mutedText(context),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                for (final item in _list) _buildRecordCard(context, colors, item),
                if (_list.length < _total)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Center(
                      child: GglButton(
                        label: _loading
                            ? '加载中...'
                            : '加载更多 (${_list.length} / $_total)',
                        variant: WelkButtonVariant.secondary,
                        onPressed: _loading ? null : _loadMore,
                      ),
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(
    BuildContext context,
    WelkColors colors,
    EssayAnswerRecord item,
  ) {
    final (String statusLabel, WelkBadgeVariant statusVariant) =
        switch (item.teacherStatus) {
      1 => ('老师已批通过', WelkBadgeVariant.success),
      2 => ('老师批：待订正', WelkBadgeVariant.error),
      _ => ('待老师批改', WelkBadgeVariant.info),
    };

    final sourceParts = <String>[
      if (item.realmName.isNotEmpty) item.realmName,
      if (item.chapterName.isNotEmpty) item.chapterName else '解答作答',
      if (item.gateName.isNotEmpty) item.gateName,
    ];

    return GglComicPanel(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sourceParts.join(' · '),
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
              GglStatusTag(label: statusLabel, variant: statusVariant),
            ],
          ),
          const SizedBox(height: 10),
          MathText(
            item.stem,
            style: TextStyle(
              color: colors.ink,
              fontSize: 15,
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
          if (item.answerText.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: AppTheme.insetBoxDecoration(context, radius: 8),
              child: Text(
                '文字补充：${item.answerText}',
                style: TextStyle(
                  color: AppTheme.inkColor(context),
                  fontSize: 13,
                ),
              ),
            ),
          ],
          if (item.answerImageUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '我的手写作答（点击放大）：',
              style: TextStyle(
                color: AppTheme.mutedText(context),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            _PreviewThumb(
              imageUrl: item.answerImageUrl,
              title: '我的手写作答',
            ),
          ],
          if (item.teacherImageUrl != null &&
              item.teacherImageUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '老师画板批注（点击放大）：',
              style: TextStyle(
                color: AppTheme.mutedText(context),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            _PreviewThumb(
              imageUrl: item.teacherImageUrl!,
              title: '老师画板批注',
            ),
          ],
          if (item.referenceAnswer.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: AppTheme.insetBoxDecoration(
                context,
                color: colors.success.withValues(
                  alpha: colors.isDark ? 0.16 : 0.22,
                ),
                radius: 8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '参考答案',
                    style: TextStyle(
                      color: AppTheme.inkColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  MathText(
                    item.referenceAnswer,
                    style: TextStyle(
                      color: AppTheme.inkColor(context),
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (item.teacherComment.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '老师点评：${item.teacherComment}',
              style: TextStyle(
                color: colors.ink,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            FormatUtils.formatDateTimeShort(item.createdAt),
            style: TextStyle(
              color: AppTheme.mutedText(context),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewThumb extends StatelessWidget {
  const _PreviewThumb({required this.imageUrl, required this.title});

  final String imageUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          ImagePreviewPage.open(context, imageUrl: imageUrl, title: title),
      child: Container(
        width: double.infinity,
        height: 170,
        decoration: AppTheme.insetBoxDecoration(
          context,
          color: Colors.white,
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Center(
            child: Text('图片加载失败', style: TextStyle(color: Colors.black54)),
          ),
        ),
      ),
    );
  }
}
