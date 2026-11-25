import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../models/models.dart';
import 'board_diagram_painter.dart';
import 'board_models.dart';
import 'canvas_math_painter.dart';

/// 计算每块世界坐标白板板书区域的精确外接矩形（供拖动命中、防重叠排版、自动对焦与导出使用）
class SmartBoardLayoutMetrics {
  const SmartBoardLayoutMetrics({
    this.problemRect,
    this.ideasRect,
    this.diagnosisRect,
    this.solutionRect,
  });

  final Rect? problemRect;
  final Rect? ideasRect;
  final Rect? diagnosisRect;
  final Rect? solutionRect;

  Rect? rectOf(BoardCardId id) => switch (id) {
        BoardCardId.problem => problemRect,
        BoardCardId.ideas => ideasRect,
        BoardCardId.diagnosis => diagnosisRect,
        BoardCardId.solution => solutionRect,
      };

  static SmartBoardLayoutMetrics compute({
    required SmartBoardCardState cards,
    required BoardLayerVisibility visibility,
    ui.Image? problemPhoto,
  }) {
    Rect? pRect;
    if (cards.problem != null && visibility.showProblemCard) {
      final h = measureProblemHeight(
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
      final h = measureGuidanceHeight(cards.ideas!, cards.ideasWidth);
      iRect = Rect.fromLTWH(
        cards.ideasPos.dx,
        cards.ideasPos.dy,
        cards.ideasWidth,
        h,
      );
    }

    Rect? dRect;
    if (cards.diagnosis != null && visibility.showDiagnosisCard) {
      final h = measureGuidanceHeight(cards.diagnosis!, cards.diagnosisWidth);
      dRect = Rect.fromLTWH(
        cards.diagnosisPos.dx,
        cards.diagnosisPos.dy,
        cards.diagnosisWidth,
        h,
      );
    }

    Rect? sRect;
    if (cards.solution != null && visibility.showSolutionCard) {
      final h = measureGuidanceHeight(cards.solution!, cards.solutionWidth);
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
      diagnosisRect: dRect,
      solutionRect: sRect,
    );
  }

  static double measureProblemHeight(
    AiRecognizeResult problem,
    double width, {
    bool hasPhoto = false,
  }) {
    final contentW = width - 24;
    var h = 34.0;
    if (problem.problemText.isNotEmpty) {
      h += CanvasMathPainter.measureHeight(
            problem.problemText,
            maxWidth: contentW,
            style: _problemBodyStyle,
          ) +
          10;
    }
    if (problem.knownConditions.isNotEmpty) {
      h += 18;
      for (final c in problem.knownConditions) {
        h += CanvasMathPainter.measureHeight(
              '· $c',
              maxWidth: contentW - 8,
              style: _subtleMetaStyle,
            ) +
            3;
      }
      h += 6;
    }
    if (problem.targets.isNotEmpty) {
      h += 18;
      for (final t in problem.targets) {
        h += CanvasMathPainter.measureHeight(
              '→ $t',
              maxWidth: contentW - 8,
              style: _subtleMetaStyle,
            ) +
            3;
      }
      h += 6;
    }
    if (hasPhoto) {
      h += 156;
    }
    if (problem.diagrams.isNotEmpty) {
      h += problem.diagrams.length * 188.0;
    }
    return math.max(96, h + 10);
  }

  static double measureGuidanceHeight(
    AiBoardGuidance guidance,
    double width,
  ) {
    final contentW = width - 24;
    var h = 36.0;

    if (guidance.summary.isNotEmpty) {
      h += CanvasMathPainter.measureHeight(
            guidance.summary,
            maxWidth: contentW,
            style: _summaryStyle,
          ) +
          8;
    }

    final diag = guidance.studentDiagnosis;
    if (guidance.isDiagnose &&
        diag != null &&
        (diag.comment.isNotEmpty || diag.mistakePoint.isNotEmpty)) {
      h += 22;
      if (diag.comment.isNotEmpty) {
        h += CanvasMathPainter.measureHeight(
              diag.comment,
              maxWidth: contentW - 8,
              style: _stepBodyStyle,
            ) +
            5;
      }
      if (diag.mistakePoint.isNotEmpty) {
        h += CanvasMathPainter.measureHeight(
              '错因：${diag.mistakePoint}',
              maxWidth: contentW - 8,
              style: _stepBodyStyle,
            ) +
            5;
      }
      if (diag.suggestion.isNotEmpty) {
        h += CanvasMathPainter.measureHeight(
              '建议：${diag.suggestion}',
              maxWidth: contentW - 8,
              style: _stepBodyStyle,
            ) +
            5;
      }
      h += 8;
    }

    for (final step in guidance.steps) {
      final header = step.title.isNotEmpty
          ? '${step.stepNo}. ${step.title}'
          : '${step.stepNo}.';
      h += CanvasMathPainter.measureHeight(
            header,
            maxWidth: contentW,
            style: _stepTitleStyle,
          ) +
          4;
      if (step.content.isNotEmpty) {
        h += CanvasMathPainter.measureHeight(
              step.content,
              maxWidth: contentW - 14,
              style: _stepBodyStyle,
            ) +
            4;
      }
      if (step.formula.isNotEmpty) {
        h += CanvasMathPainter.measureHeight(
              step.formula,
              maxWidth: contentW - 18,
              style: _formulaStyle,
            ) +
            8;
      }
      if (step.highlight.isNotEmpty) {
        h += CanvasMathPainter.measureHeight(
              '注：${step.highlight}',
              maxWidth: contentW - 14,
              style: _noteStyle,
            ) +
            4;
      }
      h += 8;
    }

    if (guidance.isSolve && guidance.finalAnswer.isNotEmpty) {
      h += CanvasMathPainter.measureHeight(
            '答：${guidance.finalAnswer}',
            maxWidth: contentW,
            style: _answerStyle,
          ) +
          14;
    }

    if (guidance.pitfalls.isNotEmpty) {
      for (final pit in guidance.pitfalls) {
        h += CanvasMathPainter.measureHeight(
              '注意：$pit',
              maxWidth: contentW - 4,
              style: _noteStyle,
            ) +
            4;
      }
      h += 4;
    }

    if (guidance.diagrams.isNotEmpty) {
      h += guidance.diagrams.length * 190.0;
    }
    return math.max(96, h + 10);
  }
}

const TextStyle _problemBodyStyle = TextStyle(
  color: Color(0xFF0F172A),
  fontSize: 14.5,
  height: 1.55,
  fontWeight: FontWeight.w600,
  fontFamilyFallback: AppTheme.cjkFontFallback,
);

const TextStyle _subtleMetaStyle = TextStyle(
  color: Color(0xFF475569),
  fontSize: 12.6,
  height: 1.46,
  fontWeight: FontWeight.w500,
  fontFamilyFallback: AppTheme.cjkFontFallback,
);

const TextStyle _summaryStyle = TextStyle(
  color: Color(0xFF334155),
  fontSize: 13.0,
  height: 1.46,
  fontWeight: FontWeight.w600,
  fontFamilyFallback: AppTheme.cjkFontFallback,
);

const TextStyle _stepTitleStyle = TextStyle(
  color: Color(0xFF0F172A),
  fontSize: 13.6,
  height: 1.45,
  fontWeight: FontWeight.w800,
  fontFamilyFallback: AppTheme.cjkFontFallback,
);

const TextStyle _stepBodyStyle = TextStyle(
  color: Color(0xFF1E293B),
  fontSize: 13.4,
  height: 1.5,
  fontWeight: FontWeight.w500,
  fontFamilyFallback: AppTheme.cjkFontFallback,
);

const TextStyle _formulaStyle = TextStyle(
  color: Color(0xFF1D4ED8),
  fontSize: 14.4,
  height: 1.52,
  fontWeight: FontWeight.w700,
  fontFamilyFallback: AppTheme.cjkFontFallback,
);

const TextStyle _answerStyle = TextStyle(
  color: Color(0xFF0F172A),
  fontSize: 14.6,
  height: 1.52,
  fontWeight: FontWeight.w800,
  fontFamilyFallback: AppTheme.cjkFontFallback,
);

const TextStyle _noteStyle = TextStyle(
  color: Color(0xFF64748B),
  fontSize: 12.2,
  height: 1.44,
  fontWeight: FontWeight.w500,
  fontFamilyFallback: AppTheme.cjkFontFallback,
);

class _WriteTask {
  const _WriteTask({
    required this.weight,
    required this.paint,
  });

