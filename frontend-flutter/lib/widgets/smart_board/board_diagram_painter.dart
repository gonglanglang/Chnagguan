import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/utils/math_parser.dart';
import '../../models/models.dart';

/// 坐标级矢量几何/坐标系示意图自动绘制引擎（类似 Python Turtle / Manim 轨迹绘制）。
/// 根据 AI 输出的坐标点列与图元指令，支持按 [progress] (0.0 -> 1.0) 一笔一画精准绘制，
/// 并实时返回当前笔尖所处的精确画板坐标，实现手绘自动作图视觉体验。
class BoardDiagramPainter {
  BoardDiagramPainter._();

  static Color parseColor(
    String? raw, [
    Color fallback = const Color(0xFF1E293B),
  ]) {
    if (raw == null || raw.trim().isEmpty) return fallback;
    final cleaned = raw.trim().replaceFirst('#', '');
    if (cleaned.length == 6) {
      final v = int.tryParse('FF$cleaned', radix: 16);
      if (v != null) return Color(v);
    } else if (cleaned.length == 8) {
      final v = int.tryParse(cleaned, radix: 16);
      if (v != null) return Color(v);
    }
    return fallback;
  }

  /// 全量绘制矢量示意图
  static void paintDiagram(
    Canvas canvas,
    BoardDiagramSpec spec,
    Rect targetRect,
  ) {
    paintDiagramProgressive(canvas, spec, targetRect, progress: 1.0);
  }

