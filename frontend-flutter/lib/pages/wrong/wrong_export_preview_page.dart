import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../../app/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../models/models.dart';
import '../../providers/user_provider.dart';
import '../../services/docx_share_service.dart';
import '../../services/guoguanla_api.dart';
import '../../widgets/ggl_comic_panel.dart';
import '../../widgets/ggl_feedback.dart';
import '../../widgets/ggl_skeleton.dart';
import '../../widgets/ggl_skin_widgets.dart';
import '../../widgets/math_text.dart';
import '../../widgets/question_figure_card.dart';

/// A4 纸张中的单个排版区块（用于分页引擎与实时预览渲染）。
sealed class A4LayoutBlock {
  const A4LayoutBlock();
}

class A4SectionHeaderBlock extends A4LayoutBlock {
  const A4SectionHeaderBlock(this.title, this.subtitle);
  final String title;
  final String subtitle;
}

class A4QuestionBlock extends A4LayoutBlock {
  const A4QuestionBlock({
    required this.seq,
    required this.item,
    required this.isEssay,
  });

  final int seq;
  final WrongQuestionItem item;
  final bool isEssay;
}

class A4AnswerBlock extends A4LayoutBlock {
  const A4AnswerBlock({
    required this.seq,
    required this.item,
  });

  final int seq;
  final WrongQuestionItem item;
}

class A4PageModel {
  const A4PageModel({
    required this.pageNumber,
    required this.isCoverPage,
    required this.isAnswerPage,
    required this.blocks,
  });

  final int pageNumber;
  final bool isCoverPage;
  final bool isAnswerPage;
  final List<A4LayoutBlock> blocks;
}

