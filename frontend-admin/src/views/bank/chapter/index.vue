<script setup lang="ts">
import { ref, reactive, onMounted } from "vue";
import { ElMessage, ElMessageBox } from "element-plus";
import {
  getRealms,
  getChapters,
  createChapter,
  updateChapter,
  deleteChapter,
  getGatesByChapter,
  updateGate,
  type RealmConfig,
  type ChapterItem,
  type GateItem
} from "@/api/guoguanla";

defineOptions({
  name: "ChapterManage"
});

const realms = ref<RealmConfig[]>([]);
const activeRealm = ref<string>("");
const keyword = ref("");
const loading = ref(false);
const chapters = ref<ChapterItem[]>([]);

const chapDialogVisible = ref(false);
const chapEditId = ref<number | null>(null);
const chapForm = reactive({
  gradeCode: "g7",
  name: "",
  description: "",
  sortOrder: 10,
  enabled: 1
});

const gateDrawerVisible = ref(false);
const gateLoading = ref(false);
const currentChapter = ref<ChapterItem | null>(null);
const gates = ref<GateItem[]>([]);

async function fetchRealms() {
  const res = await getRealms();
  realms.value = res.data;
}

async function fetchChapters() {
  loading.value = true;
  try {
    const res = await getChapters({
      realmCode: activeRealm.value || undefined,
      keyword: keyword.value || undefined
    });
    chapters.value = res.data;
  } finally {
    loading.value = false;
  }
}

function openCreateChapter() {
  chapEditId.value = null;
  const matched = realms.value.find(r => r.realmCode === activeRealm.value);
  chapForm.gradeCode = matched?.gradeCode || realms.value[0]?.gradeCode || "g7";
  chapForm.name = "";
  chapForm.description = "";
  chapForm.sortOrder = chapters.value.length + 1;
  chapForm.enabled = 1;
  chapDialogVisible.value = true;
}

function openEditChapter(row: ChapterItem) {
  chapEditId.value = row.id;
  chapForm.gradeCode = row.gradeCode;
  chapForm.name = row.name;
  chapForm.description = row.description;
  chapForm.sortOrder = row.sortOrder;
  chapForm.enabled = row.enabled;
  chapDialogVisible.value = true;
}

async function saveChapter() {
  if (!chapForm.name.trim()) {
    ElMessage.warning("请输入章节名称");
    return;
  }
  if (chapEditId.value) {
    await updateChapter(chapEditId.value, chapForm);
    ElMessage.success("章节已更新");
  } else {
    await createChapter(chapForm);
    ElMessage.success("新增章节成功，已自动创建 4 道关卡");
  }
  chapDialogVisible.value = false;
  fetchChapters();
}

async function handleDeleteChapter(row: ChapterItem) {
  await ElMessageBox.confirm(`确认删除章节「${row.name}」？`, "删除确认", { type: "warning" });
  await deleteChapter(row.id);
  ElMessage.success("已删除章节");
  fetchChapters();
}

async function openGatesDrawer(row: ChapterItem) {
  currentChapter.value = row;
  gateDrawerVisible.value = true;
  gateLoading.value = true;
  try {
    const res = await getGatesByChapter(row.id);
    gates.value = res.data;
  } finally {
    gateLoading.value = false;
  }
}

async function saveGateItem(gate: GateItem) {
  if (gate.passCount > gate.questionCount) {
    ElMessage.warning("过关最少答对题数不能大于抽题数");
    return;
  }
  await updateGate(gate.id, {
    gateName: gate.gateName,
    star: gate.star,
    questionCount: gate.questionCount,
    passCount: gate.passCount,
    enabled: gate.enabled
  });
  ElMessage.success(`已保存「${gate.gateName}」配置`);
}

onMounted(async () => {
  await fetchRealms();
  await fetchChapters();
});
</script>

