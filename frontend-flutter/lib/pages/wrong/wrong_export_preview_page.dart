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

/// 纯函数 A4 排版分页引擎：
/// - 严格按后端题型标记（选择题不预留作答区，仅解答题预留作答空间）估算版心高度；
/// - 自动分组（一、选择题 / 二、解答题），单题绝不跨页截断。
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

  final choices = items.where((q) => !q.needsAnswerSpace).toList();
  final essays = items.where((q) => q.needsAnswerSpace).toList();

  final orderedBlocks = <({A4LayoutBlock block, double weight})>[];
  var seq = 1;
  final numberedItems = <({int seq, WrongQuestionItem item})>[];

  double estimateQuestionWeight(WrongQuestionItem item, bool isEssay) {
    final stemLines = (item.stem.length / 28).ceil().clamp(1, 6);
    var weight = 8.5 + stemLines * 3.5;
    if (!isEssay && item.options.isNotEmpty) {
      final shortOptions = item.options.every((o) => o.length <= 16);
      weight += shortOptions ? 8.0 : item.options.length * 3.8;
    }
    final hasFig = (item.diagram != null && item.diagram!.primitives.isNotEmpty) ||
        (item.imageUrl != null && item.imageUrl!.trim().isNotEmpty);
    if (includeDiagrams && hasFig) {
      weight += 22.0;
    }
    // 仅解答题预留回答空间，选择题不预留作答/演算/反思区
    if (includeWorkspace && item.needsAnswerSpace) {
      weight += 22.0;
    }
    if (answerMode == 'INLINE') {
      final ansLen = item.formattedCorrectAnswer().length + item.analysis.length;
      final ansLines = (ansLen / 30).ceil().clamp(1, 6);
      weight += 7.0 + ansLines * 3.2;
    }
    return weight.clamp(11.0, 74.0);
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
  const double coverHeaderCost = 18.0;
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

  if (answerMode == 'END' && numberedItems.isNotEmpty) {
    currentBlocks = <A4LayoutBlock>[
      const A4SectionHeaderBlock('参考答案与解题思路', '独立附页 · 方便打印自查'),
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
  static const double _configHeaderHeight = 46.0;
  static const List<({String value, String label})> _answerModes = [
    (value: 'END', label: '文末答案'),
    (value: 'INLINE', label: '逐题解析'),
    (value: 'NONE', label: '无答案'),
  ];

  bool _loading = true;
  bool _exporting = false;
  bool _configExpanded = false;
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

  bool get _isAllSelected =>
      _allItems.isNotEmpty && _selectedIds.length == _allItems.length;

  void _toggleSelectAll() {
    setState(() {
      if (_isAllSelected) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(_allItems.map((e) => e.id));
      }
      _currentPageIndex = 0;
      _invalidateDocxCache();
    });
  }

  String _buildSignature() {
    final ids = _selectedItems.map((e) => e.id).join(',');
    return '$ids|$_title|$_answerMode|$_includeDiagrams|$_includeWorkspace';
  }

  Future<({Uint8List bytes, String fileName})?> _ensureDocxGenerated() async {
    final chosen = _selectedItems;
    if (chosen.isEmpty) {
      GglFeedback.warning(context, '请先勾选至少 1 道错题再生成试卷');
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
    if (_configExpanded) setState(() => _configExpanded = false);
    final working = Set<int>.from(_selectedIds);
    final applied = await showGglBottomSheet<bool>(
      context: context,
      title: '挑选导出错题',
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
                      label: allSelected ? '取消全选' : '全选',
                      variant: WelkButtonVariant.primary,
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
                      label: '仅选高频',
                      variant: WelkButtonVariant.secondary,
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
                      '已选 ${working.length}/${_allItems.length} 题',
                      maxLines: 1,
                      softWrap: false,
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
                            vertical: 8,
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
                                        GglStatusTag(
                                          label: q.displayTypeLabel,
                                          variant: q.isEssay
                                              ? WelkBadgeVariant.info
                                              : WelkBadgeVariant.defaultStyle,
                                          neutral: !q.isEssay,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '${i + 1}. ${q.realmName} · ${q.chapterName}',
                                            maxLines: 1,
                                            softWrap: false,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: muted,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
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
                  label: '确定（已选 ${working.length} 题）',
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

  Widget _buildCollapsedConfigBar(BuildContext context) {
    final ink = AppTheme.inkColor(context);
    final accent = AppTheme.accentColor(context);
    final displayTitle =
        _title.trim().isEmpty ? '过关啦数学错题巩固卷' : _title.trim();

    return Container(
      height: _configHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: AppTheme.barDecoration(context, bottomBorder: true),
      child: Row(
        children: [
          Icon(Icons.description_outlined, size: 17, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _configExpanded = !_configExpanded),
              child: Text(
                displayTitle,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  fontFamilyFallback: AppTheme.cjkFontFallback,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: _configExpanded ? '收起打印配置' : '展开打印配置',
            child: InkWell(
              onTap: () => setState(() => _configExpanded = !_configExpanded),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: AppTheme.insetBoxDecoration(
                  context,
                  color: _configExpanded
                      ? accent.withValues(alpha: 0.16)
                      : AppTheme.mutedSurfaceColor(context),
                  radius: 8,
                  width: 1,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 14,
                      color: _configExpanded ? accent : ink,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '打印配置',
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        color: _configExpanded ? accent : ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Icon(
                      _configExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: _configExpanded ? accent : ink,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingConfigOverlay(BuildContext context) {
    final ink = AppTheme.inkColor(context);
    final muted = AppTheme.mutedText(context);
    final surface = AppTheme.surfaceColor(context);

    return Positioned.fill(
      top: _configHeaderHeight,
      child: Stack(
        children: [
          // 点击半透明遮罩即刻收起（不占用底层文档流）
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _configExpanded = false),
            child: Container(
              color: Colors.black.withValues(alpha: 0.28),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: GglComicPanel(
                  color: surface,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: ink,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          for (var i = 0; i < _answerModes.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: GglPillChip(
                                label: _answerModes[i].label,
                                selected: _answerMode == _answerModes[i].value,
                                onTap: () {
                                  setState(() {
                                    _answerMode = _answerModes[i].value;
                                    _currentPageIndex = 0;
                                    _invalidateDocxCache();
                                  });
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GglSwitch(
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
                          ),
                          Expanded(
                            child: GglSwitch(
                              value: _includeWorkspace,
                              label: '解答题作答区',
                              onChanged: (v) {
                                setState(() {
                                  _includeWorkspace = v;
                                  _currentPageIndex = 0;
                                  _invalidateDocxCache();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '选择题自动保持清爽试卷排版；仅解答题按开关预留「解：」手写空间。',
                        style: TextStyle(color: muted, fontSize: 11.5),
                      ),
                      const SizedBox(height: 10),
                      GglBlockButton(
                        label: '收起配置',
                        size: WelkButtonSize.small,
                        variant: WelkButtonVariant.secondary,
                        onPressed: () =>
                            setState(() => _configExpanded = false),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
      appBar: const GglAppBar(
        title: 'A4 错题卷导出',
        showBack: true,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 顶部默认收起的打印配置栏（仅展示试卷标题 + 展开图标）
              _buildCollapsedConfigBar(context),

              // 紧凑单行选题与全选工具条
              if (_allItems.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration:
                      AppTheme.barDecoration(context, bottomBorder: true),
                  child: Row(
                    children: [
                      GglCheckbox(
                        value: _isAllSelected,
                        label: '全选',
                        onChanged: (_) => _toggleSelectAll(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '已选 ${selectedItems.length}/${_allItems.length} 题',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      GglButton(
                        label: '挑选题目',
                        icon: Icons.checklist_rounded,
                        variant: WelkButtonVariant.secondary,
                        compact: true,
                        onPressed: () => unawaited(_openQuestionSelector()),
                      ),
                    ],
                  ),
                ),

              // 主视区：最大化 A4 纸张预览
              Expanded(
                child: _loading && _allItems.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(14),
                        children: const [
                          AspectRatio(
                            aspectRatio: 210 / 297,
                            child:
                                GglSkeletonBox(width: double.infinity, height: 420),
                          ),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                        children: [
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
                                    '请先勾选需要生成试卷的错题',
                                    style: TextStyle(
                                      color: ink,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      GglButton(
                                        label: '一键全选',
                                        variant: WelkButtonVariant.primary,
                                        onPressed: _allItems.isEmpty
                                            ? null
                                            : _toggleSelectAll,
                                      ),
                                      const SizedBox(width: 10),
                                      GglButton(
                                        label: '挑选题目',
                                        variant: WelkButtonVariant.secondary,
                                        onPressed: () =>
                                            unawaited(_openQuestionSelector()),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          else ...[
                            Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 520),
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
                                          blurRadius: 14,
                                          offset: Offset(0, 5),
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
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GglButton(
                                  label: '上一页',
                                  icon: Icons.chevron_left_rounded,
                                  variant: WelkButtonVariant.secondary,
                                  compact: true,
                                  onPressed: safePageIdx > 0
                                      ? () => setState(
                                            () =>
                                                _currentPageIndex = safePageIdx - 1,
                                          )
                                      : null,
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  '第 ${safePageIdx + 1} / ${pages.length} 页',
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(
                                    color: ink,
                                    fontSize: 13,
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
                                      ? () => setState(
                                            () =>
                                                _currentPageIndex = safePageIdx + 1,
                                          )
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          ),

          // 悬浮打印配置浮层（不占文档流）
          if (_configExpanded) _buildFloatingConfigOverlay(context),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          decoration: AppTheme.barDecoration(context, topBorder: true),
          child: Row(
            children: [
              GglButton(
                label: '打开',
                icon: Icons.open_in_new_rounded,
                variant: WelkButtonVariant.secondary,
                compact: true,
                onPressed: selectedItems.isEmpty || _exporting
                    ? null
                    : _handleOpenLocal,
              ),
              const SizedBox(width: 8),
              GglButton(
                label: '分享',
                icon: Icons.ios_share_rounded,
                variant: WelkButtonVariant.secondary,
                compact: true,
                onPressed: selectedItems.isEmpty || _exporting
                    ? null
                    : _handleShareSystem,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GglBlockButton(
                  label: _exporting ? '正在生成...' : '导出 Word 发微信',
                  icon: Icons.chat_rounded,
                  variant: WelkButtonVariant.success,
                  size: WelkButtonSize.small,
                  loading: _exporting,
                  onPressed: selectedItems.isEmpty || _exporting
                      ? null
                      : _handleShareWeChat,
                ),
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
                page.isAnswerPage ? '参考答案附页' : '标准 A4',
                style: const TextStyle(
                  color: _paperMuted,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Divider(height: 8, thickness: 0.7, color: _paperRule),
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '姓名：$studentName',
                            style: const TextStyle(
                              color: _paperInk,
                              fontSize: 8.6,
                            ),
                          ),
                          Text(
                            '年级：$gradeName',
                            style: const TextStyle(
                              color: _paperInk,
                              fontSize: 8.6,
                            ),
                          ),
                          Text(
                            '日期：$dateStr',
                            style: const TextStyle(
                              color: _paperInk,
                              fontSize: 8.6,
                            ),
                          ),
                          const Text(
                            '得分：____',
                            style: TextStyle(color: _paperInk, fontSize: 8.6),
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
          const Divider(height: 8, thickness: 0.6, color: _paperRule),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '共 $totalQuestions 题 · 过关啦数学错题本',
                style: const TextStyle(color: _paperMuted, fontSize: 8),
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
        item.options.length == 4 &&
        item.options.every((o) => o.length <= 16 && !o.contains('\n'));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.only(bottom: 6),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFECEEF2), width: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 题号与题型标签行
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(
                left: BorderSide(color: _paperAccent, width: 2),
              ),
            ),
            child: Text(
              '第 $seq 题  [${item.displayTypeLabel}]  ${item.realmName} · ${item.chapterName} · 错${item.wrongCount}次',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _paperMuted,
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // 题干（独立行，绝不与选项合并）
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$seq. ',
                style: const TextStyle(
                  color: _paperInk,
                  fontSize: 9.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Expanded(
                child: MathText(
                  item.stem,
                  style: const TextStyle(
                    color: _paperInk,
                    fontSize: 9.8,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
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

          // 选择题选项（规整 2×2 网格或单列，绝不预留作答/订正反思区）
          if (!isEssay && item.options.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: twoColOptions
                  ? Column(
                      children: [
                        for (var r = 0; r < 2; r++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: MathText(
                                    '${_letters[r * 2]}. ${item.options[r * 2]}',
                                    style: const TextStyle(
                                      color: _paperInk,
                                      fontSize: 9.2,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: MathText(
                                    '${_letters[r * 2 + 1]}. ${item.options[r * 2 + 1]}',
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

          // 仅解答题预留回答空间，选择题不预留任何作答/演算/反思区
          if (includeWorkspace && item.needsAnswerSpace) ...[
            const SizedBox(height: 6),
            Container(
              height: 56,
              width: double.infinity,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                border: Border.all(color: _paperRule, width: 0.8),
                borderRadius: BorderRadius.circular(2),
              ),
              alignment: Alignment.topLeft,
              child: const Text(
                '解：',
                style: TextStyle(
                  color: _paperMuted,
                  fontSize: 8.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],

          if (answerMode == 'INLINE') ...[
            const SizedBox(height: 5),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                border: Border.all(color: const Color(0xFFBBF7D0), width: 0.7),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MathText(
                    '【参考答案】${item.formattedCorrectAnswer()}',
                    style: const TextStyle(
                      color: Color(0xFF15803D),
                      fontSize: 8.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.analysis.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    MathText(
                      '【解题思路】${item.analysis}',
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
            '第 $seq 题  [${item.displayTypeLabel}]  参考答案：${item.formattedCorrectAnswer()}',
            style: const TextStyle(
              color: Color(0xFF15803D),
              fontSize: 9.1,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (item.analysis.trim().isNotEmpty) ...[
            const SizedBox(height: 3),
            MathText(
              '解题思路：${item.analysis}',
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
