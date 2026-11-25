import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/utils/math_parser.dart';

class _LaidOutItem {
  const _LaidOutItem({
    required this.token,
    required this.width,
    required this.height,
    required this.baselineOffset,
    this.mainPainter,
    this.numPainter,
    this.denPainter,
  });

  final MathToken token;
  final double width;
  final double height;
  final double baselineOffset;
  final TextPainter? mainPainter;
  final TextPainter? numPainter;
  final TextPainter? denPainter;
}

class _LaidOutLine {
  const _LaidOutLine({
    required this.items,
    required this.height,
  });

  final List<_LaidOutItem> items;
  final double height;
}

class MathPaintResult {
  const MathPaintResult({
    required this.height,
    this.penTip,
  });

  final double height;
  final Offset? penTip;
}

/// 高精度 Canvas 数学公式矢量排版与逐笔书写渲染器。
/// 支持：
/// 1. 真上下分式、真上下标、根号与中英文数学混排自动折行；
/// 2. [paintProgressive] 支持 0.0~1.0 逐字/逐符号实时书写（分子→分数线→分母），
///    并返回当前笔尖所处的精确坐标，用于驱动“拟真手写自动绘制”动画。
class CanvasMathPainter {
  CanvasMathPainter._();

  static TextPainter _makeTextPainter(String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp;
  }

  static List<_LaidOutLine> _layoutLines(
    String raw,
    double maxWidth,
    TextStyle baseStyle,
  ) {
    if (raw.trim().isEmpty || maxWidth <= 12) return const [];
    final tokens = MathParser.parseTokens(raw);
    if (tokens.isEmpty) return const [];

    final fontSize = baseStyle.fontSize ?? 14.0;
    final lineHeight = fontSize * (baseStyle.height ?? 1.48);
    final effectiveStyle = baseStyle.copyWith(
      fontFamilyFallback:
          baseStyle.fontFamilyFallback ?? AppTheme.cjkFontFallback,
    );
    final scriptStyle = effectiveStyle.copyWith(
      fontSize: fontSize * 0.72,
      height: 1.05,
    );
    final fracStyle = effectiveStyle.copyWith(
      fontSize: fontSize * 0.78,
      height: 1.12,
    );

    final atomicTokens = <MathToken>[];
    for (final tok in tokens) {
      if (tok.type != MathTokenType.text) {
        atomicTokens.add(tok);
        continue;
      }
      final text = tok.value;
      var i = 0;
      while (i < text.length) {
        final code = text.codeUnitAt(i);
        final isAsciiWord = (code >= 48 && code <= 57) ||
            (code >= 65 && code <= 90) ||
            (code >= 97 && code <= 122) ||
            code == 46;
        if (isAsciiWord) {
          final start = i;
          while (i < text.length) {
            final c = text.codeUnitAt(i);
            final ok = (c >= 48 && c <= 57) ||
                (c >= 65 && c <= 90) ||
                (c >= 97 && c <= 122) ||
                c == 46;
            if (!ok) break;
            i++;
          }
          atomicTokens.add(MathToken.text(text.substring(start, i)));
        } else {
          atomicTokens.add(MathToken.text(text[i]));
          i++;
        }
      }
    }

    final lines = <_LaidOutLine>[];
    var currentItems = <_LaidOutItem>[];
    var curX = 0.0;
    var curMaxH = lineHeight;

    void flushLine() {
      lines.add(
        _LaidOutLine(
          items: currentItems,
          height: math.max(lineHeight, curMaxH),
        ),
      );
      currentItems = <_LaidOutItem>[];
      curX = 0.0;
      curMaxH = lineHeight;
    }

    for (final tok in atomicTokens) {
      if (tok.type == MathTokenType.lineBreak) {
        flushLine();
        continue;
      }

      late final _LaidOutItem item;
      switch (tok.type) {
        case MathTokenType.text:
          final tp = _makeTextPainter(tok.value, effectiveStyle);
          item = _LaidOutItem(
            token: tok,
            width: tp.width,
            height: tp.height,
            baselineOffset: 0,
            mainPainter: tp,
          );
        case MathTokenType.sup:
          final tp = _makeTextPainter(tok.value, scriptStyle);
          item = _LaidOutItem(
            token: tok,
            width: tp.width + 1,
            height: math.max(lineHeight, tp.height + fontSize * 0.45),
            baselineOffset: -fontSize * 0.28,
            mainPainter: tp,
          );
        case MathTokenType.sub:
          final tp = _makeTextPainter(tok.value, scriptStyle);
          item = _LaidOutItem(
            token: tok,
            width: tp.width + 1,
            height: math.max(lineHeight, tp.height + fontSize * 0.45),
            baselineOffset: fontSize * 0.34,
            mainPainter: tp,
          );
        case MathTokenType.frac:
          final numTp = _makeTextPainter(tok.num, fracStyle);
          final denTp = _makeTextPainter(tok.den, fracStyle);
          final w = math.max(numTp.width, denTp.width) + 10;
          final h = numTp.height + denTp.height + 6;
          item = _LaidOutItem(
            token: tok,
            width: w,
            height: math.max(lineHeight, h),
            baselineOffset: 0,
            numPainter: numTp,
            denPainter: denTp,
          );
        case MathTokenType.sqrt:
          final radicalLabel = tok.rootIndex.isNotEmpty
              ? '${tok.rootIndex}√(${tok.value})'
              : '√(${tok.value})';
          final tp = _makeTextPainter(radicalLabel, effectiveStyle);
          item = _LaidOutItem(
            token: tok,
            width: tp.width,
            height: tp.height,
            baselineOffset: 0,
            mainPainter: tp,
          );
        case MathTokenType.lineBreak:
          continue;
      }

      if (currentItems.isNotEmpty && curX + item.width > maxWidth) {
        flushLine();
      }
      currentItems.add(item);
      curX += item.width;
      if (item.height > curMaxH) {
        curMaxH = item.height;
      }
    }

    if (currentItems.isNotEmpty || lines.isEmpty) {
      flushLine();
    }

    return lines;
  }

