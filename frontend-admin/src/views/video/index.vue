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
  pageSize: 10
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

    <el-card shadow="never">
      <el-table v-loading="loading" :data="tableData" border stripe>
        <el-table-column prop="id" label="ID" width="66" align="center" />
        <el-table-column label="封面" width="140" align="center">
          <template #default="{ row }">
            <el-image
              v-if="row.coverImageUrl"
              :src="row.coverImageUrl"
              fit="cover"
              class="h-16 w-28 rounded border border-slate-200"
            />
            <div v-else class="flex h-16 w-28 items-center justify-center rounded bg-slate-100 text-xs text-slate-400">
              无封面
            </div>
          </template>
        </el-table-column>
        <el-table-column label="系列标题与介绍" min-width="260">
          <template #default="{ row }">
            <div class="font-bold text-slate-800">{{ row.title }}</div>
            <div class="mt-1 line-clamp-2 text-xs text-slate-500">
              {{ row.intro || "暂无系列介绍" }}
            </div>
          </template>
        </el-table-column>
        <el-table-column label="境界分类" width="120" align="center">
          <template #default="{ row }">
            <el-tag size="small" :type="row.realmCode ? 'success' : 'info'">
              {{ row.realmName || "全境界通用" }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="已传课时" width="110" align="center">
          <template #default="{ row }">
            <el-tag size="small" type="primary">{{ row.lessonCount }} 节</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="sortOrder" label="排序" width="80" align="center" />
        <el-table-column label="上架" width="84" align="center">
          <template #default="{ row }">
            <el-switch :model-value="row.enabled === 1" size="small" @change="handleToggleEnabled(row)" />
          </template>
        </el-table-column>
        <el-table-column label="操作" width="240" align="center">
          <template #default="{ row }">
            <div class="inline-flex items-center gap-1 whitespace-nowrap">
              <el-button link type="success" @click="openLessons(row)">
                <GglIcon name="video-play" :size="14" class="mr-1" />
                上传/管理多节视频
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