/// 纯函数 A4 排版分页引擎：按标准 A4（210×297mm）版心高度自动分栏与分页，确保单题不被跨页截断。
List<A4PageModel> buildWrongA4Pages({
  required List<WrongQuestionItem> items,
  required String answerMode,
  required bool includeDiagrams,
  required bool includeWorkspace,
}) {
  if (items.isEmpty) {
    return const [
      A4PageModel(
        pageNumber: 1,
        isCoverPage: true,
        isAnswerPage: false,
        blocks: [],
      ),
    ];
  }

  final choices = items.where((q) => q.questionFormat != 'ESSAY').toList();
  final essays = items.where((q) => q.questionFormat == 'ESSAY').toList();

  final orderedBlocks = <({A4LayoutBlock block, double weight})>[];
  var seq = 1;
  final numberedItems = <({int seq, WrongQuestionItem item})>[];

  double estimateQuestionWeight(WrongQuestionItem item, bool isEssay) {
    final stemLines = (item.stem.length / 28).ceil().clamp(1, 6);
    var weight = 9.0 + stemLines * 3.6;
    if (!isEssay && item.options.isNotEmpty) {
      final shortOptions = item.options.every((o) => o.length <= 16);
      weight += shortOptions ? 8.5 : item.options.length * 4.0;
    }
    final hasFig = (item.diagram != null && item.diagram!.primitives.isNotEmpty) ||
        (item.imageUrl != null && item.imageUrl!.trim().isNotEmpty);
    if (includeDiagrams && hasFig) {
      weight += 22.0;
    }
    if (includeWorkspace) {
      weight += isEssay ? 21.0 : 8.5;
    }
    if (answerMode == 'INLINE') {
      final ansLen = item.formattedCorrectAnswer().length + item.analysis.length;
      final ansLines = (ansLen / 30).ceil().clamp(1, 6);
      weight += 7.0 + ansLines * 3.2;
    }
    return weight.clamp(12.0, 74.0);
  }

  if (choices.isNotEmpty) {
    orderedBlocks.add((
      block: A4SectionHeaderBlock('一、选择题', '共 ${choices.length} 题'),
      weight: 8.5,
    ));
    for (final q in choices) {
      numberedItems.add((seq: seq, item: q));
      orderedBlocks.add((
        block: A4QuestionBlock(seq: seq, item: q, isEssay: false),
        weight: estimateQuestionWeight(q, false),
      ));
      seq++;
    }
  }

  if (essays.isNotEmpty) {
    final sectionPrefix = choices.isEmpty ? '一、解答题' : '二、解答题';
    orderedBlocks.add((
      block: A4SectionHeaderBlock(sectionPrefix, '共 ${essays.length} 题'),
      weight: 8.5,
    ));
    for (final q in essays) {
      numberedItems.add((seq: seq, item: q));
      orderedBlocks.add((
        block: A4QuestionBlock(seq: seq, item: q, isEssay: true),
        weight: estimateQuestionWeight(q, true),
      ));
      seq++;
    }
  }

  const double pageCapacity = 100.0;
  const double coverHeaderCost = 20.0;
  final pages = <A4PageModel>[];

  var currentBlocks = <A4LayoutBlock>[];
  var used = coverHeaderCost;
  var isCover = true;

  void flushPage({required bool answerPage}) {
    pages.add(
      A4PageModel(
        pageNumber: pages.length + 1,
        isCoverPage: isCover && !answerPage,
        isAnswerPage: answerPage,
        blocks: List<A4LayoutBlock>.unmodifiable(currentBlocks),
      ),
    );
    currentBlocks = <A4LayoutBlock>[];
    used = 0.0;
    isCover = false;
  }

  for (var i = 0; i < orderedBlocks.length; i++) {
    final entry = orderedBlocks[i];
    // 防止章节标题落单在页尾
    var needed = entry.weight;
    if (entry.block is A4SectionHeaderBlock && i + 1 < orderedBlocks.length) {
      needed += orderedBlocks[i + 1].weight;
    }
    if (currentBlocks.isNotEmpty && used + needed > pageCapacity) {
      flushPage(answerPage: false);
    }
    currentBlocks.add(entry.block);
    used += entry.weight;
  }
  if (currentBlocks.isNotEmpty) {
    flushPage(answerPage: false);
  }

  // 文末附答案：新起独立 A4 答案页
  if (answerMode == 'END' && numberedItems.isNotEmpty) {
    currentBlocks = <A4LayoutBlock>[
      const A4SectionHeaderBlock('参考答案与解析', '独立附页 · 方便撕页自查'),
    ];
    used = 12.0;
    for (final pair in numberedItems) {
      final textLen =
          pair.item.formattedCorrectAnswer().length + pair.item.analysis.length;
      final weight = (9.0 + (textLen / 32).ceil().clamp(1, 6) * 3.4)
          .clamp(10.0, 48.0);
      if (currentBlocks.length > 1 && used + weight > pageCapacity) {
        flushPage(answerPage: true);
      }
      currentBlocks.add(A4AnswerBlock(seq: pair.seq, item: pair.item));
      used += weight;
    }
    if (currentBlocks.isNotEmpty) {
      flushPage(answerPage: true);
    }
  }

  return pages;
}

class WrongExportPreviewPage extends StatefulWidget {
  const WrongExportPreviewPage({
    super.key,
    required this.initialFilter,
    required this.filterLabel,
    this.initialItems = const [],
  });

  final String initialFilter;
  final String filterLabel;
  final List<WrongQuestionItem> initialItems;

  @override
  State<WrongExportPreviewPage> createState() => _WrongExportPreviewPageState();
}

class _WrongExportPreviewPageState extends State<WrongExportPreviewPage> {
  static const List<GglTabOption> _answerModeTabs = <GglTabOption>[
    GglTabOption(value: 'END', label: '文末附答案'),
    GglTabOption(value: 'INLINE', label: '逐题解析'),
    GglTabOption(value: 'NONE', label: '纯题无答案'),
  ];

  bool _loading = true;
  bool _exporting = false;
  List<WrongQuestionItem> _allItems = const [];
  final Set<int> _selectedIds = <int>{};

  late String _title;
  String _answerMode = 'END';
  bool _includeDiagrams = true;
  bool _includeWorkspace = true;
  int _currentPageIndex = 0;

  String _cachedSignature = '';
  Uint8List? _cachedDocxBytes;
  String _cachedFileName = '';

