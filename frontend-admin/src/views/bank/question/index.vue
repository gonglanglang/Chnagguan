<script setup lang="ts">
import { ref, reactive, computed, onMounted } from "vue";
import { ElMessage, ElMessageBox } from "element-plus";
import MathFormulaText from "@/components/MathFormulaText.vue";
import MathFormulaDialog from "@/components/MathFormulaDialog.vue";
import {
  getRealms,
  getChapters,
  getGatesByChapter,
  getQuestionPage,
  createQuestion,
  updateQuestion,
  toggleQuestionStatus,
  deleteQuestion,
  previewGenerateQuestion,
  type RealmConfig,
  type ChapterItem,
  type GateItem,
  type QuestionItem,
  type GeneratedSample
} from "@/api/guoguanla";

defineOptions({
  name: "QuestionManage"
});

interface VarEntry {
  name: string;
  min: number;
  max: number;
}

const loading = ref(false);
const tableData = ref<QuestionItem[]>([]);
const total = ref(0);

const realms = ref<RealmConfig[]>([]);
const filterChapters = ref<ChapterItem[]>([]);
const filterGates = ref<GateItem[]>([]);

const query = reactive({
  realmCode: "",
  chapterId: undefined as number | undefined,
  gateId: undefined as number | undefined,
  questionMode: "",
  questionFormat: "",
  keyword: "",
  pageNum: 1,
  pageSize: 10
});

// 编辑抽屉状态
const editorVisible = ref(false);
const editorSaving = ref(false);
const editId = ref<number | null>(null);
const editChapters = ref<ChapterItem[]>([]);
const editGates = ref<GateItem[]>([]);

const form = reactive({
  gradeCode: "g7",
  chapterId: undefined as number | undefined,
  gateId: undefined as number | undefined,
  questionMode: "STATIC" as "STATIC" | "DYNAMIC_TEMPLATE",
  questionFormat: "SINGLE_CHOICE" as "SINGLE_CHOICE" | "ESSAY",
  stem: "",
  options: ["", "", "", ""],
  answerIndex: 0,
  essayAnswerText: "",
  analysis: "",
  enabled: 1,
  syncGateCount: true
});

// 随机变数编辑器状态
const dynamicEngineType = ref<"PARAM_TEMPLATE" | "PROTOTYPE_JS_EXPR">("PARAM_TEMPLATE");
const paramVars = ref<VarEntry[]>([
  { name: "a", min: 2, max: 9 },
  { name: "b", min: 1, max: 8 }
]);
const paramRule = reactive({
  stemTpl: "",
  ansExpr: "",
  wrongExprs: ["", "", ""]
});
const jsSource = ref("");
const drawerPreviewLoading = ref(false);
const drawerPreviewSamples = ref<GeneratedSample[]>([]);

// 列表弹窗预览
const previewVisible = ref(false);
const previewLoading = ref(false);
const previewSamples = ref<GeneratedSample[]>([]);

const selectedEditGate = computed(() =>
  editGates.value.find(g => g.id === form.gateId) || null
);

// 可视化数学公式弹窗
type FormulaTarget =
  | { field: "stem" }
  | { field: "essayAnswer" }
  | { field: "stemTpl" }
  | { field: "ansExpr" }
  | { field: "analysis" }
  | { field: "option"; index: number };

const stemInputRef = ref<any>(null);
const essayAnswerInputRef = ref<any>(null);
const stemTplInputRef = ref<any>(null);
const ansExprInputRef = ref<any>(null);
const analysisInputRef = ref<any>(null);
const optionInputRefs = ref<any[]>([]);
const formulaDialogVisible = ref(false);
const formulaInitialLatex = ref("");
const formulaTarget = ref<FormulaTarget>({ field: "stem" });
const formulaSelection = ref<{ start: number; end: number }>({ start: 0, end: 0 });
const formulaTargetLabel = ref("题目内容");

function getTargetNativeEl(target: FormulaTarget): HTMLInputElement | HTMLTextAreaElement | null {
  let comp: any = null;
  if (target.field === "stem") comp = stemInputRef.value;
  else if (target.field === "essayAnswer") comp = essayAnswerInputRef.value;
  else if (target.field === "stemTpl") comp = stemTplInputRef.value;
  else if (target.field === "ansExpr") comp = ansExprInputRef.value;
  else if (target.field === "analysis") comp = analysisInputRef.value;
  else comp = optionInputRefs.value[target.index];
  return comp?.textarea || comp?.input || null;
}

function getTargetText(target: FormulaTarget): string {
  if (target.field === "stem") return form.stem;
  if (target.field === "essayAnswer") return form.essayAnswerText;
  if (target.field === "stemTpl") return paramRule.stemTpl;
  if (target.field === "ansExpr") return paramRule.ansExpr;
  if (target.field === "analysis") return form.analysis;
  return form.options[target.index] || "";
}

function setTargetText(target: FormulaTarget, val: string) {
  if (target.field === "stem") form.stem = val;
  else if (target.field === "essayAnswer") form.essayAnswerText = val;
  else if (target.field === "stemTpl") paramRule.stemTpl = val;
  else if (target.field === "ansExpr") paramRule.ansExpr = val;
  else if (target.field === "analysis") form.analysis = val;
  else form.options[target.index] = val;
}

