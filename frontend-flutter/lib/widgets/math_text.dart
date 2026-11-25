import 'package:flutter/material.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../app/app_theme.dart';
import '../core/utils/math_parser.dart';

/// Native cross-platform math formula renderer supporting nested LaTeX fractions
/// (`\frac`, `\dfrac`, `\tfrac`, `\cfrac`), real vinculum radicals (`\sqrt`),
/// superscripts, subscripts, and Unicode math symbols.
class MathText extends StatelessWidget {
  const MathText(
    this.text, {
    super.key,
    this.style,
    this.inline = false,
  });

  final String? text;
  final TextStyle? style;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final raw = text ?? '';
    if (raw.isEmpty) return const SizedBox.shrink();

    final colors = WelkTheme.of(context).resolveColors(context);
    final baseStyle = DefaultTextStyle.of(context).style.merge(
          TextStyle(
            color: colors.ink,
            fontSize: 15,
            height: 1.55,
            fontFamilyFallback: AppTheme.cjkFontFallback,
          ),
        ).merge(style);

    final tokens = MathParser.parseTokens(raw);
    if (tokens.isEmpty) {
      return Text(raw, style: baseStyle);
    }

    final hasComplex = tokens.any(
      (t) =>
          t.type == MathTokenType.frac ||
          t.type == MathTokenType.sqrt ||
          t.type == MathTokenType.sup ||
          t.type == MathTokenType.sub,
    );

    if (!hasComplex) {
      final plain = tokens
          .map((t) => t.type == MathTokenType.lineBreak ? '\n' : t.value)
          .join();
      return Text(plain, style: baseStyle);
    }

    // Group tokens into lines separated by explicit lineBreak tokens.
    final lines = <List<MathToken>>[<MathToken>[]];
    for (final tok in tokens) {
      if (tok.type == MathTokenType.lineBreak) {
        lines.add(<MathToken>[]);
      } else {
        lines.last.add(tok);
      }
    }

    if (inline || lines.length == 1) {
      return Text.rich(
        TextSpan(
          style: baseStyle,
          children: _buildSpans(tokens, baseStyle, colors.ink),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              style: baseStyle,
              children: _buildSpans(lines[i], baseStyle, colors.ink),
            ),
          ),
        ],
      ],
    );
  }

  List<InlineSpan> _buildSpans(
    List<MathToken> tokens,
    TextStyle currentStyle,
    Color fallbackInk,
  ) {
    final fontSize = currentStyle.fontSize ?? 15;
    final textColor = currentStyle.color ?? fallbackInk;

    return [
      for (final tok in tokens)
        switch (tok.type) {
          MathTokenType.text => TextSpan(text: tok.value, style: currentStyle),
          MathTokenType.sup => WidgetSpan(
              alignment: PlaceholderAlignment.top,
              child: Transform.translate(
                offset: Offset(0, -fontSize * 0.14),
                child: Text(
                  tok.value,
                  style: currentStyle.copyWith(
                    fontSize: fontSize * 0.72,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          MathTokenType.sub => WidgetSpan(
              alignment: PlaceholderAlignment.bottom,
              child: Transform.translate(
                offset: Offset(0, fontSize * 0.14),
                child: Text(
                  tok.value,
                  style: currentStyle.copyWith(
                    fontSize: fontSize * 0.72,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          MathTokenType.sqrt => WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: _MathRadicalWidget(
                rootIndex: tok.rootIndex,
                color: textColor,
                fontSize: fontSize,
                child: tok.innerTokens.isNotEmpty
                    ? Text.rich(
                        TextSpan(
                          style: currentStyle.copyWith(height: 1.15),
                          children: _buildSpans(
                            tok.innerTokens,
                            currentStyle.copyWith(height: 1.15),
                            fallbackInk,
                          ),
                        ),
                      )
                    : Text(
                        tok.value,
                        style: currentStyle.copyWith(height: 1.15),
                      ),
              ),
            ),
          MathTokenType.frac => WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: IntrinsicWidth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _buildFractionPart(
                          tok.numTokens,
                          tok.num,
                          currentStyle.copyWith(
                            fontSize: fontSize * 0.82,
                            height: 1.15,
                          ),
                          fallbackInk,
                        ),
                      ),
                      Container(
                        height: 1.35,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        color: textColor,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _buildFractionPart(
                          tok.denTokens,
                          tok.den,
                          currentStyle.copyWith(
                            fontSize: fontSize * 0.82,
                            height: 1.15,
                          ),
                          fallbackInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          MathTokenType.lineBreak => const TextSpan(text: '\n'),
        },
    ];
  }

  Widget _buildFractionPart(
    List<MathToken> subTokens,
    String fallbackText,
    TextStyle subStyle,
    Color fallbackInk,
  ) {
    if (subTokens.isEmpty) {
      return Text(fallbackText, textAlign: TextAlign.center, style: subStyle);
    }
    return Text.rich(
      TextSpan(
        style: subStyle,
        children: _buildSpans(subTokens, subStyle, fallbackInk),
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// 真实数学根号渲染组件：绘制清晰勾形根号与顶部贯穿被开方数的横线（vinculum）。
class _MathRadicalWidget extends StatelessWidget {
  const _MathRadicalWidget({
    required this.rootIndex,
    required this.color,
    required this.fontSize,
    required this.child,
  });

  final String rootIndex;
  final Color color;
  final double fontSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hookWidth = (fontSize * 0.56).clamp(7.0, 14.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (rootIndex.isNotEmpty)
            Transform.translate(
              offset: Offset(2, -fontSize * 0.28),
              child: Text(
                rootIndex,
                style: TextStyle(
                  color: color,
                  fontSize: fontSize * 0.58,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
            ),
          CustomPaint(
            painter: _RadicalFramePainter(
              color: color,
              hookWidth: hookWidth,
              strokeWidth: (fontSize * 0.085).clamp(1.15, 1.8),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(hookWidth + 2, 2.5, 2.5, 0.5),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _RadicalFramePainter extends CustomPainter {
  const _RadicalFramePainter({
    required this.color,
    required this.hookWidth,
    required this.strokeWidth,
  });

  final Color color;
  final double hookWidth;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final topY = strokeWidth * 0.9;
    final bottomY = size.height - strokeWidth;
    final path = Path()
      ..moveTo(0, size.height * 0.56)
      ..lineTo(hookWidth * 0.24, size.height * 0.48)
      ..lineTo(hookWidth * 0.54, bottomY)
      ..lineTo(hookWidth, topY)
      ..lineTo(size.width, topY);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RadicalFramePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.hookWidth != hookWidth ||
      oldDelegate.strokeWidth != strokeWidth;
}