  @override
  void initState() {
    super.initState();
    final suffix =
        widget.filterLabel.isNotEmpty && widget.filterLabel != '全部'
            ? '（${widget.filterLabel}）'
            : '';
    _title = '过关啦数学错题巩固卷$suffix';
    if (widget.initialItems.isNotEmpty) {
      _allItems = List<WrongQuestionItem>.from(widget.initialItems);
      _selectedIds.addAll(_allItems.map((e) => e.id));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExportCandidates());
  }

  Future<void> _loadExportCandidates() async {
    setState(() => _loading = true);
    try {
      final activeRealmCode =
          (widget.initialFilter == 'all' || widget.initialFilter == 'high')
              ? null
              : widget.initialFilter;
      final page = await context.read<GuoguanlaApi>().getWrongPage(
            realmCode: activeRealmCode,
            pageNum: 1,
            pageSize: 100,
          );
      if (!mounted) return;
      final filtered = widget.initialFilter == 'high'
          ? page.records.where((e) => e.wrongCount >= 2).toList()
          : page.records;
      setState(() {
        _allItems = filtered;
        _selectedIds
          ..clear()
          ..addAll(filtered.map((e) => e.id));
        _currentPageIndex = 0;
        _invalidateDocxCache();
      });
    } catch (e) {
      if (mounted && _allItems.isEmpty) {
        GglFeedback.error(context, friendlyErrorMessage(e, '加载错题失败'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _invalidateDocxCache() {
    _cachedSignature = '';
    _cachedDocxBytes = null;
    _cachedFileName = '';
  }

  List<WrongQuestionItem> get _selectedItems =>
      _allItems.where((item) => _selectedIds.contains(item.id)).toList();

  String _buildSignature() {
    final ids = _selectedItems.map((e) => e.id).join(',');
    return '$ids|$_title|$_answerMode|$_includeDiagrams|$_includeWorkspace';
  }

  Future<({Uint8List bytes, String fileName})?> _ensureDocxGenerated() async {
    final chosen = _selectedItems;
    if (chosen.isEmpty) {
      GglFeedback.warning(context, '请至少勾选 1 道错题再导出');
      return null;
    }
    final sig = _buildSignature();
    if (_cachedDocxBytes != null && _cachedSignature == sig) {
      return (bytes: _cachedDocxBytes!, fileName: _cachedFileName);
    }

    setState(() => _exporting = true);
    try {
      final activeRealmCode =
          (widget.initialFilter == 'all' || widget.initialFilter == 'high')
              ? null
              : widget.initialFilter;
      final res = await context.read<GuoguanlaApi>().exportWrongDocx(
            wrongIds: chosen.map((e) => e.id).toList(),
            realmCode: activeRealmCode,
            highFrequencyOnly: widget.initialFilter == 'high',
            title: _title,
            answerMode: _answerMode,
            includeDiagrams: _includeDiagrams,
            includeWorkspace: _includeWorkspace,
          );
      _cachedSignature = sig;
      _cachedDocxBytes = res.bytes;
      _cachedFileName = res.fileName;
      return res;
    } catch (e) {
      if (mounted) {
        GglFeedback.error(context, friendlyErrorMessage(e, '生成 Word 文档失败'));
      }
      return null;
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _handleShareWeChat() async {
    final doc = await _ensureDocxGenerated();
    if (doc == null || !mounted) return;
    final result = await DocxShareService.shareToWeChat(
      bytes: doc.bytes,
      fileName: doc.fileName,
      title: _title,
    );
    if (!mounted) return;
    if (result.success) {
      GglFeedback.success(context, result.message);
    } else {
      GglFeedback.warning(context, result.message);
    }
  }

  Future<void> _handleShareSystem() async {
    final doc = await _ensureDocxGenerated();
    if (doc == null || !mounted) return;
    final result = await DocxShareService.shareSystem(
      bytes: doc.bytes,
      fileName: doc.fileName,
      title: _title,
    );
    if (!mounted) return;
    if (result.success) {
      GglFeedback.success(context, result.message);
    } else {
      GglFeedback.warning(context, result.message);
    }
  }

  Future<void> _handleOpenLocal() async {
    final doc = await _ensureDocxGenerated();
    if (doc == null || !mounted) return;
    final result = await DocxShareService.openLocally(
      bytes: doc.bytes,
      fileName: doc.fileName,
    );
    if (!mounted) return;
    if (result.success) {
      GglFeedback.success(context, result.message);
    } else {
      GglFeedback.warning(context, result.message);
    }
  }

  Future<void> _openQuestionSelector() async {
    final working = Set<int>.from(_selectedIds);
    final applied = await showGglBottomSheet<bool>(
      context: context,
      title: '勾选导出错题（已选 ${working.length}/${_allItems.length}）',
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final ink = AppTheme.inkColor(ctx);
            final muted = AppTheme.mutedText(ctx);
            final allSelected =
                working.length == _allItems.length && _allItems.isNotEmpty;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    GglButton(
                      label: allSelected ? '全部取消' : '全选全部',
                      variant: WelkButtonVariant.secondary,
                      compact: true,
                      onPressed: () {
                        setSheetState(() {
                          if (allSelected) {
                            working.clear();
                          } else {
                            working
                              ..clear()
                              ..addAll(_allItems.map((e) => e.id));
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    GglButton(
                      label: '仅选高频错题',
                      variant: WelkButtonVariant.info,
                      compact: true,
                      onPressed: () {
                        setSheetState(() {
                          working
                            ..clear()
                            ..addAll(
                              _allItems
                                  .where((e) => e.wrongCount >= 2)
                                  .map((e) => e.id),
                            );
                        });
                      },
                    ),
                    const Spacer(),
                    Text(
                      '已选 ${working.length} 题',
                      style: TextStyle(
                        color: muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < _allItems.length; i++) ...[
                  Builder(
                    builder: (rowCtx) {
                      final q = _allItems[i];
                      final checked = working.contains(q.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GglComicPanel(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                          shadowOffset: const Offset(1.5, 1.5),
                          onTap: () {
                            setSheetState(() {
                              if (checked) {
                                working.remove(q.id);
                              } else {
                                working.add(q.id);
                              }
                            });
                          },
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GglCheckbox(
                                value: checked,
                                onChanged: (v) {
                                  setSheetState(() {
                                    if (v) {
                                      working.add(q.id);
                                    } else {
                                      working.remove(q.id);
                                    }
                                  });
                                },
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${i + 1}. ${q.realmName} · ${q.chapterName}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: muted,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        GglStatusTag(
                                          label: '错${q.wrongCount}次',
                                          variant: q.wrongCount >= 2
                                              ? WelkBadgeVariant.error
                                              : WelkBadgeVariant.warning,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      q.stem.replaceAll('\$', ''),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: ink,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
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
                ],
                const SizedBox(height: 10),
                GglBlockButton(
                  label: '应用勾选（${working.length} 题）',
                  onPressed: () => Navigator.of(sheetCtx).pop(true),
                ),
              ],
            );
          },
        );
      },
    );

    if (applied == true && mounted) {
      setState(() {
        _selectedIds
          ..clear()
          ..addAll(working);
        _currentPageIndex = 0;
        _invalidateDocxCache();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final ink = AppTheme.inkColor(context);
    final muted = AppTheme.mutedText(context);
    final selectedItems = _selectedItems;
    final pages = buildWrongA4Pages(
      items: selectedItems,
      answerMode: _answerMode,
      includeDiagrams: _includeDiagrams,
      includeWorkspace: _includeWorkspace,
    );
    final int safePageIdx =
        _currentPageIndex.clamp(0, math.max(0, pages.length - 1)).toInt();
    final activePage = pages[safePageIdx];
    final studentName = (user.userInfo?.nickname.isNotEmpty ?? false)
        ? user.userInfo!.nickname
        : '________';
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: GglAppBar(
        title: 'A4 错题卷预览与导出',
        showBack: true,
        actions: [
          if (_allItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GglButton(
                label: '选题(${selectedItems.length})',
                variant: WelkButtonVariant.secondary,
                compact: true,
                onPressed: () => unawaited(_openQuestionSelector()),
              ),
            ),
        ],
      ),
      body: _loading && _allItems.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                GglCardSkeleton(lines: 3),
                SizedBox(height: 14),
                AspectRatio(
                  aspectRatio: 210 / 297,
                  child: GglSkeletonBox(width: double.infinity, height: 420),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                // 排版参数配置卡片
                GglComicPanel(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GglInput(
                        label: '试卷标题',
                        value: _title,
                        placeholder: '请输入导出 Word 试卷标题',
                        onChanged: (v) {
                          setState(() {
                            _title = v;
                            _invalidateDocxCache();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '答案与解析排版',
                        style: TextStyle(
                          color: ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      GglTabs(
                        semanticLabel: '答案排版模式',
                        items: _answerModeTabs,
                        value: _answerMode,
                        scrollable: false,
                        onChanged: (v) {
                          setState(() {
                            _answerMode = v;
                            _currentPageIndex = 0;
                            _invalidateDocxCache();
                          });
                        },
                        panelChild: Wrap(
                          spacing: 18,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            GglSwitch(
                              value: _includeDiagrams,
                              label: '包含配图',
                              onChanged: (v) {
                                setState(() {
                                  _includeDiagrams = v;
                                  _currentPageIndex = 0;
                                  _invalidateDocxCache();
                                });
                              },
                            ),
                            GglSwitch(
                              value: _includeWorkspace,
                              label: '预留答题区',
                              onChanged: (v) {
                                setState(() {
                                  _includeWorkspace = v;
                                  _currentPageIndex = 0;
                                  _invalidateDocxCache();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // A4 分页工具条
                Row(
                  children: [
                    Icon(Icons.description_outlined, size: 17, color: ink),
                    const SizedBox(width: 6),
                    Text(
                      'A4 打印效果预览（210×297mm）',
                      style: TextStyle(
                        color: ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    GglStatusTag(
                      label: '共 ${pages.length} 页 · ${selectedItems.length} 题',
                      variant: WelkBadgeVariant.info,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 标准 A4 纸模板实时预览容器（支持双指缩放）
                if (selectedItems.isEmpty)
                  GglComicPanel(
                    padding: const EdgeInsets.symmetric(
                      vertical: 38,
                      horizontal: 20,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.checklist_rtl_rounded,
                          size: 38,
                          color: muted,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '尚未勾选任何错题',
                          style: TextStyle(
                            color: ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GglButton(
                          label: '去勾选错题',
                          onPressed: () => unawaited(_openQuestionSelector()),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: AspectRatio(
                        aspectRatio: 210 / 297,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFFD4D4D8),
                              width: 1,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x22000000),
                                blurRadius: 16,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InteractiveViewer(
                            minScale: 0.95,
                            maxScale: 2.8,
                            child: _A4PaperSheetView(
                              page: activePage,
                              totalPages: pages.length,
                              totalQuestions: selectedItems.length,
                              title: _title.trim().isEmpty
                                  ? '过关啦数学错题巩固卷'
                                  : _title.trim(),
                              studentName: studentName,
                              gradeName: user.currentGrade.gradeName,
                              dateStr: dateStr,
                              answerMode: _answerMode,
                              includeDiagrams: _includeDiagrams,
                              includeWorkspace: _includeWorkspace,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GglButton(
                        label: '上一页',
                        icon: Icons.chevron_left_rounded,
                        variant: WelkButtonVariant.secondary,
                        compact: true,
                        onPressed: safePageIdx > 0
                            ? () =>
                                setState(() => _currentPageIndex = safePageIdx - 1)
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        '第 ${safePageIdx + 1} / ${pages.length} 页',
                        style: TextStyle(
                          color: ink,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 14),
                      GglButton(
                        label: '下一页',
                        icon: Icons.chevron_right_rounded,
                        variant: WelkButtonVariant.secondary,
                        compact: true,
                        onPressed: safePageIdx < pages.length - 1
                            ? () =>
                                setState(() => _currentPageIndex = safePageIdx + 1)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '提示：双指可放大查看 A4 试卷排版细节；导出的 Word (.docx) 将按 A4 标准纸型自动排版并嵌入高清矢量图。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 11.5),
                  ),
                ],
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: AppTheme.barDecoration(context, topBorder: true),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GglBlockButton(
                label: _exporting ? '正在生成 A4 Word 文件...' : '生成 Word 并分享至微信',
                icon: Icons.chat_rounded,
                variant: WelkButtonVariant.success,
                size: WelkButtonSize.large,
                loading: _exporting,
                onPressed:
                    selectedItems.isEmpty || _exporting ? null : _handleShareWeChat,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GglBlockButton(
                      label: '系统分享',
                      icon: Icons.ios_share_rounded,
                      variant: WelkButtonVariant.secondary,
                      size: WelkButtonSize.small,
                      onPressed: selectedItems.isEmpty || _exporting
                          ? null
                          : _handleShareSystem,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GglBlockButton(
                      label: '打开 Word 预览',
                      icon: Icons.open_in_new_rounded,
                      variant: WelkButtonVariant.info,
                      size: WelkButtonSize.small,
                      onPressed: selectedItems.isEmpty || _exporting
                          ? null
                          : _handleOpenLocal,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _A4PaperSheetView extends StatelessWidget {
  const _A4PaperSheetView({
    required this.page,
    required this.totalPages,
    required this.totalQuestions,
    required this.title,
    required this.studentName,
    required this.gradeName,
    required this.dateStr,
    required this.answerMode,
    required this.includeDiagrams,
    required this.includeWorkspace,
  });

  final A4PageModel page;
  final int totalPages;
  final int totalQuestions;
  final String title;
  final String studentName;
  final String gradeName;
  final String dateStr;
  final String answerMode;
  final bool includeDiagrams;
  final bool includeWorkspace;

  static const Color _paperInk = Color(0xFF18181B);
  static const Color _paperMuted = Color(0xFF52525B);
  static const Color _paperRule = Color(0xFFD4D4D8);
  static const Color _paperAccent = Color(0xFF0284C7);
  static const List<String> _letters = ['A', 'B', 'C', 'D', 'E', 'F'];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 页眉
          Row(
            children: [
              Expanded(
                child: Text(
                  '过关啦 · $gradeName数学错题巩固卷',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _paperMuted,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w500,
                    fontFamilyFallback: AppTheme.cjkFontFallback,
                  ),
                ),
              ),
              Text(
                page.isAnswerPage ? '参考答案附页' : 'A4 标准打印模板',
                style: const TextStyle(
                  color: _paperMuted,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Divider(height: 8, thickness: 0.7, color: _paperRule),

          // 正文区
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (page.isCoverPage) ...[
                    const SizedBox(height: 4),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _paperInk,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        fontFamilyFallback: AppTheme.cjkFontFallback,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        border: Border.all(color: _paperRule, width: 0.7),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 10,
                        runSpacing: 3,
                        children: [
                          Text(
                            '姓名：$studentName',
                            style: const TextStyle(
                              color: _paperInk,
                              fontSize: 9,
                            ),
                          ),
                          Text(
                            '年级：$gradeName',
                            style: const TextStyle(
                              color: _paperInk,
                              fontSize: 9,
                            ),
                          ),
                          Text(
                            '题量：$totalQuestions 题',
                            style: const TextStyle(
                              color: _paperInk,
                              fontSize: 9,
                            ),
                          ),
                          Text(
                            '日期：$dateStr',
                            style: const TextStyle(
                              color: _paperInk,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  for (final block in page.blocks) _buildBlock(block),
                ],
              ),
            ),
          ),

          // 页脚
          const Divider(height: 8, thickness: 0.6, color: _paperRule),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '过关啦数学学习系统自动排版',
                style: TextStyle(color: _paperMuted, fontSize: 8),
              ),
              Text(
                '第 ${page.pageNumber} 页 / 共 $totalPages 页',
                style: const TextStyle(
                  color: _paperInk,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBlock(A4LayoutBlock block) {
    return switch (block) {
      A4SectionHeaderBlock(:final title, :final subtitle) => Container(
          margin: const EdgeInsets.only(top: 4, bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
          decoration: const BoxDecoration(
            color: Color(0xFFF1F5F9),
            border: Border(
              left: BorderSide(color: _paperAccent, width: 2.5),
            ),
          ),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _paperInk,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  fontFamilyFallback: AppTheme.cjkFontFallback,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                subtitle,
                style: const TextStyle(color: _paperMuted, fontSize: 8.5),
              ),
            ],
          ),
        ),
      A4QuestionBlock(:final seq, :final item, :final isEssay) =>
        _buildQuestionBlock(seq, item, isEssay),
      A4AnswerBlock(:final seq, :final item) => _buildAnswerBlock(seq, item),
    };
  }

  Widget _buildQuestionBlock(int seq, WrongQuestionItem item, bool isEssay) {
    final hasDiagram = item.diagram != null && item.diagram!.primitives.isNotEmpty;
    final hasImg = item.imageUrl != null && item.imageUrl!.trim().isNotEmpty;
    final twoColOptions = !isEssay &&
        item.options.length >= 2 &&
        item.options.every((o) => o.length <= 16);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.only(bottom: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFECEEF2), width: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$seq. ',
                style: const TextStyle(
                  color: _paperInk,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '[${item.realmName} · ${item.chapterName} · 错${item.wrongCount}次]',
                      style: const TextStyle(
                        color: _paperMuted,
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1.5),
                    MathText(
                      item.stem,
                      style: const TextStyle(
                        color: _paperInk,
                        fontSize: 9.8,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (includeDiagrams && (hasDiagram || hasImg)) ...[
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 96, maxWidth: 210),
                child: QuestionFigureCard(
                  diagram: item.diagram,
                  imageUrl: item.imageUrl,
                  compact: true,
                ),
              ),
            ),
          ],
          if (!isEssay && item.options.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: twoColOptions
                  ? Wrap(
                      spacing: 10,
                      runSpacing: 3,
                      children: [
                        for (var i = 0; i < item.options.length; i++)
                          SizedBox(
                            width: 120,
                            child: MathText(
                              '${i < _letters.length ? _letters[i] : '${i + 1}'}. ${item.options[i]}',
                              style: const TextStyle(
                                color: _paperInk,
                                fontSize: 9.2,
                                height: 1.35,
                              ),
                            ),
                          ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < item.options.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: MathText(
                              '${i < _letters.length ? _letters[i] : '${i + 1}'}. ${item.options[i]}',
                              style: const TextStyle(
                                color: _paperInk,
                                fontSize: 9.2,
                                height: 1.35,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
          if (includeWorkspace) ...[
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: isEssay
                  ? Container(
                      height: 48,
                      width: double.infinity,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _paperRule,
                          width: 0.7,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      alignment: Alignment.topLeft,
                      child: const Text(
                        '解：',
                        style: TextStyle(color: _paperMuted, fontSize: 8.5),
                      ),
                    )
                  : const Text(
                      '我的作答：________    订正反思：____________________',
                      style: TextStyle(color: _paperMuted, fontSize: 8.2),
                    ),
            ),
          ],
          if (answerMode == 'INLINE') ...[
            const SizedBox(height: 5),
            Container(
              margin: const EdgeInsets.only(left: 14),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                border: Border.all(color: const Color(0xFFBAE6FD), width: 0.7),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MathText(
                    '【参考答案】${item.formattedCorrectAnswer()}',
                    style: const TextStyle(
                      color: Color(0xFF0369A1),
                      fontSize: 8.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.analysis.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    MathText(
                      '【思路解析】${item.analysis}',
                      style: const TextStyle(
                        color: _paperMuted,
                        fontSize: 8.4,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnswerBlock(int seq, WrongQuestionItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        border: Border.all(color: _paperRule, width: 0.6),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MathText(
            '$seq. 答案：${item.formattedCorrectAnswer()}',
            style: const TextStyle(
              color: _paperInk,
              fontSize: 9.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (item.analysis.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            MathText(
              '解析：${item.analysis}',
              style: const TextStyle(
                color: _paperMuted,
                fontSize: 8.5,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
