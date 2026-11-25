import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../models/models.dart';
import 'board_diagram_painter.dart';
import 'board_models.dart';
import 'canvas_math_painter.dart';

/// 计算每张世界坐标板书卡片的精确外接矩形（供命中测试、防重叠自动排版与视野对焦使用）
class SmartBoardLayoutMetrics {
  const SmartBoardLayoutMetrics({
    this.problemRect,
    this.ideasRect,
    this.solutionRect,
  });

  final Rect? problemRect;
  final Rect? ideasRect;
  final Rect? solutionRect;

  Rect? rectOf(BoardCardId id) => switch (id) {
        BoardCardId.problem => problemRect,
        BoardCardId.ideas => ideasRect,
        BoardCardId.solution => solutionRect,
      };

  static SmartBoardLayoutMetrics compute({
    required SmartBoardCardState cards,
    required BoardLayerVisibility visibility,
    ui.Image? problemPhoto,
  }) {
    Rect? pRect;
    if (cards.problem != null && visibility.showProblemCard) {
      final h = measureProblemCardHeight(
        cards.problem!,
        cards.problemWidth,
        hasPhoto: problemPhoto != null && visibility.showPhotoCard,
      );
      pRect = Rect.fromLTWH(
        cards.problemPos.dx,
        cards.problemPos.dy,
        cards.problemWidth,
        h,
      );
    }

    Rect? iRect;
    if (cards.ideas != null && visibility.showIdeasCard) {
      final h = measureGuidanceCardHeight(cards.ideas!, cards.ideasWidth);
      iRect = Rect.fromLTWH(
        cards.ideasPos.dx,
        cards.ideasPos.dy,
        cards.ideasWidth,
        h,
      );
    }

    Rect? sRect;
    if (cards.solution != null && visibility.showSolutionCard) {
      final h = measureGuidanceCardHeight(cards.solution!, cards.solutionWidth);
      sRect = Rect.fromLTWH(
        cards.solutionPos.dx,
        cards.solutionPos.dy,
        cards.solutionWidth,
        h,
      );
    }

    return SmartBoardLayoutMetrics(
      problemRect: pRect,
      ideasRect: iRect,
      solutionRect: sRect,
    );
  }

  static double measureProblemCardHeight(
    AiRecognizeResult problem,
    double width, {
    bool hasPhoto = false,
  }) {
    final contentW = width - 32;
    var h = 50.0; // Header + padding
    if (problem.problemText.isNotEmpty) {
      h += CanvasMathPainter.measureHeight(
        problem.problemText,
        maxWidth: contentW,
        style: _problemBodyStyle,
      );
      h += 12;
    }
    if (problem.knownConditions.isNotEmpty) {
      h += 22;
      for (final c in problem.knownConditions) {
        h += CanvasMathPainter.measureHeight(
              '• $c',
              maxWidth: contentW - 10,
              style: _metaBodyStyle,
            ) +
            4;
      }
      h += 8;
    }
    if (problem.targets.isNotEmpty) {
      h += 22;
      for (final t in problem.targets) {
        h += CanvasMathPainter.measureHeight(
              '▸ $t',
              maxWidth: contentW - 10,
              style: _metaBodyStyle,
            ) +
            4;
      }
      h += 8;
    }
    if (hasPhoto) {
      h += 164;
    }
    if (problem.diagrams.isNotEmpty) {
      h += problem.diagrams.length * 196.0;
    }
    return math.max(120, h + 12);
  }

