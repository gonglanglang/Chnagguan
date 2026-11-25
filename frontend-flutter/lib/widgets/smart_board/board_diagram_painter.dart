import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/utils/math_parser.dart';
import '../../models/models.dart';

/// 将 AI 返回的结构化数学矢量几何/坐标系示意图直接绘制到 Canvas 上。
class BoardDiagramPainter {
  BoardDiagramPainter._();

  static Color parseColor(String? raw, [Color fallback = const Color(0xFF1E293B)]) {
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

  static void paintDiagram(
    Canvas canvas,
    BoardDiagramSpec spec,
    Rect targetRect,
  ) {
    // 卡片背景与边框
    final bgRRect = RRect.fromRectAndRadius(
      targetRect,
      const Radius.circular(10),
    );
    canvas.drawRRect(bgRRect, Paint()..color = const Color(0xFFF8FAFC));
    canvas.drawRRect(
      bgRRect,
      Paint()
        ..color = const Color(0xFFCBD5E1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    var plotRect = targetRect.deflate(8);
    if (spec.title.isNotEmpty) {
      final titleTp = TextPainter(
        text: TextSpan(
          text: '📐 ${spec.title}',
          style: const TextStyle(
            color: Color(0xFF334155),
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

    if (plotRect.width <= 12 || plotRect.height <= 12) return;

    final logicalW = spec.width > 20 ? spec.width : 320.0;
    final logicalH = spec.height > 20 ? spec.height : 220.0;
    final scale = math.min(
      plotRect.width / logicalW,
      plotRect.height / logicalH,
    );
    final dx = plotRect.left + (plotRect.width - logicalW * scale) / 2;
    final dy = plotRect.top + (plotRect.height - logicalH * scale) / 2;

    Offset mapPt(double x, double y) => Offset(dx + x * scale, dy + y * scale);

    canvas.save();
    canvas.clipRect(plotRect.inflate(2));

    for (final p in spec.primitives) {
      final strokeColor = parseColor(p.color);
      final strokePaint = Paint()
        ..color = strokeColor
        ..strokeWidth = math.max(1.4, 2.0 * scale)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      switch (p.type) {
        case 'line':
          if (p.x1 != null && p.y1 != null && p.x2 != null && p.y2 != null) {
            final a = mapPt(p.x1!, p.y1!);
            final b = mapPt(p.x2!, p.y2!);
            if (p.dashed) {
              drawDashedLine(canvas, a, b, strokePaint);
            } else {
              canvas.drawLine(a, b, strokePaint);
            }
          }
        case 'arrow':
          if (p.x1 != null && p.y1 != null && p.x2 != null && p.y2 != null) {
            final a = mapPt(p.x1!, p.y1!);
            final b = mapPt(p.x2!, p.y2!);
            drawArrowLine(canvas, a, b, strokePaint);
          }
        case 'circle':
          if (p.cx != null && p.cy != null && p.r != null && p.r! > 0) {
            final c = mapPt(p.cx!, p.cy!);
            final r = p.r! * scale;
            if (p.fillColor != null && p.fillColor!.isNotEmpty) {
              canvas.drawCircle(
                c,
                r,
                Paint()
                  ..color = parseColor(p.fillColor).withValues(alpha: 0.25)
                  ..style = PaintingStyle.fill,
              );
            }
            if (p.dashed) {
              drawDashedCircle(canvas, c, r, strokePaint);
            } else {
              canvas.drawCircle(c, r, strokePaint);
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
            if (p.fillColor != null && p.fillColor!.isNotEmpty) {
              canvas.drawPath(
                path,
                Paint()
                  ..color = parseColor(p.fillColor).withValues(alpha: 0.28)
                  ..style = PaintingStyle.fill,
              );
            }
            canvas.drawPath(path, strokePaint);
          }
        case 'polyline':
          if (p.points.length >= 2) {
            final mapped = [
              for (final pt in p.points) mapPt(pt[0], pt[1]),
            ];
            final path = buildSmoothPath(mapped);
            if (p.dashed) {
              for (var i = 0; i < mapped.length - 1; i++) {
                drawDashedLine(canvas, mapped[i], mapped[i + 1], strokePaint);
              }
            } else {
              canvas.drawPath(path, strokePaint);
            }
          }
        case 'point':
          if (p.x != null && p.y != null) {
            final pt = mapPt(p.x!, p.y!);
            canvas.drawCircle(
              pt,
              math.max(2.6, 3.6 * scale),
              Paint()..color = strokeColor,
            );
            canvas.drawCircle(
              pt,
              math.max(1.2, 1.6 * scale),
              Paint()..color = Colors.white,
            );
            final lbl = p.label ?? p.text ?? '';
            if (lbl.isNotEmpty) {
              _paintLabel(
                canvas,
                MathParser.renderPlainText(lbl),
                pt + const Offset(5, -14),
                strokeColor,
              );
            }
          }
        case 'text':
          if (p.x != null && p.y != null) {
            final txt = p.text ?? p.label ?? '';
            if (txt.isNotEmpty) {
              final pt = mapPt(p.x!, p.y!);
              _paintLabel(
                canvas,
                MathParser.renderPlainText(txt),
                pt,
                strokeColor,
              );
            }
          }
      }
    }

    canvas.restore();
  }

  static void _paintLabel(
    Canvas canvas,
    String text,
    Offset pos,
    Color color,
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
    tp.paint(canvas, pos);
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

  static void drawDashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
  ) {
    const segments = 24;
    const step = (math.pi * 2) / segments;
    for (var i = 0; i < segments; i += 2) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * step,
        step * 0.72,
        false,
        paint,
      );
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
