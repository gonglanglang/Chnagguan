import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { G7_CHAPTERS } from './data/bank-g7.mjs';
import { G8_CHAPTERS } from './data/bank-g8.mjs';
import { G9_CHAPTERS } from './data/bank-g9.mjs';
import { H1_CHAPTERS } from './data/bank-h1.mjs';
import { H2_CHAPTERS } from './data/bank-h2.mjs';
import { H3_CHAPTERS } from './data/bank-h3.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const OUTPUT_DIR = path.join(__dirname, 'output');
const BATCH_TAG = 'TASK-20261122-002';

const ALL_CHAPTERS = [
  ...G7_CHAPTERS,
  ...G8_CHAPTERS,
  ...G9_CHAPTERS,
  ...H1_CHAPTERS,
  ...H2_CHAPTERS,
  ...H3_CHAPTERS,
];

// 与后端 SafeParamEvaluator 完全一致的表达式与分数化简求值器
function gcd(a, b) {
  let x = Math.abs(Math.trunc(a));
  let y = Math.abs(Math.trunc(b));
  while (y !== 0) {
    const t = x % y;
    x = y;
    y = t;
  }
  return x === 0 ? 1 : x;
}

function splitTopLevelArgs(body) {
  const parts = [];
  let depth = 0;
  let start = 0;
  for (let i = 0; i < body.length; i++) {
    const ch = body[i];
    if (ch === '(') depth++;
    else if (ch === ')') depth--;
    else if (ch === ',' && depth === 0) {
      parts.push(body.slice(start, i).trim());
      start = i + 1;
    }
  }
  parts.push(body.slice(start).trim());
  return parts;
}

function evalNumeric(expr, env) {
  const tokens = [];
  let i = 0;
  const src = String(expr ?? '').trim();
  while (i < src.length) {
    const ch = src[i];
    if (/\s/.test(ch)) {
      i++;
      continue;
    }
    if (/[0-9.]/.test(ch)) {
      let j = i;
      while (j < src.length && /[0-9.]/.test(src[j])) j++;
      const num = Number(src.slice(i, j));
      if (!Number.isFinite(num)) throw new Error(`数字解析失败: ${src.slice(i, j)}`);
      tokens.push({ type: 'NUM', val: num });
      i = j;
      continue;
    }
    if (/[A-Za-z_]/.test(ch)) {
      let j = i;
      while (j < src.length && /[A-Za-z0-9_]/.test(src[j])) j++;
      tokens.push({ type: 'ID', val: src.slice(i, j) });
      i = j;
      continue;
    }
    if ('+-*/%^(),'.includes(ch)) {
      tokens.push({ type: 'OP', val: ch });
      i++;
      continue;
    }
    throw new Error(`不支持的字符 "${ch}" in expr: ${expr}`);
  }

  let pos = 0;
  const peek = () => tokens[pos];
  const next = () => tokens[pos++];

  function parseExpr() {
    let left = parseTerm();
    while (peek() && (peek().val === '+' || peek().val === '-')) {
      const op = next().val;
      const right = parseTerm();
      left = op === '+' ? left + right : left - right;
    }
    return left;
  }

  function parseTerm() {
    let left = parseUnary();
    while (peek() && (peek().val === '*' || peek().val === '/' || peek().val === '%')) {
      const op = next().val;
      const right = parseUnary();
      if ((op === '/' || op === '%') && Math.abs(right) < 1e-12) {
        throw new Error(`除零错误 in expr: ${expr}`);
      }
      if (op === '*') left *= right;
      else if (op === '/') left /= right;
      else left %= right;
    }
    return left;
  }

  function parseUnary() {
    if (peek() && (peek().val === '+' || peek().val === '-')) {
      const op = next().val;
      const val = parseUnary();
      return op === '-' ? -val : val;
    }
    return parsePow();
  }

  function parsePow() {
    let base = parsePrimary();
    if (peek() && peek().val === '^') {
      next();
      const exp = parseUnary();
      base = Math.pow(base, exp);
    }
    return base;
  }

  function parsePrimary() {
    const t = peek();
    if (!t) throw new Error(`表达式意外结束: ${expr}`);
    if (t.type === 'NUM') {
      next();
      return t.val;
    }
    if (t.val === '(') {
      next();
      const v = parseExpr();
      if (!peek() || peek().val !== ')') throw new Error(`缺少右括号: ${expr}`);
      next();
      return v;
    }
    if (t.type === 'ID') {
      next();
      if (peek() && peek().val === '(') {
        next();
        const args = [];
        if (peek() && peek().val !== ')') {
          args.push(parseExpr());
          while (peek() && peek().val === ',') {
            next();
            args.push(parseExpr());
          }
        }
        if (!peek() || peek().val !== ')') throw new Error(`函数缺少右括号: ${expr}`);
        next();
        if (t.val === 'abs') return Math.abs(args[0]);
        if (t.val === 'sqrt') {
          if (args[0] < 0) throw new Error(`负数开方: ${expr}`);
          return Math.sqrt(args[0]);
        }
        if (t.val === 'min') return Math.min(...args);
        if (t.val === 'max') return Math.max(...args);
        throw new Error(`不支持的函数 "${t.val}" in expr: ${expr}`);
      }
      if (!(t.val in env)) throw new Error(`未定义变量 "${t.val}" in expr: ${expr}`);
      return env[t.val];
    }
    throw new Error(`无法解析 token "${t.val}" in expr: ${expr}`);
  }

  const res = parseExpr();
  if (pos !== tokens.length) {
    throw new Error(`多余字符 "${tokens[pos].val}" in expr: ${expr}`);
  }
  if (!Number.isFinite(res)) {
    throw new Error(`求值得到非有限数 in expr: ${expr}`);
  }
  return res;
}