function openFormulaDialog(
  field: "stem" | "essayAnswer" | "stemTpl" | "ansExpr" | "analysis" | "option",
  index = 0
) {
  const target: FormulaTarget = field === "option" ? { field: "option", index } : { field };
  formulaTarget.value = target;
  const labelMap: Record<string, string> = {
    stem: "题目内容",
    essayAnswer: "解答题参考答案",
    stemTpl: "随机题干模板",
    ansExpr: "答案表达式",
    analysis: "解题思路",
    option: `选项 ${"ABCD"[index]}`
  };
  formulaTargetLabel.value = labelMap[field] || "公式";

  const currentVal = getTargetText(target);
  const el = getTargetNativeEl(target);
  const start = el && typeof el.selectionStart === "number" ? el.selectionStart : currentVal.length;
  const end = el && typeof el.selectionEnd === "number" ? el.selectionEnd : currentVal.length;
  formulaSelection.value = { start, end };

  const selectedText = currentVal.slice(start, end).trim();
  const matchedDollar = selectedText.match(/^\$\$?([\s\S]+?)\$\$?$/);
  formulaInitialLatex.value = matchedDollar ? matchedDollar[1].trim() : "";
  formulaDialogVisible.value = true;
}

function handleFormulaInsert(formatted: string) {
  const target = formulaTarget.value;
  const current = getTargetText(target);
  const { start, end } = formulaSelection.value;
  const before = current.slice(0, start);
  const after = current.slice(end);
  setTargetText(target, `${before}${formatted}${after}`);
}

async function loadRealms() {
  const res = await getRealms();
  realms.value = res.data;
}

async function onFilterRealmChange() {
  query.chapterId = undefined;
  query.gateId = undefined;
  filterGates.value = [];
  if (query.realmCode) {
    const res = await getChapters({ realmCode: query.realmCode });
    filterChapters.value = res.data;
  } else {
    filterChapters.value = [];
  }
  handleSearch();
}

async function onFilterChapterChange() {
  query.gateId = undefined;
  if (query.chapterId) {
    const res = await getGatesByChapter(query.chapterId);
    filterGates.value = res.data;
  } else {
    filterGates.value = [];
  }
  handleSearch();
}

async function fetchQuestions() {
  loading.value = true;
  try {
    const res = await getQuestionPage(query);
    tableData.value = res.data.records;
    total.value = res.data.total;
  } finally {
    loading.value = false;
  }
}

function handleSearch() {
  query.pageNum = 1;
  fetchQuestions();
}

function handleReset() {
  query.realmCode = "";
  query.chapterId = undefined;
  query.gateId = undefined;
  query.questionMode = "";
  query.questionFormat = "";
  query.keyword = "";
  filterChapters.value = [];
  filterGates.value = [];
  handleSearch();
}

async function onEditGradeChange(code: string) {
  const res = await getChapters({ gradeCode: code });
  editChapters.value = res.data;
  form.chapterId = editChapters.value[0]?.id;
  if (form.chapterId) {
    await onEditChapterChange(form.chapterId);
  } else {
    editGates.value = [];
    form.gateId = undefined;
  }
}

async function onEditChapterChange(chapId: number) {
  const res = await getGatesByChapter(chapId);
  editGates.value = res.data;
  form.gateId = editGates.value[0]?.id;
}

function resetDynamicDraft(presetStem = "") {
  dynamicEngineType.value = "PARAM_TEMPLATE";
  paramVars.value = [
    { name: "a", min: 2, max: 6 },
    { name: "b", min: 1, max: 8 }
  ];
  paramRule.stemTpl = presetStem || "已知 $x = {{a}}$，$y = {{b}}$，求 $2x + y$ 的值。";
  paramRule.ansExpr = form.questionFormat === "ESSAY" ? "解：$2x + y = 2×{{a}} + {{b}} = {{2*a+b}}$" : "2*a + b";
  paramRule.wrongExprs = ["a + b", "2*a - b", "a + 2*b"];
  jsSource.value = "";
  drawerPreviewSamples.value = [];
}

function applyTemplatePreset(kind: "linear" | "fraction" | "essay_equation") {
  form.questionMode = "DYNAMIC_TEMPLATE";
  dynamicEngineType.value = "PARAM_TEMPLATE";
  if (kind === "linear") {
    form.questionFormat = "SINGLE_CHOICE";
    paramVars.value = [
      { name: "a", min: 2, max: 6 },
      { name: "x", min: 1, max: 9 },
      { name: "b", min: 1, max: 9 }
    ];
    paramRule.stemTpl = "解一元一次方程：${{a}}x + {{b}} = {{a*x + b}}$，则 $x =$";
    paramRule.ansExpr = "x";
    paramRule.wrongExprs = ["x + 1", "x - 1", "-x"];
    form.analysis = "移项得 ${{a}}x = {{a*x}}$，两边同除以 {{a}} 得 $x = {{x}}$。";
  } else if (kind === "fraction") {
    form.questionFormat = "SINGLE_CHOICE";
    paramVars.value = [
      { name: "a", min: 1, max: 7 },
      { name: "b", min: 2, max: 9 }
    ];
    paramRule.stemTpl = "计算：$\\frac{ {{a}} }{ {{b}} } + \\frac{1}{ {{b}} } =$";
    paramRule.ansExpr = "frac(a + 1, b)";
    paramRule.wrongExprs = ["frac(a, b)", "frac(a + 2, b)", "a + 1"];
    form.analysis = "同分母分数相加，分母 {{b}} 不变，分子相加得 {{a + 1}}，结果约分即可。";
  } else {
    form.questionFormat = "ESSAY";
    paramVars.value = [
      { name: "k", min: 2, max: 5 },
      { name: "x", min: 2, max: 8 },
      { name: "c", min: 1, max: 9 }
    ];
    paramRule.stemTpl = "解方程并写出步骤：${{k}}x - {{c}} = {{k*x - c}}$";
    paramRule.ansExpr = "解：移项得 ${{k}}x = {{k*x}}$，系数化为 1 得 $x = {{x}}$";
    paramRule.wrongExprs = ["", "", ""];
    form.analysis = "先把常数项 -{{c}} 移到等号右边，再两边同除以 {{k}}。";
  }
  void runDrawerPreview();
}

