<script setup lang="ts">
import { ref, reactive, computed, onMounted } from "vue";
import { useRoute, useRouter } from "vue-router";
import { ElMessage, ElMessageBox } from "element-plus";
import MathFormulaText from "@/components/MathFormulaText.vue";
import MathFormulaDialog from "@/components/MathFormulaDialog.vue";
import GglIcon from "@/components/GglIcon/index.vue";
import {
  getVideoSeriesDetail,
  createVideoLesson,
  updateVideoLesson,
  deleteVideoLesson,
  uploadVideoMedia,
  type VideoSeriesItem,
  type VideoLessonItem
} from "@/api/guoguanla";

defineOptions({
  name: "VideoLessonManage"
});

const route = useRoute();
const router = useRouter();
const seriesId = computed(() => Number(route.params.seriesId || 0));

const loading = ref(false);
const series = ref<VideoSeriesItem | null>(null);
const lessons = ref<VideoLessonItem[]>([]);

const dialogVisible = ref(false);
const editLessonId = ref<number | null>(null);
const saving = ref(false);
const videoUploading = ref(false);
const uploadProgress = ref(0);
const videoInputRef = ref<HTMLInputElement | null>(null);
const notesInputRef = ref<any>(null);

const form = reactive({
  title: "",
  videoKey: "",
  videoPreviewUrl: "",
  durationSec: 0,
  classNotes: "",
  sortOrder: 1,
  enabled: 1
});

const formulaDialogVisible = ref(false);
const formulaSelection = ref({ start: 0, end: 0 });
const formulaInitialLatex = ref("");

function goBack() {
  router.push("/video/index");
}