  static double measureGuidanceCardHeight(
    AiBoardGuidance guidance,
    double width,
  ) {
    final contentW = width - 32;
    var h = 54.0; // Header bar + top padding
    if (guidance.summary.isNotEmpty) {
      h += CanvasMathPainter.measureHeight(
            guidance.summary,
            maxWidth: contentW - 16,
            style: _summaryStyle,
          ) +
          22;
    }
    if (guidance.studentDiagnosis != null &&
        (guidance.studentDiagnosis!.comment.isNotEmpty ||
            guidance.studentDiagnosis!.mistakePoint.isNotEmpty)) {
      final d = guidance.studentDiagnosis!;
      h += 26;
      if (d.comment.isNotEmpty) {
        h += CanvasMathPainter.measureHeight(
              d.comment,
              maxWidth: contentW - 20,
              style: _metaBodyStyle,
            ) +
            6;
      }
      if (d.mistakePoint.isNotEmpty) {
        h += CanvasMathPainter.measureHeight(
              '定位：${d.mistakePoint}',
              maxWidth: contentW - 20,
              style: _metaBodyStyle,
            ) +
            6;
      }
      if (d.suggestion.isNotEmpty) {
        h += CanvasMathPainter.measureHeight(
              '建议：${d.suggestion}',
              maxWidth: contentW - 20,
              style: _metaBodyStyle,
            ) +
            6;
      }
      h += 16;
    }

    for (final step in guidance.steps) {
      h += 26; // Step header pill
      if (step.content.isNotEmpty) {
        h += CanvasMathPainter.measureHeight(
              step.content,
              maxWidth: contentW - 22,
              style: _stepBodyStyle,
            ) +
            6;
      }
      if (step.formula.isNotEmpty) {
        h += CanvasMathPainter.measureHeight(
              step.formula,
              maxWidth: contentW - 34,
              style: _formulaBoxStyle,
            ) +
            20;
      }
      if (step.highlight.isNotEmpty) {
        h += CanvasMathPainter.measureHeight(
              '💡 ${step.highlight}',
              maxWidth: contentW - 24,
              style: _tipStyle,
            ) +
            8;
      }
      h += 12;
    }

    if (guidance.finalAnswer.isNotEmpty) {
      h += 24 +
          CanvasMathPainter.measureHeight(
            guidance.finalAnswer,
            maxWidth: contentW - 24,
            style: _answerStyle,
          ) +
          20;
    }

    if (guidance.pitfalls.isNotEmpty) {
      h += 24;
      for (final pit in guidance.pitfalls) {
        h += CanvasMathPainter.measureHeight(
              '⚠ $pit',
              maxWidth: contentW - 14,
              style: _tipStyle,
            ) +
            4;
      }
      h += 10;
    }

    if (guidance.diagrams.isNotEmpty) {
      h += guidance.diagrams.length * 198.0;
    }
    return math.max(140, h + 14);
  }
}

const TextStyle _problemBodyStyle = TextStyle(
  color: Color(0xFF0F172A),
  fontSize: 14.5,
  height: 1.55,
  fontWeight: FontWeight.w600,
  fontFamilyFallback: AppTheme.cjkFontFallback,
);

const TextStyle _metaBodyStyle = TextStyle(
  color: Color(0xFF334155),
  fontSize: 12.8,
  height: 1.48,
  fontWeight: FontWeight.w500,
  fontFamilyFallback: AppTheme.cjkFontFallback,
);

const TextStyle _summaryStyle = TextStyle(
  color: Color(0xFF1E293B),
  fontSize: 13.0,
  height: 1.45,
  fontWeight: FontWeight.w600,
  fontFamilyFallback: AppTheme.cjkFontFallback,
);

const TextStyle _stepBodyStyle = TextStyle(
  color: Color(0xFF1E293B),
  fontSize: 13.4,
  height: 1.5,
  fontWeight: FontWeight.w500,
  fontFamilyFallback: AppTheme.cjkFontFallback,
);

const TextStyle _formulaBoxStyle = TextStyle(
  color: Color(0xFF1D4ED8),
  fontSize: 14.2,
  height: 1.52,
  fontWeight: FontWeight.w700,
  fontFamilyFallback: AppTheme.cjkFontFallback,
);

const TextStyle _answerStyle = TextStyle(
  color: Color(0xFF065F46),
  fontSize: 14.4,
  height: 1.5,
  fontWeight: FontWeight.w800,
  fontFamilyFallback: AppTheme.cjkFontFallback,
);

const TextStyle _tipStyle = TextStyle(
  color: Color(0xFFB45309),
  fontSize: 12.2,
  height: 1.42,
  fontWeight: FontWeight.w600,
  fontFamilyFallback: AppTheme.cjkFontFallback,
);

class SmartBoardPainter extends CustomPainter {
  const SmartBoardPainter({
    required this.strokes,
    required this.shapes,
    required this.panX,
    required this.panY,
    required this.zoom,
    this.activeStroke,
    this.activeShape,
    this.paperStyle = BoardPaperStyle.dots,
    this.cards = const SmartBoardCardState(),
    this.visibility = const BoardLayerVisibility(),
    this.problemPhoto,
    this.ideasReveal = 1.0,
    this.solutionReveal = 1.0,
    this.draggingCardId,
    this.eraserCursorWorld,
    this.eraserCursorRadius = 18.0,
  });

  final List<BoardStroke> strokes;
  final List<BoardShape> shapes;
  final BoardStroke? activeStroke;
  final BoardShape? activeShape;
  final double panX;
  final double panY;
  final double zoom;
  final BoardPaperStyle paperStyle;
  final SmartBoardCardState cards;
  final BoardLayerVisibility visibility;
  final ui.Image? problemPhoto;
  final double ideasReveal;
  final double solutionReveal;
  final BoardCardId? draggingCardId;
  final Offset? eraserCursorWorld;
  final double eraserCursorRadius;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 纸张背景与底纹
    paintPaperBackground(
      canvas,
      size,
      paperStyle: paperStyle,
      panX: panX,
      panY: panY,
      zoom: zoom,
    );