function addVarRow() {
  const existing = new Set(paramVars.value.map(v => v.name));
  const candidates = ["a", "b", "c", "d", "k", "m", "n", "x", "y"];
  const nextName = candidates.find(c => !existing.has(c)) || `v${paramVars.value.length + 1}`;
  paramVars.value.push({ name: nextName, min: 1, max: 10 });
}

function removeVarRow(idx: number) {
  if (paramVars.value.length <= 1) {
    ElMessage.warning("至少保留 1 个随机变量");
    return;
  }
  paramVars.value.splice(idx, 1);
}

function insertVarToken(name: string) {
  const clean = name.trim();
  if (!clean) return;
  paramRule.stemTpl = `${paramRule.stemTpl}{{${clean}}}`;
}

function onQuestionModeChange(mode: "STATIC" | "DYNAMIC_TEMPLATE") {
  drawerPreviewSamples.value = [];
  if (mode === "DYNAMIC_TEMPLATE") {
    if (!paramRule.stemTpl.trim() && !jsSource.value.trim()) {
      resetDynamicDraft(form.stem.trim());
    }
  } else if (!form.stem.trim() && paramRule.stemTpl.trim()) {
    form.stem = paramRule.stemTpl.trim();
  }
}

function switchJsToParamTemplate() {
  dynamicEngineType.value = "PARAM_TEMPLATE";
  resetDynamicDraft(form.stem.trim());
}

function buildTemplateRulePayload(): Record<string, any> | null {
  if (form.questionMode !== "DYNAMIC_TEMPLATE") return null;
  if (dynamicEngineType.value === "PROTOTYPE_JS_EXPR") {
    return {
      type: "PROTOTYPE_JS_EXPR",
      source: jsSource.value.trim(),
      sampleStem: form.stem.trim()
    };
  }
  const varsObj: Record<string, number[]> = {};
  for (const v of paramVars.value) {
    const key = v.name.trim();
    if (!key) continue;
    if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(key)) {
      throw new Error(`变量名「${key}」需以字母开头且仅含字母数字下划线`);
    }
    const lo = Number(v.min);
    const hi = Number(v.max);
    varsObj[key] = [Math.min(lo, hi), Math.max(lo, hi)];
  }
  if (Object.keys(varsObj).length === 0) {
    throw new Error("请至少配置 1 个有效的随机变量");
  }
  if (!paramRule.stemTpl.trim()) {
    throw new Error("请填写随机题干模板");
  }
  if (form.questionFormat !== "ESSAY" && !paramRule.ansExpr.trim()) {
    throw new Error("请填写正确答案计算表达式");
  }
  return {
    type: "PARAM_TEMPLATE",
    vars: varsObj,
    stemTpl: paramRule.stemTpl.trim(),
    ansExpr: paramRule.ansExpr.trim(),
    wrongExprs:
      form.questionFormat === "ESSAY"
        ? []
        : paramRule.wrongExprs.map(s => s.trim()).filter(Boolean)
  };
}

async function runDrawerPreview() {
  let rule: Record<string, any> | null = null;
  try {
    rule = buildTemplateRulePayload();
  } catch (err: any) {
    ElMessage.warning(err?.message || "请先完善随机变数模板");
    return;
  }
  drawerPreviewLoading.value = true;
  try {
    const res = await previewGenerateQuestion({
      questionMode: "DYNAMIC_TEMPLATE",
      questionFormat: form.questionFormat,
      stem: paramRule.stemTpl.trim() || form.stem.trim(),
      analysis: form.analysis,
      templateRule: rule,
      count: 3
    });
    drawerPreviewSamples.value = res.data;
  } finally {
    drawerPreviewLoading.value = false;
  }
}

async function openCreate() {
  editId.value = null;
  const matched = realms.value.find(r => r.realmCode === query.realmCode);
  form.gradeCode = matched?.gradeCode || realms.value[0]?.gradeCode || "g7";
  await onEditGradeChange(form.gradeCode);
  if (query.chapterId) {
    form.chapterId = query.chapterId;
    await onEditChapterChange(query.chapterId);
  }
  if (query.gateId) {
    form.gateId = query.gateId;
  }
  form.questionMode = "STATIC";
  form.questionFormat = "SINGLE_CHOICE";
  form.stem = "";
  form.options = ["", "", "", ""];
  form.answerIndex = 0;
  form.essayAnswerText = "";
  form.analysis = "";
  form.enabled = 1;
  form.syncGateCount = true;
  resetDynamicDraft("");
  editorVisible.value = true;
}