  /// 坐标级逐笔绘制矢量示意图（progress: 0.0 -> 1.0），返回当前绘制笔尖的世界坐标
  static Offset? paintDiagramProgressive(
    Canvas canvas,
    BoardDiagramSpec spec,
    Rect targetRect, {
    double progress = 1.0,
  }) {
    final clamped = progress.clamp(0.0, 1.0);
    if (clamped <= 0.0001) return null;

    // 极简白板参考框（淡虚线轮廓，无厚重花哨背景）
    final borderPaint = Paint()
      ..color = const Color(0xFFCBD5E1).withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    drawDashedLine(canvas, targetRect.topLeft, targetRect.topRight, borderPaint,
        dashLen: 5, gapLen: 4);
    drawDashedLine(canvas, targetRect.topRight, targetRect.bottomRight, borderPaint,
        dashLen: 5, gapLen: 4);
    drawDashedLine(canvas, targetRect.bottomRight, targetRect.bottomLeft, borderPaint,
        dashLen: 5, gapLen: 4);
    drawDashedLine(canvas, targetRect.bottomLeft, targetRect.topLeft, borderPaint,
        dashLen: 5, gapLen: 4);

    var plotRect = targetRect.deflate(8);
    if (spec.title.isNotEmpty) {
      final titleTp = TextPainter(
        text: TextSpan(
          text: spec.title,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            fontFamilyFallback: AppTheme.cjkFontFallback,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: plotRect.width);
      titleTp.paint(canvas, Offset(plotRect.left + 2, plotRect.top));
      plotRect = Rect.fromLTRB(
        plotRect.left,
        plotRect.top + titleTp.height + 4,
        plotRect.right,
        plotRect.bottom,
      );
    }

    if (plotRect.width <= 12 ||
        plotRect.height <= 12 ||
        spec.primitives.isEmpty) {
      return null;
    }

    final logicalW = spec.width > 20 ? spec.width : 320.0;
    final logicalH = spec.height > 20 ? spec.height : 220.0;
    final scale = math.min(
      plotRect.width / logicalW,
      plotRect.height / logicalH,
    );
    final dx = plotRect.left + (plotRect.width - logicalW * scale) / 2;
    final dy = plotRect.top + (plotRect.height - logicalH * scale) / 2;

    Offset mapPt(double x, double y) => Offset(dx + x * scale, dy + y * scale);

    // 为每个图元按实际路径长度/复杂度分配绘制时间权重
    final weights = <double>[
      for (final p in spec.primitives) _primitiveWeight(p),
    ];
    final totalWeight = weights.fold<double>(0.0, (a, b) => a + b);
    if (totalWeight <= 0) return null;

    final budget = clamped >= 0.999 ? double.infinity : totalWeight * clamped;
    var consumed = 0.0;
    Offset? activePenTip;

    canvas.save();
    canvas.clipRect(plotRect.inflate(6));

    for (var idx = 0; idx < spec.primitives.length; idx++) {
      if (consumed >= budget) break;
      final p = spec.primitives[idx];
      final w = weights[idx];
      final localT =
          budget.isInfinite ? 1.0 : ((budget - consumed) / w).clamp(0.0, 1.0);
      consumed += w;

      final strokeColor = parseColor(p.color);
      final strokePaint = Paint()
        ..color = strokeColor
        ..strokeWidth = math.max(1.5, 2.0 * scale)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke;

      Offset? tip;
      switch (p.type) {
        case 'line':
          if (p.x1 != null && p.y1 != null && p.x2 != null && p.y2 != null) {
            final a = mapPt(p.x1!, p.y1!);
            final b = mapPt(p.x2!, p.y2!);
            final curEnd = Offset.lerp(a, b, localT)!;
            if (p.dashed) {
              drawDashedLine(canvas, a, curEnd, strokePaint);
            } else {
              canvas.drawLine(a, curEnd, strokePaint);
            }
            if (localT < 0.999) tip = curEnd;
          }
        case 'arrow':
          if (p.x1 != null && p.y1 != null && p.x2 != null && p.y2 != null) {
            final a = mapPt(p.x1!, p.y1!);
            final b = mapPt(p.x2!, p.y2!);
            if (localT <= 0.82) {
              final st = (localT / 0.82).clamp(0.0, 1.0);
              final cur = Offset.lerp(a, b, st)!;
              canvas.drawLine(a, cur, strokePaint);
              tip = cur;
            } else {
              canvas.drawLine(a, b, strokePaint);
              final ht = ((localT - 0.82) / 0.18).clamp(0.0, 1.0);
              tip = _drawPartialArrowHead(canvas, a, b, strokePaint, ht);
              if (localT >= 0.999) tip = null;
            }
          }
        case 'circle':
          if (p.cx != null && p.cy != null && p.r != null && p.r! > 0) {
            final c = mapPt(p.cx!, p.cy!);
            final r = p.r! * scale;
            if (localT >= 0.999 &&
                p.fillColor != null &&
                p.fillColor!.isNotEmpty) {
              canvas.drawCircle(
                c,
                r,
                Paint()
                  ..color = parseColor(p.fillColor).withValues(alpha: 0.16)
                  ..style = PaintingStyle.fill,
              );
            }
            final sweep = math.pi * 2 * localT;
            const startAngle = -math.pi / 2;
            if (p.dashed) {
              drawDashedArc(canvas, c, r, startAngle, sweep, strokePaint);
            } else {
              canvas.drawArc(
                Rect.fromCircle(center: c, radius: r),
                startAngle,
                sweep,
                false,
                strokePaint,
              );
            }
            if (localT < 0.999) {
              final ang = startAngle + sweep;
              tip = Offset(c.dx + r * math.cos(ang), c.dy + r * math.sin(ang));
            }
          }
        case 'polygon':
          if (p.points.length >= 3) {
            final path = Path();
            final first = mapPt(p.points.first[0], p.points.first[1]);
            path.moveTo(first.dx, first.dy);
            for (var i = 1; i < p.points.length; i++) {
              final pt = mapPt(p.points[i][0], p.points[i][1]);
              path.lineTo(pt.dx, pt.dy);
            }
            path.close();
            if (localT >= 0.999) {
              if (p.fillColor != null && p.fillColor!.isNotEmpty) {
                canvas.drawPath(
                  path,
                  Paint()
                    ..color = parseColor(p.fillColor).withValues(alpha: 0.16)
                    ..style = PaintingStyle.fill,
                );
              }
              canvas.drawPath(path, strokePaint);
            } else {
              tip = _drawPartialPath(canvas, path, strokePaint, localT);
            }
          }
        case 'polyline':
          if (p.points.length >= 2) {
            final mapped = [
              for (final pt in p.points) mapPt(pt[0], pt[1]),
            ];
            final path = buildSmoothPath(mapped);
            if (localT >= 0.999) {
              if (p.dashed) {
                for (var i = 0; i < mapped.length - 1; i++) {
                  drawDashedLine(canvas, mapped[i], mapped[i + 1], strokePaint);
                }
              } else {
                canvas.drawPath(path, strokePaint);
              }
            } else {
              tip = _drawPartialPath(
                canvas,
                path,
                strokePaint,
                localT,
                dashed: p.dashed,
              );
            }
          }
        case 'point':
          if (p.x != null && p.y != null) {
            final pt = mapPt(p.x!, p.y!);
            final r = math.max(2.6, 3.6 * scale) * math.min(1.0, localT * 2.2);
            canvas.drawCircle(pt, r, Paint()..color = strokeColor);
            canvas.drawCircle(pt, r * 0.45, Paint()..color = Colors.white);
            final lbl = p.label ?? p.text ?? '';
            if (lbl.isNotEmpty && localT > 0.35) {
              final lt = ((localT - 0.35) / 0.65).clamp(0.0, 1.0);
              tip = _paintLabelProgressive(
                canvas,
                MathParser.renderPlainText(lbl),
                pt + const Offset(5, -14),
                strokeColor,
                lt,
              );
            } else if (localT < 0.999) {
              tip = pt;
            }
          }
        case 'text':
          if (p.x != null && p.y != null) {
            final txt = p.text ?? p.label ?? '';
            if (txt.isNotEmpty) {
              final pt = mapPt(p.x!, p.y!);
              tip = _paintLabelProgressive(
                canvas,
                MathParser.renderPlainText(txt),
                pt,
                strokeColor,
                localT,
              );
            }
          }
      }
      if (tip != null) {
        activePenTip = tip;
      }
    }

    canvas.restore();
    return activePenTip;
  }

  static double _primitiveWeight(DiagramPrimitive p) {
    switch (p.type) {
      case 'polyline':
        return math.max(18.0, p.points.length * 6.0);
      case 'polygon':
        return math.max(20.0, p.points.length * 7.0);
      case 'circle':
        return 22.0;
      case 'line':
      case 'arrow':
        return 14.0;
      case 'point':
      case 'text':
        return 7.0;
      default:
        return 10.0;
    }
  }

  static Offset? _drawPartialPath(
    Canvas canvas,
    Path fullPath,
    Paint paint,
    double t, {
    bool dashed = false,
  }) {
    final metrics = fullPath.computeMetrics().toList();
    if (metrics.isEmpty) return null;
    final totalLen = metrics.fold<double>(0.0, (a, m) => a + m.length);
    if (totalLen <= 0.1) return null;
    final targetLen = totalLen * t.clamp(0.0, 1.0);
    var acc = 0.0;
    Offset? tip;

    for (final m in metrics) {
      if (acc >= targetLen) break;
      final segLen = math.min(m.length, targetLen - acc);
      if (dashed) {
        var d = 0.0;
        while (d < segLen) {
          final next = math.min(segLen, d + 7.0);
          canvas.drawPath(m.extractPath(d, next), paint);
          d += 12.0;
        }
      } else {
        canvas.drawPath(m.extractPath(0, segLen), paint);
      }
      final tangent = m.getTangentForOffset(segLen);
      if (tangent != null) {
        tip = tangent.position;
      }
      acc += m.length;
    }
    return tip;
  }

  static Offset? _drawPartialArrowHead(
    Canvas canvas,
    Offset a,
    Offset b,
    Paint paint,
    double t, {
    double headLen = 10,
  }) {
    final angle = math.atan2(b.dy - a.dy, b.dx - a.dx);
    const wing = 0.46;
    final p1 = Offset(
      b.dx - headLen * math.cos(angle - wing),
      b.dy - headLen * math.sin(angle - wing),
    );
    final p2 = Offset(
      b.dx - headLen * math.cos(angle + wing),
      b.dy - headLen * math.sin(angle + wing),
    );
    if (t <= 0.5) {
      final cur = Offset.lerp(b, p1, t * 2)!;
      canvas.drawLine(b, cur, paint);
      return cur;
    } else {
      canvas.drawLine(b, p1, paint);
      final cur = Offset.lerp(b, p2, (t - 0.5) * 2)!;
      canvas.drawLine(b, cur, paint);
      return cur;
    }
  }

  static Offset? _paintLabelProgressive(
    Canvas canvas,
    String text,
    Offset pos,
    Color color,
    double t,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          fontFamilyFallback: AppTheme.cjkFontFallback,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    if (t >= 0.999) {
      tp.paint(canvas, pos);
      return null;
    }
    final cw = math.max(1.0, tp.width * t);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(pos.dx, pos.dy - 2, cw, tp.height + 4));
    tp.paint(canvas, pos);
    canvas.restore();
    return Offset(pos.dx + cw, pos.dy + tp.height * 0.7);
  }