  final double weight;
  final Offset? Function(Canvas canvas, double localT) paint;
}

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
    this.diagnosisReveal = 1.0,
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
  final double diagnosisReveal;
  final double solutionReveal;
  final BoardCardId? draggingCardId;
  final Offset? eraserCursorWorld;
  final double eraserCursorRadius;

  @override
  void paint(Canvas canvas, Size size) {
    // 强硬裁剪画板视口边界，确保板书与笔迹永不越界覆盖顶栏或底栏导航！
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // 1. 纸张底纹
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

    Offset? activeAiPenTip;
    Color activeAiPenColor = const Color(0xFF1D4ED8);

    // 3. 题目板书区（极简干净白板风）
    if (cards.problem != null &&
        visibility.showProblemCard &&
        metrics.problemRect != null) {
      paintProblemBlock(
        canvas,
        cards.problem!,
        metrics.problemRect!,
        photo: visibility.showPhotoCard ? problemPhoto : null,
        highlighted: draggingCardId == BoardCardId.problem,
      );
    }

    // 4. AI 解题思路区（蓝笔引导 · 逐字逐笔按坐标手写绘制，不给答案）
    if (cards.ideas != null &&
        visibility.showIdeasCard &&
        metrics.ideasRect != null) {
      final tip = paintGuidanceBlock(
        canvas,
        cards.ideas!,
        metrics.ideasRect!,
        revealProgress: ideasReveal,
        highlighted: draggingCardId == BoardCardId.ideas,
      );
      if (tip != null) {
        activeAiPenTip = tip;
        activeAiPenColor = const Color(0xFF1D4ED8);
      }
    }

    // 5. AI 手写诊断区（红/绿批改笔 · 仅诊断对错不给答案）
    if (cards.diagnosis != null &&
        visibility.showDiagnosisCard &&
        metrics.diagnosisRect != null) {
      final tip = paintGuidanceBlock(
        canvas,
        cards.diagnosis!,
        metrics.diagnosisRect!,
        revealProgress: diagnosisReveal,
        highlighted: draggingCardId == BoardCardId.diagnosis,
      );
      if (tip != null) {
        activeAiPenTip = tip;
        activeAiPenColor = const Color(0xFFDC2626);
      }
    }

    // 6. AI 完整解题区（规范钢笔板书 · 逐字逐笔按坐标绘制完整过程与答案）
    if (cards.solution != null &&
        visibility.showSolutionCard &&
        metrics.solutionRect != null) {
      final tip = paintGuidanceBlock(
        canvas,
        cards.solution!,
        metrics.solutionRect!,
        revealProgress: solutionReveal,
        highlighted: draggingCardId == BoardCardId.solution,
      );
      if (tip != null) {
        activeAiPenTip = tip;
        activeAiPenColor = const Color(0xFF0F172A);
      }
    }

    // 7. 几何图形与坐标系
    for (final shape in shapes) {
      paintShape(canvas, shape);
    }
    if (activeShape != null) {
      paintShape(canvas, activeShape!);
    }

    // 8. 学生手写笔迹（先荧光笔后钢笔）
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

    // 9. 拟真动态书写笔尖（AI 正在坐标逐笔绘制时跟随显示）
    if (activeAiPenTip != null) {
      _paintActivePenNib(canvas, activeAiPenTip, activeAiPenColor);
    }

    // 10. 橡皮擦光标环
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
    canvas.restore();
  }