  /// 估算一段数学文本的书写权重（用于匀速逐字手写动画时间分配）
  static double estimateWriteWeight(String raw) {
    final cleaned = raw.trim();
    if (cleaned.isEmpty) return 0;
    return math.max(4.0, cleaned.length.toDouble());
  }

  /// 测量给定最大宽度下渲染所需的总高度
  static double measureHeight(
    String raw, {
    required double maxWidth,
    required TextStyle style,
    double lineSpacing = 3.0,
  }) {
    final lines = _layoutLines(raw, maxWidth, style);
    if (lines.isEmpty) return 0;
    var total = 0.0;
    for (var i = 0; i < lines.length; i++) {
      total += lines[i].height;
      if (i < lines.length - 1) total += lineSpacing;
    }
    return total;
  }

  /// 全量绘制数学公式文本
  static double paint(
    Canvas canvas,
    String raw, {
    required Offset origin,
    required double maxWidth,
    required TextStyle style,
    double lineSpacing = 3.0,
  }) {
    return paintProgressive(
      canvas,
      raw,
      origin: origin,
      maxWidth: maxWidth,
      style: style,
      lineSpacing: lineSpacing,
      progress: 1.0,
    ).height;
  }

  /// 逐笔坐标书写模式绘制数学公式文本（progress: 0.0 -> 1.0），返回高度与当前笔尖精确世界坐标
  static MathPaintResult paintProgressive(
    Canvas canvas,
    String raw, {
    required Offset origin,
    required double maxWidth,
    required TextStyle style,
    double lineSpacing = 3.0,
    double progress = 1.0,
  }) {
    final lines = _layoutLines(raw, maxWidth, style);
    if (lines.isEmpty) return const MathPaintResult(height: 0);

    var totalHeight = 0.0;
    var totalWidthWeight = 0.0;
    for (var i = 0; i < lines.length; i++) {
      totalHeight += lines[i].height;
      if (i < lines.length - 1) totalHeight += lineSpacing;
      for (final item in lines[i].items) {
        totalWidthWeight +=
            item.token.type == MathTokenType.frac ? item.width * 2.2 : math.max(6.0, item.width);
      }
    }

    final clamped = progress.clamp(0.0, 1.0);
    if (clamped <= 0.0001) {
      return MathPaintResult(height: totalHeight);
    }

    final lineColor = style.color ?? const Color(0xFF111827);
    final barPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round;

    final budget = clamped >= 0.999
        ? double.infinity
        : totalWidthWeight * clamped;
    var consumed = 0.0;
    Offset? activePenTip;

    var y = origin.dy;
    for (var lineIdx = 0; lineIdx < lines.length; lineIdx++) {
      final line = lines[lineIdx];
      var x = origin.dx;
      final midY = y + line.height / 2;

      for (final item in line.items) {
        final itemWeight = item.token.type == MathTokenType.frac
            ? item.width * 2.2
            : math.max(6.0, item.width);

        if (consumed >= budget) {
          return MathPaintResult(height: totalHeight, penTip: activePenTip);
        }

        final remaining = budget - consumed;
        final localT = budget.isInfinite
            ? 1.0
            : (remaining / itemWeight).clamp(0.0, 1.0);
        consumed += itemWeight;

        switch (item.token.type) {
          case MathTokenType.text:
          case MathTokenType.sup:
          case MathTokenType.sub:
          case MathTokenType.sqrt:
            final tp = item.mainPainter!;
            final topY = midY - tp.height / 2 + item.baselineOffset;
            if (localT >= 0.999) {
              tp.paint(canvas, Offset(x, topY));
            } else {
              final clipW = math.max(1.0, item.width * localT);
              canvas.save();
              canvas.clipRect(Rect.fromLTWH(x, topY - 2, clipW, tp.height + 4));
              tp.paint(canvas, Offset(x, topY));
              canvas.restore();
              // 拟真运笔微小上下律动
              final jitter = math.sin(localT * math.pi * 4) * 2.4;
              activePenTip = Offset(x + clipW, topY + tp.height * 0.68 + jitter);
            }
          case MathTokenType.frac:
            final numTp = item.numPainter!;
            final denTp = item.denPainter!;
            final innerW = item.width - 4;
            final barY = midY;
            final numX = x + (item.width - numTp.width) / 2;
            final numY = barY - numTp.height - 2.2;
            final denX = x + (item.width - denTp.width) / 2;
            final denY = barY + 2.2;

            if (localT >= 0.999) {
              numTp.paint(canvas, Offset(numX, numY));
              canvas.drawLine(
                Offset(x + 2, barY),
                Offset(x + 2 + innerW, barY),
                barPaint,
              );
              denTp.paint(canvas, Offset(denX, denY));
            } else if (localT < 0.42) {
              // 阶段1：写分子
              final nt = (localT / 0.42).clamp(0.0, 1.0);
              final cw = math.max(1.0, numTp.width * nt);
              canvas.save();
              canvas.clipRect(Rect.fromLTWH(numX, numY - 2, cw, numTp.height + 4));
              numTp.paint(canvas, Offset(numX, numY));
              canvas.restore();
              activePenTip = Offset(numX + cw, numY + numTp.height * 0.7);
            } else if (localT < 0.62) {
              // 阶段2：从左向右画分数线
              numTp.paint(canvas, Offset(numX, numY));
              final bt = ((localT - 0.42) / 0.20).clamp(0.0, 1.0);
              final endX = x + 2 + innerW * bt;
              canvas.drawLine(Offset(x + 2, barY), Offset(endX, barY), barPaint);
              activePenTip = Offset(endX, barY);
            } else {
              // 阶段3：写分母
              numTp.paint(canvas, Offset(numX, numY));
              canvas.drawLine(
                Offset(x + 2, barY),
                Offset(x + 2 + innerW, barY),
                barPaint,
              );
              final dt = ((localT - 0.62) / 0.38).clamp(0.0, 1.0);
              final cw = math.max(1.0, denTp.width * dt);
              canvas.save();
              canvas.clipRect(Rect.fromLTWH(denX, denY - 2, cw, denTp.height + 4));
              denTp.paint(canvas, Offset(denX, denY));
              canvas.restore();
              activePenTip = Offset(denX + cw, denY + denTp.height * 0.7);
            }
          case MathTokenType.lineBreak:
            break;
        }
        x += item.width;
      }

      y += line.height;
      if (lineIdx < lines.length - 1) {
        y += lineSpacing;
      }
    }

    return MathPaintResult(height: totalHeight, penTip: activePenTip);
  }
}