  static Path buildSmoothPath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    if (points.length == 2) {
      path.lineTo(points[1].dx, points[1].dy);
      return path;
    }
    for (var i = 1; i < points.length - 1; i++) {
      final mid = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        (points[i].dy + points[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  static void drawDashedLine(
    Canvas canvas,
    Offset a,
    Offset b,
    Paint paint, {
    double dashLen = 7,
    double gapLen = 5,
  }) {
    final total = (b - a).distance;
    if (total < 1) return;
    final dir = (b - a) / total;
    var dist = 0.0;
    while (dist < total) {
      final next = math.min(total, dist + dashLen);
      canvas.drawLine(a + dir * dist, a + dir * next, paint);
      dist += dashLen + gapLen;
    }
  }

  static void drawDashedArc(
    Canvas canvas,
    Offset center,
    double radius,
    double startAngle,
    double sweepAngle,
    Paint paint,
  ) {
    const step = (math.pi * 2) / 24;
    var cur = 0.0;
    while (cur < sweepAngle) {
      final seg = math.min(step * 0.68, sweepAngle - cur);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + cur,
        seg,
        false,
        paint,
      );
      cur += step;
    }
  }

  static void drawArrowLine(
    Canvas canvas,
    Offset a,
    Offset b,
    Paint paint, {
    double headLen = 10,
  }) {
    canvas.drawLine(a, b, paint);
    final angle = math.atan2(b.dy - a.dy, b.dx - a.dx);
    const wing = 0.46;
    final p1 = Offset(
      b.dx - headLen * math.cos(angle - wing),
      b.dy - headLen * math.sin(angle - wing),
    );
    final p2 = Offset(
      b.dx - headLen * math.cos(angle + wing),
      b.dy - headLen * math.sin(angle + wing),
    );
    canvas.drawLine(b, p1, paint);
    canvas.drawLine(b, p2, paint);
  }
}
