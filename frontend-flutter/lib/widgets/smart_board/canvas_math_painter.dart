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

/// 高精度 Canvas 数学公式矢量排版渲染器。
/// 支持将 LaTeX 分式（分子/分数线/分母）、上下标、根号与中英文数学题干
/// 直接绘制到无限画板 Canvas 与离屏 PNG 上，任意缩放均保持矢量锐利。
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
      fontFamilyFallback: baseStyle.fontFamilyFallback ?? AppTheme.cjkFontFallback,
    );
    final scriptStyle = effectiveStyle.copyWith(
      fontSize: fontSize * 0.72,
      height: 1.05,
    );
    final fracStyle = effectiveStyle.copyWith(
      fontSize: fontSize * 0.78,
      height: 1.12,
    );

    // 拆分长文本 token 为可自然换行的字符/英文词元，确保中英混排自动折行不溢出
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

  /// 测量在给定最大宽度下渲染所需的高度
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

  /// 将数学公式文本绘制到 Canvas 指定位置，并返回实际占用高度
  static double paint(
    Canvas canvas,
    String raw, {
    required Offset origin,
    required double maxWidth,
    required TextStyle style,
    double lineSpacing = 3.0,
  }) {
    final lines = _layoutLines(raw, maxWidth, style);
    if (lines.isEmpty) return 0;
    final lineColor = style.color ?? const Color(0xFF111827);
    final barPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.25;

    var y = origin.dy;
    for (var lineIdx = 0; lineIdx < lines.length; lineIdx++) {
      final line = lines[lineIdx];
      var x = origin.dx;
      final midY = y + line.height / 2;

      for (final item in line.items) {
        switch (item.token.type) {
          case MathTokenType.text:
            final tp = item.mainPainter!;
            tp.paint(canvas, Offset(x, midY - tp.height / 2));
          case MathTokenType.sup:
            final tp = item.mainPainter!;
            tp.paint(
              canvas,
              Offset(x, midY - tp.height / 2 + item.baselineOffset),
            );
          case MathTokenType.sub:
            final tp = item.mainPainter!;
            tp.paint(
              canvas,
              Offset(x, midY - tp.height / 2 + item.baselineOffset),
            );
          case MathTokenType.frac:
            final numTp = item.numPainter!;
            final denTp = item.denPainter!;
            final innerW = item.width - 4;
            final barY = midY;
            numTp.paint(
              canvas,
              Offset(
                x + (item.width - numTp.width) / 2,
                barY - numTp.height - 2.2,
              ),
            );
            canvas.drawLine(
              Offset(x + 2, barY),
              Offset(x + 2 + innerW, barY),
              barPaint,
            );
            denTp.paint(
              canvas,
              Offset(
                x + (item.width - denTp.width) / 2,
                barY + 2.2,
              ),
            );
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

    return y - origin.dy;
  }
}