  @override
  bool shouldRepaint(SmartBoardPainter oldDelegate) => true;

  static void _paintActivePenNib(Canvas canvas, Offset tip, Color inkColor) {
    // 笔尖着墨微光
    canvas.drawCircle(
      tip,
      5.5,
      Paint()..color = inkColor.withValues(alpha: 0.22),
    );
    canvas.drawCircle(tip, 2.3, Paint()..color = inkColor);

    // 倾斜的极简手写笔杆（向右上方 45 度倾斜）
    final nibNeck = tip + const Offset(6, -8);
    final bodyTop = tip + const Offset(22, -30);

    // 金属笔尖三角
    final nibPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(nibNeck.dx - 3.2, nibNeck.dy - 2.4)
      ..lineTo(nibNeck.dx + 3.2, nibNeck.dy + 2.4)
      ..close();
    canvas.drawPath(nibPath, Paint()..color = const Color(0xFF94A3B8));

    // 笔杆
    canvas.drawLine(
      nibNeck,
      bodyTop,
      Paint()
        ..color = inkColor
        ..strokeWidth = 6.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      nibNeck,
      bodyTop,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  static void paintPaperBackground(
    Canvas canvas,
    Size size, {
    required BoardPaperStyle paperStyle,
    required double panX,
    required double panY,
    required double zoom,
  }) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFCFDFF),
    );
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

