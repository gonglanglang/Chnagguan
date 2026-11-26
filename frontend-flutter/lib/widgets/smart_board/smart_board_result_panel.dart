import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../../app/app_theme.dart';
import '../../models/models.dart';
import '../ggl_comic_panel.dart';
import '../ggl_feedback.dart';
import '../ggl_skin_widgets.dart';
import '../math_text.dart';
import 'board_diagram_painter.dart';
import 'photo_figure_extractor.dart';

enum BoardResultTab { problem, ideas, diagnosis, solution }

/// 统一采用当前 UI 组件库（WelkUI / Skribble）渲染的智能画板结果浮层面板：
/// - 题目（含 1:1 裁剪提纯还原配图、原图/提纯切换、放大预览与重框配图）
/// - 思路（仅引导思路与公式，不给答案）
/// - 诊断（仅批改学生手写，不给答案）
/// - 解题（严格「上纯答案，下解题思路」，顶部仅展示纯粹答案）
/// 支持在画布安全区内自由拖拽定位与一键收起/展开，严格不覆盖导航栏。
class SmartBoardResultPanel extends StatefulWidget {
  const SmartBoardResultPanel({
    super.key,
    required this.canvasSize,
    required this.activeTab,
    required this.collapsed,
    required this.position,
    required this.onPositionChanged,
    required this.onTabChanged,
    required this.onToggleCollapsed,
    required this.onEditProblem,
    required this.onRecropFigure,
    required this.onCloseActiveTab,
    this.onDrawDiagramToBoard,
    this.onClearHandwritingToSolve,
    this.showClearHandwritingAction = false,
    this.problem,
    this.ideas,
    this.diagnosis,
    this.solution,
    this.extractedFigures = const [],
    this.hasSourcePhoto = false,
    this.purifyFigures = true,
    this.onTogglePurifyFigures,
    this.revealProgress = 1.0,
    this.isAnimating = false,
    this.traceSpeed = 1.0,
    this.onToggleSpeed,
    this.onSkipAnimation,
    this.onReplayAnimation,
  });

  final Size canvasSize;
  final BoardResultTab activeTab;
  final bool collapsed;
  final Offset position;
  final ValueChanged<Offset> onPositionChanged;
  final ValueChanged<BoardResultTab> onTabChanged;
  final VoidCallback onToggleCollapsed;
  final VoidCallback? onEditProblem;
  final VoidCallback? onRecropFigure;
  final VoidCallback? onCloseActiveTab;
  final ValueChanged<BoardDiagramSpec>? onDrawDiagramToBoard;
  final VoidCallback? onClearHandwritingToSolve;
  final bool showClearHandwritingAction;

  final AiRecognizeResult? problem;
  final AiBoardGuidance? ideas;
  final AiBoardGuidance? diagnosis;
  final AiBoardGuidance? solution;
  final List<ExtractedBoardFigure> extractedFigures;
  final bool hasSourcePhoto;
  final bool purifyFigures;
  final VoidCallback? onTogglePurifyFigures;

  final double revealProgress;
  final bool isAnimating;
  final double traceSpeed;
  final VoidCallback? onToggleSpeed;
  final VoidCallback? onSkipAnimation;
  final VoidCallback? onReplayAnimation;

  @override
  State<SmartBoardResultPanel> createState() => _SmartBoardResultPanelState();
}

class _SmartBoardResultPanelState extends State<SmartBoardResultPanel> {
  bool _solutionIdeaExpanded = true;
  bool _showOriginalPhotoRef = false;