async function openEdit(row: QuestionItem) {
  editId.value = row.id;
  form.gradeCode = row.gradeCode;
  const chRes = await getChapters({ gradeCode: row.gradeCode });
  editChapters.value = chRes.data;
  form.chapterId = row.chapterId;
  const gtRes = await getGatesByChapter(row.chapterId);
  editGates.value = gtRes.data;
  form.gateId = row.gateId;

  form.questionMode = row.questionMode;
  form.questionFormat = row.questionFormat === "ESSAY" ? "ESSAY" : "SINGLE_CHOICE";
  form.stem = row.stem || "";
  form.options = row.options?.length ? [...row.options] : ["", "", "", ""];
  while (form.options.length < 4) form.options.push("");
  form.answerIndex = Number(row.answer?.index ?? 0);
  form.essayAnswerText = String(row.answer?.text ?? "");
  form.analysis = row.analysis || "";
  form.enabled = row.enabled;
  form.syncGateCount = true;
  drawerPreviewSamples.value = [];

  const rule = row.templateRule;
  if (rule && rule.type === "PROTOTYPE_JS_EXPR") {
    dynamicEngineType.value = "PROTOTYPE_JS_EXPR";
    jsSource.value = rule.source || "";
    paramVars.value = [{ name: "a", min: 2, max: 9 }];
    paramRule.stemTpl = row.stem || "";
    paramRule.ansExpr = "";
    paramRule.wrongExprs = ["", "", ""];
  } else if (rule && rule.type === "PARAM_TEMPLATE") {
    dynamicEngineType.value = "PARAM_TEMPLATE";
    jsSource.value = "";
    const varsObj = rule.vars && typeof rule.vars === "object" ? rule.vars : {};
    const parsedVars: VarEntry[] = Object.entries(varsObj).map(([k, val]) => {
      if (Array.isArray(val) && val.length >= 2) {
        return { name: k, min: Number(val[0]), max: Number(val[1]) };
      }
      return { name: k, min: Number(val) || 1, max: Number(val) || 10 };
    });
    paramVars.value = parsedVars.length ? parsedVars : [{ name: "a", min: 1, max: 9 }];
    paramRule.stemTpl = rule.stemTpl || row.stem || "";
    paramRule.ansExpr = rule.ansExpr || "";
    const wrongs = Array.isArray(rule.wrongExprs) ? [...rule.wrongExprs] : [];
    while (wrongs.length < 3) wrongs.push("");
    paramRule.wrongExprs = wrongs.slice(0, 3);
  } else {
    resetDynamicDraft(row.stem || "");
  }
  editorVisible.value = true;
}

async function handleSave() {
  if (!form.chapterId || !form.gateId) {
    ElMessage.warning("请选择所属章节与关卡");
    return;
  }

  let templateRulePayload: Record<string, any> | null = null;
  if (form.questionMode === "DYNAMIC_TEMPLATE") {
    try {
      templateRulePayload = buildTemplateRulePayload();
    } catch (err: any) {
      ElMessage.warning(err?.message || "随机变数配置有误");
      return;
    }
  } else {
    if (!form.stem.trim()) {
      ElMessage.warning("请填写题干内容");
      return;
    }
    if (form.questionFormat === "SINGLE_CHOICE" && form.options.some(o => !o.trim())) {
      ElMessage.warning("请填写完整的四个选项内容");
      return;
    }
  }

  const isEssay = form.questionFormat === "ESSAY";
  const payload = {
    gradeCode: form.gradeCode,
    chapterId: form.chapterId,
    gateId: form.gateId,
    questionMode: form.questionMode,
    questionFormat: form.questionFormat,
    stem:
      form.questionMode === "DYNAMIC_TEMPLATE"
        ? (paramRule.stemTpl.trim() || form.stem.trim())
        : form.stem.trim(),
    options: isEssay ? [] : form.options.map(o => o.trim()),
    answer: isEssay ? { text: form.essayAnswerText.trim() } : { index: form.answerIndex },
    analysis: form.analysis.trim(),
    templateRule: templateRulePayload,
    enabled: form.enabled,
    syncGateCount: form.syncGateCount
  };

  editorSaving.value = true;
  try {
    if (editId.value) {
      await updateQuestion(editId.value, payload);
      ElMessage.success("题目已保存");
    } else {
      await createQuestion(payload);
      ElMessage.success("新增题目成功，已同步确保该关可抽到新题");
    }
    editorVisible.value = false;
    fetchQuestions();
  } finally {
    editorSaving.value = false;
  }
}

async function handleToggleStatus(row: QuestionItem) {
  const next = row.enabled === 1 ? 0 : 1;
  await toggleQuestionStatus(row.id, next);
  row.enabled = next;
  ElMessage.success(next === 1 ? "已启用" : "已停用");
}

async function handleDelete(row: QuestionItem) {
  await ElMessageBox.confirm(`确认删除题目「${row.stem.slice(0, 24)}...」？`, "确认删除", {
    type: "warning"
  });
  await deleteQuestion(row.id);
  ElMessage.success("已删除");
  fetchQuestions();
}

async function handlePreviewRow(row: QuestionItem) {
  previewVisible.value = true;
  previewLoading.value = true;
  try {
    const res = await previewGenerateQuestion({ questionId: row.id, count: 3 });
    previewSamples.value = res.data;
  } finally {
    previewLoading.value = false;
  }
}

onMounted(async () => {
  await loadRealms();
  await fetchQuestions();
});
</script>

