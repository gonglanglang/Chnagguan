<script setup lang="ts">
import { ref, reactive, onMounted } from "vue";
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
  keyword: "",
  pageNum: 1,
  pageSize: 10
});

// 简洁直观编辑抽屉
const editorVisible = ref(false);
const editorSaving = ref(false);
const editId = ref<number | null>(null);
const editChapters = ref<ChapterItem[]>([]);
const editGates = ref<GateItem[]>([]);
const existingDynamicRule = ref<Record<string, any> | null>(null);

const form = reactive({
  gradeCode: "g7",
  chapterId: undefined as number | undefined,
  gateId: undefined as number | undefined,
  questionMode: "STATIC" as "STATIC" | "DYNAMIC_TEMPLATE",
  stem: "",
  options: ["", "", "", ""],
  answerIndex: 0,
  analysis: "",
  enabled: 1
});

// 试生成效果预览
const previewVisible = ref(false);
const previewLoading = ref(false);
const previewSamples = ref<GeneratedSample[]>([]);

// 可视化数学公式弹窗
type FormulaTarget =
  | { field: "stem" }
  | { field: "analysis" }
  | { field: "option"; index: number };

const stemInputRef = ref<any>(null);
const analysisInputRef = ref<any>(null);
const optionInputRefs = ref<any[]>([]);
const formulaDialogVisible = ref(false);
const formulaInitialLatex = ref("");
const formulaTarget = ref<FormulaTarget>({ field: "stem" });
const formulaSelection = ref<{ start: number; end: number }>({ start: 0, end: 0 });
const formulaTargetLabel = ref("题目内容");

function getTargetNativeEl(target: FormulaTarget): HTMLInputElement | HTMLTextAreaElement | null {
  const comp =
    target.field === "stem"
      ? stemInputRef.value
      : target.field === "analysis"
        ? analysisInputRef.value
        : optionInputRefs.value[target.index];
  return comp?.textarea || comp?.input || null;
}

function getTargetText(target: FormulaTarget): string {
  if (target.field === "stem") return form.stem;
  if (target.field === "analysis") return form.analysis;
  return form.options[target.index] || "";
}

function setTargetText(target: FormulaTarget, val: string) {
  if (target.field === "stem") form.stem = val;
  else if (target.field === "analysis") form.analysis = val;
  else form.options[target.index] = val;
}

