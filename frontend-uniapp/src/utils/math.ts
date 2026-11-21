// #ifdef H5
import katex from "katex";
// #endif

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
  "\\ne": "≠",
  "\\neq": "≠",
  "\\le": "≤",
  "\\leq": "≤",
  "\\ge": "≥",
  "\\geq": "≥",
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
  "\\in": "∈",
  "\\notin": "∉",
  "\\subset": "⊂",
  "\\subseteq": "⊆",
  "\\cup": "∪",
  "\\cap": "∩",
  "\\emptyset": "∅",
  "\\forall": "∀",
  "\\exists": "∃",
  "\\to": "→",
  "\\rightarrow": "→",
  "\\Rightarrow": "⇒",
  "\\Leftrightarrow": "⇔",
  "\\circ": "°",
  "\\sum": "∑",
  "\\prod": "∏",
  "\\int": "∫",
  "\\quad": " ",
  "\\qquad": "  ",
};

function renderReadableMathHtml(latex: string): string {
  let out = latex
    .replace(/\\left\s*\./g, "")
    .replace(/\\right\s*\./g, "")
    .replace(/\\left/g, "")
    .replace(/\\right/g, "")
    .replace(/\\begin\{cases\}([\s\S]*?)\\end\{cases\}/g, (_m, body: string) =>
      `{ ${body.replace(/\\\\/g, "； ")} }`,
    )
    .replace(/\\text\{([^{}]*)\}/g, "$1")
    .replace(/\\mathrm\{([^{}]*)\}/g, "$1");

  // 先规范化无花括号的简单分数写法（如 \frac12 -> \frac{1}{2}）
  out = out
    .replace(/\\frac\s*([0-9A-Za-z])\s*([0-9A-Za-z])/g, "\\frac{$1}{$2}")
    .replace(/\\frac\s*([0-9A-Za-z])\s*\{([^{}]+)\}/g, "\\frac{$1}{$2}")
    .replace(/\\frac\s*\{([^{}]+)\}\s*([0-9A-Za-z])/g, "\\frac{$1}{$2}");

  // 支持常见分数与根号的嵌套化简
  for (let i = 0; i < 3; i += 1) {
    out = out
      .replace(
        /\\frac\s*\{([^{}]+)\}\s*\{([^{}]+)\}/g,
        (_m, num: string, den: string) => {
          const n = num.trim();
          const d = den.trim();
          const simpleN = /^[A-Za-z0-9]+$/.test(n);
          const simpleD = /^[A-Za-z0-9]+$/.test(d);
          return `${simpleN ? n : `(${n})`}/${simpleD ? d : `(${d})`}`;
        },
      )
      .replace(/\\sqrt\[([^{}]+)\]\{([^{}]+)\}/g, (_m, n: string, x: string) => `ⁿ√(${n}:${x})`)
      .replace(/\\sqrt\{([^{}]+)\}/g, (_m, x: string) => `√(${x})`);
  }

  for (const [cmd, sym] of Object.entries(LATEX_SYMBOL_MAP)) {
    out = out.replaceAll(cmd, sym);
  }

  out = escapeHtml(out)
    .replace(/\^\{([^{}]+)\}/g, "<sup>$1</sup>")
    .replace(/\^([A-Za-z0-9])/g, "<sup>$1</sup>")
    .replace(/_\{([^{}]+)\}/g, "<sub>$1</sub>")
    .replace(/_([A-Za-z0-9])/g, "<sub>$1</sub>")
    .replace(/\\\\/g, "<br />")
    .replace(/[{}]/g, "");

  return `<span style="font-style: normal;">${out}</span>`;
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
 * 将题目、选项与解析中的 `$...$` / `$$...$$` 渲染为跨端富文本 HTML
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
