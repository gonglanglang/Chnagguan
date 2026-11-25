enum MathTokenType { text, sup, sub, frac, sqrt, lineBreak }

class MathToken {
  const MathToken.text(this.value)
      : type = MathTokenType.text,
        num = '',
        den = '',
        rootIndex = '',
        numTokens = const [],
        denTokens = const [],
        innerTokens = const [];

  const MathToken.sup(this.value)
      : type = MathTokenType.sup,
        num = '',
        den = '',
        rootIndex = '',
        numTokens = const [],
        denTokens = const [],
        innerTokens = const [];

  const MathToken.sub(this.value)
      : type = MathTokenType.sub,
        num = '',
        den = '',
        rootIndex = '',
        numTokens = const [],
        denTokens = const [],
        innerTokens = const [];

  const MathToken.frac(
    this.num,
    this.den, {
    this.numTokens = const [],
    this.denTokens = const [],
  })  : type = MathTokenType.frac,
        value = '',
        rootIndex = '',
        innerTokens = const [];

  const MathToken.sqrt(
    this.value, {
    this.rootIndex = '',
    this.innerTokens = const [],
  })  : type = MathTokenType.sqrt,
        num = '',
        den = '',
        numTokens = const [],
        denTokens = const [];

  const MathToken.lineBreak()
      : type = MathTokenType.lineBreak,
        value = '',
        num = '',
        den = '',
        rootIndex = '',
        numTokens = const [],
        denTokens = const [],
        innerTokens = const [];

  final MathTokenType type;
  final String value;
  final String num;
  final String den;
  final String rootIndex;
  final List<MathToken> numTokens;
  final List<MathToken> denTokens;
  final List<MathToken> innerTokens;
}

class MathParser {
  MathParser._();

