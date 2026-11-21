import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";

const PROTOTYPE_SRC_DIR =
  "C:\\Users\\LangLang\\Downloads\\过关啦-完整源码\\过关啦-完整源码\\src";
const OUT_DIR = "C:\\Users\\LangLang\\Desktop\\guoguanla\\scripts\\output";
const BACKEND_DB_DIR =
  "C:\\Users\\LangLang\\Desktop\\guoguanla\\backend\\src\\main\\resources\\db";

fs.mkdirSync(OUT_DIR, { recursive: true });
fs.mkdirSync(BACKEND_DB_DIR, { recursive: true });

const files = [
  "02-bank-ch1.js",
  "03-bank-ch2.js",
  "04-bank-ch3.js",
  "05-bank-high.js",
];

const combinedBankJs = files
  .map((f) => fs.readFileSync(path.join(PROTOTYPE_SRC_DIR, f), "utf8"))
  .join("\n");

function R(a, b) {
  return Math.floor(Math.random() * (b - a + 1)) + a;
}
function sh(arr) {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}
function mkg(q, ans, wrongs) {
  const seen = new Set([ans]);
  const d = [];
  for (const w of wrongs) {
    if (!seen.has(w)) {
      seen.add(w);
      d.push(w);
    }
  }
  let i = 0;
  const num = parseFloat(ans);
  if (isFinite(num) && String(num) === String(ans).trim()) {
    const cand = [num + 1, num - 1, num + 2, num - 2];
    while (d.length < 3) {
      const v = String(cand[i++ % 4]);
      if (!seen.has(v)) {
        seen.add(v);
        d.push(v);
      }
    }
  } else {
    const suf = ["+1", "−1", "×2", "½"];
    while (d.length < 3) {
      const v = ans + suf[i++ % 4];
      if (!seen.has(v)) {
        seen.add(v);
        d.push(v);
      }
    }
  }
  const o = sh([ans, ...d.slice(0, 3)]);
  return { q, o, a: o.indexOf(ans) };
}
function frac(n, d) {
  let a = n,
    b = d;
  while (b) {
    [a, b] = [b, a % b];
  }
  return a === d
    ? "1"
    : a === 1
      ? String(n) + "/" + String(d)
      : String(n / a) + "/" + String(d / a);
}

const sandbox = { R, sh, mkg, frac, Math, String, Number, parseFloat, isFinite, Set, Array };
vm.createContext(sandbox);
vm.runInContext(combinedBankJs + "\nthis.__BANK__ = BANK;", sandbox);
const BANK = sandbox.__BANK__;

const LEVELS = [
  [0, "🌱", "数学村的小学徒", "刚踏进数学世界，一切都很新鲜！"],
  [5, "🍃", "青青草原探险家", "走出新手村，开始探索啦！"],
  [12, "⚔️", "持剑的基础骑士", "基础关拿下了不少，装备升级！"],
  [24, "🛡️", "中档关勇士", "中档题挡不住你了！"],
  [40, "🏹", "拓展森林猎手", "拓展关的猛兽纷纷落网！"],
  [60, "🐉", "压轴巨龙挑战者", "敢挑战压轴巨龙的勇者！"],
  [84, "🧙", "数学魔法师", "难题在你面前都会露出解法！"],
  [120, "👑", "过关王国守护者", "王国因你而安心！"],
  [160, "💫", "数学传说勇者", "你的名字已被写进传说！"],
  [200, "🌟", "数学世界之神", "通关封神！你就是数学世界之神！"],
];

const grades = [];
const chapters = [];
const gates = [];
const questions = [];

let gradeSort = 1;
let chapterSort = 1;
let chapterAutoId = 1;
let gateAutoId = 1;
let questionAutoId = 1;

for (const gradeCode of ["g7", "g8", "g9", "h1", "h2", "h3"]) {
  const g = BANK[gradeCode];
  grades.push({
    id: gradeSort,
    gradeCode,
    gradeName: g.name,
    icon: g.icon,
    sortOrder: gradeSort++,
  });

  for (const ch of g.chapters) {
    const chapId = chapterAutoId++;
    chapters.push({
      id: chapId,
      chapterCode: ch.id,
      gradeCode,
      name: ch.name,
      description: ch.desc || "",
      sortOrder: chapterSort++,
    });

    ch.gates.forEach((gt, gateIndex) => {
      const gateId = gateAutoId++;
      gates.push({
        id: gateId,
        chapterId: chapId,
        gateIndex,
        gateName: gt.lv,
        star: gt.star,
        questionCount: 3,
        passCount: 2,
      });

      if (Array.isArray(gt.qs)) {
        gt.qs.forEach((item, idx) => {
          questions.push({
            id: questionAutoId++,
            gradeCode,
            chapterId: chapId,
            gateId,
            questionMode: "STATIC",
            questionFormat: "SINGLE_CHOICE",
            stem: item.q,
            options: item.o,
            answer: { index: item.a },
            analysis: "",
            generatorCode: null,
            templateRule: null,
            difficulty: gt.star,
            tags: [g.name, ch.name],
            sortOrder: idx + 1,
          });
        });
      }

      if (Array.isArray(gt.gen)) {
        gt.gen.forEach((fn, idx) => {
          const sample = fn();
          const genCode = `${ch.id}_g${gateIndex}_${idx}`;
          questions.push({
            id: questionAutoId++,
            gradeCode,
            chapterId: chapId,
            gateId,
            questionMode: "DYNAMIC_TEMPLATE",
            questionFormat: "SINGLE_CHOICE",
            stem: sample.q,
            options: sample.o,
            answer: { index: sample.a },
            analysis: "动态随机题型（每次闯关随机生成参数与选项）",
            generatorCode: genCode,
            templateRule: {
              type: "PROTOTYPE_JS_EXPR",
              source: fn.toString(),
              sampleStem: sample.q,
            },
            difficulty: gt.star,
            tags: [g.name, ch.name, "动态随机"],
            sortOrder: idx + 1,
          });
        });
      }
    });
  }
}

