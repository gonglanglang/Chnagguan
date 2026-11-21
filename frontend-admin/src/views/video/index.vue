<script setup lang="ts">
import { ref, reactive, onMounted } from "vue";
import { useRouter } from "vue-router";
import { ElMessage, ElMessageBox } from "element-plus";
import GglIcon from "@/components/GglIcon/index.vue";
import {
  getRealms,
  getVideoSeriesPage,
  createVideoSeries,
  updateVideoSeries,
  deleteVideoSeries,
  uploadVideoCover,
  type RealmConfig,
  type VideoSeriesItem
} from "@/api/guoguanla";

defineOptions({
  name: "VideoSeriesManage"
});

const router = useRouter();
const loading = ref(false);
const tableData = ref<VideoSeriesItem[]>([]);
const total = ref(0);
const realms = ref<RealmConfig[]>([]);

const query = reactive({
  realmCode: "",
  keyword: "",
  pageNum: 1,
  pageSize: 15
});

const dialogVisible = ref(false);
const editId = ref<number | null>(null);
const saving = ref(false);
const coverUploading = ref(false);
const coverInputRef = ref<HTMLInputElement | null>(null);

const form = reactive({
  title: "",
  coverImageKey: "",
  coverPreviewUrl: "",
  intro: "",
  realmCode: "",
  sortOrder: 0,
  enabled: 1
});

async function loadRealms() {
  const res = await getRealms();
  realms.value = res.data;
}

async function fetchSeries() {
  loading.value = true;
  try {
    const res = await getVideoSeriesPage(query);
    tableData.value = res.data.records;
    total.value = res.data.total;
  } finally {
    loading.value = false;
  }
}

function handleSearch() {
  query.pageNum = 1;
  fetchSeries();
}

function handleReset() {
  query.realmCode = "";
  query.keyword = "";
  handleSearch();
}

function openCreate() {
  editId.value = null;
  form.title = "";
  form.coverImageKey = "";
  form.coverPreviewUrl = "";
  form.intro = "";
  form.realmCode = "";
  form.sortOrder = 0;
  form.enabled = 1;
  dialogVisible.value = true;
}

function openEdit(row: VideoSeriesItem) {
  editId.value = row.id;
  form.title = row.title;
  form.coverImageKey = row.coverImageKey || "";
  form.coverPreviewUrl = row.coverImageUrl || "";
  form.intro = row.intro || "";
  form.realmCode = row.realmCode || "";
  form.sortOrder = row.sortOrder ?? 0;
  form.enabled = row.enabled ?? 1;
  dialogVisible.value = true;
}

function openLessons(row: VideoSeriesItem) {
  router.push(`/video/lessons/${row.id}`);
}

function triggerCoverPick() {
  coverInputRef.value?.click();
}

async function onCoverFileChange(evt: Event) {
  const input = evt.target as HTMLInputElement;
  const file = input.files?.[0];
  input.value = "";
  if (!file) return;

  coverUploading.value = true;
  try {
    const fd = new FormData();
    fd.append("file", file);
    const res = await uploadVideoCover(fd);
    form.coverImageKey = res.data.objectKey;
    form.coverPreviewUrl = res.data.previewUrl;
    ElMessage.success("系列封面上传成功");
  } finally {
    coverUploading.value = false;
  }
}

async function handleSave() {
  if (!form.title.trim()) {
    ElMessage.warning("请输入教学视频系列标题");
    return;
  }
  saving.value = true;
  try {
    const payload = {
      title: form.title.trim(),
      coverImageKey: form.coverImageKey,
      intro: form.intro.trim(),
      realmCode: form.realmCode,
      sortOrder: form.sortOrder,
      enabled: form.enabled
    };
    if (editId.value) {
      await updateVideoSeries(editId.value, payload);
      ElMessage.success("视频系列已更新");
    } else {
      await createVideoSeries(payload);
      ElMessage.success("教学视频系列创建成功，可点击「管理课时」继续上传多节视频");
    }
    dialogVisible.value = false;
    fetchSeries();
  } finally {
    saving.value = false;
  }
}

async function handleToggleEnabled(row: VideoSeriesItem) {
  const next = row.enabled === 1 ? 0 : 1;
  await updateVideoSeries(row.id, {
    title: row.title,
    coverImageKey: row.coverImageKey,
    intro: row.intro,
    realmCode: row.realmCode,
    sortOrder: row.sortOrder,
    enabled: next
  });
  row.enabled = next;
  ElMessage.success(next === 1 ? "已上架展示" : "已下架");
}

async function handleDelete(row: VideoSeriesItem) {
  await ElMessageBox.confirm(`确认删除视频系列「${row.title}」及其下属全部课时？`, "确认删除", {
    type: "warning"
  });
  await deleteVideoSeries(row.id);
  ElMessage.success("已删除");
  fetchSeries();
}

onMounted(async () => {
  await loadRealms();
  await fetchSeries();
});
</script>