  static const Map<String, String> _latexSymbolMap = <String, String>{
    // 运算符与关系符
    r'\pm': '±',
    r'\mp': '∓',
    r'\times': '×',
    r'\div': '÷',
    r'\cdot': '·',
    r'\ast': '*',
    r'\star': '★',
    r'\neq': '≠',
    r'\ne': '≠',
    r'\leqslant': '≤',
    r'\leq': '≤',
    r'\le': '≤',
    r'\geqslant': '≥',
    r'\geq': '≥',
    r'\ge': '≥',
    r'\approx': '≈',
    r'\equiv': '≡',
    r'\sim': '∽',
    r'\cong': '≌',
    r'\propto': '∝',
    r'\because': '∵',
    r'\therefore': '∴',

    // 希腊字母
    r'\pi': 'π',
    r'\theta': 'θ',
    r'\Theta': 'Θ',
    r'\alpha': 'α',
    r'\beta': 'β',
    r'\gamma': 'γ',
    r'\Gamma': 'Γ',
    r'\delta': 'δ',
    r'\Delta': 'Δ',
    r'\varepsilon': 'ε',
    r'\epsilon': 'ε',
    r'\zeta': 'ζ',
    r'\eta': 'η',
    r'\lambda': 'λ',
    r'\Lambda': 'Λ',
    r'\mu': 'μ',
    r'\nu': 'ν',
    r'\xi': 'ξ',
    r'\rho': 'ρ',
    r'\sigma': 'σ',
    r'\Sigma': 'Σ',
    r'\tau': 'τ',
    r'\varphi': 'φ',
    r'\phi': 'φ',
    r'\Phi': 'Φ',
    r'\chi': 'χ',
    r'\psi': 'ψ',
    r'\Psi': 'Ψ',
    r'\omega': 'ω',
    r'\Omega': 'Ω',

    // 几何 / 集合 / 逻辑 / 箭头
    r'\infty': '∞',
    r'\triangle': '△',
    r'\angle': '∠',
    r'\perp': '⊥',
    r'\parallel': '∥',
    r'\odot': '⊙',
    r'\degree': '°',
    r'\circ': '°',
    r'\prime': '′',
    r'\notin': '∉',
    r'\in': '∈',
    r'\nsubseteq': '⊈',
    r'\subseteq': '⊆',
    r'\subset': '⊂',
    r'\supseteq': '⊇',
    r'\supset': '⊃',
    r'\bigcup': '⋃',
    r'\bigcap': '⋂',
    r'\cup': '∪',
    r'\cap': '∩',
    r'\setminus': '∖',
    r'\varnothing': '∅',
    r'\emptyset': '∅',
    r'\forall': '∀',
    r'\exists': '∃',
    r'\neg': '¬',
    r'\land': '∧',
    r'\lor': '∨',
    r'\Leftrightarrow': '⇔',
    r'\leftrightarrow': '↔',
    r'\iff': '⇔',
    r'\Rightarrow': '⇒',
    r'\implies': '⇒',
    r'\Leftarrow': '⇐',
    r'\rightarrow': '→',
    r'\leftarrow': '←',
    r'\to': '→',
    r'\uparrow': '↑',
    r'\downarrow': '↓',
    r'\partial': '∂',
    r'\nabla': '∇',
    r'\sum': '∑',
    r'\prod': '∏',
    r'\int': '∫',
    r'\cdots': '…',
    r'\ldots': '…',
    r'\dots': '…',
    r'\mid': ' | ',
    r'\vert': '|',
    r'\langle': '⟨',
    r'\rangle': '⟩',

    // 常见标准数学函数名（去除反斜杠，保持清晰正体）
    r'\arcsin': 'arcsin',
    r'\arccos': 'arccos',
    r'\arctan': 'arctan',
    r'\sin': 'sin',
    r'\cos': 'cos',
    r'\tan': 'tan',
    r'\cot': 'cot',
    r'\sec': 'sec',
    r'\csc': 'csc',
    r'\ln': 'ln',
    r'\lg': 'lg',
    r'\log': 'log',
    r'\lim': 'lim',
    r'\max': 'max',
    r'\min': 'min',
    r'\exp': 'exp',
    r'\det': 'det',
    r'\gcd': 'gcd',
    r'\mod': 'mod',

    // 排版样式与间距指令
    r'\displaystyle': '',
    r'\textstyle': '',
    r'\scriptstyle': '',
    r'\scriptscriptstyle': '',
    r'\limits': '',
    r'\nolimits': '',
    r'\qquad': '  ',
    r'\quad': ' ',
  };

  static final List<MapEntry<String, String>> _sortedSymbols =
      _latexSymbolMap.entries.toList()
        ..sort((a, b) => b.key.length.compareTo(a.key.length));

  static const Map<String, String> _blackboardMap = <String, String>{
    'R': 'ℝ',
    'N': 'ℕ',
    'Z': 'ℤ',
    'Q': 'ℚ',
    'C': 'ℂ',
  };

  static const List<String> _fracCommands = <String>[
    r'\dfrac',
    r'\tfrac',
    r'\cfrac',
    r'\frac',
  ];

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
  static final RegExp _simpleTermRegex = RegExp(r'^[A-Za-z0-9π√⁰¹²³⁴⁵⁶⁷⁸⁹₀₁₂₃₄₅₆₇₈₉]+$');
  static final RegExp _delimiterRegex = RegExp(
    r'\\\$|\$\$([\s\S]+?)\$\$|\$([^$\n]+?)\$|\\\[([\s\S]+?)\\\]|\\\(([\s\S]+?)\\\)',
  );
  static final RegExp _rawLatexHintRegex = RegExp(
    r'\\[dtcf]?frac|\\sqrt|\\times|\\div|\\pm|\\leqslant|\\geqslant|\\leq|\\geq|\\because|\\therefore',
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
        if (str[idx] == r'\' && idx + 1 < str.length) {
          idx += 2;
          continue;
        }
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
    if (str[idx] == r'\') {
      var end = idx + 1;
      while (end < str.length && _isAlphaAt(str, end)) {
        end++;
      }
      if (end > idx + 1) {
        return (value: str.substring(idx, end), nextIndex: end);
      }
    }
    return (value: str[idx], nextIndex: idx + 1);
  }