  @override
  void didUpdateWidget(covariant SmartBoardResultPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.problem?.problemText != widget.problem?.problemText) {
      _showOriginalPhotoRef = false;
    }
  }

  void _openZoomDiagram(BuildContext context, BoardDiagramSpec spec) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0F172A),
        insetPadding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      spec.title.isNotEmpty ? spec.title : '题目矢量配图',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GglButton(
                    label: '关闭',
                    variant: WelkButtonVariant.secondary,
                    compact: true,
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.5,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
                  child: AspectRatio(
                    aspectRatio: (spec.width > 20 ? spec.width : 320.0) /
                        (spec.height > 20 ? spec.height : 210.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: CustomPaint(
                        painter: _SingleDiagramPainter(
                          spec: spec,
                          progress: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<BoardResultTab> get _availableTabs => [
        if (widget.problem != null) BoardResultTab.problem,
        if (widget.ideas != null) BoardResultTab.ideas,
        if (widget.diagnosis != null) BoardResultTab.diagnosis,
        if (widget.solution != null) BoardResultTab.solution,
      ];

  String _tabLabel(BoardResultTab t) => switch (t) {
        BoardResultTab.problem => '题目',
        BoardResultTab.ideas => '思路',
        BoardResultTab.diagnosis => '诊断',
        BoardResultTab.solution => '解题',
      };

  void _openZoomFigure(BuildContext context, Uint8List bytes, String title) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black87,
        insetPadding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GglButton(
                    label: '关闭',
                    variant: WelkButtonVariant.secondary,
                    compact: true,
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Container(
                color: Colors.white,
                constraints: const BoxConstraints(maxHeight: 460),
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.5,
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _availableTabs;
    if (tabs.isEmpty || widget.canvasSize.isEmpty) {
      return const SizedBox.shrink();
    }

    final active = tabs.contains(widget.activeTab) ? widget.activeTab : tabs.first;
    final colors = WelkTheme.of(context).resolveColors(context);
    final isWide = widget.canvasSize.width > widget.canvasSize.height;

    final panelWidth = widget.collapsed
        ? null
        : math.min(
            isWide ? 360.0 : widget.canvasSize.width - 20.0,
            math.max(270.0, widget.canvasSize.width * (isWide ? 0.44 : 0.92)),
          );
    final maxPanelHeight = math.max(
      160.0,
      widget.canvasSize.height * (isWide ? 0.84 : 0.54),
    );

    final double clampedLeft = widget.collapsed
        ? 10.0
        : widget.position.dx
            .clamp(
              8.0,
              math.max(8.0, widget.canvasSize.width - (panelWidth ?? 280) - 8.0),
            )
            .toDouble();
    final double clampedTop = widget.collapsed
        ? 8.0
        : widget.position.dy
            .clamp(
              8.0,
              math.max(8.0, widget.canvasSize.height - 96.0),
            )
            .toDouble();

    if (widget.collapsed) {
      return Positioned(
        left: clampedLeft,
        top: clampedTop,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: math.max(120, widget.canvasSize.width - 20),
          ),
          child: GglComicPanel(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            shadowOffset: const Offset(2, 2),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final t in tabs) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: GglButton(
                        label: _tabLabel(t),
                        compact: true,
                        variant: t == active
                            ? WelkButtonVariant.primary
                            : WelkButtonVariant.secondary,
                        onPressed: () {
                          widget.onTabChanged(t);
                          widget.onToggleCollapsed();
                        },
                      ),
                    ),
                  ],
                  GglButton(
                    label: '展开',
                    icon: Icons.unfold_more_rounded,
                    compact: true,
                    variant: WelkButtonVariant.ghost,
                    onPressed: widget.onToggleCollapsed,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Positioned(
      left: clampedLeft,
      top: clampedTop,
      child: SizedBox(
        width: panelWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxPanelHeight),
          child: GglComicPanel(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            shadowOffset: const Offset(2, 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 可拖拽顶栏 + Tab 切换 + 收起按钮
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (d) {
                    final maxX = math.max(
                      8.0,
                      widget.canvasSize.width - (panelWidth ?? 280) - 8.0,
                    );
                    final maxY = math.max(8.0, widget.canvasSize.height - 96.0);
                    widget.onPositionChanged(
                      Offset(
                        (clampedLeft + d.delta.dx).clamp(8.0, maxX),
                        (clampedTop + d.delta.dy).clamp(8.0, maxY),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Icon(
                        Icons.drag_indicator_rounded,
                        size: 16,
                        color: AppTheme.mutedText(context),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final t in tabs) ...[
                                Padding(
                                  padding: const EdgeInsets.only(right: 5),
                                  child: GglButton(
                                    label: _tabLabel(t),
                                    compact: true,
                                    variant: t == active
                                        ? WelkButtonVariant.primary
                                        : WelkButtonVariant.secondary,
                                    onPressed: () => widget.onTabChanged(t),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GglButton(
                        label: '收起',
                        compact: true,
                        variant: WelkButtonVariant.ghost,
                        onPressed: widget.onToggleCollapsed,
                      ),
                    ],
                  ),
                ),
                const GglDivider(verticalPadding: 8),

                // 主内容区（可滚动，确保不溢出画布）
                Flexible(
                  child: SingleChildScrollView(
                    child: switch (active) {
                      BoardResultTab.problem =>
                        _buildProblemBody(context, colors, widget.problem!),
                      BoardResultTab.ideas =>
                        _buildIdeasBody(context, colors, widget.ideas!),
                      BoardResultTab.diagnosis =>
                        _buildDiagnosisBody(context, colors, widget.diagnosis!),
                      BoardResultTab.solution =>
                        _buildSolutionBody(context, colors, widget.solution!),
                    },
                  ),
                ),

                // 思路/诊断/解题 逐段演示控制条（仅在播放中或可重播时展示）
                if (active != BoardResultTab.problem &&
                    (widget.isAnimating || widget.onReplayAnimation != null)) ...[
                  const GglDivider(verticalPadding: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (widget.isAnimating) ...[
                        GglStatusTag(
                          label: '逐步呈现中',
                          variant: WelkBadgeVariant.info,
                        ),
                        const SizedBox(width: 6),
                        if (widget.onToggleSpeed != null)
                          GglButton(
                            label: '${widget.traceSpeed.toStringAsFixed(0)}x',
                            compact: true,
                            variant: WelkButtonVariant.secondary,
                            onPressed: widget.onToggleSpeed,
                          ),
                        const SizedBox(width: 6),
                        if (widget.onSkipAnimation != null)
                          GglButton(
                            label: '立即显示',
                            compact: true,
                            variant: WelkButtonVariant.success,
                            onPressed: widget.onSkipAnimation,
                          ),
                      ] else if (widget.onReplayAnimation != null) ...[
                        GglButton(
                          label: '重播',
                          icon: Icons.replay_rounded,
                          compact: true,
                          variant: WelkButtonVariant.secondary,
                          onPressed: widget.onReplayAnimation,
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProblemBody(
    BuildContext context,
    WelkColors colors,
    AiRecognizeResult p,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (p.subjectTag.isNotEmpty)
                    GglStatusTag(
                      label: p.subjectTag,
                      variant: WelkBadgeVariant.info,
                    ),
                  if (p.questionType.isNotEmpty)
                    GglStatusTag(label: p.questionType, neutral: true),
                  if (p.difficulty.isNotEmpty)
                    GglStatusTag(
                      label: p.difficulty,
                      variant: WelkBadgeVariant.warning,
                    ),
                ],
              ),
            ),
            if (widget.showClearHandwritingAction &&
                widget.onClearHandwritingToSolve != null) ...[
              GglButton(
                label: '清笔迹作答',
                compact: true,
                variant: WelkButtonVariant.warning,
                onPressed: widget.onClearHandwritingToSolve,
              ),
              const SizedBox(width: 5),
            ],
            GglButton(
              label: '编辑',
              compact: true,
              variant: WelkButtonVariant.secondary,
              onPressed: widget.onEditProblem,
            ),
          ],
        ),
        const SizedBox(height: 8),
        MathText(
          p.problemText,
          style: TextStyle(
            color: colors.ink,
            fontSize: 14,
            height: 1.55,
            fontWeight: FontWeight.w500,
          ),
        ),

        // 题目配图区：优先展示矢量重绘图形（支持一键画到白板与点击放大），原图截图仅作可选对照
        if (p.diagrams.isNotEmpty ||
            widget.extractedFigures.isNotEmpty ||
            (widget.hasSourcePhoto && p.hasFigure)) ...[
          const GglDivider(verticalPadding: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  p.diagrams.isNotEmpty && !_showOriginalPhotoRef
                      ? '题目配图（矢量重绘）'
                      : '原题配图对照',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.inkColor(context),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (p.diagrams.isNotEmpty &&
                  !_showOriginalPhotoRef &&
                  widget.onDrawDiagramToBoard != null) ...[
                GglButton(
                  label: '画到白板',
                  icon: Icons.draw_rounded,
                  compact: true,
                  variant: WelkButtonVariant.primary,
                  onPressed: () =>
                      widget.onDrawDiagramToBoard!(p.diagrams.first),
                ),
                const SizedBox(width: 6),
              ],
              if (p.diagrams.isNotEmpty && widget.extractedFigures.isNotEmpty) ...[
                GglButton(
                  label: _showOriginalPhotoRef ? '矢量重绘' : '原图对照',
                  compact: true,
                  variant: WelkButtonVariant.secondary,
                  onPressed: () => setState(
                    () => _showOriginalPhotoRef = !_showOriginalPhotoRef,
                  ),
                ),
              ] else if (_showOriginalPhotoRef || p.diagrams.isEmpty) ...[
                if (widget.extractedFigures.isNotEmpty &&
                    widget.onTogglePurifyFigures != null) ...[
                  GglButton(
                    label: widget.purifyFigures ? '白板提纯' : '原图',
                    compact: true,
                    variant: WelkButtonVariant.secondary,
                    onPressed: widget.onTogglePurifyFigures,
                  ),
                  const SizedBox(width: 6),
                ],
                if (widget.hasSourcePhoto)
                  GglButton(
                    label: '重框配图',
                    icon: Icons.crop_rounded,
                    compact: true,
                    variant: WelkButtonVariant.secondary,
                    onPressed: widget.onRecropFigure,
                  ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (p.diagrams.isNotEmpty && !_showOriginalPhotoRef)
            for (final d in p.diagrams)
              GestureDetector(
                onTap: () => _openZoomDiagram(context, d),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _VectorDiagramBox(
                      spec: d,
                      progress: widget.revealProgress.clamp(0.0, 1.0),
                    ),
                    Text(
                      '点击矢量图可全屏缩放 · 点「画到白板」可直接添加辅助线',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.mutedText(context),
                        fontSize: 10.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              )
          else if (widget.extractedFigures.isNotEmpty)
            for (final fig in widget.extractedFigures) ...[
              GestureDetector(
                onTap: () => _openZoomFigure(
                  context,
                  widget.purifyFigures ? fig.purifiedBytes : fig.rawBytes,
                  fig.title,
                ),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(6),
                  decoration: AppTheme.insetBoxDecoration(
                    context,
                    color: Colors.white,
                    borderColor: AppTheme.borderColor(context)
                        .withValues(alpha: AppTheme.isForui(context) ? 1 : 0.4),
                    radius: 8,
                    width: AppTheme.isForui(context) ? 1 : 1.2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: AspectRatio(
                          aspectRatio: fig.aspectRatio,
                          child: Image.memory(
                            widget.purifyFigures
                                ? fig.purifiedBytes
                                : fig.rawBytes,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '点击配图可放大查看 · 如范围有偏差可点「重框配图」',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.mutedText(context),
                          fontSize: 10.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ]
          else
            GglButton(
              label: '手动框选题目配图',
              icon: Icons.crop_rounded,
              variant: WelkButtonVariant.secondary,
              onPressed: widget.onRecropFigure,
            ),
        ],

        if (p.knownConditions.isNotEmpty || p.targets.isNotEmpty) ...[
          const GglDivider(verticalPadding: 8),
          if (p.knownConditions.isNotEmpty)
            MathText(
              '已知：${p.knownConditions.join('；')}',
              style: TextStyle(
                color: AppTheme.mutedText(context),
                fontSize: 12.2,
                height: 1.45,
              ),
            ),
          if (p.targets.isNotEmpty) ...[
            const SizedBox(height: 4),
            MathText(
              '求证/求解：${p.targets.join('；')}',
              style: TextStyle(
                color: colors.ink,
                fontSize: 12.4,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildIdeasBody(
    BuildContext context,
    WelkColors colors,
    AiBoardGuidance g,
  ) {
    final visibleSteps = _visibleCount(g.steps.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const GglStatusTag(
              label: '引导思路（不含答案）',
              variant: WelkBadgeVariant.info,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                g.headline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        if (g.summary.isNotEmpty) ...[
          const SizedBox(height: 6),
          MathText(
            g.summary,
            style: TextStyle(
              color: AppTheme.mutedText(context),
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ],
        const SizedBox(height: 8),
        for (var i = 0; i < visibleSteps; i++)
          _StepCardItem(step: g.steps[i], accent: colors.info),
        if (g.diagrams.isNotEmpty && widget.revealProgress > 0.72) ...[
          const SizedBox(height: 6),
          for (final d in g.diagrams)
            _VectorDiagramBox(
              spec: d,
              progress: ((widget.revealProgress - 0.72) / 0.28).clamp(0.0, 1.0),
            ),
        ],
      ],
    );
  }

  Widget _buildDiagnosisBody(
    BuildContext context,
    WelkColors colors,
    AiBoardGuidance g,
  ) {
    final diag = g.studentDiagnosis;
    final (statusLabel, badgeVar) = switch (diag?.status) {
      'CORRECT' => ('手写步骤正确', WelkBadgeVariant.success),
      'INCORRECT' => ('发现错误步骤', WelkBadgeVariant.error),
      'PARTIAL' => ('方向正确 · 待完善', WelkBadgeVariant.warning),
      _ => ('过程诊断（不含答案）', WelkBadgeVariant.info),
    };
    final visibleSteps = _visibleCount(g.steps.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            GglStatusTag(label: statusLabel, variant: badgeVar),
            const GglStatusTag(label: '仅诊断不剧透答案', neutral: true),
          ],
        ),
        if (diag != null && diag.comment.isNotEmpty) ...[
          const SizedBox(height: 8),
          MathText(
            diag.comment,
            style: TextStyle(
              color: colors.ink,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ],
        if (diag != null && diag.mistakePoint.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.error.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.error.withValues(alpha: 0.55)),
            ),
            child: MathText(
              '错误定位：${diag.mistakePoint}',
              style: TextStyle(
                color: colors.ink,
                fontSize: 12.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (diag != null && diag.suggestion.isNotEmpty) ...[
          const SizedBox(height: 6),
          MathText(
            '检查方向：${diag.suggestion}',
            style: TextStyle(
              color: AppTheme.mutedText(context),
              fontSize: 12.6,
              height: 1.45,
            ),
          ),
        ],
        if (g.steps.isNotEmpty) ...[
          const GglDivider(verticalPadding: 8),
          for (var i = 0; i < visibleSteps; i++)
            _StepCardItem(step: g.steps[i], accent: colors.error),
        ],
      ],
    );
  }

  /// 严格按照需求：顶部只展示纯粹答案，解题思路写在下方！
  Widget _buildSolutionBody(
    BuildContext context,
    WelkColors colors,
    AiBoardGuidance g,
  ) {
    final pureAnswer = g.finalAnswer.trim().isNotEmpty
        ? g.finalAnswer.trim()
        : (g.steps.isNotEmpty
            ? (g.steps.last.formula.isNotEmpty
                ? g.steps.last.formula
                : g.steps.last.content)
            : '暂无答案');
    final visibleSteps = _visibleCount(g.steps.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 顶部：纯粹答案区（无多余标题/摘要堆砌）
        Row(
          children: [
            const GglStatusTag(
              label: '答案',
              variant: WelkBadgeVariant.success,
            ),
            const Spacer(),
            GglButton(
              label: '复制答案',
              icon: Icons.copy_rounded,
              compact: true,
              variant: WelkButtonVariant.secondary,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: pureAnswer));
                GglFeedback.success(context, '答案已复制');
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: AppTheme.insetBoxDecoration(
            context,
            color: colors.success.withValues(alpha: colors.isDark ? 0.16 : 0.22),
          ),
          child: MathText(
            pureAnswer,
            style: TextStyle(
              color: AppTheme.inkColor(context),
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              height: 1.55,
            ),
          ),
        ),

        // 下方：解题思路区
        if (g.steps.isNotEmpty) ...[
          const GglDivider(verticalPadding: 10),
          Row(
            children: [
              Text(
                '解题思路',
                style: TextStyle(
                  color: colors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              GglButton(
                label: _solutionIdeaExpanded ? '收起思路' : '展开思路',
                compact: true,
                variant: WelkButtonVariant.ghost,
                onPressed: () => setState(
                  () => _solutionIdeaExpanded = !_solutionIdeaExpanded,
                ),
              ),
            ],
          ),
          if (_solutionIdeaExpanded) ...[
            const SizedBox(height: 6),
            for (var i = 0; i < visibleSteps; i++)
              _StepCardItem(step: g.steps[i], accent: colors.accent),
          ],
        ],
        if (g.diagrams.isNotEmpty && _solutionIdeaExpanded) ...[
          const SizedBox(height: 6),
          for (final d in g.diagrams)
            _VectorDiagramBox(
              spec: d,
              progress: widget.revealProgress.clamp(0.0, 1.0),
            ),
        ],
      ],
    );
  }

  int _visibleCount(int total) {
    if (total <= 0) return 0;
    if (widget.revealProgress >= 0.99) return total;
    return math.max(1, (total * widget.revealProgress).ceil()).clamp(0, total);
  }
}

class _StepCardItem extends StatelessWidget {
  const _StepCardItem({
    required this.step,
    required this.accent,
  });

  final AiBoardStep step;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GglStatusTag(
                label: '${step.stepNo}',
                neutral: true,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  step.title,
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (step.content.isNotEmpty) ...[
            const SizedBox(height: 4),
            MathText(
              step.content,
              style: TextStyle(
                color: colors.ink,
                fontSize: 12.8,
                height: 1.5,
              ),
            ),
          ],
          if (step.formula.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.mutedSurfaceColor(context)
                    .withValues(alpha: AppTheme.isForui(context) ? 0.9 : 0.72),
                borderRadius: BorderRadius.circular(7),
                border: Border(
                  left: BorderSide(color: accent, width: 3),
                ),
              ),
              child: MathText(
                step.formula,
                style: TextStyle(
                  color: colors.ink,
                  fontSize: 13.2,
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
              ),
            ),
          ],
          if (step.highlight.isNotEmpty) ...[
            const SizedBox(height: 3),
            MathText(
              '提示：${step.highlight}',
              style: TextStyle(
                color: AppTheme.mutedText(context),
                fontSize: 11.8,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VectorDiagramBox extends StatelessWidget {
  const _VectorDiagramBox({
    required this.spec,
    required this.progress,
  });

  final BoardDiagramSpec spec;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final aspect = spec.height > 0 ? (spec.width / spec.height).clamp(0.7, 2.2) : 1.45;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(6),
      decoration: AppTheme.insetBoxDecoration(
        context,
        color: Colors.white,
        borderColor: AppTheme.borderColor(context)
            .withValues(alpha: AppTheme.isForui(context) ? 1 : 0.35),
        radius: 8,
        width: AppTheme.isForui(context) ? 1 : 1.2,
      ),
      child: AspectRatio(
        aspectRatio: aspect,
        child: CustomPaint(
          painter: _SingleDiagramPainter(spec: spec, progress: progress),
        ),
      ),
    );
  }
}

class _SingleDiagramPainter extends CustomPainter {
  const _SingleDiagramPainter({
    required this.spec,
    required this.progress,
  });

  final BoardDiagramSpec spec;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    BoardDiagramPainter.paintDiagramProgressive(
      canvas,
      spec,
      Offset.zero & size,
      progress: progress,
    );
  }

  @override
  bool shouldRepaint(covariant _SingleDiagramPainter oldDelegate) =>
      oldDelegate.spec != spec || oldDelegate.progress != progress;
}
