import katex from "katex";

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

function renderKatex(expr: string, displayMode: boolean): string {
  const cleaned = expr.trim();
  if (!cleaned) return "";
  try {
    return katex.renderToString(cleaned, {
      displayMode,
      throwOnError: false,
      strict: "ignore"
    });
  } catch {
    return escapeHtml(expr);
  }
}

/**
 * 将包含 `$...$` / `$$...$$` 的题目文本安全地渲染为富文本 HTML。
 * 非公式纯文本与普通 Unicode 符号均做 HTML 转义并保留换行。
 */
export function renderMathRichText(raw?: string | null): string {
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
      result += `<span class="math-block">${renderKatex(match[1], true)}</span>`;
    } else if (match[2] !== undefined) {
      result += `<span class="math-inline">${renderKatex(match[2], false)}</span>`;
    } else if (match[3] !== undefined) {
      result += `<span class="math-block">${renderKatex(match[3], true)}</span>`;
    } else if (match[4] !== undefined) {
      result += `<span class="math-inline">${renderKatex(match[4], false)}</span>`;
    }
    lastIndex = tokenPattern.lastIndex;
  }

  if (lastIndex < raw.length) {
    result += escapeTextSegment(raw.slice(lastIndex));
  }
  return result;
}

export function wrapLatexDelimiter(latex: string, displayMode: boolean): string {
  const clean = latex.replace(/\\placeholder\{([^}]*)\}/g, "$1").trim();
  if (!clean) return "";
  return displayMode ? `\n$$\n${clean}\n$$\n` : `$${clean}$`;
}