  static String _restoreControlCharLatex(String raw) {
    // 兜底修复后端/历史数据中单反斜杠被 JSON 误转义为控制字符的 LaTeX 命令
    var s = raw;
    if (s.contains('\x0c')) {
      s = s.replaceAll('\x0crac', r'\frac');
    }
    if (s.contains('\x09')) {
      s = s
          .replaceAll('\x09frac', r'\tfrac')
          .replaceAll('\x09imes', r'\times')
          .replaceAll('\x09riangle', r'\triangle')
          .replaceAll('\x09heta', r'\theta')
          .replaceAll('\x09ext', r'\text')
          .replaceAll('\x09an', r'\tan')
          .replaceAll('\x09o', r'\to');
    }
    if (s.contains('\x08')) {
      s = s
          .replaceAll('\x08eta', r'\beta')
          .replaceAll('\x08egin', r'\begin')
          .replaceAll('\x08ecause', r'\because');
    }
    if (s.contains('\x0d')) {
      s = s
          .replaceAll('\x0dight', r'\right')
          .replaceAll('\x0dho', r'\rho');
    }
    return s;
  }

  static String _preprocessLatex(String latex) {
    var result = _restoreControlCharLatex(latex)
        .replaceAll(RegExp(r'\\left\s*\.'), '')
        .replaceAll(RegExp(r'\\right\s*\.'), '')
        .replaceAll(r'\left', '')
        .replaceAll(r'\right', '')
        .replaceAll(RegExp(r'\\big[lr]?|\\Big[lr]?|\\bigg[lr]?|\\Bigg[lr]?'), '');

    result = result.replaceAllMapped(
      RegExp(r'\\begin\{cases\}([\s\S]*?)\\end\{cases\}'),
      (m) => '{ ${(m.group(1) ?? '').replaceAll('&', ' ').replaceAll(r'\\', '； ')} }',
    );
    result = result.replaceAllMapped(
      RegExp(r'\\begin\{(?:aligned|align\*?|gather\*?|array)\}(?:\{[^}]*\})?([\s\S]*?)\\end\{(?:aligned|align\*?|gather\*?|array)\}'),
      (m) => (m.group(1) ?? '').replaceAll('&', ' '),
    );

    // 文本/字体包裹命令解包（循环几轮兼容简单嵌套）
    for (var pass = 0; pass < 2; pass++) {
      result = result.replaceAllMapped(
        RegExp(r'\\(?:text|textbf|textit|mathrm|mathbf|mathit|boldsymbol|operatorname|rm|bf)\{([^{}]*)\}'),
        (m) => m.group(1) ?? '',
      );
      result = result.replaceAllMapped(
        RegExp(r'\\mathbb\{([^{}]*)\}'),
        (m) {
          final inner = (m.group(1) ?? '').trim();
          return _blackboardMap[inner] ?? inner;
        },
      );
      result = result.replaceAllMapped(
        RegExp(r'\\(?:overline|bar|vec|widehat|widetilde|hat|tilde)\{([^{}]*)\}'),
        (m) => m.group(1) ?? '',
      );
    }

    return result;
  }