  /// 极简干净的题目白板区（无花哨边框与阴影）
  static void paintProblemBlock(
    Canvas canvas,
    AiRecognizeResult problem,
    Rect rect, {
    ui.Image? photo,
    bool highlighted = false,
  }) {
    _paintMinimalBlockFrame(
      canvas,
      rect,
      accent: const Color(0xFF334155),
      title: '题目 · ${problem.title}',
      highlighted: highlighted,
    );

    final contentW = rect.width - 24;
    var y = rect.top + 32;
    final x = rect.left + 14;

    if (problem.problemText.isNotEmpty) {
      y += CanvasMathPainter.paint(
        canvas,
        problem.problemText,
        origin: Offset(x, y),
        maxWidth: contentW,
        style: _problemBodyStyle,
      );
      y += 8;
    }

    if (problem.knownConditions.isNotEmpty) {
      y = _paintMiniLabel(canvas, '已知：', Offset(x, y), const Color(0xFF475569));
      for (final cond in problem.knownConditions) {
        y += CanvasMathPainter.paint(
          canvas,
          '· $cond',
          origin: Offset(x + 6, y),
          maxWidth: contentW - 8,
          style: _subtleMetaStyle,
        );
        y += 3;
      }
      y += 5;
    }

    if (problem.targets.isNotEmpty) {
      y = _paintMiniLabel(canvas, '求/证：', Offset(x, y), const Color(0xFF475569));
      for (final target in problem.targets) {
        y += CanvasMathPainter.paint(
          canvas,
          '→ $target',
          origin: Offset(x + 6, y),
          maxWidth: contentW - 8,
          style: _subtleMetaStyle,
        );
        y += 3;
      }
      y += 5;
    }

    if (photo != null) {
      final photoRect = Rect.fromLTWH(x, y, contentW, 146);
      final rrect = RRect.fromRectAndRadius(photoRect, const Radius.circular(6));
      canvas.save();
      canvas.clipRRect(rrect);
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
          ..strokeWidth = 1.0,
      );
      y += 156;
    }