function formatNumber(val) {
  if (Math.abs(val - Math.round(val)) < 1e-9) {
    const r = Math.round(val);
    return String(r === 0 ? 0 : r);
  }
  return Number(val.toFixed(4)).toString();
}

function evalDisplay(expr, env) {
  const trimmed = String(expr ?? '').trim();
  if (!trimmed) throw new Error('空表达式');
  if (trimmed.startsWith('frac(') && trimmed.endsWith(')')) {
    const inner = trimmed.slice(5, -1);
    const args = splitTopLevelArgs(inner);
    if (args.length !== 2) throw new Error(`frac 参数个数错误: ${expr}`);
    const numVal = Math.round(evalNumeric(args[0], env));
    const denVal = Math.round(evalNumeric(args[1], env));
    if (denVal === 0) throw new Error(`frac 分母为 0: ${expr}`);
    if (numVal === 0) return '0';
    const sign = (numVal < 0) ^ (denVal < 0) ? '-' : '';
    const nAbs = Math.abs(numVal);
    const dAbs = Math.abs(denVal);
    const g = gcd(nAbs, dAbs);
    const n = nAbs / g;
    const d = dAbs / g;
    if (d === 1) return `${sign}${n}`;
    return `$${sign}\\frac{${n}}{${d}}$`;
  }
  return formatNumber(evalNumeric(trimmed, env));
}

function renderTemplate(tpl, env) {
  return String(tpl ?? '').replace(/\{\{([^}]+)\}\}/g, (_, expr) => evalDisplay(expr, env));
}

function cartesianProduct(vars) {
  const keys = Object.keys(vars);
  const results = [];
  function backtrack(idx, curr) {
    if (idx === keys.length) {
      results.push({ ...curr });
      return;
    }
    const k = keys[idx];
    const [minV, maxV] = vars[k];
    if (!Number.isInteger(minV) || !Number.isInteger(maxV) || minV > maxV) {
      throw new Error(`变量范围非法 ${k}: [${minV}, ${maxV}]`);
    }
    for (let v = minV; v <= maxV; v++) {
      curr[k] = v;
      backtrack(idx + 1, curr);
    }
  }
  backtrack(0, {});
  return results;
}

