import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/models.dart';

enum BoardToolMode {
  pen,
  highlighter,
  strokeEraser,
  pixelEraser,
  line,
  dashedLine,
  arrow,
  rect,
  oval,
  axes,
  hand,
}

enum BoardPaperStyle {
  dots,
  grid,
  lined,
  plain,
}

enum BoardShapeKind {
  line,
  dashedLine,
  arrow,
  rect,
  oval,
  axes,
}

class BoardStroke {
  BoardStroke({
    required this.colorValue,
    required this.width,
    required this.points,
    this.isEraser = false,
    this.isHighlighter = false,
  });

  final int colorValue;
  final double width;
  final List<Offset> points;
  final bool isEraser;
  final bool isHighlighter;

  Color get color => Color(colorValue);

  BoardStroke clone() => BoardStroke(
        colorValue: colorValue,
        width: width,
        points: List<Offset>.from(points),
        isEraser: isEraser,
        isHighlighter: isHighlighter,
      );

  Rect? get bounds {
    if (points.isEmpty) return null;
    var minX = points.first.dx;
    var minY = points.first.dy;
    var maxX = points.first.dx;
    var maxY = points.first.dy;
    for (final p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    final pad = width * 0.6 + 2;
    return Rect.fromLTRB(minX - pad, minY - pad, maxX + pad, maxY + pad);
  }

  bool hitTest(Offset worldPoint, double threshold) {
    if (isEraser || points.isEmpty) return false;
    final b = bounds;
    if (b != null && !b.inflate(threshold).contains(worldPoint)) {
      return false;
    }
    final effective = threshold + width * 0.5;
    final effSq = effective * effective;
    if (points.length == 1) {
      return (points.first - worldPoint).distanceSquared <= effSq;
    }
    for (var i = 0; i < points.length - 1; i++) {
      if (_pointToSegmentDistSq(worldPoint, points[i], points[i + 1]) <=
          effSq) {
        return true;
      }
    }
    return false;
  }

  Map<String, dynamic> toJson() => {
        'c': colorValue,
        'w': width,
        if (isEraser) 'e': true,
        if (isHighlighter) 'h': true,
        'p': points
            .map((o) => <double>[
                  double.parse(o.dx.toStringAsFixed(1)),
                  double.parse(o.dy.toStringAsFixed(1)),
                ])
            .toList(),
      };

  static BoardStroke? fromJson(Map<String, dynamic> json) {
    final rawPts = json['p'];
    if (rawPts is! List) return null;
    final pts = <Offset>[];
    for (final item in rawPts) {
      if (item is List && item.length >= 2) {
        final x = (item[0] as num?)?.toDouble();
        final y = (item[1] as num?)?.toDouble();
        if (x != null && y != null) {
          pts.add(Offset(x, y));
        }
      }
    }
    if (pts.isEmpty) return null;
    return BoardStroke(
      colorValue: (json['c'] as num?)?.toInt() ?? 0xFF111827,
      width: (json['w'] as num?)?.toDouble() ?? 3.2,
      isEraser: json['e'] == true,
      isHighlighter: json['h'] == true,
      points: pts,
    );
  }
}

class BoardShape {
  BoardShape({
    required this.kind,
    required this.start,
    required this.end,
    required this.colorValue,
    required this.width,
  });

  final BoardShapeKind kind;
  final Offset start;
  final Offset end;
  final int colorValue;
  final double width;

  Color get color => Color(colorValue);

  BoardShape clone() => BoardShape(
        kind: kind,
        start: start,
        end: end,
        colorValue: colorValue,
        width: width,
      );

  Rect get bounds {
    final left = math.min(start.dx, end.dx);
    final top = math.min(start.dy, end.dy);
    final right = math.max(start.dx, end.dx);
    final bottom = math.max(start.dy, end.dy);
    return Rect.fromLTRB(left, top, right, bottom).inflate(width + 6);
  }

