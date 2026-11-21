<script setup lang="ts">
import { ref, reactive, computed, onMounted } from "vue";
import { useRoute, useRouter } from "vue-router";
import { ElMessage } from "element-plus";
import MathFormulaText from "@/components/MathFormulaText.vue";
import MathFormulaDialog from "@/components/MathFormulaDialog.vue";
import GglIcon from "@/components/GglIcon/index.vue";
import {
  getRealms,
  getChapters,
  getGatesByChapter,
  getQuestionDetail,
  createQuestion,
  updateQuestion,
  previewGenerateQuestion,
  type RealmConfig,
  type ChapterItem,
  type GateItem,
  type QuestionItem,
  type GeneratedSample
} from "@/api/guoguanla";

defineOptions({
  name: "QuestionEditor"
});

interface VarEntry {
  name: string;
  min: number;
  max: number;
}

const route = useRoute();
const router = useRouter();

const loading = ref(false);
const saving = ref(false);
const realms = ref<RealmConfig[]>([]);
const chapters = ref<ChapterItem[]>([]);
const gates = ref<GateItem[]>([]);

const activeTab = ref<"content" | "answer" | "analysis">("content");
const phonePreviewStage = ref<"answering" | "reviewed">("answering");
const activeSampleIndex = ref(0);

const editId = computed(() => {
  const raw = route.query.id;
  const n = Number(raw);
  return raw && Number.isFinite(n) && n > 0 ? n : null;
});

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
const previewLoading = ref(false);
const previewSamples = ref<GeneratedSample[]>([]);

const selectedRealm = computed(
  () => realms.value.find(r => r.gradeCode === form.gradeCode) || null
);
const selectedChapter = computed(
  () => chapters.value.find(c => c.id === form.chapterId) || null
);
const selectedGate = computed(
  () => gates.value.find(g => g.id === form.gateId) || null
);

// 可视化公式输入定位
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
  setTargetText(target, `${current.slice(0, start)}${formatted}${current.slice(end)}`);
}

async function onGradeChange(code: string) {
  const res = await getChapters({ gradeCode: code });
  chapters.value = res.data;
  form.chapterId = chapters.value[0]?.id;
  if (form.chapterId) {
    await onChapterChange(form.chapterId);
  } else {
    gates.value = [];
    form.gateId = undefined;
  }
}

async function onChapterChange(chapId: number) {
  const res = await getGatesByChapter(chapId);
  gates.value = res.data;
  form.gateId = gates.value[0]?.id;
}