function checkLatexHygiene(label, text) {
  const errors = [];
  const s = String(text ?? '');
  // 统计未转义 $ 个数
  let dollarCount = 0;
  for (let i = 0; i < s.length; i++) {
    if (s[i] === '$' && (i === 0 || s[i - 1] !== '\\')) {
      dollarCount++;
    }
  }
  if (dollarCount % 2 !== 0) {
    errors.push(`${label}: '$' 数量为奇数 (${dollarCount})`);
  }

  // 检测禁用或未用 \mathrm 的裸命令
  const stripped = s.replace(/\\mathrm\{[a-z]+\}/g, '');
  const rawTrigMatch = stripped.match(/\\(sin|cos|tan|cot|sec|csc|log|lg|ln)(?![A-Za-z])/);
  if (rawTrigMatch) {
    errors.push(`${label}: 存在未用 \\mathrm{} 包裹的命令 "${rawTrigMatch[0]}"`);
  }
  if (/\\begin\{(pmatrix|bmatrix|vmatrix|matrix)\}/.test(s)) {
    errors.push(`${label}: 存在 App 原生不支持的矩阵环境`);
  }
  // 检测紧贴外层大括号的三连续大括号 {{{ 或 }}}（会导致 {{expr}} 匹配错位，需留空格 { {{expr}} }）
  if (/\{\{\{|\}\}\}/.test(s)) {
    errors.push(`${label}: 存在连续三花括号 {{{ 或 }}}（需写为 { {{expr}} }）`);
  }
  // 单花括号占位符检查（排除 \frac{a}{b}, \sqrt{x}, x_{i}, 2^{k}, \{a, b\}, \mathrm{...} 等合法 LaTeX）
  const barePlaceholder = s
    .replace(/\{\{[^}]+\}\}/g, '')
    .replace(/\\\{|\\\}|\\[A-Za-z]+\{[^}]*\}(?:\{[^}]*\})?|\^\{[^}]*\}|_\{[^}]*\}/g, '')
    .match(/(?<![A-Za-z0-9\\_^}])\{[a-z]\}/);
  if (barePlaceholder) {
    errors.push(`${label}: 疑似漏写双花括号占位符 "${barePlaceholder[0]}"`);
  }
  return errors;
}

function validateAll() {
  const issues = [];
  if (ALL_CHAPTERS.length !== 51) {
    issues.push(`章节总数应为 51，实际 ${ALL_CHAPTERS.length}`);
  }

  const seenChapCodes = new Set();
  const flatQuestions = [];
  const gradeCounts = {};

  for (let ci = 0; ci < ALL_CHAPTERS.length; ci++) {
    const ch = ALL_CHAPTERS[ci];
    const expectedCode = `c${ci + 1}`;
    if (ch.chapterCode !== expectedCode) {
      issues.push(`第 ${ci + 1} 章编码应为 ${expectedCode}，实际 ${ch.chapterCode}`);
    }
    if (seenChapCodes.has(ch.chapterCode)) {
      issues.push(`重复章节编码 ${ch.chapterCode}`);
    }
    seenChapCodes.add(ch.chapterCode);
    gradeCounts[ch.gradeCode] = (gradeCounts[ch.gradeCode] || 0) + 1;

    let chapQCount = 0;
    let chapEssayCount = 0;

    for (let gi = 0; gi < 4; gi++) {
      const qs = ch.gates?.[gi];
      const expectedLen = gi === 3 ? 5 : 4;
      if (!Array.isArray(qs) || qs.length !== expectedLen) {
        issues.push(`${ch.chapterCode} gate ${gi} 题数应为 ${expectedLen}，实际 ${qs?.length}`);
        continue;
      }

      for (let qi = 0; qi < qs.length; qi++) {
        const q = qs[qi];
        const qTag = `${ch.chapterCode}-g${gi}-q${qi + 1}`;
        chapQCount++;
        if (q.questionFormat === 'ESSAY') chapEssayCount++;

        if (!q.stem || !q.stem.trim()) issues.push(`${qTag}: stem 为空`);
        if (!q.analysis || !q.analysis.trim()) issues.push(`${qTag}: analysis 为空`);

        issues.push(...checkLatexHygiene(`${qTag}.stem`, q.stem));
        issues.push(...checkLatexHygiene(`${qTag}.analysis`, q.analysis));

        if (q.questionMode === 'STATIC') {
          if (q.questionFormat === 'SINGLE_CHOICE') {
            if (!Array.isArray(q.options) || q.options.length !== 4) {
              issues.push(`${qTag}: options 必须有 4 项`);
            } else {
              const trimmedOpts = q.options.map((o) => String(o).trim());
              if (trimmedOpts.some((o) => !o)) issues.push(`${qTag}: 存在空选项`);
              if (new Set(trimmedOpts).size !== 4) {
                issues.push(`${qTag}: 存在重复选项 ${JSON.stringify(trimmedOpts)}`);
              }
              trimmedOpts.forEach((opt, oi) => {
                issues.push(...checkLatexHygiene(`${qTag}.opt${oi}`, opt));
              });
            }
            const idx = q.answer?.index;
            if (!Number.isInteger(idx) || idx < 0 || idx > 3) {
              issues.push(`${qTag}: answer.index 非法: ${idx}`);
            }
          } else if (q.questionFormat === 'ESSAY') {
            const ansText = q.answer?.text;
            if (!ansText || !String(ansText).trim()) {
              issues.push(`${qTag}: ESSAY 解答 text 为空`);
            } else {
              issues.push(...checkLatexHygiene(`${qTag}.essayAns`, ansText));
            }
          } else {
            issues.push(`${qTag}: 未知题型 ${q.questionFormat}`);
          }
        } else if (q.questionMode === 'DYNAMIC_TEMPLATE') {
          const rule = q.templateRule;
          if (!rule || rule.type !== 'PARAM_TEMPLATE') {
            issues.push(`${qTag}: DYNAMIC_TEMPLATE 缺少 PARAM_TEMPLATE`);
            continue;
          }
          if (!Array.isArray(rule.wrongExprs) || rule.wrongExprs.length !== 3) {
            issues.push(`${qTag}: wrongExprs 必须有 3 项`);
            continue;
          }
          const envs = cartesianProduct(rule.vars || {});
          if (envs.length === 0 || envs.length > 200000) {
            issues.push(`${qTag}: 笛卡尔积规模异常 (${envs.length})`);
            continue;
          }
          for (const env of envs) {
            try {
              const renderedStem = renderTemplate(rule.stemTpl, env);
              const renderedAnalysis = renderTemplate(q.analysis, env);
              const ansStr = evalDisplay(rule.ansExpr, env);
              const wrongStrs = rule.wrongExprs.map((we) => evalDisplay(we, env));
              const allOpts = [ansStr, ...wrongStrs];
              if (new Set(allOpts).size !== 4) {
                issues.push(
                  `${qTag} 在参数 ${JSON.stringify(env)} 下选项重复: ${JSON.stringify(allOpts)}`,
                );
                break;
              }
              if (!renderedStem.trim() || !renderedAnalysis.trim()) {
                issues.push(`${qTag} 在参数 ${JSON.stringify(env)} 下渲染为空`);
                break;
              }
            } catch (err) {
              issues.push(`${qTag} 在参数 ${JSON.stringify(env)} 求值失败: ${err.message}`);
              break;
            }
          }
        } else {
          issues.push(`${qTag}: 未知 questionMode ${q.questionMode}`);
        }

        const mergedTags = Array.from(new Set([...(q.tags || []), BATCH_TAG]));
        flatQuestions.push({
          gradeCode: ch.gradeCode,
          chapterCode: ch.chapterCode,
          chapterName: ch.chapterName,
          gateIndex: gi,
          sortOrder: 101 + qi,
          difficulty: gi + 1,
          questionMode: q.questionMode,
          questionFormat: q.questionFormat,
          stem: q.stem,
          options: q.questionFormat === 'SINGLE_CHOICE' && q.questionMode === 'STATIC' ? q.options : [],
          answer:
            q.questionFormat === 'ESSAY'
              ? { text: q.answer.text }
              : { index: q.questionMode === 'STATIC' ? q.answer.index : 0 },
          analysis: q.analysis,
          generatorCode: null,
          templateRule: q.questionMode === 'DYNAMIC_TEMPLATE' ? q.templateRule : null,
          tags: mergedTags,
        });
      }
    }

    if (chapQCount !== 17) issues.push(`${ch.chapterCode} 题目总数应为 17，实际 ${chapQCount}`);
    if (chapEssayCount !== 2) issues.push(`${ch.chapterCode} 解答题应为 2，实际 ${chapEssayCount}`);
  }

  return { issues, flatQuestions, gradeCounts };
}

