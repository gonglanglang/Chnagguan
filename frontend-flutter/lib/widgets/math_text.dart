import 'package:flutter/material.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../app/app_theme.dart';
import '../core/utils/math_parser.dart';

/// Native cross-platform math formula renderer supporting LaTeX fractions,
/// superscripts, subscripts, radicals, and Unicode math symbols.
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
          t.type == MathTokenType.sup ||
          t.type == MathTokenType.sub,
    );

    if (!hasComplex) {
      final plain = tokens
          .map((t) => t.type == MathTokenType.lineBreak ? '\n' : t.value)
          .join();
      return Text(plain, style: baseStyle);
    }

    final fontSize = baseStyle.fontSize ?? 15;
    final textColor = baseStyle.color ?? colors.ink;

    // Group tokens into lines separated by explicit lineBreak tokens.
    final lines = <List<MathToken>>[<MathToken>[]];
    for (final tok in tokens) {
      if (tok.type == MathTokenType.lineBreak) {
        lines.add(<MathToken>[]);
      } else {
        lines.last.add(tok);
      }
    }

    InlineSpan buildSpan(MathToken tok) {
      switch (tok.type) {
        case MathTokenType.text:
          return TextSpan(text: tok.value, style: baseStyle);
        case MathTokenType.sup:
          return WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: Transform.translate(
              offset: const Offset(0, -3),
              child: Text(
                tok.value,
                style: baseStyle.copyWith(
                  fontSize: fontSize * 0.72,
                  height: 1.0,
                ),
              ),
            ),
          );
        case MathTokenType.sub:
          return WidgetSpan(
            alignment: PlaceholderAlignment.bottom,
            child: Transform.translate(
              offset: const Offset(0, 3),
              child: Text(
                tok.value,
                style: baseStyle.copyWith(
                  fontSize: fontSize * 0.72,
                  height: 1.0,
                ),
              ),
            ),
          );
        case MathTokenType.frac:
          return WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Text(
                        tok.num,
                        textAlign: TextAlign.center,
                        style: baseStyle.copyWith(
                          fontSize: fontSize * 0.78,
                          height: 1.15,
                        ),
                      ),
                    ),
                    Container(
                      height: 1.3,
                      margin: const EdgeInsets.symmetric(vertical: 1.5),
                      color: textColor,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Text(
                        tok.den,
                        textAlign: TextAlign.center,
                        style: baseStyle.copyWith(
                          fontSize: fontSize * 0.78,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        case MathTokenType.lineBreak:
          return const TextSpan(text: '\n');
      }
    }

    if (inline || lines.length == 1) {
      return Text.rich(
        TextSpan(
          style: baseStyle,
          children: [for (final tok in tokens) buildSpan(tok)],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              style: baseStyle,
              children: [for (final tok in lines[i]) buildSpan(tok)],
            ),
          ),
        ],
      ],
    );
  }
}
