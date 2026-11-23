enum MathTokenType { text, sup, sub, frac, lineBreak }

class MathToken {
  const MathToken.text(this.value)
      : type = MathTokenType.text,
        num = '',
        den = '';

  const MathToken.sup(this.value)
      : type = MathTokenType.sup,
        num = '',
        den = '';

  const MathToken.sub(this.value)
      : type = MathTokenType.sub,
        num = '',
        den = '';

  const MathToken.frac(this.num, this.den)
      : type = MathTokenType.frac,
        value = '';

  const MathToken.lineBreak()
      : type = MathTokenType.lineBreak,
        value = '',
        num = '',
        den = '';

  final MathTokenType type;
  final String value;
  final String num;
  final String den;
}

class MathParser {
  MathParser._();

  static const Map<String, String> _latexSymbolMap = <String, String>{
    r'\pm': '±',
    r'\mp': '∓',
    r'\times': '×',
    r'\div': '÷',
    r'\cdot': '·',
    r'\neq': '≠',
    r'\ne': '≠',
    r'\leq': '≤',
    r'\le': '≤',
    r'\geq': '≥',
    r'\ge': '≥',
    r'\approx': '≈',
    r'\equiv': '≡',
    r'\sim': '∽',
    r'\cong': '≌',
    r'\pi': 'π',
    r'\theta': 'θ',
    r'\alpha': 'α',
    r'\beta': 'β',
    r'\gamma': 'γ',
    r'\delta': 'δ',
    r'\Delta': 'Δ',
    r'\lambda': 'λ',
    r'\mu': 'μ',
    r'\sigma': 'σ',
    r'\omega': 'ω',
    r'\Omega': 'Ω',
    r'\infty': '∞',
    r'\triangle': '△',
    r'\angle': '∠',
    r'\perp': '⊥',
    r'\parallel': '∥',
    r'\notin': '∉',
    r'\in': '∈',
    r'\subseteq': '⊆',
    r'\subset': '⊂',
    r'\cup': '∪',
    r'\cap': '∩',
    r'\emptyset': '∅',
    r'\forall': '∀',
    r'\exists': '∃',
    r'\rightarrow': '→',
    r'\to': '→',
    r'\Rightarrow': '⇒',
    r'\Leftrightarrow': '⇔',
    r'\circ': '°',
    r'\sum': '∑',
    r'\prod': '∏',
    r'\int': '∫',
    r'\qquad': '  ',
    r'\quad': ' ',
  };

  static final List<MapEntry<String, String>> _sortedSymbols =
      _latexSymbolMap.entries.toList()
        ..sort((a, b) => b.key.length.compareTo(a.key.length));

  static const Map<String, String> _supMap = <String, String>{
    '0': '⁰',
    '1': '¹',
    '2': '²',
    '3': '³',
    '4': '⁴',
    '5': '⁵',
    '6': '⁶',
    '7': '⁷',
    '8': '⁸',
    '9': '⁹',
    '+': '⁺',
    '-': '⁻',
    '(': '⁽',
    ')': '⁾',
    'n': 'ⁿ',
    'i': 'ⁱ',
  };

  static const Map<String, String> _subMap = <String, String>{
    '0': '₀',
    '1': '₁',
    '2': '₂',
    '3': '₃',
    '4': '₄',
    '5': '₅',
    '6': '₆',
    '7': '₇',
    '8': '₈',
    '9': '₉',
    '+': '₊',
    '-': '₋',
    '(': '₍',
    ')': '₎',
  };

  static final RegExp _alphaRegex = RegExp(r'[A-Za-z]');
  static final RegExp _simpleTermRegex = RegExp(r'^[A-Za-z0-9π√]+$');
  static final RegExp _delimiterRegex = RegExp(
    r'\\\$|\$\$([\s\S]+?)\$\$|\$([^$\n]+?)\$|\\\[([\s\S]+?)\\\]|\\\(([\s\S]+?)\\\)',
  );
  static final RegExp _rawLatexHintRegex = RegExp(
    r'\\frac|\\sqrt|\\times|\\div|\\pm',
  );