<template>
  <div class="space-y-4">
    <el-card shadow="never">
      <div class="mb-3 flex flex-wrap items-center justify-between gap-2">
        <span class="font-bold text-gray-800">按修仙境界筛选章节</span>
        <span class="text-xs text-gray-500">每个境界对应一套难度课程体系</span>
      </div>
      <div class="grid grid-cols-2 gap-3 sm:grid-cols-4 xl:grid-cols-7">
        <div
          class="cursor-pointer rounded-lg border px-2.5 py-3 text-center transition"
          :class="activeRealm === '' ? 'border-green-600 bg-green-50 text-green-800' : 'border-gray-200 hover:border-green-400'"
          @click="activeRealm = ''; fetchChapters()"
        >
          <div class="whitespace-nowrap text-sm font-bold">全部境界</div>
          <div class="mt-1 whitespace-nowrap text-xs text-gray-500">全部难度</div>
        </div>
        <div
          v-for="r in realms"
          :key="r.realmCode"
          class="cursor-pointer rounded-lg border px-2.5 py-3 text-center transition"
          :class="activeRealm === r.realmCode ? 'border-green-600 bg-green-50 text-green-800' : 'border-gray-200 hover:border-green-400'"
          @click="activeRealm = r.realmCode; fetchChapters()"
        >
          <div class="whitespace-nowrap text-sm font-bold">{{ r.realmName }}</div>
          <div class="mt-1 truncate whitespace-nowrap text-xs text-gray-500">{{ r.difficultyLabel }}</div>
        </div>
      </div>
    </el-card>

    <el-card shadow="never">
      <div class="mb-4 flex flex-wrap items-center justify-between gap-2">
        <div class="flex flex-wrap items-center gap-2">
          <el-input
            v-model="keyword"
            placeholder="搜索章节名称或简介"
            clearable
            style="width: 240px"
            @keyup.enter="fetchChapters"
          />
          <el-button type="primary" @click="fetchChapters">查询</el-button>
        </div>
        <el-button type="success" class="shrink-0" @click="openCreateChapter">+ 新增章节</el-button>
      </div>

      <el-table v-loading="loading" :data="chapters" border stripe>
        <el-table-column prop="id" label="ID" width="64" align="center" />
        <el-table-column label="所属境界" width="104" align="center">
          <template #default="{ row }">
            <el-tag type="success" size="small" class="whitespace-nowrap">
              {{ row.realmName || row.gradeName }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="name" label="章节名称" min-width="190">
          <template #default="{ row }">
            <span class="font-semibold text-gray-800">{{ row.name }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="description" label="知识点说明" min-width="200" show-overflow-tooltip />
        <el-table-column label="关卡与题数" width="144" align="center">
          <template #default="{ row }">
            <span class="whitespace-nowrap">{{ row.gateCount }} 关 / {{ row.questionCount }} 题</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="86" align="center">
          <template #default="{ row }">
            <el-tag :type="row.enabled === 1 ? 'success' : 'info'" size="small" class="whitespace-nowrap">
              {{ row.enabled === 1 ? "启用" : "隐藏" }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="216" align="center">
          <template #default="{ row }">
            <div class="inline-flex items-center justify-center whitespace-nowrap">
              <el-button link type="primary" @click="openGatesDrawer(row)">设置关卡</el-button>
              <el-button link type="primary" @click="openEditChapter(row)">编辑</el-button>
              <el-button link type="danger" @click="handleDeleteChapter(row)">删除</el-button>
            </div>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="chapDialogVisible" :title="chapEditId ? '编辑章节' : '新增章节'" width="460px">
      <el-form label-width="90px">
        <el-form-item label="所属境界" required>
          <el-select v-model="chapForm.gradeCode" class="w-full">
            <el-option
              v-for="r in realms"
              :key="r.gradeCode"
              :label="`${r.realmName}（${r.difficultyLabel}）`"
              :value="r.gradeCode"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="章节名称" required>
          <el-input v-model="chapForm.name" placeholder="如 第一章 有理数入门" />
        </el-form-item>
        <el-form-item label="知识点简介">
          <el-input v-model="chapForm.description" placeholder="简短描述本章学习内容" />
        </el-form-item>
        <el-form-item label="排序">
          <el-input-number v-model="chapForm.sortOrder" :min="0" />
        </el-form-item>
        <el-form-item label="是否显示">
          <el-switch v-model="chapForm.enabled" :active-value="1" :inactive-value="0" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="chapDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="saveChapter">保存</el-button>
      </template>
    </el-dialog>

    <el-drawer v-model="gateDrawerVisible" :title="`${currentChapter?.name || ''} · 关卡设置`" size="600px">
      <div v-loading="gateLoading" class="space-y-4">
        <el-card v-for="gate in gates" :key="gate.id" shadow="never">
          <div class="mb-3 flex flex-wrap items-center justify-between gap-2">
            <div class="font-bold text-gray-800">
              第 {{ gate.gateIndex + 1 }} 关 · 当前共有 {{ gate.actualQuestionCount }} 道启用题目
            </div>
            <el-switch v-model="gate.enabled" class="shrink-0" :active-value="1" :inactive-value="0" active-text="启用" />
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <div class="mb-1 text-xs text-gray-500">关卡名称</div>
              <el-input v-model="gate.gateName" size="small" />
            </div>
            <div>
              <div class="mb-1 text-xs text-gray-500">难度星级（1~5）</div>
              <el-input-number v-model="gate.star" :min="1" :max="5" size="small" class="w-full" />
            </div>
            <div>
              <div class="mb-1 text-xs text-gray-500">每次答题数</div>
              <el-input-number v-model="gate.questionCount" :min="1" :max="20" size="small" class="w-full" />
            </div>
            <div>
              <div class="mb-1 text-xs text-gray-500">过关需答对数</div>
              <el-input-number v-model="gate.passCount" :min="1" :max="gate.questionCount" size="small" class="w-full" />
            </div>
          </div>
          <div class="mt-3 flex justify-end">
            <el-button type="primary" size="small" @click="saveGateItem(gate)">保存本关设置</el-button>
          </div>
        </el-card>
      </div>
    </el-drawer>
  </div>
</template>