  bool hitTest(Offset worldPoint, double threshold) {
    final rect = Rect.fromPoints(start, end);
    if (!rect.inflate(threshold + width + 8).contains(worldPoint)) {
      return false;
    }
    final eff = threshold + width * 0.6;
    final effSq = eff * eff;
    switch (kind) {
      case BoardShapeKind.line:
      case BoardShapeKind.dashedLine:
      case BoardShapeKind.arrow:
        return _pointToSegmentDistSq(worldPoint, start, end) <= effSq;
      case BoardShapeKind.rect:
        final tl = rect.topLeft;
        final tr = rect.topRight;
        final br = rect.bottomRight;
        final bl = rect.bottomLeft;
        return _pointToSegmentDistSq(worldPoint, tl, tr) <= effSq ||
            _pointToSegmentDistSq(worldPoint, tr, br) <= effSq ||
            _pointToSegmentDistSq(worldPoint, br, bl) <= effSq ||
            _pointToSegmentDistSq(worldPoint, bl, tl) <= effSq;
      case BoardShapeKind.oval:
        final rx = math.max(1.0, rect.width / 2);
        final ry = math.max(1.0, rect.height / 2);
        final cx = rect.center.dx;
        final cy = rect.center.dy;
        final nx = (worldPoint.dx - cx) / rx;
        final ny = (worldPoint.dy - cy) / ry;
        final dist = math.sqrt(nx * nx + ny * ny);
        final tol = eff / math.min(rx, ry);
        return (dist - 1.0).abs() <= math.max(0.18, tol);
      case BoardShapeKind.axes:
        final cx = rect.center.dx;
        final cy = rect.center.dy;
        return _pointToSegmentDistSq(
                  worldPoint,
                  Offset(rect.left, cy),
                  Offset(rect.right, cy),
                ) <=
                effSq ||
            _pointToSegmentDistSq(
                  worldPoint,
                  Offset(cx, rect.top),
                  Offset(cx, rect.bottom),
                ) <=
                effSq;
    }
  }

  Map<String, dynamic> toJson() => {
        'k': kind.name,
        'sx': double.parse(start.dx.toStringAsFixed(1)),
        'sy': double.parse(start.dy.toStringAsFixed(1)),
        'ex': double.parse(end.dx.toStringAsFixed(1)),
        'ey': double.parse(end.dy.toStringAsFixed(1)),
        'c': colorValue,
        'w': width,
      };

  static BoardShape? fromJson(Map<String, dynamic> json) {
    final kindName = json['k']?.toString() ?? '';
    final kind = BoardShapeKind.values.cast<BoardShapeKind?>().firstWhere(
          (k) => k?.name == kindName,
          orElse: () => null,
        );
    if (kind == null) return null;
    final sx = (json['sx'] as num?)?.toDouble();
    final sy = (json['sy'] as num?)?.toDouble();
    final ex = (json['ex'] as num?)?.toDouble();
    final ey = (json['ey'] as num?)?.toDouble();
    if (sx == null || sy == null || ex == null || ey == null) return null;
    return BoardShape(
      kind: kind,
      start: Offset(sx, sy),
      end: Offset(ex, ey),
      colorValue: (json['c'] as num?)?.toInt() ?? 0xFF2563EB,
      width: (json['w'] as num?)?.toDouble() ?? 2.6,
    );
  }
}

class BoardUndoSnapshot {
  const BoardUndoSnapshot({
    required this.strokes,
    required this.shapes,
  });

  final List<BoardStroke> strokes;
  final List<BoardShape> shapes;

  factory BoardUndoSnapshot.capture(
    List<BoardStroke> strokes,
    List<BoardShape> shapes,
  ) {
    return BoardUndoSnapshot(
      strokes: strokes.map((s) => s.clone()).toList(),
      shapes: shapes.map((s) => s.clone()).toList(),
    );
  }
}

class BoardLayerVisibility {
  const BoardLayerVisibility({
    this.showProblemCard = true,
    this.showPhotoCard = true,
    this.showIdeasCard = true,
    this.showDiagnosisCard = true,
    this.showSolutionCard = true,
  });