  static String _toMappedScript(
    String raw,
    Map<String, String> map,
    String prefix,
  ) {
    final cleaned = raw.trim();
    if (cleaned.isEmpty) return '';
    final buffer = StringBuffer();
    for (var i = 0; i < cleaned.length; i++) {
      final ch = cleaned[i];
      final mapped = map[ch];
      if (mapped == null) {
        return cleaned.length > 1 ? '$prefix($cleaned)' : '$prefix$cleaned';
      }
      buffer.write(mapped);
    }
    return buffer.toString();
  }

  static ({String value, int nextIndex}) _readLatexArg(String str, int start) {
    var idx = start;
    while (idx < str.length && str[idx] == ' ') {
      idx++;
    }
    if (idx >= str.length) {
      return (value: '', nextIndex: idx);
    }
    if (str[idx] == '{') {
      var depth = 0;
      final contentStart = idx + 1;
      while (idx < str.length) {
        if (str[idx] == '{') {
          depth++;
        } else if (str[idx] == '}') {
          depth--;
          if (depth == 0) {
            return (value: str.substring(contentStart, idx), nextIndex: idx + 1);
          }
        }
        idx++;
      }
      return (value: str.substring(contentStart), nextIndex: str.length);
    }
    return (value: str[idx], nextIndex: idx + 1);
  }

  static String _preprocessLatex(String latex) {
    var result = latex
        .replaceAll(RegExp(r'\\left\s*\.'), '')
        .replaceAll(RegExp(r'\\right\s*\.'), '')
        .replaceAll(r'\left', '')
        .replaceAll(r'\right', '');
    result = result.replaceAllMapped(
      RegExp(r'\\begin\{cases\}([\s\S]*?)\\end\{cases\}'),
      (m) => '{ ${(m.group(1) ?? '').replaceAll(r'\\', '； ')} }',
    );
    result = result.replaceAllMapped(
      RegExp(r'\\text\{([^{}]*)\}'),
      (m) => m.group(1) ?? '',
    );
    result = result.replaceAllMapped(
      RegExp(r'\\mathrm\{([^{}]*)\}'),
      (m) => m.group(1) ?? '',
    );
    return result;
  }

  static String _formatCompactMath(String expr) {
    final tokens = _parseFormulaToTokens(expr);
    final buffer = StringBuffer();
    for (final tok in tokens) {
      switch (tok.type) {
        case MathTokenType.text:
          buffer.write(tok.value);
        case MathTokenType.sup:
          buffer.write(_toMappedScript(tok.value, _supMap, '^'));
        case MathTokenType.sub:
          buffer.write(_toMappedScript(tok.value, _subMap, '_'));
        case MathTokenType.frac:
          final simpleN = _simpleTermRegex.hasMatch(tok.num);
          final simpleD = _simpleTermRegex.hasMatch(tok.den);
          final left = simpleN ? tok.num : '(${tok.num})';
          final right = simpleD ? tok.den : '(${tok.den})';
          buffer.write('$left/$right');
        case MathTokenType.lineBreak:
          buffer.write(' ');
      }
    }
    return buffer.toString().trim();
  }

  static bool _isAlphaAt(String src, int index) {
    if (index < 0 || index >= src.length) return false;
    return _alphaRegex.hasMatch(src[index]);
  }