const summary = {
  grades: grades.length,
  chapters: chapters.length,
  gates: gates.length,
  questions: questions.length,
  staticQuestions: questions.filter((q) => q.questionMode === "STATIC").length,
  dynamicQuestions: questions.filter((q) => q.questionMode === "DYNAMIC_TEMPLATE").length,
};

const payload = {
  summary,
  levels: LEVELS.map((lv, idx) => ({
    id: idx + 1,
    minGates: lv[0],
    icon: lv[1],
    levelName: lv[2],
    quote: lv[3],
    sortOrder: idx + 1,
  })),
  grades,
  chapters,
  gates,
  questions,
};

const jsonStr = JSON.stringify(payload, null, 2);
fs.writeFileSync(path.join(OUT_DIR, "prototype-bank.json"), jsonStr, "utf8");
fs.writeFileSync(path.join(BACKEND_DB_DIR, "prototype-bank.json"), jsonStr, "utf8");

function sqlStr(val) {
  if (val === null || val === undefined) return "NULL";
  return "'" + String(val).replace(/\\/g, "\\\\").replace(/'/g, "\\'") + "'";
}

const sqlLines = [
  "-- ============================================================================",
  "-- 过关啦 · 原版 51 章 204 关题库初始化 SQL（MySQL 8.0+）",
  "-- ============================================================================",
  "SET NAMES utf8mb4;",
  "",
  "-- 1. 段位规则（10 级）",
];

payload.levels.forEach((lv) => {
  sqlLines.push(
    `INSERT IGNORE INTO edu_level_rule (id, min_gates, icon, level_name, quote, sort_order) VALUES (${lv.id}, ${lv.minGates}, ${sqlStr(lv.icon)}, ${sqlStr(lv.levelName)}, ${sqlStr(lv.quote)}, ${lv.sortOrder});`
  );
});

sqlLines.push("", "-- 2. 年级（6 个）");
grades.forEach((g) => {
  sqlLines.push(
    `INSERT IGNORE INTO edu_grade (id, grade_code, grade_name, icon, sort_order, enabled) VALUES (${g.id}, ${sqlStr(g.gradeCode)}, ${sqlStr(g.gradeName)}, ${sqlStr(g.icon)}, ${g.sortOrder}, 1);`
  );
});

sqlLines.push("", "-- 3. 章节（51 章）");
chapters.forEach((c) => {
  sqlLines.push(
    `INSERT IGNORE INTO edu_chapter (id, chapter_code, grade_code, name, description, is_custom, sort_order, enabled) VALUES (${c.id}, ${sqlStr(c.chapterCode)}, ${sqlStr(c.gradeCode)}, ${sqlStr(c.name)}, ${sqlStr(c.description)}, 0, ${c.sortOrder}, 1);`
  );
});

sqlLines.push("", "-- 4. 关卡（204 关）");
gates.forEach((gt) => {
  sqlLines.push(
    `INSERT IGNORE INTO edu_gate (id, chapter_id, gate_index, gate_name, star, question_count, pass_count, enabled) VALUES (${gt.id}, ${gt.chapterId}, ${gt.gateIndex}, ${sqlStr(gt.gateName)}, ${gt.star}, ${gt.questionCount}, ${gt.passCount}, 1);`
  );
});

sqlLines.push("", "-- 5. 题目（静态题 204 + 动态随机模板题 408 = 612 条）");
questions.forEach((q) => {
  const optsJson = JSON.stringify(q.options);
  const ansJson = JSON.stringify(q.answer);
  const tagsJson = JSON.stringify(q.tags);
  const tplJson = q.templateRule ? JSON.stringify(q.templateRule) : null;
  sqlLines.push(
    `INSERT IGNORE INTO edu_question (id, grade_code, chapter_id, gate_id, question_mode, question_format, stem, options_json, answer_json, analysis, generator_code, template_rule_json, difficulty, tags_json, source, version, sort_order, enabled) VALUES (${q.id}, ${sqlStr(q.gradeCode)}, ${q.chapterId}, ${q.gateId}, ${sqlStr(q.questionMode)}, ${sqlStr(q.questionFormat)}, ${sqlStr(q.stem)}, ${sqlStr(optsJson)}, ${sqlStr(ansJson)}, ${sqlStr(q.analysis)}, ${sqlStr(q.generatorCode)}, ${sqlStr(tplJson)}, ${q.difficulty}, ${sqlStr(tagsJson)}, 'PROTOTYPE', 1, ${q.sortOrder}, 1);`
  );
});

const sqlContent = sqlLines.join("\n");
fs.writeFileSync(path.join(OUT_DIR, "seed-prototype.sql"), sqlContent, "utf8");
fs.writeFileSync(path.join(BACKEND_DB_DIR, "seed-prototype.sql"), sqlContent, "utf8");

const schemaSql = fs.readFileSync(path.join(BACKEND_DB_DIR, "schema.sql"), "utf8");
const fullMysql = [
  "CREATE DATABASE IF NOT EXISTS `guoguanla` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;",
  "USE `guoguanla`;",
  "SET NAMES utf8mb4;",
  "",
  schemaSql,
  "",
  sqlContent,
].join("\n");
fs.writeFileSync(path.join(OUT_DIR, "init-mysql-all.sql"), fullMysql, "utf8");
console.log("Generated prototype-bank.json & seed-prototype.sql & init-mysql-all.sql:", summary);