<template>
  <div class="space-y-4">
    <el-card shadow="never">
      <el-form :inline="true" :model="query" class="flex flex-wrap items-center gap-y-2">
        <el-form-item label="适用境界">
          <el-select v-model="query.realmCode" placeholder="全部境界" clearable style="width: 160px">
            <el-option
              v-for="r in realms"
              :key="r.realmCode"
              :label="r.realmName"
              :value="r.realmCode"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="关键词">
          <el-input
            v-model="query.keyword"
            placeholder="系列标题 / 介绍"
            clearable
            style="width: 220px"
            @keyup.enter="handleSearch"
          />
        </el-form-item>
        <el-form-item>
          <div class="flex items-center gap-2">
            <el-button type="primary" @click="handleSearch">查询</el-button>
            <el-button @click="handleReset">重置</el-button>
            <el-button type="success" @click="openCreate">+ 创建教学视频系列</el-button>
          </div>
        </el-form-item>
      </el-form>
    </el-card>

    <el-card v-loading="loading" shadow="never">
      <div
        v-if="tableData.length > 0"
        class="grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5"
      >
        <div
          v-for="row in tableData"
          :key="row.id"
          class="group flex flex-col overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm transition hover:-translate-y-0.5 hover:border-green-500/60 hover:shadow-md"
        >
          <div
            class="relative aspect-video w-full cursor-pointer overflow-hidden bg-slate-900"
            @click="openLessons(row)"
          >
            <el-image
              v-if="row.coverImageUrl"
              :src="row.coverImageUrl"
              fit="cover"
              class="h-full w-full transition duration-300 group-hover:scale-105"
            />
            <div
              v-else
              class="flex h-full w-full flex-col items-center justify-center gap-1.5 bg-gradient-to-br from-emerald-600 to-green-700 text-white/90"
            >
              <GglIcon name="video-play" :size="28" />
              <span class="text-xs">暂无系列封面</span>
            </div>

            <div class="pointer-events-none absolute left-2 top-2">
              <el-tag size="small" :type="row.realmCode ? 'success' : 'info'" effect="dark">
                {{ row.realmName || "全境界通用" }}
              </el-tag>
            </div>
            <div class="pointer-events-none absolute right-2 top-2">
              <el-tag size="small" :type="row.enabled === 1 ? 'success' : 'info'">
                {{ row.enabled === 1 ? "已上架" : "已下架" }}
              </el-tag>
            </div>
            <div class="pointer-events-none absolute bottom-2 right-2 rounded bg-black/65 px-2 py-0.5 text-[11px] font-medium text-white">
              {{ row.lessonCount }} 节
            </div>
          </div>

          <div class="flex flex-1 flex-col p-3">
            <div
              class="line-clamp-1 cursor-pointer text-sm font-bold text-slate-800 transition hover:text-green-600"
              :title="row.title"
              @click="openLessons(row)"
            >
              {{ row.title }}
            </div>
            <div class="mt-1 line-clamp-2 min-h-[34px] text-xs leading-relaxed text-slate-500">
              {{ row.intro || "暂无系列介绍" }}
            </div>
            <div class="mt-2 flex items-center justify-between text-[11px] text-slate-400">
              <span>系列 #{{ row.id }}</span>
              <span>排序 {{ row.sortOrder ?? 0 }}</span>
            </div>
          </div>

          <div class="mt-auto flex items-center justify-between border-t border-slate-100 bg-slate-50/70 px-3 py-2">
            <el-switch :model-value="row.enabled === 1" size="small" @change="handleToggleEnabled(row)" />
            <div class="flex items-center gap-1">
              <el-button link size="small" type="success" @click="openLessons(row)">管理课时</el-button>
              <el-button link size="small" type="primary" @click="openEdit(row)">编辑</el-button>
              <el-button link size="small" type="danger" @click="handleDelete(row)">删除</el-button>
            </div>
          </div>
        </div>
      </div>

      <el-empty v-else description="暂无教学视频系列，点击上方「+ 创建教学视频系列」开始创建" />

      <div class="mt-4 flex justify-end">
        <el-pagination
          v-model:current-page="query.pageNum"
          v-model:page-size="query.pageSize"
          :total="total"
          :page-sizes="[10, 15, 25, 50]"
          layout="total, sizes, prev, pager, next"
          @current-change="fetchSeries"
          @size-change="fetchSeries"
        />
      </div>
    </el-card>

    <el-dialog
      v-model="dialogVisible"
      :title="editId ? '编辑教学视频系列' : '创建教学视频系列'"
      width="560px"
    >
      <el-form label-width="92px">
        <el-form-item label="系列标题" required>
          <el-input v-model="form.title" placeholder="例如：七年级有理数高频易错突破课" maxlength="100" />
        </el-form-item>
        <el-form-item label="适用境界">
          <el-select v-model="form.realmCode" clearable placeholder="全境界通用（可选）" class="w-full">
            <el-option label="全境界通用" value="" />
            <el-option
              v-for="r in realms"
              :key="r.realmCode"
              :label="`${r.realmName}（${r.difficultyLabel}）`"
              :value="r.realmCode"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="系列封面">
          <div class="flex items-center gap-4">
            <el-image
              v-if="form.coverPreviewUrl"
              :src="form.coverPreviewUrl"
              fit="cover"
              class="h-24 w-40 rounded-lg border border-slate-200"
            />
            <div
              v-else
              class="flex h-24 w-40 items-center justify-center rounded-lg border border-dashed border-slate-300 bg-slate-50 text-xs text-slate-400"
            >
              16:9 封面预览
            </div>
            <div>
              <input
                ref="coverInputRef"
                type="file"
                accept="image/png,image/jpeg,image/webp"
                class="hidden"
                @change="onCoverFileChange"
              />
              <el-button :loading="coverUploading" plain @click="triggerCoverPick">
                上传封面图片
              </el-button>
              <div class="mt-1 text-xs text-slate-400">支持 PNG/JPG/WEBP，建议 16:9 横图</div>
            </div>
          </div>
        </el-form-item>
        <el-form-item label="系列介绍">
          <el-input
            v-model="form.intro"
            type="textarea"
            :rows="4"
            placeholder="填写本套教学视频系列的课程目标、适合阶段与学习建议"
          />
        </el-form-item>
        <el-form-item label="排序权重">
          <el-input-number v-model="form.sortOrder" :min="0" :max="9999" />
        </el-form-item>
        <el-form-item label="立即上架">
          <el-switch v-model="form.enabled" :active-value="1" :inactive-value="0" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="handleSave">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>