function formatDuration(sec?: number): string {
  const total = Math.max(0, Number(sec || 0));
  if (!total) return "--:--";
  const m = Math.floor(total / 60);
  const s = total % 60;
  return `${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
}

async function fetchDetail() {
  if (!seriesId.value) return;
  loading.value = true;
  try {
    const res = await getVideoSeriesDetail(seriesId.value);
    series.value = res.data.series;
    lessons.value = res.data.lessons;
  } finally {
    loading.value = false;
  }
}

function openCreateLesson() {
  editLessonId.value = null;
  form.title = `第 ${lessons.value.length + 1} 节：`;
  form.videoKey = "";
  form.videoPreviewUrl = "";
  form.durationSec = 0;
  form.classNotes = "";
  form.sortOrder = lessons.value.length + 1;
  form.enabled = 1;
  uploadProgress.value = 0;
  dialogVisible.value = true;
}

function openEditLesson(row: VideoLessonItem) {
  editLessonId.value = row.id;
  form.title = row.title;
  form.videoKey = row.videoKey || "";
  form.videoPreviewUrl = row.videoUrl || "";
  form.durationSec = row.durationSec || 0;
  form.classNotes = row.classNotes || "";
  form.sortOrder = row.sortOrder ?? 1;
  form.enabled = row.enabled ?? 1;
  uploadProgress.value = 0;
  dialogVisible.value = true;
}

function triggerVideoPick() {
  videoInputRef.value?.click();
}

async function onVideoFileChange(evt: Event) {
  const input = evt.target as HTMLInputElement;
  const file = input.files?.[0];
  input.value = "";
  if (!file) return;

  videoUploading.value = true;
  uploadProgress.value = 0;
  try {
    const fd = new FormData();
    fd.append("file", file);
    const res = await uploadVideoMedia(fd, p => {
      uploadProgress.value = p;
    });
    form.videoKey = res.data.objectKey;
    form.videoPreviewUrl = res.data.previewUrl;
    ElMessage.success("课程视频上传完成");
  } finally {
    videoUploading.value = false;
  }
}

function onPreviewVideoLoaded(evt: Event) {
  const el = evt.target as HTMLVideoElement;
  if (el && Number.isFinite(el.duration) && el.duration > 0) {
    form.durationSec = Math.round(el.duration);
  }
}

function openNotesFormulaDialog() {
  const comp = notesInputRef.value;
  const el: HTMLTextAreaElement | null = comp?.textarea || comp?.input || null;
  const current = form.classNotes;
  const start = el && typeof el.selectionStart === "number" ? el.selectionStart : current.length;
  const end = el && typeof el.selectionEnd === "number" ? el.selectionEnd : current.length;
  formulaSelection.value = { start, end };
  const selectedText = current.slice(start, end).trim();
  const matched = selectedText.match(/^\$\$?([\s\S]+?)\$\$?$/);
  formulaInitialLatex.value = matched ? matched[1].trim() : "";
  formulaDialogVisible.value = true;
}

function handleNotesFormulaInsert(formatted: string) {
  const { start, end } = formulaSelection.value;
  form.classNotes = `${form.classNotes.slice(0, start)}${formatted}${form.classNotes.slice(end)}`;
}

async function handleSaveLesson() {
  if (!form.title.trim()) {
    ElMessage.warning("请填写节标题");
    return;
  }
  if (!form.videoKey.trim()) {
    ElMessage.warning("请先上传教学视频");
    return;
  }
  saving.value = true;
  try {
    const payload = {
      title: form.title.trim(),
      videoKey: form.videoKey.trim(),
      durationSec: form.durationSec,
      classNotes: form.classNotes,
      sortOrder: form.sortOrder,
      enabled: form.enabled
    };
    if (editLessonId.value) {
      await updateVideoLesson(editLessonId.value, payload);
      ElMessage.success("课时已更新");
    } else {
      await createVideoLesson(seriesId.value, payload);
      ElMessage.success("视频课时已添加");
    }
    dialogVisible.value = false;
    fetchDetail();
  } finally {
    saving.value = false;
  }
}

async function handleDeleteLesson(row: VideoLessonItem) {
  await ElMessageBox.confirm(`确认删除课时「${row.title}」？`, "确认删除", { type: "warning" });
  await deleteVideoLesson(row.id);
  ElMessage.success("已删除");
  fetchDetail();
}

onMounted(() => {
  fetchDetail();
});
</script>

<template>
  <div v-loading="loading" class="space-y-4">
    <!-- 系列信息头部 -->
    <el-card shadow="never">
      <div class="flex flex-wrap items-center justify-between gap-4">
        <div class="flex items-center gap-4">
          <el-button plain @click="goBack">
            <GglIcon name="back" :size="15" class="mr-1" />
            返回系列列表
          </el-button>
          <el-image
            v-if="series?.coverImageUrl"
            :src="series.coverImageUrl"
            fit="cover"
            class="h-16 w-28 shrink-0 rounded-lg border border-slate-200"
          />
          <div>
            <div class="flex items-center gap-2">
              <h2 class="text-base font-bold text-slate-800">{{ series?.title || "教学系列" }}</h2>
              <el-tag size="small" type="success">{{ series?.realmName || "全境界通用" }}</el-tag>
              <el-tag size="small" type="info">共 {{ lessons.length }} 节</el-tag>
            </div>
            <p class="mt-1 text-xs text-slate-500">{{ series?.intro || "暂无介绍" }}</p>
          </div>
        </div>

        <el-button type="primary" @click="openCreateLesson">
          + 上传视频课时
        </el-button>
      </div>
    </el-card>

    <!-- 多节课时列表 -->
    <el-card shadow="never">
      <div v-if="lessons.length > 0" class="space-y-4">
        <div
          v-for="(item, idx) in lessons"
          :key="item.id"
          class="grid grid-cols-1 gap-4 rounded-xl border border-slate-200 bg-slate-50/50 p-4 lg:grid-cols-12"
        >
          <div class="lg:col-span-4">
            <video
              v-if="item.videoUrl"
              :src="item.videoUrl"
              controls
              preload="metadata"
              class="h-44 w-full rounded-lg bg-black object-contain"
            />
          </div>

          <div class="flex flex-col justify-between lg:col-span-8">
            <div>
              <div class="flex flex-wrap items-center justify-between gap-2">
                <div class="flex items-center gap-2">
                  <el-tag size="small" type="primary">第 {{ idx + 1 }} 节</el-tag>
                  <span class="text-sm font-bold text-slate-800">{{ item.title }}</span>
                  <span class="text-xs text-slate-400">时长 {{ formatDuration(item.durationSec) }}</span>
                  <el-tag size="small" :type="item.enabled === 1 ? 'success' : 'info'">
                    {{ item.enabled === 1 ? "已上架" : "已下架" }}
                  </el-tag>
                </div>

                <div class="flex items-center gap-2">
                  <el-button link type="primary" @click="openEditLesson(item)">编辑视频与笔记</el-button>
                  <el-button link type="danger" @click="handleDeleteLesson(item)">删除</el-button>
                </div>
              </div>

              <div class="mt-3 rounded-lg border border-slate-200 bg-white p-3">
                <div class="mb-1 flex items-center gap-1 text-xs font-semibold text-green-700">
                  <GglIcon name="notes" :size="14" />
                  <span>课堂笔记</span>
                </div>
                <div class="whitespace-pre-wrap text-xs leading-relaxed text-slate-700">
                  <MathFormulaText :text="item.classNotes || '（暂未编写本节课堂笔记）'" />
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <el-empty v-else description="该系列暂未上传视频课时，点击右上角「+ 上传视频课时」开始添加" />
    </el-card>

    <!-- 上传 / 编辑课时弹窗 -->
    <el-dialog
      v-model="dialogVisible"
      :title="editLessonId ? '编辑视频课时与课堂笔记' : '新增视频课时'"
      width="720px"
    >
      <el-form label-width="92px">
        <el-form-item label="课时标题" required>
          <el-input v-model="form.title" placeholder="例如：第 1 节：有理数混合运算重难点突破" maxlength="100" />
        </el-form-item>

        <el-form-item label="上传视频" required>
          <div class="w-full space-y-2.5">
            <div class="flex items-center gap-3">
              <input
                ref="videoInputRef"
                type="file"
                accept="video/mp4,video/webm,video/quicktime,.mp4,.webm,.mov"
                class="hidden"
                @change="onVideoFileChange"
              />
              <el-button type="primary" plain :loading="videoUploading" @click="triggerVideoPick">
                {{ form.videoKey ? "重新上传视频" : "选择本地视频上传" }}
              </el-button>
              <span class="text-xs text-slate-400">支持 MP4 / WEBM / MOV（最大 500MB，自动传至阿里云 OSS）</span>
            </div>

            <el-progress v-if="videoUploading" :percentage="uploadProgress" />

            <video
              v-if="form.videoPreviewUrl"
              :src="form.videoPreviewUrl"
              controls
              class="h-44 w-full rounded-lg border border-slate-200 bg-black object-contain"
              @loadedmetadata="onPreviewVideoLoaded"
            />
          </div>
        </el-form-item>

        <el-form-item label="课堂笔记">
          <div class="w-full space-y-2">
            <div class="flex items-center justify-between">
              <span class="text-xs text-slate-500">学生端在播放本节视频下方同步阅读课堂笔记</span>
              <el-button size="small" type="success" plain @click="openNotesFormulaDialog">
                + 插入数学公式
              </el-button>
            </div>
            <el-input
              ref="notesInputRef"
              v-model="form.classNotes"
              type="textarea"
              :rows="6"
              placeholder="编写本节课核心公式、解题步骤口诀与课堂要点（支持 $...$ 与 $$...$$ 数学公式）"
            />
            <div v-if="form.classNotes" class="rounded-lg border border-slate-200 bg-slate-50 p-3 text-xs text-slate-700">
              <div class="mb-1 font-semibold text-slate-500">笔记排版预览：</div>
              <div class="whitespace-pre-wrap leading-relaxed">
                <MathFormulaText :text="form.classNotes" />
              </div>
            </div>
          </div>
        </el-form-item>

        <div class="grid grid-cols-2 gap-4">
          <el-form-item label="排序序号">
            <el-input-number v-model="form.sortOrder" :min="0" :max="9999" />
          </el-form-item>
          <el-form-item label="立即上架">
            <el-switch v-model="form.enabled" :active-value="1" :inactive-value="0" />
          </el-form-item>
        </div>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" :disabled="videoUploading" @click="handleSaveLesson">
          保存课时
        </el-button>
      </template>
    </el-dialog>

    <MathFormulaDialog
      v-model="formulaDialogVisible"
      :initial-latex="formulaInitialLatex"
      target-label="课堂笔记"
      @insert="handleNotesFormulaInsert"
    />
  </div>
</template>
