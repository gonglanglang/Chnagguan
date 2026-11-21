// #ifdef H5
import katex from "katex";
// #endif

export type MathToken =
  | { type: "text"; value: string }
  | { type: "sup"; value: string }
  | { type: "sub"; value: string }
  | { type: "frac"; num: string; den: string }
  | { type: "br" };

function escapeHtml(text: string): string {
  return text
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function escapeTextSegment(segment: string): string {
  return escapeHtml(segment).replace(/\r?\n/g, "<br />");
}

const LATEX_SYMBOL_MAP: Record<string, string> = {
  "\\pm": "±",
  "\\mp": "∓",
  "\\times": "×",
  "\\div": "÷",
  "\\cdot": "·",
  "\\neq": "≠",
  "\\ne": "≠",
  "\\leq": "≤",
  "\\le": "≤",
  "\\geq": "≥",
  "\\ge": "≥",
  "\\approx": "≈",
  "\\equiv": "≡",
  "\\sim": "∽",
  "\\cong": "≌",
  "\\pi": "π",
  "\\theta": "θ",
  "\\alpha": "α",
  "\\beta": "β",
  "\\gamma": "γ",
  "\\delta": "δ",
  "\\Delta": "Δ",
  "\\lambda": "λ",
  "\\mu": "μ",
  "\\sigma": "σ",
  "\\omega": "ω",
  "\\Omega": "Ω",
  "\\infty": "∞",
  "\\triangle": "△",
  "\\angle": "∠",
  "\\perp": "⊥",
  "\\parallel": "∥",
  "\\notin": "∉",
  "\\in": "∈",
  "\\subseteq": "⊆",
  "\\subset": "⊂",
  "\\cup": "∪",
  "\\cap": "∩",
  "\\emptyset": "∅",
  "\\forall": "∀",
  "\\exists": "∃",
  "\\rightarrow": "→",
  "\\to": "→",
  "\\Rightarrow": "⇒",
  "\\Leftrightarrow": "⇔",
  "\\circ": "°",
  "\\sum": "∑",
  "\\prod": "∏",
  "\\int": "∫",
  "\\qquad": "  ",
  "\\quad": " ",
};

const LATEX_SYMBOLS_SORTED = Object.entries(LATEX_SYMBOL_MAP).sort(
  (a, b) => b[0].length - a[0].length,
);

const SUP_CHAR_MAP: Record<string, string> = {
  "0": "⁰",
  "1": "¹",
  "2": "²",
  "3": "³",
  "4": "⁴",
  "5": "⁵",
  "6": "⁶",
  "7": "⁷",
  "8": "⁸",
  "9": "⁹",
  "+": "⁺",
  "-": "⁻",
  "(": "⁽",
  ")": "⁾",
  "n": "ⁿ",
  "i": "ⁱ",
};

const SUB_CHAR_MAP: Record<string, string> = {
  "0": "₀",
  "1": "₁",
  "2": "₂",
  "3": "₃",
  "4": "₄",
  "5": "₅",
  "6": "₆",
  "7": "₇",
  "8": "₈",
  "9": "₉",
  "+": "₊",
  "-": "₋",
  "(": "₍",
  ")": "₎",
};

function toMappedScript(raw: string, map: Record<string, string>, prefix: string): string {
  const cleaned = raw.trim();
  if (!cleaned) return "";
  let converted = "";
  for (const ch of cleaned) {
    if (!map[ch]) {
      return cleaned.length > 1 ? `${prefix}(${cleaned})` : `${prefix}${cleaned}`;
    }
    converted += map[ch];
  }
  return converted;
}

function readLatexArg(str: string, start: number): { value: string; nextIndex: number } {
  let idx = start;
  while (idx < str.length && str[idx] === " ") {
    idx += 1;
  }
  if (idx >= str.length) {
    return { value: "", nextIndex: idx };
  }
  if (str[idx] === "{") {
    let depth = 0;
    const contentStart = idx + 1;
    while (idx < str.length) {
      if (str[idx] === "{") {
        depth += 1;
      } else if (str[idx] === "}") {
        depth -= 1;
        if (depth === 0) {
          return {
            value: str.slice(contentStart, idx),
            nextIndex: idx + 1,
          };
        }
      }
      idx += 1;
    }
    return { value: str.slice(contentStart), nextIndex: str.length };
  }
  return { value: str[idx], nextIndex: idx + 1 };
}

function preprocessLatex(latex: string): string {
  return latex
    .replace(/\\left\s*\./g, "")
    .replace(/\\right\s*\./g, "")
    .replace(/\\left/g, "")
    .replace(/\\right/g, "")
    .replace(/\\begin\{cases\}([\s\S]*?)\\end\{cases\}/g, (_m, body: string) =>
      `{ ${body.replace(/\\\\/g, "； ")} }`,
    )
    .replace(/\\text\{([^{}]*)\}/g, "$1")
    .replace(/\\mathrm\{([^{}]*)\}/g, "$1");
}

function formatCompactMath(expr: string): string {
  const tokens = parseFormulaToTokens(expr);
  return tokens
    .map((tok) => {
      if (tok.type === "text") return tok.value;
      if (tok.type === "sup") return toMappedScript(tok.value, SUP_CHAR_MAP, "^");
      if (tok.type === "sub") return toMappedScript(tok.value, SUB_CHAR_MAP, "_");
      if (tok.type === "frac") {
        const simpleN = /^[A-Za-z0-9π√]+$/.test(tok.num);
        const simpleD = /^[A-Za-z0-9π√]+$/.test(tok.den);
        return `${simpleN ? tok.num : `(${tok.num})`}/${simpleD ? tok.den : `(${tok.den})`}`;
      }
      return " ";
    })
    .join("")
    .trim();
}

function parseFormulaToTokens(latex: string): MathToken[] {
  const src = preprocessLatex(latex.trim());
  const tokens: MathToken[] = [];
  let textBuf = "";

  const flushText = () => {
    if (textBuf) {
      tokens.push({ type: "text", value: textBuf });
      textBuf = "";
    }
  };

  let i = 0;
  while (i < src.length) {
    if (src.startsWith("\\\\", i)) {
      flushText();
      tokens.push({ type: "br" });
      i += 2;
      continue;
    }

    if (src.startsWith("\\frac", i) && !/[A-Za-z]/.test(src[i + 5] || "")) {
      const numArg = readLatexArg(src, i + 5);
      const denArg = readLatexArg(src, numArg.nextIndex);
      const num = formatCompactMath(numArg.value);
      const den = formatCompactMath(denArg.value);
      if (num || den) {
        flushText();
        tokens.push({ type: "frac", num: num || "?", den: den || "?" });
      }
      i = denArg.nextIndex;
      continue;
    }

    if (src.startsWith("\\sqrt", i) && !/[A-Za-z]/.test(src[i + 5] || "")) {
      let cursor = i + 5;
      while (cursor < src.length && src[cursor] === " ") cursor += 1;
      let rootPrefix = "";
      if (src[cursor] === "[") {
        const closeBracket = src.indexOf("]", cursor + 1);
        if (closeBracket > cursor) {
          rootPrefix = toMappedScript(src.slice(cursor + 1, closeBracket), SUP_CHAR_MAP, "^");
          cursor = closeBracket + 1;
        }
      }
      const radArg = readLatexArg(src, cursor);
      const inner = formatCompactMath(radArg.value);
      textBuf += `${rootPrefix}√(${inner})`;
      i = radArg.nextIndex;
      continue;
    }

    if (src[i] === "^") {
      const arg = readLatexArg(src, i + 1);
      const val = formatCompactMath(arg.value);
      if (val) {
        flushText();
        tokens.push({ type: "sup", value: val });
      }
      i = arg.nextIndex;
      continue;
    }

    if (src[i] === "_") {
      const arg = readLatexArg(src, i + 1);
      const val = formatCompactMath(arg.value);
      if (val) {
        flushText();
        tokens.push({ type: "sub", value: val });
      }
      i = arg.nextIndex;
      continue;
    }

    if (src[i] === "\\") {
      let matched = false;
      for (const [cmd, sym] of LATEX_SYMBOLS_SORTED) {
        if (src.startsWith(cmd, i) && !/[A-Za-z]/.test(src[i + cmd.length] || "")) {
          textBuf += sym;
          i += cmd.length;
          matched = true;
          break;
        }
      }
      if (matched) continue;
    }

    if (src[i] === "{" || src[i] === "}") {
      i += 1;
      continue;
    }

    textBuf += src[i];
    i += 1;
  }

  flushText();
  return tokens;
}

function pushPlainSegment(tokens: MathToken[], segment: string): void {
  if (!segment) return;
  const lines = segment.split(/\r?\n/);
  lines.forEach((line, idx) => {
    if (line) {
      tokens.push({ type: "text", value: line });
    }
    if (idx < lines.length - 1) {
      tokens.push({ type: "br" });
    }
  });
}

/**
 * 将含 `$...$` / `$$...$$` / `\frac` 的文本拆分为跨端原生数学 Token（彻底规避 App `<rich-text>` 兼容问题）
 */
export function parseMathTokens(raw?: string | null): MathToken[] {
  if (!raw) return [];
  const tokenPattern =
    /\\\$|\$\$([\s\S]+?)\$\$|\$([^$\n]+?)\$|\\\[([\s\S]+?)\\\]|\\\(([\s\S]+?)\\\)/g;

  const tokens: MathToken[] = [];
  let lastIndex = 0;
  let match: RegExpExecArray | null;
  let hasDelimiters = false;

  while ((match = tokenPattern.exec(raw)) !== null) {
    hasDelimiters = true;
    if (match.index > lastIndex) {
      pushPlainSegment(tokens, raw.slice(lastIndex, match.index));
    }
    const token = match[0];
    if (token === "\\$") {
      pushPlainSegment(tokens, "$");
    } else if (match[1] !== undefined) {
      tokens.push(...parseFormulaToTokens(match[1]));
    } else if (match[2] !== undefined) {
      tokens.push(...parseFormulaToTokens(match[2]));
    } else if (match[3] !== undefined) {
      tokens.push(...parseFormulaToTokens(match[3]));
    } else if (match[4] !== undefined) {
      tokens.push(...parseFormulaToTokens(match[4]));
    }
    lastIndex = tokenPattern.lastIndex;
  }

  if (!hasDelimiters && (/\\frac|\\sqrt|\\times|\\div|\\pm/.test(raw))) {
    tokens.push(...parseFormulaToTokens(raw));
  } else if (lastIndex < raw.length) {
    pushPlainSegment(tokens, raw.slice(lastIndex));
  }

  if (tokens.length === 0 && raw) {
    tokens.push({ type: "text", value: raw });
  }
  return tokens;
}

/**
 * 将数学题干转换为紧凑单行纯文本（用于横屏作答顶部单行提示等场景）
 */
export function renderMathPlainText(raw?: string | null): string {
  const tokens = parseMathTokens(raw);
  return tokens
    .map((tok) => {
      if (tok.type === "text") return tok.value;
      if (tok.type === "sup") return toMappedScript(tok.value, SUP_CHAR_MAP, "^");
      if (tok.type === "sub") return toMappedScript(tok.value, SUB_CHAR_MAP, "_");
      if (tok.type === "frac") {
        const simpleN = /^[A-Za-z0-9π√]+$/.test(tok.num);
        const simpleD = /^[A-Za-z0-9π√]+$/.test(tok.den);
        return `${simpleN ? tok.num : `(${tok.num})`}/${simpleD ? tok.den : `(${tok.den})`}`;
      }
      return " ";
    })
    .join("");
}

function renderReadableMathHtml(latex: string): string {
  const tokens = parseFormulaToTokens(latex);
  const body = tokens
    .map((tok) => {
      if (tok.type === "text") return escapeHtml(tok.value);
      if (tok.type === "sup") return `<sup>${escapeHtml(tok.value)}</sup>`;
      if (tok.type === "sub") return `<sub>${escapeHtml(tok.value)}</sub>`;
      if (tok.type === "frac") {
        const simpleN = /^[A-Za-z0-9π√]+$/.test(tok.num);
        const simpleD = /^[A-Za-z0-9π√]+$/.test(tok.den);
        return escapeHtml(
          `${simpleN ? tok.num : `(${tok.num})`}/${simpleD ? tok.den : `(${tok.den})`}`,
        );
      }
      return "<br />";
    })
    .join("");
  return `<span style="font-style: normal;">${body}</span>`;
}

function renderFormulaExpr(expr: string, displayMode: boolean): string {
  const cleaned = expr.trim();
  if (!cleaned) return "";
  let html = "";
  // #ifdef H5
  try {
    html = katex.renderToString(cleaned, {
      displayMode,
      throwOnError: false,
      strict: "ignore",
    });
  } catch {
    html = escapeHtml(expr);
  }
  // #endif
  // #ifndef H5
  html = renderReadableMathHtml(cleaned);
  // #endif
  return html;
}

/**
 * 将题目、选项与解析中的 `$...$` / `$$...$$` 渲染为 H5 KaTeX HTML
 */
export function renderMathHtml(raw?: string | null): string {
  if (!raw) return "";
  const tokenPattern =
    /\\\$|\$\$([\s\S]+?)\$\$|\$([^$\n]+?)\$|\\\[([\s\S]+?)\\\]|\\\(([\s\S]+?)\\\)/g;

  let result = "";
  let lastIndex = 0;
  let match: RegExpExecArray | null;

  while ((match = tokenPattern.exec(raw)) !== null) {
    if (match.index > lastIndex) {
      result += escapeTextSegment(raw.slice(lastIndex, match.index));
    }
    const token = match[0];
    if (token === "\\$") {
      result += "$";
    } else if (match[1] !== undefined) {
      result += `<span class="math-block">${renderFormulaExpr(match[1], true)}</span>`;
    } else if (match[2] !== undefined) {
      result += `<span class="math-inline">${renderFormulaExpr(match[2], false)}</span>`;
    } else if (match[3] !== undefined) {
      result += `<span class="math-block">${renderFormulaExpr(match[3], true)}</span>`;
    } else if (match[4] !== undefined) {
      result += `<span class="math-inline">${renderFormulaExpr(match[4], false)}</span>`;
    }
    lastIndex = tokenPattern.lastIndex;
  }

  if (lastIndex < raw.length) {
    result += escapeTextSegment(raw.slice(lastIndex));
  }
  return result;
}