    // 2. 进入无限画板世界坐标系
    canvas.save();
    canvas.translate(panX, panY);
    canvas.scale(zoom, zoom);

    final metrics = SmartBoardLayoutMetrics.compute(
      cards: cards,
      visibility: visibility,
      problemPhoto: problemPhoto,
    );

    // 3. 绘制题目板书卡
    if (cards.problem != null &&
        visibility.showProblemCard &&
        metrics.problemRect != null) {
      paintProblemCard(
        canvas,
        cards.problem!,
        metrics.problemRect!,
        photo: visibility.showPhotoCard ? problemPhoto : null,
        highlighted: draggingCardId == BoardCardId.problem,
      );
    }

    // 4. 绘制 AI 解题思路板书卡（带逐行动画进度）
    if (cards.ideas != null &&
        visibility.showIdeasCard &&
        metrics.ideasRect != null) {
      paintGuidanceCard(
        canvas,
        cards.ideas!,
        metrics.ideasRect!,
        revealProgress: ideasReveal,
        highlighted: draggingCardId == BoardCardId.ideas,
      );
    }

    // 5. 绘制 AI 解题过程分析板书卡（带逐行动画进度）
    if (cards.solution != null &&
        visibility.showSolutionCard &&
        metrics.solutionRect != null) {
      paintGuidanceCard(
        canvas,
        cards.solution!,
        metrics.solutionRect!,
        revealProgress: solutionReveal,
        highlighted: draggingCardId == BoardCardId.solution,
      );
    }

    // 6. 绘制几何图形与坐标系
    for (final shape in shapes) {
      paintShape(canvas, shape);
    }
    if (activeShape != null) {
      paintShape(canvas, activeShape!);
    }

    // 7. 绘制学生手写笔迹（先荧光笔后普通笔，保持文字清透）
    for (final s in strokes) {
      if (s.isHighlighter) paintStroke(canvas, s);
    }
    if (activeStroke != null && activeStroke!.isHighlighter) {
      paintStroke(canvas, activeStroke!);
    }
    for (final s in strokes) {
      if (!s.isHighlighter) paintStroke(canvas, s);
    }
    if (activeStroke != null && !activeStroke!.isHighlighter) {
      paintStroke(canvas, activeStroke!);
    }

    // 8. 橡皮擦光标环提示
    if (eraserCursorWorld != null) {
      canvas.drawCircle(
        eraserCursorWorld!,
        eraserCursorRadius,
        Paint()
          ..color = const Color(0xFFEF4444).withValues(alpha: 0.14)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        eraserCursorWorld!,
        eraserCursorRadius,
        Paint()
          ..color = const Color(0xFFEF4444)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / math.max(0.3, zoom),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(SmartBoardPainter oldDelegate) => true;

  static void paintPaperBackground(
    Canvas canvas,
    Size size, {
    required BoardPaperStyle paperStyle,
    required double panX,
    required double panY,
    required double zoom,
  }) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFCFDFF));
    if (paperStyle == BoardPaperStyle.plain) return;

    const baseStep = 36.0;
    final scaledStep = baseStep * zoom;
    if (scaledStep < 12) return;

    final startX = panX % scaledStep;
    final startY = panY % scaledStep;