function openFormulaDialog(field: "stem" | "analysis" | "option", index = 0) {
  const target: FormulaTarget = field === "option" ? { field: "option", index } : { field };
  formulaTarget.value = target;
  formulaTargetLabel.value =
    field === "stem" ? "题目内容" : field === "analysis" ? "解题思路" : `选项 ${"ABCD"[index]}`;

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

async function openCreate() {
  editId.value = null;
  existingDynamicRule.value = null;
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
  form.stem = "";
  form.options = ["", "", "", ""];
  form.answerIndex = 0;
  form.analysis = "";
  form.enabled = 1;
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
  existingDynamicRule.value = row.templateRule || null;
  form.stem = row.stem;
  form.options = row.options?.length ? [...row.options] : ["", "", "", ""];
  while (form.options.length < 4) form.options.push("");
  form.answerIndex = Number(row.answer?.index ?? 0);
  form.analysis = row.analysis || "";
  form.enabled = row.enabled;
  editorVisible.value = true;
}

function switchToStaticMode() {
  form.questionMode = "STATIC";
  if (!form.stem.trim()) form.stem = "";
}

async function handleSave() {
  if (!form.chapterId || !form.gateId) {
    ElMessage.warning("请选择所属章节与关卡");
    return;
  }
  if (!form.stem.trim()) {
    ElMessage.warning("请填写题干内容");
    return;
  }
  if (form.questionMode === "STATIC" && form.options.some(o => !o.trim())) {
    ElMessage.warning("请填写完整的四个选项内容");
    return;
  }

  const payload = {
    gradeCode: form.gradeCode,
    chapterId: form.chapterId,
    gateId: form.gateId,
    questionMode: form.questionMode,
    questionFormat: "SINGLE_CHOICE",
    stem: form.stem.trim(),
    options: form.options.map(o => o.trim()),
    answer: { index: form.answerIndex },
    analysis: form.analysis.trim(),
    templateRule: form.questionMode === "DYNAMIC_TEMPLATE" ? existingDynamicRule.value : null,
    enabled: form.enabled
  };

  editorSaving.value = true;
  try {
    if (editId.value) {
      await updateQuestion(editId.value, payload);
      ElMessage.success("题目已保存");
    } else {
      await createQuestion(payload);
      ElMessage.success("新增题目成功");
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
            style="width: 140px"
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
            style="width: 200px"
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
            style="width: 130px"
            @change="handleSearch"
          >
            <el-option v-for="gt in filterGates" :key="gt.id" :label="gt.gateName" :value="gt.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="出题方式">
          <el-select v-model="query.questionMode" placeholder="全部" clearable style="width: 160px" @change="handleSearch">
            <el-option label="固定题目" value="STATIC" />
            <el-option label="系统随机变数题" value="DYNAMIC_TEMPLATE" />
          </el-select>
        </el-form-item>
        <el-form-item label="题干">
          <el-input
            v-model="query.keyword"
            placeholder="输入题干关键词"
            clearable
            style="width: 185px"
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
        <el-table-column label="出题方式" width="114" align="center">
          <template #default="{ row }">
            <el-tag
              size="small"
              class="whitespace-nowrap"
              :type="row.questionMode === 'DYNAMIC_TEMPLATE' ? 'warning' : 'success'"
            >
              {{ row.questionMode === "DYNAMIC_TEMPLATE" ? "随机变数" : "固定题目" }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="题干与选项" min-width="320">
          <template #default="{ row }">
            <div class="font-medium text-gray-800">
              <MathFormulaText :text="row.stem" />
            </div>
            <div v-if="row.options?.length" class="mt-1.5 flex flex-wrap gap-1.5 text-xs">
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

    <!-- 极简题目编辑抽屉 -->
    <el-drawer v-model="editorVisible" :title="editId ? '编辑题目' : '新增题目'" size="860px">
      <div class="grid grid-cols-1 gap-6 lg:grid-cols-12">
        <div class="space-y-4 lg:col-span-7">
          <el-form label-width="88px">
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
              <el-select v-model="form.gateId" class="w-full">
                <el-option v-for="gt in editGates" :key="gt.id" :label="gt.gateName" :value="gt.id" />
              </el-select>
            </el-form-item>

            <el-alert
              v-if="form.questionMode === 'DYNAMIC_TEMPLATE'"
              type="warning"
              :closable="false"
              class="mb-3"
              title="本题是内置自动换数字题（每次做题数字不同），可直接修改解析或停用；如需改为固定题可点击下方按钮切换。"
            />

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

            <template v-if="form.questionMode === 'STATIC'">
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

            <div v-else class="mb-3 pl-[88px]">
              <el-button size="small" plain @click="switchToStaticMode">
                改为普通固定题目
              </el-button>
            </div>

            <el-form-item label="解题思路">
              <div class="w-full space-y-1.5">
                <el-input
                  ref="analysisInputRef"
                  v-model="form.analysis"
                  type="textarea"
                  :rows="2"
                  placeholder="可选填：答完后展示给学生的解析"
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

        <div class="lg:col-span-5">
          <div class="rounded-xl border border-gray-200 bg-gray-50 p-4">
            <div class="mb-3 text-xs font-bold text-gray-600">学生端显示预览（含公式排版）</div>
            <div class="rounded-lg bg-white p-4 shadow-sm">
              <div class="text-sm font-semibold leading-relaxed text-gray-800">
                <MathFormulaText :text="form.stem || '请输入题目内容...'" />
              </div>
              <div class="mt-3 space-y-2">
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
              <div v-if="form.analysis" class="mt-3 rounded bg-gray-50 p-2 text-xs text-gray-600">
                解析：<MathFormulaText :text="form.analysis" inline />
              </div>
            </div>
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
          <div class="mt-2 grid grid-cols-2 gap-2">
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