  static List<MathToken> _parseFormulaToTokens(String latex) {
    final src = _preprocessLatex(latex.trim());
    final tokens = <MathToken>[];
    final textBuf = StringBuffer();

    void flushText() {
      if (textBuf.isNotEmpty) {
        tokens.add(MathToken.text(textBuf.toString()));
        textBuf.clear();
      }
    }

    var i = 0;
    while (i < src.length) {
      if (src.startsWith(r'\\', i)) {
        flushText();
        tokens.add(const MathToken.lineBreak());
        i += 2;
        continue;
      }

      if (src.startsWith(r'\frac', i) && !_isAlphaAt(src, i + 5)) {
        final numArg = _readLatexArg(src, i + 5);
        final denArg = _readLatexArg(src, numArg.nextIndex);
        final numStr = _formatCompactMath(numArg.value);
        final denStr = _formatCompactMath(denArg.value);
        if (numStr.isNotEmpty || denStr.isNotEmpty) {
          flushText();
          tokens.add(
            MathToken.frac(
              numStr.isEmpty ? '?' : numStr,
              denStr.isEmpty ? '?' : denStr,
            ),
          );
        }
        i = denArg.nextIndex;
        continue;
      }

      if (src.startsWith(r'\sqrt', i) && !_isAlphaAt(src, i + 5)) {
        var cursor = i + 5;
        while (cursor < src.length && src[cursor] == ' ') {
          cursor++;
        }
        var rootPrefix = '';
        if (cursor < src.length && src[cursor] == '[') {
          final closeBracket = src.indexOf(']', cursor + 1);
          if (closeBracket > cursor) {
            rootPrefix = _toMappedScript(
              src.substring(cursor + 1, closeBracket),
              _supMap,
              '^',
            );
            cursor = closeBracket + 1;
          }
        }
        final radArg = _readLatexArg(src, cursor);
        final inner = _formatCompactMath(radArg.value);
        textBuf.write('$rootPrefix√($inner)');
        i = radArg.nextIndex;
        continue;
      }

      if (src[i] == '^') {
        final arg = _readLatexArg(src, i + 1);
        final val = _formatCompactMath(arg.value);
        if (val.isNotEmpty) {
          flushText();
          tokens.add(MathToken.sup(val));
        }
        i = arg.nextIndex;
        continue;
      }

      if (src[i] == '_') {
        final arg = _readLatexArg(src, i + 1);
        final val = _formatCompactMath(arg.value);
        if (val.isNotEmpty) {
          flushText();
          tokens.add(MathToken.sub(val));
        }
        i = arg.nextIndex;
        continue;
      }

      if (src[i] == r'\') {
        var matched = false;
        for (final entry in _sortedSymbols) {
          if (src.startsWith(entry.key, i) &&
              !_isAlphaAt(src, i + entry.key.length)) {
            textBuf.write(entry.value);
            i += entry.key.length;
            matched = true;
            break;
          }
        }
        if (matched) continue;
      }

      if (src[i] == '{' || src[i] == '}') {
        i++;
        continue;
      }

      textBuf.write(src[i]);
      i++;
    }

    flushText();
    return tokens;
  }

  static void _pushPlainSegment(List<MathToken> tokens, String segment) {
    if (segment.isEmpty) return;
    final lines = segment.split(RegExp(r'\r?\n'));
    for (var idx = 0; idx < lines.length; idx++) {
      if (lines[idx].isNotEmpty) {
        tokens.add(MathToken.text(lines[idx]));
      }
      if (idx < lines.length - 1) {
        tokens.add(const MathToken.lineBreak());
      }
    }
  }

  static List<MathToken> parseTokens(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    final tokens = <MathToken>[];
    var lastIndex = 0;
    var hasDelimiters = false;

    for (final match in _delimiterRegex.allMatches(raw)) {
      hasDelimiters = true;
      if (match.start > lastIndex) {
        _pushPlainSegment(tokens, raw.substring(lastIndex, match.start));
      }
      final full = match.group(0) ?? '';
      if (full == r'\$') {
        _pushPlainSegment(tokens, r'$');
      } else {
        final inner = match.group(1) ??
            match.group(2) ??
            match.group(3) ??
            match.group(4) ??
            '';
        tokens.addAll(_parseFormulaToTokens(inner));
      }
      lastIndex = match.end;
    }

    if (!hasDelimiters && _rawLatexHintRegex.hasMatch(raw)) {
      tokens.addAll(_parseFormulaToTokens(raw));
    } else if (lastIndex < raw.length) {
      _pushPlainSegment(tokens, raw.substring(lastIndex));
    }

    if (tokens.isEmpty && raw.isNotEmpty) {
      tokens.add(MathToken.text(raw));
    }
    return tokens;
  }

  static String renderPlainText(String? raw) {
    final tokens = parseTokens(raw);
    final buffer = StringBuffer();
    for (final tok in tokens) {
      switch (tok.type) {
        case MathTokenType.text:
          buffer.write(tok.value);
        case MathTokenType.sup:
          buffer.write(_toMappedScript(tok.value, _supMap, '^'));
        case MathTokenType.sub:
          buffer.write(_toMappedScript(tok.value, _subMap, '_'));
        case MathTokenType.frac:
          final simpleN = _simpleTermRegex.hasMatch(tok.num);
          final simpleD = _simpleTermRegex.hasMatch(tok.den);
          final left = simpleN ? tok.num : '(${tok.num})';
          final right = simpleD ? tok.den : '(${tok.den})';
          buffer.write('$left/$right');
        case MathTokenType.lineBreak:
          buffer.write(' ');
      }
    }
    return buffer.toString();
  }
}