    switch (paperStyle) {
      case BoardPaperStyle.dots:
        final dotPaint = Paint()..color = const Color(0xFFD8E0EA);
        final r = math.max(0.9, math.min(1.8, 1.15 * zoom));
        for (var x = startX; x < size.width; x += scaledStep) {
          for (var y = startY; y < size.height; y += scaledStep) {
            canvas.drawCircle(Offset(x, y), r, dotPaint);
          }
        }
      case BoardPaperStyle.grid:
        final linePaint = Paint()
          ..color = const Color(0xFFE6EDF5)
          ..strokeWidth = 1.0;
        for (var x = startX; x < size.width; x += scaledStep) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
        }
        for (var y = startY; y < size.height; y += scaledStep) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
        }
      case BoardPaperStyle.lined:
        final linePaint = Paint()
          ..color = const Color(0xFFE2E8F0)
          ..strokeWidth = 1.0;
        for (var y = startY; y < size.height; y += scaledStep) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
        }
      case BoardPaperStyle.plain:
        break;
    }
  }

  static void paintStroke(Canvas canvas, BoardStroke s) {
    if (s.points.isEmpty) return;
    final paintColor = s.isEraser
        ? const Color(0xFFFCFDFF)
        : (s.isHighlighter ? s.color.withValues(alpha: 0.32) : s.color);

    if (s.points.length == 1) {
      canvas.drawCircle(
        s.points.first,
        math.max(1.0, s.width / 2),
        Paint()..color = paintColor,
      );
      return;
    }

    final paint = Paint()
      ..color = paintColor
      ..strokeWidth = s.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke;

    // 二次贝塞尔平滑曲线，消除折线锯齿
    final path = BoardDiagramPainter.buildSmoothPath(s.points);
    canvas.drawPath(path, paint);
  }

  static void paintShape(Canvas canvas, BoardShape shape) {
    final paint = Paint()
      ..color = shape.color
      ..strokeWidth = shape.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromPoints(shape.start, shape.end);
    switch (shape.kind) {
      case BoardShapeKind.line:
        canvas.drawLine(shape.start, shape.end, paint);
      case BoardShapeKind.dashedLine:
        BoardDiagramPainter.drawDashedLine(canvas, shape.start, shape.end, paint);
      case BoardShapeKind.arrow:
        BoardDiagramPainter.drawArrowLine(canvas, shape.start, shape.end, paint);
      case BoardShapeKind.rect:
        canvas.drawRect(rect, paint);
      case BoardShapeKind.oval:
        canvas.drawOval(rect, paint);
      case BoardShapeKind.axes:
        _paintCoordinateAxes(canvas, rect, paint);
    }
  }

  static void _paintCoordinateAxes(Canvas canvas, Rect rect, Paint paint) {
    if (rect.width < 24 || rect.height < 24) {
      canvas.drawRect(rect, paint);
      return;
    }
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final axisPaint = Paint()
      ..color = paint.color
      ..strokeWidth = math.max(1.8, paint.strokeWidth * 0.85)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // X 轴 & Y 轴带箭头
    BoardDiagramPainter.drawArrowLine(
      canvas,
      Offset(rect.left, cy),
      Offset(rect.right, cy),
      axisPaint,
      headLen: 9,
    );
    BoardDiagramPainter.drawArrowLine(
      canvas,
      Offset(cx, rect.bottom),
      Offset(cx, rect.top),
      axisPaint,
      headLen: 9,
    );

    // 刻度线
    const tickStep = 28.0;
    final tickPaint = Paint()
      ..color = paint.color.withValues(alpha: 0.65)
      ..strokeWidth = 1.2;
    for (var x = cx + tickStep; x < rect.right - 14; x += tickStep) {
      canvas.drawLine(Offset(x, cy - 3.5), Offset(x, cy + 3.5), tickPaint);
    }
    for (var x = cx - tickStep; x > rect.left + 8; x -= tickStep) {
      canvas.drawLine(Offset(x, cy - 3.5), Offset(x, cy + 3.5), tickPaint);
    }
    for (var y = cy - tickStep; y > rect.top + 14; y -= tickStep) {
      canvas.drawLine(Offset(cx - 3.5, y), Offset(cx + 3.5, y), tickPaint);
    }
    for (var y = cy + tickStep; y < rect.bottom - 8; y += tickStep) {
      canvas.drawLine(Offset(cx - 3.5, y), Offset(cx + 3.5, y), tickPaint);
    }

    void drawAxisText(String text, Offset pos) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: paint.color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos);
    }

    drawAxisText('x', Offset(rect.right - 12, cy + 6));
    drawAxisText('y', Offset(cx + 8, rect.top + 2));
    drawAxisText('O', Offset(cx - 14, cy + 4));
  }

  static void paintProblemCard(
    Canvas canvas,
    AiRecognizeResult problem,
    Rect rect, {
    ui.Image? photo,
    bool highlighted = false,
  }) {
    _paintCardShell(
      canvas,
      rect,
      headerColor: const Color(0xFFE0F2FE),
      borderColor:
          highlighted ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
      title: '题目板书 · ${problem.title}',
      badgeText: '${problem.subjectTag} · ${problem.difficulty}',
      badgeBg: const Color(0xFF0284C7),
      badgeFg: Colors.white,
    );

    final contentW = rect.width - 32;
    var y = rect.top + 48;
    final x = rect.left + 16;

    if (problem.problemText.isNotEmpty) {
      y += CanvasMathPainter.paint(
        canvas,
        problem.problemText,
        origin: Offset(x, y),
        maxWidth: contentW,
        style: _problemBodyStyle,
      );
      y += 10;
    }

    if (problem.knownConditions.isNotEmpty) {
      y = _paintMiniSectionTitle(canvas, '已知条件', Offset(x, y), const Color(0xFF0369A1));
      for (final cond in problem.knownConditions) {
        y += CanvasMathPainter.paint(
          canvas,
          '• $cond',
          origin: Offset(x + 6, y),
          maxWidth: contentW - 10,
          style: _metaBodyStyle,
        );
        y += 4;
      }
      y += 6;
    }

    if (problem.targets.isNotEmpty) {
      y = _paintMiniSectionTitle(canvas, '求解目标', Offset(x, y), const Color(0xFF0F766E));
      for (final target in problem.targets) {
        y += CanvasMathPainter.paint(
          canvas,
          '▸ $target',
          origin: Offset(x + 6, y),
          maxWidth: contentW - 10,
          style: _metaBodyStyle,
        );
        y += 4;
      }
      y += 6;
    }

    if (photo != null) {
      final photoRect = Rect.fromLTWH(x, y, contentW, 152);
      final rrect = RRect.fromRectAndRadius(photoRect, const Radius.circular(8));
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawRect(photoRect, Paint()..color = const Color(0xFFF1F5F9));
      final srcSize = Size(photo.width.toDouble(), photo.height.toDouble());
      final fitted = applyBoxFit(BoxFit.contain, srcSize, photoRect.size);
      final dst = Alignment.center.inscribe(fitted.destination, photoRect);
      canvas.drawImageRect(
        photo,
        Offset.zero & srcSize,
        dst,
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = const Color(0xFFCBD5E1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      y += 162;
    }

    for (final diagram in problem.diagrams) {
      final dRect = Rect.fromLTWH(x, y, contentW, 186);
      BoardDiagramPainter.paintDiagram(canvas, diagram, dRect);
      y += 196;
    }
  }

  static void paintGuidanceCard(
    Canvas canvas,
    AiBoardGuidance guidance,
    Rect rect, {
    double revealProgress = 1.0,
    bool highlighted = false,
  }) {
    final isIdeas = guidance.isIdeas;
    final accent = isIdeas ? const Color(0xFFD97706) : const Color(0xFF059669);
    final headerBg =
        isIdeas ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5);
    final titlePrefix = isIdeas ? '💡 AI 解题思路' : '✨ AI 解题分析与板书';

    final clampedReveal = revealProgress.clamp(0.05, 1.0);
    final visibleRect = clampedReveal >= 0.999
        ? rect
        : Rect.fromLTWH(
            rect.left,
            rect.top,
            rect.width,
            math.max(66.0, rect.height * clampedReveal),
          );

    canvas.save();
    if (clampedReveal < 0.999) {
      canvas.clipRRect(
        RRect.fromRectAndRadius(visibleRect, const Radius.circular(14)),
      );
    }

    _paintCardShell(
      canvas,
      rect,
      headerColor: headerBg,
      borderColor: highlighted ? accent : const Color(0xFF1E293B),
      title: '$titlePrefix · ${guidance.headline}',
      badgeText: guidance.knowledgePoints.isNotEmpty
          ? guidance.knowledgePoints.first
          : (isIdeas ? '启发思路' : '规范板书'),
      badgeBg: accent,
      badgeFg: Colors.white,
    );

    final contentW = rect.width - 32;
    var y = rect.top + 48;
    final x = rect.left + 16;

    // 1. 总领点评
    if (guidance.summary.isNotEmpty) {
      final sumH = CanvasMathPainter.measureHeight(
        guidance.summary,
        maxWidth: contentW - 16,
        style: _summaryStyle,
      );
      final box = Rect.fromLTWH(x, y, contentW, sumH + 14);
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(8)),
        Paint()..color = headerBg.withValues(alpha: 0.45),
      );
      canvas.drawLine(
        Offset(box.left + 3, box.top + 5),
        Offset(box.left + 3, box.bottom - 5),
        Paint()
          ..color = accent
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round,
      );
      CanvasMathPainter.paint(
        canvas,
        guidance.summary,
        origin: Offset(x + 12, y + 7),
        maxWidth: contentW - 16,
        style: _summaryStyle,
      );
      y += sumH + 22;
    }

    // 2. 学生手写过程诊断卡
    final diag = guidance.studentDiagnosis;
    if (diag != null &&
        (diag.comment.isNotEmpty || diag.mistakePoint.isNotEmpty)) {
      final isCorrect = diag.status == 'CORRECT';
      final isWrong = diag.status == 'INCORRECT';
      final diagAccent = isCorrect
          ? const Color(0xFF059669)
          : (isWrong ? const Color(0xFFDC2626) : const Color(0xFFD97706));
      final diagBg = isCorrect
          ? const Color(0xFFECFDF5)
          : (isWrong ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB));
      final diagLabel = switch (diag.status) {
        'CORRECT' => '手写诊断 · 步骤正确',
        'PARTIAL' => '手写诊断 · 部分正确',
        'INCORRECT' => '手写诊断 · 发现错误',
        _ => '起步建议',
      };

      var innerH = 22.0;
      if (diag.comment.isNotEmpty) {
        innerH += CanvasMathPainter.measureHeight(
              diag.comment,
              maxWidth: contentW - 20,
              style: _metaBodyStyle,
            ) +
            5;
      }
      if (diag.mistakePoint.isNotEmpty) {
        innerH += CanvasMathPainter.measureHeight(
              '定位：${diag.mistakePoint}',
              maxWidth: contentW - 20,
              style: _metaBodyStyle,
            ) +
            5;
      }
      if (diag.suggestion.isNotEmpty) {
        innerH += CanvasMathPainter.measureHeight(
              '建议：${diag.suggestion}',
              maxWidth: contentW - 20,
              style: _metaBodyStyle,
            ) +
            5;
      }

      final diagRect = Rect.fromLTWH(x, y, contentW, innerH + 10);
      canvas.drawRRect(
        RRect.fromRectAndRadius(diagRect, const Radius.circular(8)),
        Paint()..color = diagBg,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(diagRect, const Radius.circular(8)),
        Paint()
          ..color = diagAccent.withValues(alpha: 0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3,
      );

      var dy = y + 7;
      dy = _paintMiniSectionTitle(canvas, diagLabel, Offset(x + 10, dy), diagAccent);
      if (diag.comment.isNotEmpty) {
        dy += CanvasMathPainter.paint(
          canvas,
          diag.comment,
          origin: Offset(x + 10, dy),
          maxWidth: contentW - 20,
          style: _metaBodyStyle,
        );
        dy += 4;
      }
      if (diag.mistakePoint.isNotEmpty) {
        dy += CanvasMathPainter.paint(
          canvas,
          '定位：${diag.mistakePoint}',
          origin: Offset(x + 10, dy),
          maxWidth: contentW - 20,
          style: _metaBodyStyle.copyWith(color: const Color(0xFFB91C1C)),
        );
        dy += 4;
      }
      if (diag.suggestion.isNotEmpty) {
        CanvasMathPainter.paint(
          canvas,
          '建议：${diag.suggestion}',
          origin: Offset(x + 10, dy),
          maxWidth: contentW - 20,
          style: _metaBodyStyle.copyWith(color: const Color(0xFF0F766E)),
        );
      }
      y = diagRect.bottom + 10;
    }

    // 3. 分步板书绘制（含序号胶囊 + 流程竖线 + 公式高亮块）
    for (var i = 0; i < guidance.steps.length; i++) {
      final step = guidance.steps[i];
      final stepStartY = y;

      // 步骤圆标
      final badgeCenter = Offset(x + 10, y + 10);
      canvas.drawCircle(badgeCenter, 9.5, Paint()..color = accent);
      final noTp = TextPainter(
        text: TextSpan(
          text: '${step.stepNo}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      noTp.paint(
        canvas,
        Offset(
          badgeCenter.dx - noTp.width / 2,
          badgeCenter.dy - noTp.height / 2,
        ),
      );

      final titleTp = TextPainter(
        text: TextSpan(
          text: step.title.isNotEmpty ? step.title : '第 ${step.stepNo} 步',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            fontFamilyFallback: AppTheme.cjkFontFallback,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(maxWidth: contentW - 28);
      titleTp.paint(canvas, Offset(x + 25, y + 1));
      y += 24;

      if (step.content.isNotEmpty) {
        y += CanvasMathPainter.paint(
          canvas,
          step.content,
          origin: Offset(x + 22, y),
          maxWidth: contentW - 22,
          style: _stepBodyStyle,
        );
        y += 5;
      }

      if (step.formula.isNotEmpty) {
        final fh = CanvasMathPainter.measureHeight(
          step.formula,
          maxWidth: contentW - 36,
          style: _formulaBoxStyle,
        );
        final fBox = Rect.fromLTWH(x + 20, y, contentW - 20, fh + 12);
        canvas.drawRRect(
          RRect.fromRectAndRadius(fBox, const Radius.circular(7)),
          Paint()..color = const Color(0xFFEFF6FF),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(fBox, const Radius.circular(7)),
          Paint()
            ..color = const Color(0xFFBFDBFE)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
        CanvasMathPainter.paint(
          canvas,
          step.formula,
          origin: Offset(x + 28, y + 6),
          maxWidth: contentW - 36,
          style: _formulaBoxStyle,
        );
        y = fBox.bottom + 6;
      }

      if (step.highlight.isNotEmpty) {
        y += CanvasMathPainter.paint(
          canvas,
          '💡 ${step.highlight}',
          origin: Offset(x + 22, y),
          maxWidth: contentW - 24,
          style: _tipStyle,
        );
        y += 5;
      }

      // 步骤连接线
      if (i < guidance.steps.length - 1) {
        canvas.drawLine(
          Offset(x + 10, stepStartY + 21),
          Offset(x + 10, y + 4),
          Paint()
            ..color = accent.withValues(alpha: 0.32)
            ..strokeWidth = 1.8,
        );
      }
      y += 8;
    }

    // 4. 最终结论
    if (guidance.finalAnswer.isNotEmpty) {
      final ansH = CanvasMathPainter.measureHeight(
        guidance.finalAnswer,
        maxWidth: contentW - 24,
        style: _answerStyle,
      );
      final aBox = Rect.fromLTWH(x, y, contentW, ansH + 34);
      canvas.drawRRect(
        RRect.fromRectAndRadius(aBox, const Radius.circular(9)),
        Paint()..color = const Color(0xFFECFDF5),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(aBox, const Radius.circular(9)),
        Paint()
          ..color = const Color(0xFF10B981)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      final labelY = _paintMiniSectionTitle(
        canvas,
        isIdeas ? '目标检验 / 关键结论' : '最终答案',
        Offset(x + 10, y + 7),
        const Color(0xFF047857),
      );
      CanvasMathPainter.paint(
        canvas,
        guidance.finalAnswer,
        origin: Offset(x + 10, labelY),
        maxWidth: contentW - 24,
        style: _answerStyle,
      );
      y = aBox.bottom + 10;
    }

    // 5. 易错点提醒
    if (guidance.pitfalls.isNotEmpty) {
      y = _paintMiniSectionTitle(canvas, '易错警示', Offset(x, y), const Color(0xFFB45309));
      for (final pit in guidance.pitfalls) {
        y += CanvasMathPainter.paint(
          canvas,
          '⚠ $pit',
          origin: Offset(x + 4, y),
          maxWidth: contentW - 14,
          style: _tipStyle,
        );
        y += 4;
      }
      y += 6;
    }

    // 6. 矢量几何 / 函数示意图
    for (final diagram in guidance.diagrams) {
      final dRect = Rect.fromLTWH(x, y, contentW, 188);
      BoardDiagramPainter.paintDiagram(canvas, diagram, dRect);
      y += 198;
    }

    canvas.restore();
  }

  static void _paintCardShell(
    Canvas canvas,
    Rect rect, {
    required Color headerColor,
    required Color borderColor,
    required String title,
    required String badgeText,
    required Color badgeBg,
    required Color badgeFg,
  }) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14));
    // 漫画硬阴影
    canvas.drawRRect(
      rrect.shift(const Offset(3.5, 3.5)),
      Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.14),
    );
    // 卡片纯白底
    canvas.drawRRect(rrect, Paint()..color = Colors.white);

    // 标题栏底色
    final headerRect = Rect.fromLTWH(rect.left, rect.top, rect.width, 38);
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(headerRect, Paint()..color = headerColor);
    canvas.drawLine(
      Offset(rect.left, rect.top + 38),
      Offset(rect.right, rect.top + 38),
      Paint()
        ..color = borderColor
        ..strokeWidth = 1.6,
    );
    canvas.restore();

    // 徽章
    final badgeTp = TextPainter(
      text: TextSpan(
        text: badgeText,
        style: TextStyle(
          color: badgeFg,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          fontFamilyFallback: AppTheme.cjkFontFallback,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 130);
    final badgeW = badgeTp.width + 14;
    final badgeRect = Rect.fromLTWH(
      rect.right - badgeW - 10,
      rect.top + 9,
      badgeW,
      20,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(6)),
      Paint()..color = badgeBg,
    );
    badgeTp.paint(
      canvas,
      Offset(badgeRect.left + 7, badgeRect.top + (20 - badgeTp.height) / 2),
    );

    // 标题文字（左侧带抓手图标提示可拖动）
    final titleTp = TextPainter(
      text: TextSpan(
        text: '⋮⋮ $title',
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 12.8,
          fontWeight: FontWeight.w800,
          fontFamilyFallback: AppTheme.cjkFontFallback,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: math.max(60, rect.width - badgeW - 34));
    titleTp.paint(
      canvas,
      Offset(rect.left + 12, rect.top + (38 - titleTp.height) / 2),
    );

    // 外描边
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  static double _paintMiniSectionTitle(
    Canvas canvas,
    String title,
    Offset pos,
    Color color,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: title,
        style: TextStyle(
          color: color,
          fontSize: 11.8,
          fontWeight: FontWeight.w800,
          fontFamilyFallback: AppTheme.cjkFontFallback,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
    return pos.dy + tp.height + 3;
  }
}

/// 离屏高清渲染画板内容为 PNG 字节流：
/// - [includeAiCards] = false 时仅渲染题目板书 + 学生笔迹 + 几何图形（最适合提交给 AI 诊断手写过程，避免旧 AI 解答干扰）；
/// - [includeAiCards] = true 时渲染完整画板（包含题目、学生笔迹、几何图、AI 思路与 AI 过程板书）。
Future<Uint8List> renderSmartBoardToPng({
  required List<BoardStroke> strokes,
  required List<BoardShape> shapes,
  SmartBoardCardState cards = const SmartBoardCardState(),
  BoardLayerVisibility visibility = const BoardLayerVisibility(),
  ui.Image? problemPhoto,
  bool includeProblemCard = false,
  bool includeAiCards = false,
  double maxDimension = 1800.0,
}) async {
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = double.negativeInfinity;
  var maxY = double.negativeInfinity;

  void includeRect(Rect r) {
    if (r.left < minX) minX = r.left;
    if (r.top < minY) minY = r.top;
    if (r.right > maxX) maxX = r.right;
    if (r.bottom > maxY) maxY = r.bottom;
  }

  for (final s in strokes) {
    if (s.isEraser) continue;
    final b = s.bounds;
    if (b != null) includeRect(b);
  }
  for (final sh in shapes) {
    includeRect(sh.bounds);
  }

  final exportVis = BoardLayerVisibility(
    showProblemCard: includeProblemCard && visibility.showProblemCard,
    showPhotoCard: includeProblemCard && visibility.showPhotoCard,
    showIdeasCard: includeAiCards && visibility.showIdeasCard,
    showSolutionCard: includeAiCards && visibility.showSolutionCard,
  );
  final metrics = SmartBoardLayoutMetrics.compute(
    cards: cards,
    visibility: exportVis,
    problemPhoto: problemPhoto,
  );
  if (metrics.problemRect != null) includeRect(metrics.problemRect!);
  if (metrics.ideasRect != null) includeRect(metrics.ideasRect!);
  if (metrics.solutionRect != null) includeRect(metrics.solutionRect!);

  if (!minX.isFinite || !minY.isFinite) {
    throw StateError('画板暂无可导出内容');
  }

  const pad = 36.0;
  final rawW = math.max(480.0, maxX - minX + pad * 2);
  final rawH = math.max(300.0, maxY - minY + pad * 2);
  final scale = math.min(
    2.0,
    math.min(maxDimension / rawW, maxDimension / rawH),
  );
  final outW = math.max(1, (rawW * scale).round());
  final outH = math.max(1, (rawH * scale).round());

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
    Paint()..color = Colors.white,
  );

  canvas.save();
  canvas.scale(scale, scale);
  canvas.translate(pad - minX, pad - minY);

  if (cards.problem != null &&
      exportVis.showProblemCard &&
      metrics.problemRect != null) {
    SmartBoardPainter.paintProblemCard(
      canvas,
      cards.problem!,
      metrics.problemRect!,
      photo: exportVis.showPhotoCard ? problemPhoto : null,
    );
  }
  if (cards.ideas != null &&
      exportVis.showIdeasCard &&
      metrics.ideasRect != null) {
    SmartBoardPainter.paintGuidanceCard(
      canvas,
      cards.ideas!,
      metrics.ideasRect!,
    );
  }
  if (cards.solution != null &&
      exportVis.showSolutionCard &&
      metrics.solutionRect != null) {
    SmartBoardPainter.paintGuidanceCard(
      canvas,
      cards.solution!,
      metrics.solutionRect!,
    );
  }

  for (final sh in shapes) {
    SmartBoardPainter.paintShape(canvas, sh);
  }
  for (final s in strokes) {
    if (s.isHighlighter) SmartBoardPainter.paintStroke(canvas, s);
  }
  for (final s in strokes) {
    if (!s.isHighlighter) SmartBoardPainter.paintStroke(canvas, s);
  }

  canvas.restore();

  final picture = recorder.endRecording();
  final image = await picture.toImage(outW, outH);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (byteData == null) {
    throw StateError('生成画板图片失败');
  }
  return byteData.buffer.asUint8List();
}