<template>
  <div class="space-y-4">
    <el-card shadow="never">
      <el-form :inline="true" :model="query" class="flex flex-wrap items-center gap-y-2">
        <el-form-item label="境界">
          <el-select
            v-model="query.realmCode"
            placeholder="全部境界"
            clearable
            style="width: 136px"
            @change="onFilterRealmChange"
          >
            <el-option
              v-for="r in realms"
              :key="r.realmCode"
              :label="r.realmName"
              :value="r.realmCode"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="章节">
          <el-select
            v-model="query.chapterId"
            placeholder="先选境界"
            clearable
            style="width: 190px"
            @change="onFilterChapterChange"
          >
            <el-option v-for="c in filterChapters" :key="c.id" :label="c.name" :value="c.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="关卡">
          <el-select
            v-model="query.gateId"
            placeholder="全部关卡"
            clearable
            style="width: 120px"
            @change="handleSearch"
          >
            <el-option v-for="gt in filterGates" :key="gt.id" :label="gt.gateName" :value="gt.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="出题方式">
          <el-select v-model="query.questionMode" placeholder="全部" clearable style="width: 150px" @change="handleSearch">
            <el-option label="固定题目" value="STATIC" />
            <el-option label="随机变数题" value="DYNAMIC_TEMPLATE" />
          </el-select>
        </el-form-item>
        <el-form-item label="题型">
          <el-select v-model="query.questionFormat" placeholder="全部" clearable style="width: 120px" @change="handleSearch">
            <el-option label="选择题" value="SINGLE_CHOICE" />
            <el-option label="解答题" value="ESSAY" />
          </el-select>
        </el-form-item>
        <el-form-item label="题干">
          <el-input
            v-model="query.keyword"
            placeholder="输入题干关键词"
            clearable
            style="width: 175px"
            @keyup.enter="handleSearch"
          />
        </el-form-item>
        <el-form-item>
          <div class="flex items-center gap-2 whitespace-nowrap">
            <el-button type="primary" @click="handleSearch">查询</el-button>
            <el-button @click="handleReset">重置</el-button>
            <el-button type="success" @click="openCreate">+ 新增题目</el-button>
          </div>
        </el-form-item>
      </el-form>
    </el-card>

    <el-card shadow="never">
      <el-table v-loading="loading" :data="tableData" border stripe>
        <el-table-column prop="id" label="ID" width="64" align="center" />
        <el-table-column label="所属境界与章节" width="200">
          <template #default="{ row }">
            <div class="truncate text-xs font-bold text-green-700">
              {{ row.realmName || row.gradeName }} · {{ row.gateName }}
            </div>
            <div class="truncate text-xs text-gray-500">{{ row.chapterName }}</div>
          </template>
        </el-table-column>
        <el-table-column label="方式与题型" width="168" align="center">
          <template #default="{ row }">
            <div class="inline-flex items-center gap-1 whitespace-nowrap">
              <el-tag
                size="small"
                class="whitespace-nowrap"
                :type="row.questionMode === 'DYNAMIC_TEMPLATE' ? 'warning' : 'success'"
              >
                {{ row.questionMode === "DYNAMIC_TEMPLATE" ? "随机变数" : "固定题目" }}
              </el-tag>
              <el-tag
                size="small"
                class="whitespace-nowrap"
                :type="row.questionFormat === 'ESSAY' ? 'primary' : 'info'"
              >
                {{ row.questionFormat === "ESSAY" ? "解答题" : "选择题" }}
              </el-tag>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="题干与选项 / 参考答案" min-width="320">
          <template #default="{ row }">
            <div class="font-medium text-gray-800">
              <MathFormulaText :text="row.stem" />
            </div>
            <div v-if="row.questionFormat === 'ESSAY'" class="mt-1.5 text-xs text-green-700">
              参考答案：<MathFormulaText :text="row.answer?.text || '（自由手写作答，老师可点评）'" inline />
            </div>
            <div v-else-if="row.options?.length" class="mt-1.5 flex flex-wrap gap-1.5 text-xs">
              <span
                v-for="(op, idx) in row.options"
                :key="idx"
                class="inline-flex max-w-full items-baseline gap-1 rounded px-2 py-0.5"
                :class="
                  row.answer?.index === idx
                    ? 'bg-green-100 font-bold text-green-800'
                    : 'bg-gray-100 text-gray-600'
                "
              >
                <span class="shrink-0">{{ "ABCD"[idx] }}.</span>
                <MathFormulaText :text="op" inline />
              </span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="启用" width="84" align="center">
          <template #default="{ row }">
            <el-switch
              :model-value="row.enabled === 1"
              size="small"
              @change="handleToggleStatus(row)"
            />
          </template>
        </el-table-column>
        <el-table-column label="操作" width="220" align="center">
          <template #default="{ row }">
            <div class="inline-flex items-center justify-center whitespace-nowrap">
              <el-button
                v-if="row.questionMode === 'DYNAMIC_TEMPLATE'"
                link
                type="warning"
                @click="handlePreviewRow(row)"
              >
                预览出题
              </el-button>
              <el-button link type="primary" @click="openEdit(row)">编辑</el-button>
              <el-button link type="danger" @click="handleDelete(row)">删除</el-button>
            </div>
          </template>
        </el-table-column>
      </el-table>

      <div class="mt-4 flex justify-end">
        <el-pagination
          v-model:current-page="query.pageNum"
          v-model:page-size="query.pageSize"
          :total="total"
          :page-sizes="[10, 20, 50]"
          layout="total, sizes, prev, pager, next"
          @current-change="fetchQuestions"
          @size-change="fetchQuestions"
        />
      </div>
    </el-card>

    <!-- 题目编辑抽屉（支持选择题/解答题 + 固定/随机变数互转） -->
    <el-drawer v-model="editorVisible" :title="editId ? '编辑题目' : '新增题目'" size="960px">
      <div class="grid grid-cols-1 gap-6 lg:grid-cols-12">
        <div class="space-y-4 lg:col-span-7">
          <el-form label-width="92px">
            <el-form-item label="所属境界" required>
              <el-select v-model="form.gradeCode" class="w-full" @change="onEditGradeChange">
                <el-option
                  v-for="r in realms"
                  :key="r.gradeCode"
                  :label="`${r.realmName}（${r.difficultyLabel}）`"
                  :value="r.gradeCode"
                />
              </el-select>
            </el-form-item>
            <el-form-item label="所属章节" required>
              <el-select v-model="form.chapterId" class="w-full" @change="onEditChapterChange">
                <el-option v-for="c in editChapters" :key="c.id" :label="c.name" :value="c.id" />
              </el-select>
            </el-form-item>
            <el-form-item label="所属关卡" required>
              <div class="w-full space-y-1.5">
                <el-select v-model="form.gateId" class="w-full">
                  <el-option v-for="gt in editGates" :key="gt.id" :label="gt.gateName" :value="gt.id" />
                </el-select>
                <div v-if="selectedEditGate" class="flex flex-wrap items-center justify-between gap-2 text-xs text-gray-500">
                  <span>
                    当前每轮抽 <b class="text-green-700">{{ selectedEditGate.questionCount }}</b> 题 ·
                    过关需对 {{ selectedEditGate.passCount }} 题 · 库中共 {{ selectedEditGate.actualQuestionCount }} 题
                  </span>
                  <el-checkbox v-model="form.syncGateCount" size="small">
                    自动扩充抽题数以包含新题
                  </el-checkbox>
                </div>
              </div>
            </el-form-item>

            <el-form-item label="题型格式" required>
              <el-radio-group v-model="form.questionFormat" @change="drawerPreviewSamples = []">
                <el-radio-button value="SINGLE_CHOICE">选择题</el-radio-button>
                <el-radio-button value="ESSAY">解答题（学生画板手写作答）</el-radio-button>
              </el-radio-group>
            </el-form-item>

            <el-form-item label="出题方式" required>
              <el-radio-group v-model="form.questionMode" @change="onQuestionModeChange">
                <el-radio-button value="STATIC">固定题目</el-radio-button>
                <el-radio-button value="DYNAMIC_TEMPLATE">随机变数题（每次做题换数字）</el-radio-button>
              </el-radio-group>
            </el-form-item>

            <!-- 固定题目表单 -->
            <template v-if="form.questionMode === 'STATIC'">
              <el-form-item label="题目内容" required>
                <div class="w-full space-y-1.5">
                  <el-input
                    ref="stemInputRef"
                    v-model="form.stem"
                    type="textarea"
                    :rows="3"
                    placeholder="请输入题目题干，需要分数/根号可点击下方插入公式"
                  />
                  <div class="flex flex-wrap items-center justify-between gap-2">
                    <el-button size="small" type="success" plain @click="openFormulaDialog('stem')">
                      + 插入可视化公式
                    </el-button>
                    <span class="whitespace-nowrap text-xs text-gray-400">支持普通文字与数学公式混排</span>
                  </div>
                </div>
              </el-form-item>

              <template v-if="form.questionFormat === 'SINGLE_CHOICE'">
                <el-form-item label="四个选项" required>
                  <div class="w-full space-y-2">
                    <div v-for="(_, idx) in form.options" :key="idx" class="flex items-center gap-2">
                      <span class="w-6 shrink-0 font-bold text-green-700">{{ "ABCD"[idx] }}.</span>
                      <el-input
                        :ref="el => { if (el) optionInputRefs[idx] = el; }"
                        v-model="form.options[idx]"
                        :placeholder="`请输入选项 ${'ABCD'[idx]}`"
                      />
                      <el-button
                        size="small"
                        plain
                        class="shrink-0"
                        title="插入数学公式"
                        @click="openFormulaDialog('option', idx)"
                      >
                        公式
                      </el-button>
                    </div>
                  </div>
                </el-form-item>

                <el-form-item label="正确答案" required>
                  <el-radio-group v-model="form.answerIndex">
                    <el-radio v-for="idx in [0, 1, 2, 3]" :key="idx" :value="idx">
                      {{ "ABCD"[idx] }}
                    </el-radio>
                  </el-radio-group>
                </el-form-item>
              </template>

              <el-form-item v-else label="参考答案">
                <div class="w-full space-y-1.5">
                  <el-input
                    ref="essayAnswerInputRef"
                    v-model="form.essayAnswerText"
                    type="textarea"
                    :rows="3"
                    placeholder="请输入解答题参考步骤与标准答案（学生交卷或保存画板后可对照核对）"
                  />
                  <el-button size="small" plain @click="openFormulaDialog('essayAnswer')">
                    + 插入答案公式
                  </el-button>
                </div>
              </el-form-item>
            </template>

            <!-- 随机变数题编辑器 -->
            <template v-else>
              <div class="mb-3 rounded-lg border border-amber-200 bg-amber-50 p-3">
                <div class="flex flex-wrap items-center justify-between gap-2">
                  <span v-if="dynamicEngineType === 'PARAM_TEMPLATE'" class="text-xs font-bold text-amber-800">
                    可视化随机变数配置（用 &#123;&#123;变量名&#125;&#125; 或 &#123;&#123;表达式&#125;&#125; 插入动态数字）
                  </span>
                  <span v-else class="text-xs font-bold text-amber-800">
                    内置 JS 生成器模式（可修改脚本或一键转为可视化变量配置）
                  </span>
                  <div class="flex flex-wrap items-center gap-1.5">
                    <el-button size="small" plain @click="applyTemplatePreset('linear')">示例: 方程选择题</el-button>
                    <el-button size="small" plain @click="applyTemplatePreset('fraction')">示例: 分数题</el-button>
                    <el-button size="small" plain @click="applyTemplatePreset('essay_equation')">示例: 随机解答题</el-button>
                    <el-button
                      v-if="dynamicEngineType === 'PROTOTYPE_JS_EXPR'"
                      size="small"
                      type="warning"
                      plain
                      @click="switchJsToParamTemplate"
                    >
                      转为可视化变量配置
                    </el-button>
                  </div>
                </div>
              </div>

              <template v-if="dynamicEngineType === 'PARAM_TEMPLATE'">
                <el-form-item label="随机变量" required>
                  <div class="w-full space-y-2">
                    <div v-for="(v, idx) in paramVars" :key="idx" class="flex flex-wrap items-center gap-2">
                      <el-input v-model="v.name" placeholder="变量名 如 a" style="width: 96px" />
                      <span class="text-xs text-gray-500">范围</span>
                      <el-input-number v-model="v.min" :step="1" controls-position="right" style="width: 96px" />
                      <span class="text-xs text-gray-500">~</span>
                      <el-input-number v-model="v.max" :step="1" controls-position="right" style="width: 96px" />
                      <el-button size="small" plain @click="insertVarToken(v.name)">
                        插 &#123;&#123;{{ v.name || "a" }}&#125;&#125;
                      </el-button>
                      <el-button link type="danger" size="small" @click="removeVarRow(idx)">删</el-button>
                    </div>
                    <el-button size="small" type="primary" plain @click="addVarRow">+ 添加变量</el-button>
                  </div>
                </el-form-item>

                <el-form-item label="题干模板" required>
                  <div class="w-full space-y-1.5">
                    <el-input
                      ref="stemTplInputRef"
                      v-model="paramRule.stemTpl"
                      type="textarea"
                      :rows="3"
                      placeholder="例：解方程 ${{a}}x + {{b}} = {{a*x+b}}$"
                    />
                    <div class="flex flex-wrap items-center justify-between gap-2">
                      <el-button size="small" type="success" plain @click="openFormulaDialog('stemTpl')">
                        + 插入可视化公式
                      </el-button>
                      <span class="text-xs text-gray-400">支持 + - * / % ^ 与 abs/sqrt/frac(n,d)</span>
                    </div>
                  </div>
                </el-form-item>

                <el-form-item :label="form.questionFormat === 'ESSAY' ? '答案模板' : '答案公式'" :required="form.questionFormat !== 'ESSAY'">
                  <div class="w-full space-y-1.5">
                    <el-input
                      ref="ansExprInputRef"
                      v-model="paramRule.ansExpr"
                      :type="form.questionFormat === 'ESSAY' ? 'textarea' : 'text'"
                      :rows="2"
                      :placeholder="
                        form.questionFormat === 'ESSAY'
                          ? '例：解：移项得 ${{a}}x = {{a*x}}$，解得 $x = {{x}}$'
                          : '填正确答案计算表达式，如 a + b、2*x 或 frac(a, b)'
                      "
                    />
                    <el-button size="small" plain @click="openFormulaDialog('ansExpr')">
                      + 插入答案公式
                    </el-button>
                  </div>
                </el-form-item>

                <el-form-item v-if="form.questionFormat === 'SINGLE_CHOICE'" label="干扰项规则">
                  <div class="w-full space-y-2">
                    <div v-for="(_, idx) in paramRule.wrongExprs" :key="idx" class="flex items-center gap-2">
                      <span class="w-12 shrink-0 text-xs text-gray-500">错项 {{ idx + 1 }}</span>
                      <el-input
                        v-model="paramRule.wrongExprs[idx]"
                        placeholder="选填公式如 a - b（留空自动生成不同干扰项）"
                      />
                    </div>
                  </div>
                </el-form-item>
              </template>

              <template v-else>
                <el-form-item label="生成器脚本" required>
                  <div class="w-full space-y-1.5">
                    <el-input
                      v-model="jsSource"
                      type="textarea"
                      :rows="6"
                      placeholder="()=>mkg('若 |x|='+k, ...)"
                    />
                    <div class="text-xs text-gray-500">
                      内置助手：<code>R(min, max)</code> 随机整数、<code>mkg(题干, 正答, [错1,错2,错3])</code>、<code>frac(n, d)</code> 约分分数
                    </div>
                  </div>
                </el-form-item>
              </template>
            </template>

            <el-form-item label="解题思路">
              <div class="w-full space-y-1.5">
                <el-input
                  ref="analysisInputRef"
                  v-model="form.analysis"
                  type="textarea"
                  :rows="2"
                  placeholder="可选填：答完后展示给学生的解析（随机题同样支持 {{变量}} 插值）"
                />
                <el-button size="small" plain @click="openFormulaDialog('analysis')">
                  + 插入解析公式
                </el-button>
              </div>
            </el-form-item>

            <el-form-item label="是否启用">
              <el-switch v-model="form.enabled" :active-value="1" :inactive-value="0" />
            </el-form-item>
          </el-form>
        </div>

        <!-- 右侧实时预览区 -->
        <div class="lg:col-span-5">
          <div class="rounded-xl border border-gray-200 bg-gray-50 p-4">
            <div class="mb-3 flex items-center justify-between gap-2">
              <span class="text-xs font-bold text-gray-600">
                {{ form.questionMode === "DYNAMIC_TEMPLATE" ? "随机出题试生成预览" : "学生端显示预览（含公式排版）" }}
              </span>
              <el-button
                v-if="form.questionMode === 'DYNAMIC_TEMPLATE'"
                size="small"
                type="warning"
                :loading="drawerPreviewLoading"
                @click="runDrawerPreview"
              >
                试生成 3 题
              </el-button>
            </div>

            <template v-if="form.questionMode === 'STATIC'">
              <div class="rounded-lg bg-white p-4 shadow-sm">
                <div class="mb-2">
                  <el-tag size="small" :type="form.questionFormat === 'ESSAY' ? 'primary' : 'info'">
                    {{ form.questionFormat === "ESSAY" ? "解答题" : "选择题" }}
                  </el-tag>
                </div>
                <div class="text-sm font-semibold leading-relaxed text-gray-800">
                  <MathFormulaText :text="form.stem || '请输入题目内容...'" />
                </div>
                <div v-if="form.questionFormat === 'SINGLE_CHOICE'" class="mt-3 space-y-2">
                  <div
                    v-for="(op, idx) in form.options"
                    :key="idx"
                    class="flex items-baseline gap-1.5 rounded border px-3 py-2 text-xs"
                    :class="form.answerIndex === idx ? 'border-green-600 bg-green-50 font-semibold text-green-800' : 'border-gray-200 text-gray-700'"
                  >
                    <span class="shrink-0">{{ "ABCD"[idx] }}.</span>
                    <MathFormulaText :text="op || `选项 ${'ABCD'[idx]}`" inline class="min-w-0 flex-1" />
                  </div>
                </div>
                <div v-else class="mt-3 space-y-2">
                  <div class="rounded border border-dashed border-gray-300 bg-gray-50 p-4 text-center text-xs text-gray-400">
                    学生端此处展示「题目绘制面板」手写作答并上传阿里云 OSS
                  </div>
                  <div v-if="form.essayAnswerText" class="rounded bg-green-50 p-2 text-xs text-green-800">
                    参考答案：<MathFormulaText :text="form.essayAnswerText" inline />
                  </div>
                </div>
                <div v-if="form.analysis" class="mt-3 rounded bg-gray-50 p-2 text-xs text-gray-600">
                  解析：<MathFormulaText :text="form.analysis" inline />
                </div>
              </div>
            </template>

            <template v-else>
              <div v-if="drawerPreviewSamples.length" class="space-y-3">
                <div v-for="(s, idx) in drawerPreviewSamples" :key="idx" class="rounded-lg bg-white p-3.5 shadow-sm">
                  <div class="text-xs font-bold text-gray-500">示例 {{ idx + 1 }}</div>
                  <div class="mt-1 text-sm font-semibold text-gray-800">
                    <MathFormulaText :text="s.stem" />
                  </div>
                  <div v-if="s.questionFormat === 'ESSAY' || !s.options?.length" class="mt-2 rounded bg-green-50 p-2 text-xs text-green-800">
                    参考答案：<MathFormulaText :text="s.referenceAnswer || '（暂无参考答案）'" inline />
                  </div>
                  <div v-else class="mt-2 grid grid-cols-2 gap-1.5">
                    <div
                      v-for="(op, j) in s.options"
                      :key="j"
                      class="flex items-baseline gap-1 rounded border px-2 py-1 text-xs"
                      :class="s.answerIndex === j ? 'border-green-600 bg-green-50 font-bold text-green-800' : 'border-gray-200'"
                    >
                      <span class="shrink-0">{{ "ABCD"[j] }}.</span>
                      <MathFormulaText :text="op" inline class="min-w-0 flex-1" />
                    </div>
                  </div>
                  <div v-if="s.analysis" class="mt-2 rounded bg-gray-50 p-1.5 text-xs text-gray-500">
                    解析：<MathFormulaText :text="s.analysis" inline />
                  </div>
                </div>
              </div>
              <div v-else class="rounded-lg bg-white p-6 text-center text-xs text-gray-400">
                配置变量与模板后，点击右上角「试生成 3 题」即可预览每次抽取的随机效果。
              </div>
            </template>
          </div>
        </div>
      </div>

      <template #footer>
        <el-button @click="editorVisible = false">取消</el-button>
        <el-button type="primary" :loading="editorSaving" @click="handleSave">保存</el-button>
      </template>
    </el-drawer>

    <MathFormulaDialog
      v-model="formulaDialogVisible"
      :initial-latex="formulaInitialLatex"
      :target-label="formulaTargetLabel"
      @insert="handleFormulaInsert"
    />

    <el-dialog v-model="previewVisible" title="随机出题预览（示例 3 题）" width="640px">
      <div v-loading="previewLoading" class="space-y-3">
        <el-card v-for="(s, idx) in previewSamples" :key="idx" shadow="never">
          <div class="font-bold text-gray-800">
            第 {{ idx + 1 }} 题：<MathFormulaText :text="s.stem" inline />
          </div>
          <div v-if="s.questionFormat === 'ESSAY' || !s.options?.length" class="mt-2 rounded bg-green-50 p-2 text-sm text-green-800">
            参考答案：<MathFormulaText :text="s.referenceAnswer || '（自由作答）'" inline />
          </div>
          <div v-else class="mt-2 grid grid-cols-2 gap-2">
            <div
              v-for="(op, j) in s.options"
              :key="j"
              class="flex items-baseline gap-1.5 rounded border px-2.5 py-1.5 text-sm"
              :class="s.answerIndex === j ? 'border-green-600 bg-green-50 font-bold text-green-800' : 'border-gray-200'"
            >
              <span class="shrink-0">{{ "ABCD"[j] }}.</span>
              <MathFormulaText :text="op" inline class="min-w-0 flex-1" />
            </div>
          </div>
        </el-card>
      </div>
    </el-dialog>
  </div>
</template>