function sqlString(value) {
  if (value === null || value === undefined) return 'NULL';
  const s = String(value)
    .replace(/\\/g, '\\\\')
    .replace(/'/g, "\\'")
    .replace(/\r/g, '')
    .replace(/\n/g, '\\n');
  return `'${s}'`;
}

function sqlJson(value) {
  if (value === null || value === undefined) return 'NULL';
  return sqlString(JSON.stringify(value));
}

function buildSql(flatQuestions) {
  const lines = [
    '-- 「过关啦」初一至高三全章节同步题库脚本 (TASK-20261122-002)',
    '-- 覆盖: 51 章 x 4 关 = 204 关，共计 867 道题（STATIC + PARAM_TEMPLATE + ESSAY），保留现有手工题目并幂等写入',
    'SET NAMES utf8mb4;',
    'START TRANSACTION;',
    '',
  ];

  // 按章节与关卡分组输出，查找 chapter_id 与 gate_id 后幂等写入
  const grouped = new Map();
  for (const q of flatQuestions) {
    const key = `${q.chapterCode}::${q.gateIndex}`;
    if (!grouped.has(key)) grouped.set(key, []);
    grouped.get(key).push(q);
  }

  for (const [key, list] of grouped.entries()) {
    const first = list[0];
    lines.push(`-- === ${first.gradeCode.toUpperCase()} ${first.chapterCode} ${first.chapterName} (gate_index=${first.gateIndex}) ===`);
    lines.push(
      `SET @ch_id = (SELECT id FROM edu_chapter WHERE chapter_code = ${sqlString(first.chapterCode)} AND deleted = 0 LIMIT 1);`,
    );
    lines.push(
      `SET @gt_id = (SELECT id FROM edu_gate WHERE chapter_id = @ch_id AND gate_index = ${first.gateIndex} AND deleted = 0 LIMIT 1);`,
    );

    for (const q of list) {
      lines.push(
        `INSERT INTO edu_question (grade_code, chapter_id, gate_id, question_mode, question_format, stem, options_json, answer_json, analysis, generator_code, template_rule_json, difficulty, tags_json, ext_json, source, version, sort_order, enabled, created_by, deleted)`,
      );
      lines.push(
        `SELECT ${sqlString(q.gradeCode)}, @ch_id, @gt_id, ${sqlString(q.questionMode)}, ${sqlString(q.questionFormat)}, ${sqlString(q.stem)}, ${sqlJson(q.options)}, ${sqlJson(q.answer)}, ${sqlString(q.analysis)}, NULL, ${sqlJson(q.templateRule)}, ${q.difficulty}, ${sqlJson(q.tags)}, NULL, 'ADMIN', 1, ${q.sortOrder}, 1, NULL, 0 FROM DUAL`,
      );
      lines.push(
        `WHERE @ch_id IS NOT NULL AND @gt_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM edu_question WHERE gate_id = @gt_id AND deleted = 0 AND sort_order = ${q.sortOrder} AND JSON_CONTAINS(tags_json, '"${BATCH_TAG}"'));`,
      );
    }
    lines.push('');
  }

  lines.push('-- 同步各关卡抽题总数与通关门槛（基础/中档/压轴须答对3题，含1道解答+3道选择的拓展关须答对2道选择题）');
  lines.push(
    `UPDATE edu_gate gt JOIN (SELECT gate_id, COUNT(*) AS cnt FROM edu_question WHERE deleted = 0 AND enabled = 1 GROUP BY gate_id) q ON gt.id = q.gate_id SET gt.question_count = q.cnt, gt.pass_count = CASE WHEN gt.gate_index = 2 THEN LEAST(2, q.cnt) ELSE LEAST(3, q.cnt) END WHERE gt.deleted = 0;`,
  );
  lines.push('');
  lines.push('COMMIT;');
  lines.push('');
  return lines.join('\n');
}

const { issues, flatQuestions, gradeCounts } = validateAll();

console.log('=== 题库校验统计 ===');
console.log('年级章节分布:', gradeCounts);
console.log('章节总数:', ALL_CHAPTERS.length, '题目总数:', flatQuestions.length);

if (issues.length > 0) {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  const reportPath = path.join(OUTPUT_DIR, 'validation-issues.txt');
  fs.writeFileSync(reportPath, issues.join('\n'), 'utf8');
  console.error(`\n发现 ${issues.length} 个校验问题（完整清单已写入 ${reportPath}）：`);
  issues.slice(0, 60).forEach((msg, i) => console.error(`  ${i + 1}. ${msg}`));
  if (issues.length > 60) console.error(`  ... 其余 ${issues.length - 60} 项见 validation-issues.txt`);
  process.exit(1);
}

fs.mkdirSync(OUTPUT_DIR, { recursive: true });
const jsonPath = path.join(OUTPUT_DIR, 'curriculum-bank-20261122.json');
const sqlPath = path.join(OUTPUT_DIR, 'seed-curriculum-20261122.sql');

fs.writeFileSync(
  jsonPath,
  JSON.stringify(
    {
      batchTag: BATCH_TAG,
      totalChapters: ALL_CHAPTERS.length,
      totalQuestions: flatQuestions.length,
      gradeChapterCounts: gradeCounts,
      questions: flatQuestions,
    },
    null,
    2,
  ),
  'utf8',
);

fs.writeFileSync(sqlPath, buildSql(flatQuestions), 'utf8');

const modeBreakdown = flatQuestions.reduce((acc, q) => {
  const k = `${q.questionMode}:${q.questionFormat}`;
  acc[k] = (acc[k] || 0) + 1;
  return acc;
}, {});
console.log('题型分布:', modeBreakdown);
console.log('校验 100% 通过！已导出:');
console.log(' - JSON:', jsonPath);
console.log(' - SQL :', sqlPath);