  final bool showProblemCard;
  final bool showPhotoCard;
  final bool showIdeasCard;
  final bool showDiagnosisCard;
  final bool showSolutionCard;

  BoardLayerVisibility copyWith({
    bool? showProblemCard,
    bool? showPhotoCard,
    bool? showIdeasCard,
    bool? showDiagnosisCard,
    bool? showSolutionCard,
  }) {
    return BoardLayerVisibility(
      showProblemCard: showProblemCard ?? this.showProblemCard,
      showPhotoCard: showPhotoCard ?? this.showPhotoCard,
      showIdeasCard: showIdeasCard ?? this.showIdeasCard,
      showDiagnosisCard: showDiagnosisCard ?? this.showDiagnosisCard,
      showSolutionCard: showSolutionCard ?? this.showSolutionCard,
    );
  }
}

enum BoardCardId {
  problem,
  ideas,
  diagnosis,
  solution,
}

class SmartBoardCardState {
  const SmartBoardCardState({
    this.problem,
    this.ideas,
    this.diagnosis,
    this.solution,
    this.problemPos = const Offset(24, 20),
    this.ideasPos = const Offset(24, 290),
    this.diagnosisPos = const Offset(430, 20),
    this.solutionPos = const Offset(430, 290),
    this.problemWidth = 380,
    this.ideasWidth = 380,
    this.diagnosisWidth = 360,
    this.solutionWidth = 420,
  });

  final AiRecognizeResult? problem;
  final AiBoardGuidance? ideas;
  final AiBoardGuidance? diagnosis;
  final AiBoardGuidance? solution;
  final Offset problemPos;
  final Offset ideasPos;
  final Offset diagnosisPos;
  final Offset solutionPos;
  final double problemWidth;
  final double ideasWidth;
  final double diagnosisWidth;
  final double solutionWidth;

  SmartBoardCardState copyWith({
    AiRecognizeResult? problem,
    bool clearProblem = false,
    AiBoardGuidance? ideas,
    bool clearIdeas = false,
    AiBoardGuidance? diagnosis,
    bool clearDiagnosis = false,
    AiBoardGuidance? solution,
    bool clearSolution = false,
    Offset? problemPos,
    Offset? ideasPos,
    Offset? diagnosisPos,
    Offset? solutionPos,
    double? problemWidth,
    double? ideasWidth,
    double? diagnosisWidth,
    double? solutionWidth,
  }) {
    return SmartBoardCardState(
      problem: clearProblem ? null : (problem ?? this.problem),
      ideas: clearIdeas ? null : (ideas ?? this.ideas),
      diagnosis: clearDiagnosis ? null : (diagnosis ?? this.diagnosis),
      solution: clearSolution ? null : (solution ?? this.solution),
      problemPos: problemPos ?? this.problemPos,
      ideasPos: ideasPos ?? this.ideasPos,
      diagnosisPos: diagnosisPos ?? this.diagnosisPos,
      solutionPos: solutionPos ?? this.solutionPos,
      problemWidth: problemWidth ?? this.problemWidth,
      ideasWidth: ideasWidth ?? this.ideasWidth,
      diagnosisWidth: diagnosisWidth ?? this.diagnosisWidth,
      solutionWidth: solutionWidth ?? this.solutionWidth,
    );
  }
}

double _pointToSegmentDistSq(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final lenSq = ab.distanceSquared;
  if (lenSq < 1e-6) return (p - a).distanceSquared;
  final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lenSq)
      .clamp(0.0, 1.0);
  final proj = Offset(a.dx + t * ab.dx, a.dy + t * ab.dy);
  return (p - proj).distanceSquared;
}