  static String _formatTokensPlain(List<MathToken> tokens) {
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
        case MathTokenType.sqrt:
          final prefix = tok.rootIndex.isNotEmpty
              ? _toMappedScript(tok.rootIndex, _supMap, '^')
              : '';
          buffer.write('$prefix√(${tok.value})');
        case MathTokenType.lineBreak:
          buffer.write(' ');
      }
    }
    return buffer.toString().trim();
  }

  static String _formatCompactMath(String expr) {
    return _formatTokensPlain(_parseFormulaToTokens(expr));
  }

  static bool _isAlphaAt(String src, int index) {
    if (index < 0 || index >= src.length) return false;
    return _alphaRegex.hasMatch(src[index]);
  }

  static String? _matchFracCommand(String src, int i) {
    for (final cmd in _fracCommands) {
      if (src.startsWith(cmd, i) && !_isAlphaAt(src, i + cmd.length)) {
        return cmd;
      }
    }
    return null;
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

      // 分式：\frac / \dfrac / \tfrac / \cfrac（保留递归子 Token 以便精准渲染嵌套上标与根号）
      final fracCmd = _matchFracCommand(src, i);
      if (fracCmd != null) {
        final numArg = _readLatexArg(src, i + fracCmd.length);
        final denArg = _readLatexArg(src, numArg.nextIndex);
        final numToks = _parseFormulaToTokens(numArg.value);
        final denToks = _parseFormulaToTokens(denArg.value);
        final numStr = _formatTokensPlain(numToks);
        final denStr = _formatTokensPlain(denToks);
        if (numStr.isNotEmpty || denStr.isNotEmpty) {
          flushText();
          tokens.add(
            MathToken.frac(
              numStr.isEmpty ? '?' : numStr,
              denStr.isEmpty ? '?' : denStr,
              numTokens: numToks.isEmpty ? const [MathToken.text('?')] : numToks,
              denTokens: denToks.isEmpty ? const [MathToken.text('?')] : denToks,
            ),
          );
        }
        i = denArg.nextIndex;
        continue;
      }

      // 根号：\sqrt{...} 与 \sqrt[n]{...}（独立 Token，支持真根号上横线渲染）
      if (src.startsWith(r'\sqrt', i) && !_isAlphaAt(src, i + 5)) {
        var cursor = i + 5;
        while (cursor < src.length && src[cursor] == ' ') {
          cursor++;
        }
        var rootIdx = '';
        if (cursor < src.length && src[cursor] == '[') {
          final closeBracket = src.indexOf(']', cursor + 1);
          if (closeBracket > cursor) {
            rootIdx = _formatCompactMath(src.substring(cursor + 1, closeBracket));
            cursor = closeBracket + 1;
          }
        }
        final radArg = _readLatexArg(src, cursor);
        final innerToks = _parseFormulaToTokens(radArg.value);
        final innerStr = _formatTokensPlain(innerToks);
        flushText();
        tokens.add(
          MathToken.sqrt(
            innerStr,
            rootIndex: rootIdx,
            innerTokens: innerToks,
          ),
        );
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
        // 转义符号与间距：\{ \} \| \; \, \: \! \space
        if (i + 1 < src.length) {
          final nextCh = src[i + 1];
          if (nextCh == '{' || nextCh == '}' || nextCh == '%' || nextCh == '&') {
            textBuf.write(nextCh);
            i += 2;
            continue;
          }
          if (nextCh == '|') {
            textBuf.write('‖');
            i += 2;
            continue;
          }
          if (nextCh == ';' || nextCh == ',' || nextCh == ':' || nextCh == ' ') {
            textBuf.write(' ');
            i += 2;
            continue;
          }
          if (nextCh == '!') {
            i += 2;
            continue;
          }
        }

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
    final normalizedRaw = _restoreControlCharLatex(raw);
    final tokens = <MathToken>[];
    var lastIndex = 0;
    var hasDelimiters = false;

    for (final match in _delimiterRegex.allMatches(normalizedRaw)) {
      hasDelimiters = true;
      if (match.start > lastIndex) {
        _pushPlainSegment(tokens, normalizedRaw.substring(lastIndex, match.start));
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

    if (!hasDelimiters && _rawLatexHintRegex.hasMatch(normalizedRaw)) {
      tokens.addAll(_parseFormulaToTokens(normalizedRaw));
    } else if (lastIndex < normalizedRaw.length) {
      _pushPlainSegment(tokens, normalizedRaw.substring(lastIndex));
    }

    if (tokens.isEmpty && normalizedRaw.isNotEmpty) {
      tokens.add(MathToken.text(normalizedRaw));
    }
    return tokens;
  }

  static String renderPlainText(String? raw) {
    return _formatTokensPlain(parseTokens(raw));
  }
}