function resetDynamicDraft(presetStem = "") {
  dynamicEngineType.value = "PARAM_TEMPLATE";
  paramVars.value = [
    { name: "a", min: 2, max: 6 },
    { name: "b", min: 1, max: 8 }
  ];
  paramRule.stemTpl = presetStem || "已知 $x = {{a}}$，$y = {{b}}$，求 $2x + y$ 的值。";
  paramRule.ansExpr =
    form.questionFormat === "ESSAY" ? "解：$2x + y = 2×{{a}} + {{b}} = {{2*a+b}}$" : "2*a + b";
  paramRule.wrongExprs = ["a + b", "2*a - b", "a + 2*b"];
  jsSource.value = "";
  previewSamples.value = [];
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
  void runDynamicPreview();
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
  previewSamples.value = [];
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

async function runDynamicPreview() {
  let rule: Record<string, any> | null = null;
  try {
    rule = buildTemplateRulePayload();
  } catch (err: any) {
    ElMessage.warning(err?.message || "请先完善随机变数模板");
    return;
  }
  previewLoading.value = true;
  try {
    const res = await previewGenerateQuestion({
      questionMode: "DYNAMIC_TEMPLATE",
      questionFormat: form.questionFormat,
      stem: paramRule.stemTpl.trim() || form.stem.trim(),
      analysis: form.analysis,
      templateRule: rule,
      count: 3
    });
    previewSamples.value = res.data;
    activeSampleIndex.value = 0;
  } finally {
    previewLoading.value = false;
  }
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
      activeTab.value = "content";
      ElMessage.warning("请填写题干内容");
      return;
    }
    if (form.questionFormat === "SINGLE_CHOICE" && form.options.some(o => !o.trim())) {
      activeTab.value = "content";
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

  saving.value = true;
  try {
    if (editId.value) {
      await updateQuestion(editId.value, payload);
      ElMessage.success("题目已更新保存");
    } else {
      await createQuestion(payload);
      ElMessage.success("新增题目成功，已同步确保该关可抽到新题");
    }
    router.push("/bank/question/index");
  } finally {
    saving.value = false;
  }
}

function goBack() {
  router.push("/bank/question/index");
}

function fillFromDetail(row: QuestionItem) {
  form.gradeCode = row.gradeCode;
  form.chapterId = row.chapterId;
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
}

// 手机端预览视图计算（统一兼顾静态题与动态随机样本）
const currentSample = computed<GeneratedSample | null>(() => {
  if (form.questionMode !== "DYNAMIC_TEMPLATE" || previewSamples.value.length === 0) return null;
  return previewSamples.value[activeSampleIndex.value] || previewSamples.value[0];
});

const phoneStem = computed(() => {
  if (form.questionMode === "DYNAMIC_TEMPLATE") {
    return currentSample.value?.stem || paramRule.stemTpl || form.stem || "请配置题干模板后点击「试生成 3 题」";
  }
  return form.stem || "请在左侧输入题目内容...";
});

const phoneOptions = computed(() => {
  if (form.questionFormat === "ESSAY") return [];
  if (form.questionMode === "DYNAMIC_TEMPLATE" && currentSample.value?.options?.length) {
    return currentSample.value.options;
  }
  return form.options;
});

const phoneAnswerIndex = computed(() => {
  if (form.questionMode === "DYNAMIC_TEMPLATE" && currentSample.value) {
    return currentSample.value.answerIndex ?? 0;
  }
  return form.answerIndex;
});

const phoneEssayAnswer = computed(() => {
  if (form.questionMode === "DYNAMIC_TEMPLATE" && currentSample.value) {
    return currentSample.value.referenceAnswer || paramRule.ansExpr || "（暂无参考答案）";
  }
  return form.essayAnswerText || "（暂无参考答案）";
});

const phoneAnalysis = computed(() => {
  if (form.questionMode === "DYNAMIC_TEMPLATE" && currentSample.value) {
    return currentSample.value.analysis || "";
  }
  return form.analysis || "";
});

onMounted(async () => {
  loading.value = true;
  try {
    const realmRes = await getRealms();
    realms.value = realmRes.data;

    if (editId.value) {
      const qRes = await getQuestionDetail(editId.value);
      const q = qRes.data;
      const chRes = await getChapters({ gradeCode: q.gradeCode });
      chapters.value = chRes.data;
      const gtRes = await getGatesByChapter(q.chapterId);
      gates.value = gtRes.data;
      fillFromDetail(q);
      if (q.questionMode === "DYNAMIC_TEMPLATE") {
        void runDynamicPreview();
      }
    } else {
      const qRealm = String(route.query.realmCode || "");
      const matched = realms.value.find(r => r.realmCode === qRealm);
      form.gradeCode = matched?.gradeCode || realms.value[0]?.gradeCode || "g7";
      await onGradeChange(form.gradeCode);

      const qChap = Number(route.query.chapterId || 0);
      if (qChap && chapters.value.some(c => c.id === qChap)) {
        form.chapterId = qChap;
        await onChapterChange(qChap);
      }
      const qGate = Number(route.query.gateId || 0);
      if (qGate && gates.value.some(g => g.id === qGate)) {
        form.gateId = qGate;
      }
      resetDynamicDraft("");
    }
  } finally {
    loading.value = false;
  }
});
</script>

<template>
  <div v-loading="loading" class="flex h-screen flex-col overflow-hidden bg-slate-100">
    <!-- 顶部工作台标题与全局动作栏 -->
    <header class="flex h-14 shrink-0 items-center justify-between border-b border-slate-200 bg-white px-5">
      <div class="flex items-center gap-3">
        <el-button plain @click="goBack">
          <GglIcon name="back" :size="15" class="mr-1" />
          返回题库
        </el-button>
        <div class="h-4 w-px bg-slate-200" />
        <h1 class="text-base font-bold text-slate-800">
          {{ editId ? `编辑题目 #${editId}` : "新增数学题目" }}
        </h1>
        <el-tag size="small" :type="form.questionFormat === 'ESSAY' ? 'primary' : 'success'">
          {{ form.questionFormat === "ESSAY" ? "解答题" : "选择题" }}
        </el-tag>
        <el-tag size="small" :type="form.questionMode === 'DYNAMIC_TEMPLATE' ? 'warning' : 'info'">
          {{ form.questionMode === "DYNAMIC_TEMPLATE" ? "随机变数题" : "固定题目" }}
        </el-tag>
      </div>

      <div class="flex items-center gap-4">
        <label class="flex items-center gap-2 text-xs text-slate-600">
          <span>上架启用</span>
          <el-switch v-model="form.enabled" :active-value="1" :inactive-value="0" size="small" />
        </label>
        <el-checkbox v-model="form.syncGateCount" size="small">
          自动扩充抽题数以包含新题
        </el-checkbox>
        <el-button
          v-if="form.questionMode === 'DYNAMIC_TEMPLATE'"
          type="warning"
          plain
          :loading="previewLoading"
          @click="runDynamicPreview"
        >
          <GglIcon name="spark" :size="15" class="mr-1" />
          试生成 3 题
        </el-button>
        <el-button type="primary" :loading="saving" @click="handleSave">
          <GglIcon name="check-circle" :size="15" class="mr-1" />
          {{ editId ? "保存修改" : "保存并发布题目" }}
        </el-button>
      </div>
    </header>

    <!-- 顶部所有题目配置条（全宽一行展示） -->
    <section class="shrink-0 border-b border-slate-200 bg-white px-5 py-3 shadow-xs">
      <div class="flex flex-wrap items-center gap-x-5 gap-y-2.5">
        <div class="flex items-center gap-2">
          <span class="shrink-0 text-xs font-semibold text-slate-600">所属境界</span>
          <el-select v-model="form.gradeCode" style="width: 175px" @change="onGradeChange">
            <el-option
              v-for="r in realms"
              :key="r.gradeCode"
              :label="`${r.realmName}（${r.difficultyLabel}）`"
              :value="r.gradeCode"
            />
          </el-select>
        </div>

        <div class="flex items-center gap-2">
          <span class="shrink-0 text-xs font-semibold text-slate-600">所属章节</span>
          <el-select v-model="form.chapterId" style="width: 220px" @change="onChapterChange">
            <el-option v-for="c in chapters" :key="c.id" :label="c.name" :value="c.id" />
          </el-select>
        </div>

        <div class="flex items-center gap-2">
          <span class="shrink-0 text-xs font-semibold text-slate-600">所属关卡</span>
          <el-select v-model="form.gateId" style="width: 145px">
            <el-option v-for="gt in gates" :key="gt.id" :label="gt.gateName" :value="gt.id" />
          </el-select>
        </div>

        <div class="flex items-center gap-2">
          <span class="shrink-0 text-xs font-semibold text-slate-600">题型格式</span>
          <el-radio-group v-model="form.questionFormat" size="small" @change="previewSamples = []">
            <el-radio-button value="SINGLE_CHOICE">选择题</el-radio-button>
            <el-radio-button value="ESSAY">解答题（手写画板）</el-radio-button>
          </el-radio-group>
        </div>

        <div class="flex items-center gap-2">
          <span class="shrink-0 text-xs font-semibold text-slate-600">出题方式</span>
          <el-radio-group v-model="form.questionMode" size="small" @change="onQuestionModeChange">
            <el-radio-button value="STATIC">固定题目</el-radio-button>
            <el-radio-button value="DYNAMIC_TEMPLATE">随机变数题</el-radio-button>
          </el-radio-group>
        </div>

        <div v-if="selectedGate" class="ml-auto text-xs text-slate-500">
          该关当前抽 <b class="text-green-700">{{ selectedGate.questionCount }}</b> 题 · 过关对
          {{ selectedGate.passCount }} 题 · 现存 {{ selectedGate.actualQuestionCount }} 题
        </div>
      </div>
    </section>

    <!-- 主工作区：左侧 Tabs（题目内容/参考答案/解题思路） + 右侧学生端手机预览 -->
    <main class="grid min-h-0 flex-1 grid-cols-12 gap-5 overflow-hidden p-5">
      <!-- 左侧 Tabs 编辑面板 -->
      <section class="col-span-7 flex min-h-0 flex-col overflow-hidden rounded-xl border border-slate-200 bg-white shadow-xs">
        <el-tabs v-model="activeTab" class="flex h-full flex-col px-5 pt-2">
          <!-- Tab 1: 题目内容 -->
          <el-tab-pane label="题目内容" name="content" class="h-full overflow-y-auto pb-6 pr-1">
            <div v-if="form.questionMode === 'STATIC'" class="space-y-5 pt-2">
              <div>
                <div class="mb-2 flex items-center justify-between">
                  <span class="text-sm font-semibold text-slate-800">题干内容（支持混排数学公式）</span>
                  <el-button size="small" type="success" plain @click="openFormulaDialog('stem')">
                    + 插入可视化公式
                  </el-button>
                </div>
                <el-input
                  ref="stemInputRef"
                  v-model="form.stem"
                  type="textarea"
                  :rows="5"
                  placeholder="请输入题目题干，需要分数、根号、方程组可点击右上角「+ 插入可视化公式」"
                />
              </div>

              <div v-if="form.questionFormat === 'SINGLE_CHOICE'" class="space-y-3">
                <div class="flex items-center justify-between">
                  <span class="text-sm font-semibold text-slate-800">四个选项内容</span>
                  <span class="text-xs text-slate-400">可在「参考答案」标签页指定正确选项</span>
                </div>
                <div
                  v-for="(_, idx) in form.options"
                  :key="idx"
                  class="flex items-center gap-2.5 rounded-lg border p-2.5"
                  :class="form.answerIndex === idx ? 'border-green-500 bg-green-50/40' : 'border-slate-200'"
                >
                  <span
                    class="flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-xs font-bold"
                    :class="form.answerIndex === idx ? 'bg-green-600 text-white' : 'bg-slate-100 text-slate-600'"
                  >
                    {{ "ABCD"[idx] }}
                  </span>
                  <el-input
                    :ref="el => { if (el) optionInputRefs[idx] = el; }"
                    v-model="form.options[idx]"
                    :placeholder="`请输入选项 ${'ABCD'[idx]} 内容`"
                  />
                  <el-button
                    size="small"
                    plain
                    class="shrink-0"
                    @click="openFormulaDialog('option', idx)"
                  >
                    公式
                  </el-button>
                </div>
              </div>
              <el-alert
                v-else
                type="info"
                :closable="false"
                show-icon
                title="解答题在学生端将直接显示「开始作答」按钮并跳转横屏手写画板，提交后由老师在后台详情批改。"
              />
            </div>

            <!-- 动态题题目内容与随机变量 -->
            <div v-else class="space-y-4 pt-2">
              <div class="rounded-lg border border-amber-200 bg-amber-50 p-3">
                <div class="flex flex-wrap items-center justify-between gap-2">
                  <span v-if="dynamicEngineType === 'PARAM_TEMPLATE'" class="text-xs font-bold text-amber-800">
                    可视化随机变数配置（使用 &#123;&#123;变量名&#125;&#125; 或 &#123;&#123;表达式&#125;&#125; 生成变化数值）
                  </span>
                  <span v-else class="text-xs font-bold text-amber-800">
                    内置 JS 生成器模式（可编辑脚本或一键转为可视化变量）
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
                <div>
                  <div class="mb-2 text-sm font-semibold text-slate-800">随机变量定义</div>
                  <div class="space-y-2">
                    <div v-for="(v, idx) in paramVars" :key="idx" class="flex flex-wrap items-center gap-2">
                      <el-input v-model="v.name" placeholder="变量名" style="width: 92px" />
                      <span class="text-xs text-slate-500">范围</span>
                      <el-input-number v-model="v.min" :step="1" controls-position="right" style="width: 96px" />
                      <span class="text-xs text-slate-500">~</span>
                      <el-input-number v-model="v.max" :step="1" controls-position="right" style="width: 96px" />
                      <el-button size="small" plain @click="insertVarToken(v.name)">
                        插 &#123;&#123;{{ v.name || "a" }}&#125;&#125;
                      </el-button>
                      <el-button link type="danger" size="small" @click="removeVarRow(idx)">删</el-button>
                    </div>
                    <el-button size="small" type="primary" plain @click="addVarRow">+ 添加变量</el-button>
                  </div>
                </div>

                <div>
                  <div class="mb-2 flex items-center justify-between">
                    <span class="text-sm font-semibold text-slate-800">题干模板</span>
                    <el-button size="small" type="success" plain @click="openFormulaDialog('stemTpl')">
                      + 插入可视化公式
                    </el-button>
                  </div>
                  <el-input
                    ref="stemTplInputRef"
                    v-model="paramRule.stemTpl"
                    type="textarea"
                    :rows="4"
                    placeholder="例：解方程 ${{a}}x + {{b}} = {{a*x+b}}$"
                  />
                  <div class="mt-1 text-xs text-slate-400">支持 + - * / % ^ 与 abs / sqrt / frac(n, d)</div>
                </div>
              </template>

              <template v-else>
                <div>
                  <div class="mb-2 text-sm font-semibold text-slate-800">生成器 JS 脚本</div>
                  <el-input v-model="jsSource" type="textarea" :rows="8" placeholder="()=>mkg(...)" />
                  <div class="mt-1.5 text-xs text-slate-500">
                    内置助手：<code>R(min, max)</code> 随机整数、<code>mkg(题干, 正答, [错1,错2,错3])</code>、<code>frac(n, d)</code> 约分分数
                  </div>
                </div>
              </template>
            </div>
          </el-tab-pane>

          <!-- Tab 2: 参考答案 -->
          <el-tab-pane label="参考答案" name="answer" class="h-full overflow-y-auto pb-6 pr-1">
            <div class="space-y-5 pt-2">
              <template v-if="form.questionMode === 'STATIC'">
                <template v-if="form.questionFormat === 'SINGLE_CHOICE'">
                  <div class="text-sm font-semibold text-slate-800">选择标准正确答案</div>
                  <div class="space-y-2.5">
                    <div
                      v-for="(op, idx) in form.options"
                      :key="idx"
                      class="flex cursor-pointer items-center justify-between rounded-xl border p-3.5 transition"
                      :class="
                        form.answerIndex === idx
                          ? 'border-green-600 bg-green-50 shadow-xs'
                          : 'border-slate-200 hover:border-green-300'
                      "
                      @click="form.answerIndex = idx"
                    >
                      <div class="flex min-w-0 flex-1 items-baseline gap-2.5">
                        <span
                          class="flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-xs font-bold"
                          :class="form.answerIndex === idx ? 'bg-green-600 text-white' : 'bg-slate-100 text-slate-600'"
                        >
                          {{ "ABCD"[idx] }}
                        </span>
                        <div class="min-w-0 flex-1 text-sm text-slate-800">
                          <MathFormulaText :text="op || `（暂未填写选项 ${'ABCD'[idx]}）`" inline />
                        </div>
                      </div>
                      <el-tag v-if="form.answerIndex === idx" type="success" size="small">正确答案</el-tag>
                    </div>
                  </div>
                </template>
                <template v-else>
                  <div class="flex items-center justify-between">
                    <span class="text-sm font-semibold text-slate-800">解答题参考答案 / 评分标准</span>
                    <el-button size="small" type="success" plain @click="openFormulaDialog('essayAnswer')">
                      + 插入答案公式
                    </el-button>
                  </div>
                  <el-input
                    ref="essayAnswerInputRef"
                    v-model="form.essayAnswerText"
                    type="textarea"
                    :rows="6"
                    placeholder="请输入标准解题过程与最终结论（批改时展示给老师参考）"
                  />
                </template>
              </template>

              <template v-else-if="dynamicEngineType === 'PARAM_TEMPLATE'">
                <div>
                  <div class="mb-2 flex items-center justify-between">
                    <span class="text-sm font-semibold text-slate-800">
                      {{ form.questionFormat === "ESSAY" ? "参考答案模板" : "正确答案计算表达式" }}
                    </span>
                    <el-button size="small" plain @click="openFormulaDialog('ansExpr')">+ 插入公式</el-button>
                  </div>
                  <el-input
                    ref="ansExprInputRef"
                    v-model="paramRule.ansExpr"
                    :type="form.questionFormat === 'ESSAY' ? 'textarea' : 'text'"
                    :rows="4"
                    :placeholder="
                      form.questionFormat === 'ESSAY'
                        ? '例：解：移项得 ${{a}}x = {{a*x}}$，解得 $x = {{x}}$'
                        : '填正确答案计算表达式，如 a + b、2*x 或 frac(a, b)'
                    "
                  />
                </div>

                <div v-if="form.questionFormat === 'SINGLE_CHOICE'" class="space-y-2.5">
                  <div class="text-sm font-semibold text-slate-800">干扰项计算表达式（可选，留空自动构造）</div>
                  <div v-for="(_, idx) in paramRule.wrongExprs" :key="idx" class="flex items-center gap-2.5">
                    <span class="w-14 shrink-0 text-xs text-slate-500">错项 {{ idx + 1 }}</span>
                    <el-input
                      v-model="paramRule.wrongExprs[idx]"
                      placeholder="选填公式如 a - b（留空自动生成不同干扰项）"
                    />
                  </div>
                </div>
              </template>

              <el-alert
                v-else
                type="info"
                :closable="false"
                title="当前为 JS 脚本生成器模式，标准答案与干扰项由「题目内容」中的 mkg(...) 脚本函数直接返回。"
              />
            </div>
          </el-tab-pane>

          <!-- Tab 3: 解题思路 -->
          <el-tab-pane label="解题思路" name="analysis" class="h-full overflow-y-auto pb-6 pr-1">
            <div class="space-y-3 pt-2">
              <div class="flex items-center justify-between">
                <span class="text-sm font-semibold text-slate-800">详细解题思路与知识点解析</span>
                <el-button size="small" type="success" plain @click="openFormulaDialog('analysis')">
                  + 插入解析公式
                </el-button>
              </div>
              <el-input
                ref="analysisInputRef"
                v-model="form.analysis"
                type="textarea"
                :rows="8"
                placeholder="选填：学生答题交卷后展示给学生的解题步骤与思路分析；随机变数题支持 {{变量名}} 插值。"
              />
              <div class="rounded-lg border border-slate-200 bg-slate-50 p-3">
                <div class="mb-1.5 text-xs font-semibold text-slate-500">解析公式实时排版预览：</div>
                <div class="text-sm leading-relaxed text-slate-700">
                  <MathFormulaText :text="form.analysis || '（暂未填写解题思路）'" />
                </div>
              </div>
            </div>
          </el-tab-pane>
        </el-tabs>
      </section>

      <!-- 右侧：学生端手机显示实时预览 -->
      <aside class="col-span-5 flex min-h-0 flex-col items-center justify-between overflow-hidden rounded-xl border border-slate-200 bg-slate-50 p-4">
        <div class="flex w-full shrink-0 flex-wrap items-center justify-between gap-2 pb-2">
          <span class="text-xs font-bold text-slate-700">学生端手机实时预览</span>
          <div class="flex items-center gap-2">
            <el-radio-group v-model="phonePreviewStage" size="small">
              <el-radio-button value="answering">答题中</el-radio-button>
              <el-radio-button value="reviewed">交卷后</el-radio-button>
            </el-radio-group>
          </div>
        </div>

        <!-- 随机样本切换条 -->
        <div
          v-if="form.questionMode === 'DYNAMIC_TEMPLATE'"
          class="mb-2 flex w-full shrink-0 items-center justify-center gap-1.5"
        >
          <template v-if="previewSamples.length > 0">
            <el-button
              v-for="(_, idx) in previewSamples"
              :key="idx"
              size="small"
              :type="activeSampleIndex === idx ? 'warning' : 'default'"
              plain
              @click="activeSampleIndex = idx"
            >
              随机样本 {{ idx + 1 }}
            </el-button>
          </template>
          <span v-else class="text-xs text-amber-700">点击右上角「试生成 3 题」查看随机效果</span>
        </div>

        <!-- 手机边框外壳 -->
        <div class="flex min-h-0 w-[348px] flex-1 flex-col overflow-hidden rounded-[32px] border-[8px] border-slate-800 bg-[#f6f8f7] shadow-xl">
          <!-- 手机状态栏 -->
          <div class="flex h-6 shrink-0 items-center justify-between bg-white px-5 text-[11px] font-semibold text-slate-700">
            <span>09:41</span>
            <div class="h-3 w-16 rounded-full bg-slate-900" />
            <span>5G</span>
          </div>

          <!-- 学生端导航栏 -->
          <div class="flex h-11 shrink-0 items-center justify-between border-b border-slate-100 bg-white px-3.5">
            <span class="text-xs text-slate-600">‹ 退出</span>
            <span class="max-w-[180px] truncate text-sm font-bold text-slate-800">
              {{ selectedGate?.gateName || "关卡挑战" }}
            </span>
            <span class="w-8" />
          </div>

          <!-- 学生端可滚动内容区 -->
          <div class="min-h-0 flex-1 space-y-3 overflow-y-auto p-3">
            <!-- 题干卡（题号直接置于题目前方，取消顶部进度条） -->
            <div class="rounded-xl bg-white p-3.5 shadow-2xs">
              <div class="flex flex-wrap items-center justify-between gap-1.5 text-[11px] text-slate-400">
                <div class="flex min-w-0 items-center gap-1.5">
                  <span class="shrink-0 rounded-full border border-green-200 bg-green-50 px-2 py-0.5 text-[11px] font-bold text-green-700">
                    第 1 / {{ selectedGate?.questionCount || 3 }} 题
                  </span>
                  <span class="shrink-0 rounded bg-slate-100 px-1.5 py-0.5 text-slate-600">
                    {{ selectedRealm?.realmName || "练气" }}
                  </span>
                  <span class="truncate">{{ selectedChapter?.name || "章节练习" }}</span>
                </div>
                <div class="flex shrink-0 items-center gap-1">
                  <span
                    v-if="form.questionFormat === 'ESSAY'"
                    class="rounded bg-green-50 px-1.5 py-0.5 text-[10px] font-medium text-green-700"
                  >
                    解答题
                  </span>
                  <span class="rounded bg-emerald-50 px-1.5 py-0.5 text-[10px] font-medium text-emerald-700">
                    答对 {{ selectedGate?.passCount || 2 }} 题过关
                  </span>
                </div>
              </div>
              <div class="mt-2.5 text-[15px] font-medium leading-relaxed text-slate-800">
                <MathFormulaText :text="phoneStem" />
              </div>
            </div>

            <!-- 选择题选项 -->
            <div v-if="form.questionFormat === 'SINGLE_CHOICE'" class="space-y-2">
              <div
                v-for="(op, idx) in phoneOptions"
                :key="idx"
                class="flex items-center gap-2.5 rounded-xl border bg-white px-3 py-2.5 text-xs transition"
                :class="
                  phonePreviewStage === 'reviewed' && idx === phoneAnswerIndex
                    ? 'border-[#16a34a] bg-[#f0fdf4] text-green-900 font-semibold'
                    : 'border-slate-200 text-slate-700'
                "
              >
                <span
                  class="flex h-6 w-6 shrink-0 items-center justify-center rounded-full text-[11px] font-bold"
                  :class="
                    phonePreviewStage === 'reviewed' && idx === phoneAnswerIndex
                      ? 'bg-[#16a34a] text-white'
                      : 'bg-slate-100 text-slate-600'
                  "
                >
                  {{ "ABCD"[idx] }}
                </span>
                <div class="min-w-0 flex-1">
                  <MathFormulaText :text="op || `选项 ${'ABCD'[idx]}`" inline />
                </div>
              </div>
            </div>

            <!-- 解答题作答后预览 -->
            <div
              v-else-if="phonePreviewStage === 'reviewed'"
              class="space-y-2 rounded-xl border border-amber-200 bg-amber-50 p-3 text-xs text-amber-800"
            >
              <div class="font-semibold">作答已提交至云端，等待老师批改点评</div>
              <div class="rounded bg-white/80 p-2 text-slate-700">
                <span class="font-semibold text-green-700">参考答案（后台可见）：</span>
                <MathFormulaText :text="phoneEssayAnswer" inline />
              </div>
            </div>

            <!-- 交卷后解析卡 -->
            <div
              v-if="phonePreviewStage === 'reviewed' && phoneAnalysis"
              class="rounded-xl border border-green-200 bg-[#f0fdf4] p-3 text-xs text-slate-700"
            >
              <div class="mb-1 font-semibold text-green-800">解题思路</div>
              <MathFormulaText :text="phoneAnalysis" />
            </div>
          </div>

          <!-- 手机端底部安全区按钮栏 -->
          <div class="shrink-0 border-t border-slate-100 bg-white px-3.5 py-2.5">
            <div
              v-if="form.questionFormat === 'ESSAY' && phonePreviewStage === 'answering'"
              class="flex h-9 w-full items-center justify-center rounded-lg bg-[#16a34a] text-xs font-semibold text-white"
            >
              开始作答
            </div>
            <div
              v-else
              class="flex h-9 w-full items-center justify-center rounded-lg bg-[#16a34a] text-xs font-semibold text-white opacity-90"
            >
              {{ phonePreviewStage === "answering" ? "下一题" : "提交交卷" }}
            </div>
          </div>
        </div>
      </aside>
    </main>

    <MathFormulaDialog
      v-model="formulaDialogVisible"
      :initial-latex="formulaInitialLatex"
      :target-label="formulaTargetLabel"
      @insert="handleFormulaInsert"
    />
  </div>
</template>

<style scoped>
:deep(.el-tabs__content) {
  flex: 1;
  min-height: 0;
  overflow: hidden;
}
:deep(.el-tab-pane) {
  height: 100%;
}
</style>