    for (final diagram in problem.diagrams) {
      final dRect = Rect.fromLTWH(x, y, contentW, 180);
      BoardDiagramPainter.paintDiagram(canvas, diagram, dRect);
      y += 188;
    }
  }

  /// 极简白板 AI 板书块（支持坐标级逐字/逐笔自动手写与矢量作图动画，返回实时笔尖坐标）
  static Offset? paintGuidanceBlock(
    Canvas canvas,
    AiBoardGuidance guidance,
    Rect rect, {
    double revealProgress = 1.0,
    bool highlighted = false,
  }) {
    final isIdeas = guidance.isIdeas;
    final isDiagnose = guidance.isDiagnose;
    final accent = isIdeas
        ? const Color(0xFF1D4ED8) // 思路：教研蓝笔
        : (isDiagnose
            ? const Color(0xFFDC2626) // 诊断：老师批改红笔
            : const Color(0xFF0F172A)); // 解题：规范黑钢笔
    final labelPrefix = isIdeas ? '思路' : (isDiagnose ? '诊断' : '解题');

    final clampedReveal = revealProgress.clamp(0.0, 1.0);
    if (clampedReveal <= 0.001) return null;

    // 极简左细线 + 极轻标题与拖动手柄
    _paintMinimalBlockFrame(
      canvas,
      rect,
      accent: accent,
      title: '$labelPrefix · ${guidance.headline}',
      highlighted: highlighted,
    );

    final contentW = rect.width - 24;
    final x = rect.left + 14;
    var y = rect.top + 34;

    // 按顺序编译所有板书书写与矢量绘图任务，实现真正的一笔一画连续绘制
    final tasks = <_WriteTask>[];

    final bodyInk = isIdeas
        ? _stepBodyStyle.copyWith(color: const Color(0xFF1E3A8A))
        : (isDiagnose
            ? _stepBodyStyle.copyWith(color: const Color(0xFF7F1D1D))
            : _stepBodyStyle);
    final titleInk = _stepTitleStyle.copyWith(color: accent);
    final formulaInk = _formulaStyle.copyWith(
      color: isDiagnose ? const Color(0xFFB91C1C) : const Color(0xFF1D4ED8),
    );

    if (guidance.summary.isNotEmpty) {
      final startY = y;
      final sumText = guidance.summary;
      final h = CanvasMathPainter.measureHeight(
        sumText,
        maxWidth: contentW,
        style: _summaryStyle,
      );
      tasks.add(
        _WriteTask(
          weight: CanvasMathPainter.estimateWriteWeight(sumText),
          paint: (c, t) => CanvasMathPainter.paintProgressive(
            c,
            sumText,
            origin: Offset(x, startY),
            maxWidth: contentW,
            style: _summaryStyle.copyWith(
              color: isIdeas ? const Color(0xFF1E40AF) : const Color(0xFF334155),
            ),
            progress: t,
          ).penTip,
        ),
      );
      y += h + 8;
    }

    // 诊断模式专属：简洁批改印章与定位（无花哨背景盒，绝不给答案）
    final diag = guidance.studentDiagnosis;
    if (isDiagnose &&
        diag != null &&
        (diag.comment.isNotEmpty || diag.mistakePoint.isNotEmpty)) {
      final isCorrect = diag.status == 'CORRECT';
      final isWrong = diag.status == 'INCORRECT';
      final statusColor = isCorrect
          ? const Color(0xFF059669)
          : (isWrong ? const Color(0xFFDC2626) : const Color(0xFFD97706));
      final verdictText = switch (diag.status) {
        'CORRECT' => '✓ 过程正确',
        'PARTIAL' => '△ 部分正确（可继续完善）',
        'INCORRECT' => '✗ 发现错误步骤',
        _ => '批改诊断',
      };

      final vy = y;
      tasks.add(
        _WriteTask(
          weight: 8,
          paint: (c, t) => CanvasMathPainter.paintProgressive(
            c,
            verdictText,
            origin: Offset(x, vy),
            maxWidth: contentW,
            style: _stepTitleStyle.copyWith(color: statusColor),
            progress: t,
          ).penTip,
        ),
      );
      y += 22;

      if (diag.comment.isNotEmpty) {
        final cy = y;
        final ch = CanvasMathPainter.measureHeight(
          diag.comment,
          maxWidth: contentW - 8,
          style: _stepBodyStyle,
        );
        tasks.add(
          _WriteTask(
            weight: CanvasMathPainter.estimateWriteWeight(diag.comment),
            paint: (c, t) => CanvasMathPainter.paintProgressive(
              c,
              diag.comment,
              origin: Offset(x + 4, cy),
              maxWidth: contentW - 8,
              style: _stepBodyStyle,
              progress: t,
            ).penTip,
          ),
        );
        y += ch + 5;
      }

      if (diag.mistakePoint.isNotEmpty) {
        final my = y;
        final txt = '错因：${diag.mistakePoint}';
        final mh = CanvasMathPainter.measureHeight(
          txt,
          maxWidth: contentW - 8,
          style: _stepBodyStyle,
        );
        tasks.add(
          _WriteTask(
            weight: CanvasMathPainter.estimateWriteWeight(txt),
            paint: (c, t) => CanvasMathPainter.paintProgressive(
              c,
              txt,
              origin: Offset(x + 4, my),
              maxWidth: contentW - 8,
              style: _stepBodyStyle.copyWith(color: const Color(0xFFB91C1C)),
              progress: t,
            ).penTip,
          ),
        );
        y += mh + 5;
      }

      if (diag.suggestion.isNotEmpty) {
        final sy = y;
        final txt = '建议：${diag.suggestion}';
        final sh = CanvasMathPainter.measureHeight(
          txt,
          maxWidth: contentW - 8,
          style: _stepBodyStyle,
        );
        tasks.add(
          _WriteTask(
            weight: CanvasMathPainter.estimateWriteWeight(txt),
            paint: (c, t) => CanvasMathPainter.paintProgressive(
              c,
              txt,
              origin: Offset(x + 4, sy),
              maxWidth: contentW - 8,
              style: _stepBodyStyle.copyWith(color: const Color(0xFF0F766E)),
              progress: t,
            ).penTip,
          ),
        );
        y += sh + 5;
      }
      y += 8;
    }

    // 分步书写任务
    for (final step in guidance.steps) {
      final header = step.title.isNotEmpty
          ? '${step.stepNo}. ${step.title}'
          : '${step.stepNo}.';
      final hy = y;
      final hh = CanvasMathPainter.measureHeight(
        header,
        maxWidth: contentW,
        style: titleInk,
      );
      tasks.add(
        _WriteTask(
          weight: CanvasMathPainter.estimateWriteWeight(header),
          paint: (c, t) => CanvasMathPainter.paintProgressive(
            c,
            header,
            origin: Offset(x, hy),
            maxWidth: contentW,
            style: titleInk,
            progress: t,
          ).penTip,
        ),
      );
      y += hh + 4;

      if (step.content.isNotEmpty) {
        final cy = y;
        final ch = CanvasMathPainter.measureHeight(
          step.content,
          maxWidth: contentW - 14,
          style: bodyInk,
        );
        tasks.add(
          _WriteTask(
            weight: CanvasMathPainter.estimateWriteWeight(step.content),
            paint: (c, t) => CanvasMathPainter.paintProgressive(
              c,
              step.content,
              origin: Offset(x + 12, cy),
              maxWidth: contentW - 14,
              style: bodyInk,
              progress: t,
            ).penTip,
          ),
        );
        y += ch + 4;
      }

      if (step.formula.isNotEmpty) {
        final fy = y;
        final fh = CanvasMathPainter.measureHeight(
          step.formula,
          maxWidth: contentW - 18,
          style: formulaInk,
        );
        tasks.add(
          _WriteTask(
            weight: CanvasMathPainter.estimateWriteWeight(step.formula) * 1.35,
            paint: (c, t) => CanvasMathPainter.paintProgressive(
              c,
              step.formula,
              origin: Offset(x + 16, fy),
              maxWidth: contentW - 18,
              style: formulaInk,
              progress: t,
            ).penTip,
          ),
        );
        y += fh + 8;
      }

      if (step.highlight.isNotEmpty) {
        final ny = y;
        final txt = '注：${step.highlight}';
        final nh = CanvasMathPainter.measureHeight(
          txt,
          maxWidth: contentW - 14,
          style: _noteStyle,
        );
        tasks.add(
          _WriteTask(
            weight: CanvasMathPainter.estimateWriteWeight(txt),
            paint: (c, t) => CanvasMathPainter.paintProgressive(
              c,
              txt,
              origin: Offset(x + 12, ny),
              maxWidth: contentW - 14,
              style: _noteStyle,
              progress: t,
            ).penTip,
          ),
        );
        y += nh + 4;
      }
      y += 8;
    }

    // 仅解题模式显示最终答案（带简洁双下划线）
    if (guidance.isSolve && guidance.finalAnswer.isNotEmpty) {
      final ay = y;
      final ansTxt = '答：${guidance.finalAnswer}';
      final ah = CanvasMathPainter.measureHeight(
        ansTxt,
        maxWidth: contentW,
        style: _answerStyle,
      );
      tasks.add(
        _WriteTask(
          weight: CanvasMathPainter.estimateWriteWeight(ansTxt) * 1.2,
          paint: (c, t) {
            final res = CanvasMathPainter.paintProgressive(
              c,
              ansTxt,
              origin: Offset(x, ay),
              maxWidth: contentW,
              style: _answerStyle,
              progress: t,
            );
            if (t > 0.85) {
              final lineT = ((t - 0.85) / 0.15).clamp(0.0, 1.0);
              final lineW = math.min(contentW, 180.0) * lineT;
              final underPaint = Paint()
                ..color = const Color(0xFF059669)
                ..strokeWidth = 1.4;
              c.drawLine(
                Offset(x, ay + ah + 3),
                Offset(x + lineW, ay + ah + 3),
                underPaint,
              );
              c.drawLine(
                Offset(x, ay + ah + 6.5),
                Offset(x + lineW, ay + ah + 6.5),
                underPaint,
              );
            }
            return res.penTip;
          },
        ),
      );
      y += ah + 14;
    }

    if (guidance.pitfalls.isNotEmpty) {
      for (final pit in guidance.pitfalls) {
        final py = y;
        final txt = '注意：$pit';
        final ph = CanvasMathPainter.measureHeight(
          txt,
          maxWidth: contentW - 4,
          style: _noteStyle,
        );
        tasks.add(
          _WriteTask(
            weight: CanvasMathPainter.estimateWriteWeight(txt),
            paint: (c, t) => CanvasMathPainter.paintProgressive(
              c,
              txt,
              origin: Offset(x, py),
              maxWidth: contentW - 4,
              style: _noteStyle,
              progress: t,
            ).penTip,
          ),
        );
        y += ph + 4;
      }
      y += 4;
    }

    // 坐标级逐笔自动绘制矢量几何/坐标系示意图！
    for (final diagram in guidance.diagrams) {
      final dRect = Rect.fromLTWH(x, y, contentW, 182);
      tasks.add(
        _WriteTask(
          weight: math.max(36.0, diagram.primitives.length * 10.0),
          paint: (c, t) => BoardDiagramPainter.paintDiagramProgressive(
            c,
            diagram,
            dRect,
            progress: t,
          ),
        ),
      );
      y += 190;
    }

    if (tasks.isEmpty) return null;
    final totalW = tasks.fold<double>(0.0, (a, b) => a + b.weight);
    final budget =
        clampedReveal >= 0.999 ? double.infinity : totalW * clampedReveal;

    var consumed = 0.0;
    Offset? activeTip;
    for (final task in tasks) {
      if (consumed >= budget) break;
      final localT = budget.isInfinite
          ? 1.0
          : ((budget - consumed) / task.weight).clamp(0.0, 1.0);
      consumed += task.weight;
      final tip = task.paint(canvas, localT);
      if (tip != null && localT < 0.999) {
        activeTip = tip;
      }
    }
    return activeTip;
  }

  /// 极简克制的白板分区框架：淡白半透纸面 + 左侧 2.5px 标识竖线 + 极轻标题与拖动手柄
  static void _paintMinimalBlockFrame(
    Canvas canvas,
    Rect rect, {
    required Color accent,
    required String title,
    bool highlighted = false,
  }) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    // 极轻半透明纸背，保证盖在点阵/方格纸上清晰可读但不突兀
    canvas.drawRRect(
      rrect,
      Paint()..color = Colors.white.withValues(alpha: 0.88),
    );
    // 细边框（拖动时稍加深提示）
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = highlighted
            ? accent.withValues(alpha: 0.85)
            : const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = highlighted ? 1.8 : 1.0,
    );
    // 左侧 2.5px 标识竖线
    canvas.drawLine(
      Offset(rect.left + 2, rect.top + 8),
      Offset(rect.left + 2, rect.bottom - 8),
      Paint()
        ..color = accent.withValues(alpha: 0.72)
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );

    // 顶部极简标题 + 右侧极轻拖动手柄
    final handleTp = TextPainter(
      text: const TextSpan(
        text: '⋮⋮',
        style: TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    handleTp.paint(canvas, Offset(rect.right - handleTp.width - 10, rect.top + 7));

    final titleTp = TextPainter(
      text: TextSpan(
        text: title,
        style: TextStyle(
          color: accent,
          fontSize: 12.6,
          fontWeight: FontWeight.w800,
          fontFamilyFallback: AppTheme.cjkFontFallback,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: math.max(60, rect.width - handleTp.width - 32));
    titleTp.paint(canvas, Offset(rect.left + 14, rect.top + 7));

    // 极细标题底分割线
    canvas.drawLine(
      Offset(rect.left + 12, rect.top + 27),
      Offset(rect.right - 12, rect.top + 27),
      Paint()
        ..color = const Color(0xFFE2E8F0)
        ..strokeWidth = 0.9,
    );
  }

  static double _paintMiniLabel(
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
          fontSize: 11.6,
          fontWeight: FontWeight.w700,
          fontFamilyFallback: AppTheme.cjkFontFallback,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
    return pos.dy + tp.height + 2;
  }
}

/// 离屏高清渲染画板为 PNG
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
    showDiagnosisCard: includeAiCards && visibility.showDiagnosisCard,
    showSolutionCard: includeAiCards && visibility.showSolutionCard,
  );
  final metrics = SmartBoardLayoutMetrics.compute(
    cards: cards,
    visibility: exportVis,
    problemPhoto: problemPhoto,
  );
  if (metrics.problemRect != null) includeRect(metrics.problemRect!);
  if (metrics.ideasRect != null) includeRect(metrics.ideasRect!);
  if (metrics.diagnosisRect != null) includeRect(metrics.diagnosisRect!);
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
    SmartBoardPainter.paintProblemBlock(
      canvas,
      cards.problem!,
      metrics.problemRect!,
      photo: exportVis.showPhotoCard ? problemPhoto : null,
    );
  }
  if (cards.ideas != null &&
      exportVis.showIdeasCard &&
      metrics.ideasRect != null) {
    SmartBoardPainter.paintGuidanceBlock(
      canvas,
      cards.ideas!,
      metrics.ideasRect!,
    );
  }
  if (cards.diagnosis != null &&
      exportVis.showDiagnosisCard &&
      metrics.diagnosisRect != null) {
    SmartBoardPainter.paintGuidanceBlock(
      canvas,
      cards.diagnosis!,
      metrics.diagnosisRect!,
    );
  }
  if (cards.solution != null &&
      exportVis.showSolutionCard &&
      metrics.solutionRect != null) {
    SmartBoardPainter.paintGuidanceBlock(
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
