<script setup lang="ts">
import { ref, reactive, onMounted } from "vue";
import { useRouter } from "vue-router";
import { ElMessage, ElMessageBox } from "element-plus";
import MathFormulaText from "@/components/MathFormulaText.vue";
import {
  getRealms,
  getChapters,
  getGatesByChapter,
  getQuestionPage,
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

const router = useRouter();
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

// 列表弹窗预览
const previewVisible = ref(false);
const previewLoading = ref(false);
const previewSamples = ref<GeneratedSample[]>([]);

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

function openCreate() {
  router.push({
    path: "/bank/question/editor",
    query: {
      ...(query.realmCode ? { realmCode: query.realmCode } : {}),
      ...(query.chapterId ? { chapterId: String(query.chapterId) } : {}),
      ...(query.gateId ? { gateId: String(query.gateId) } : {})
    }
  });
}

function openEdit(row: QuestionItem) {
  router.push({
    path: "/bank/question/editor",
    query: { id: String(row.id) }
  });
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
          <el-select
            v-model="query.questionMode"
            placeholder="全部"
            clearable
            style="width: 150px"
            @change="handleSearch"
          >
            <el-option label="固定题目" value="STATIC" />
            <el-option label="随机变数题" value="DYNAMIC_TEMPLATE" />
          </el-select>
        </el-form-item>
        <el-form-item label="题型">
          <el-select
            v-model="query.questionFormat"
            placeholder="全部"
            clearable
            style="width: 120px"
            @change="handleSearch"
          >
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
