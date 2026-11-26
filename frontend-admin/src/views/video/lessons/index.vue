<script setup lang="ts">
import { ref, reactive, computed, onMounted, onBeforeUnmount } from "vue";
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
  initVideoMultipart,
  uploadVideoPart,
  uploadPartDirectToOss,
  OssDirectNetworkError,
  completeVideoMultipart,
  abortVideoMultipart,
  uploadVideoCover,
  uploadNoteAttachment,
  type NoteAttachmentItem,
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
const uploadStatusText = ref("");
const coverUploading = ref(false);
const attachmentUploading = ref(false);
const coverInputRef = ref<HTMLInputElement | null>(null);
const videoInputRef = ref<HTMLInputElement | null>(null);
const attachmentInputRef = ref<HTMLInputElement | null>(null);
const notesInputRef = ref<any>(null);

let activeUploadAbort: AbortController | null = null;
let activeUploadMeta: { uploadId: string; objectKey: string } | null = null;
const lastSelectedVideoFile = ref<File | null>(null);
let coverUploadToken = 0;

const form = reactive({
  title: "",
  coverImageKey: "",
  coverPreviewUrl: "",
  videoKey: "",
  videoPreviewUrl: "",
  durationSec: 0,
  classNotes: "",
  notesAttachments: [] as NoteAttachmentItem[],
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

function formatFileSize(bytes?: number): string {
  const n = Math.max(0, Number(bytes || 0));
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KB`;
  if (n < 1024 * 1024 * 1024) return `${(n / (1024 * 1024)).toFixed(1)} MB`;
  return `${(n / (1024 * 1024 * 1024)).toFixed(2)} GB`;
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
  lastSelectedVideoFile.value = null;
  coverUploadToken += 1;
  form.title = `第 ${lessons.value.length + 1} 节：`;
  form.coverImageKey = "";
  form.coverPreviewUrl = "";
  form.videoKey = "";
  form.videoPreviewUrl = "";
  form.durationSec = 0;
  form.classNotes = "";
  form.notesAttachments = [];
  form.sortOrder = lessons.value.length + 1;
  form.enabled = 1;
  uploadProgress.value = 0;
  uploadStatusText.value = "";
  dialogVisible.value = true;
}

function openEditLesson(row: VideoLessonItem) {
  editLessonId.value = row.id;
  lastSelectedVideoFile.value = null;
  coverUploadToken += 1;
  form.title = row.title;
  form.coverImageKey = row.coverImageKey || "";
  form.coverPreviewUrl = row.coverImageUrl || "";
  form.videoKey = row.videoKey || "";
  form.videoPreviewUrl = row.videoUrl || "";
  form.durationSec = row.durationSec || 0;
  form.classNotes = row.classNotes || "";
  form.notesAttachments = (row.notesAttachments || []).map(item => ({ ...item }));
  form.sortOrder = row.sortOrder ?? 1;
  form.enabled = row.enabled ?? 1;
  uploadProgress.value = 0;
  uploadStatusText.value = "";
  dialogVisible.value = true;
}

function triggerCoverPick() {
  coverInputRef.value?.click();
}

function clearLessonCover() {
  coverUploadToken += 1;
  form.coverImageKey = "";
  form.coverPreviewUrl = "";
}

async function captureVideoFirstFrame(file: File): Promise<{ coverFile: File | null; durationSec: number }> {
  return new Promise(resolve => {
    const objectUrl = URL.createObjectURL(file);
    const video = document.createElement("video");
    video.muted = true;
    video.playsInline = true;
    video.preload = "auto";

    let settled = false;
    let durationSec = 0;

    const cleanup = () => {
      video.onloadedmetadata = null;
      video.onloadeddata = null;
      video.onseeked = null;
      video.onerror = null;
      video.pause();
      video.removeAttribute("src");
      video.load();
      URL.revokeObjectURL(objectUrl);
    };

    const finish = (coverFile: File | null) => {
      if (settled) return;
      settled = true;
      window.clearTimeout(hardTimer);
      cleanup();
      resolve({ coverFile, durationSec });
    };

    const grabCurrentFrame = () => {
      try {
        const vw = video.videoWidth || 0;
        const vh = video.videoHeight || 0;
        if (vw <= 0 || vh <= 0) {
          finish(null);
          return;
        }
        const maxWidth = 1280;
        const scale = vw > maxWidth ? maxWidth / vw : 1;
        const canvas = document.createElement("canvas");
        canvas.width = Math.max(1, Math.round(vw * scale));
        canvas.height = Math.max(1, Math.round(vh * scale));
        const ctx = canvas.getContext("2d");
        if (!ctx) {
          finish(null);
          return;
        }
        ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
        canvas.toBlob(
          blob => {
            if (!blob || blob.size === 0) {
              finish(null);
              return;
            }
            const baseName = file.name.replace(/\.[^.]+$/, "") || "video";
            const coverFile = new File([blob], `${baseName}-first-frame.jpg`, {
              type: "image/jpeg"
            });
            finish(coverFile);
          },
          "image/jpeg",
          0.86
        );
      } catch {
        finish(null);
      }
    };

    const hardTimer = window.setTimeout(() => {
      if (video.readyState >= 2 && video.videoWidth > 0) {
        grabCurrentFrame();
      } else {
        finish(null);
      }
    }, 8000);

    video.onloadedmetadata = () => {
      if (Number.isFinite(video.duration) && video.duration > 0) {
        durationSec = Math.round(video.duration);
      }
    };

    video.onloadeddata = () => {
      if (Number.isFinite(video.duration) && video.duration > 0) {
        durationSec = Math.round(video.duration);
      }
      const targetTime = Number.isFinite(video.duration) && video.duration > 0.25 ? 0.1 : 0;
      if (targetTime > 0 && Math.abs(video.currentTime - targetTime) > 0.02) {
        let seekFallbackTimer = 0;
        video.onseeked = () => {
          window.clearTimeout(seekFallbackTimer);
          grabCurrentFrame();
        };
        seekFallbackTimer = window.setTimeout(() => {
          grabCurrentFrame();
        }, 1500);
        try {
          video.currentTime = targetTime;
        } catch {
          window.clearTimeout(seekFallbackTimer);
          grabCurrentFrame();
        }
      } else {
        grabCurrentFrame();
      }
    };

    video.onerror = () => finish(null);
    video.src = objectUrl;
    video.load();
  });
}

async function autoGenerateFirstFrameCover(file: File, force = false) {
  if (!force && form.coverImageKey.trim()) {
    return;
  }
  const token = ++coverUploadToken;
  coverUploading.value = true;
  try {
    const { coverFile, durationSec } = await captureVideoFirstFrame(file);
    if (durationSec > 0 && form.durationSec <= 0) {
      form.durationSec = durationSec;
    }
    if (!coverFile || !dialogVisible.value || token !== coverUploadToken) {
      return;
    }
    if (!force && form.coverImageKey.trim()) {
      return;
    }
    const fd = new FormData();
    fd.append("file", coverFile);
    const res = await uploadVideoCover(fd);
    if (!dialogVisible.value || token !== coverUploadToken) {
      return;
    }
    if (!force && form.coverImageKey.trim()) {
      return;
    }
    form.coverImageKey = res.data.objectKey;
    form.coverPreviewUrl = res.data.previewUrl;
    ElMessage.success(force ? "已重新截取视频首帧作为封面" : "未设置封面，已自动截取视频首帧作为封面");
  } catch {
    if (force) {
      ElMessage.warning("截取视频首帧失败，请手动上传封面图");
    }
  } finally {
    if (token === coverUploadToken) {
      coverUploading.value = false;
    }
  }
}

async function onCoverFileChange(evt: Event) {
  const input = evt.target as HTMLInputElement;
  const file = input.files?.[0];
  input.value = "";
  if (!file) return;

  const token = ++coverUploadToken;
  coverUploading.value = true;
  try {
    const fd = new FormData();
    fd.append("file", file);
    const res = await uploadVideoCover(fd);
    if (token !== coverUploadToken) return;
    form.coverImageKey = res.data.objectKey;
    form.coverPreviewUrl = res.data.previewUrl;
    ElMessage.success("小节封面上传成功");
  } finally {
    if (token === coverUploadToken) {
      coverUploading.value = false;
    }
  }
}

function triggerVideoPick() {
  videoInputRef.value?.click();
}

function cancelVideoUpload() {
  activeUploadAbort?.abort();
  if (activeUploadMeta) {
    void abortVideoMultipart(activeUploadMeta).catch(() => {});
  }
}

function onDialogClosed() {
  lastSelectedVideoFile.value = null;
  coverUploadToken += 1;
  if (videoUploading.value) {
    cancelVideoUpload();
  }
}

function formatUploadSpeed(bytesPerSec: number): string {
  if (!Number.isFinite(bytesPerSec) || bytesPerSec <= 0) return "";
  if (bytesPerSec < 1024) return `${Math.round(bytesPerSec)} B/s`;
  if (bytesPerSec < 1024 * 1024) return `${(bytesPerSec / 1024).toFixed(1)} KB/s`;
  return `${(bytesPerSec / (1024 * 1024)).toFixed(2)} MB/s`;
}

async function uploadPartViaServer(
  uploadId: string,
  objectKey: string,
  partNumber: number,
  blob: Blob,
  signal: AbortSignal,
  onPartProgress: (loadedBytes: number) => void
): Promise<{ partNumber: number; eTag: string }> {
  const fd = new FormData();
  fd.append("uploadId", uploadId);
  fd.append("objectKey", objectKey);
  fd.append("partNumber", String(partNumber));
  fd.append("file", blob, `part_${partNumber}`);
  const partRes = await uploadVideoPart(fd, {
    signal,
    onProgress: loaded => onPartProgress(Math.min(blob.size, loaded))
  });
  onPartProgress(blob.size);
  return partRes.data;
}

async function onVideoFileChange(evt: Event) {
  const input = evt.target as HTMLInputElement;
  const file = input.files?.[0];
  input.value = "";
  if (!file) return;

  lastSelectedVideoFile.value = file;
  if (!form.coverImageKey.trim()) {
    void autoGenerateFirstFrameCover(file, false);
  }

  videoUploading.value = true;
  uploadProgress.value = 0;
  uploadStatusText.value = `正在初始化分片上传（${formatFileSize(file.size)}）...`;

  const abortController = new AbortController();
  activeUploadAbort = abortController;
  activeUploadMeta = null;

  try {
    const initRes = await initVideoMultipart({
      fileName: file.name,
      contentType: file.type || "video/mp4",
      fileSize: file.size
    });
    const {
      uploadId,
      objectKey,
      chunkSize,
      directUpload,
      partContentType,
      partUploadUrls
    } = initRes.data;
    activeUploadMeta = { uploadId, objectKey };

    const sliceSize = chunkSize || 5 * 1024 * 1024;
    const totalChunks = Math.max(1, Math.ceil(file.size / sliceSize));
    const partUrlMap = new Map<number, string>();
    for (const item of partUploadUrls || []) {
      if (item?.partNumber && item?.uploadUrl) {
        partUrlMap.set(item.partNumber, item.uploadUrl);
      }
    }

    let useDirectOss = Boolean(directUpload && partUrlMap.size >= totalChunks);
    let directSuccessCount = 0;
    let corsFallbackNotified = false;

    const chunkLoadedBytes = new Array<number>(totalChunks).fill(0);
    const completedParts = new Array<{ partNumber: number; eTag: string }>(totalChunks);
    let finishedChunks = 0;
    const uploadStartedAt = Date.now();

    const refreshProgress = () => {
      const uploadedBytes = chunkLoadedBytes.reduce((sum, n) => sum + n, 0);
      const pct = Math.min(98, Math.round((uploadedBytes * 98) / Math.max(1, file.size)));
      uploadProgress.value = pct;
      const elapsedSec = (Date.now() - uploadStartedAt) / 1000;
      const speedLabel = elapsedSec >= 0.4 ? formatUploadSpeed(uploadedBytes / elapsedSec) : "";
      const modeLabel = useDirectOss ? "OSS 直传并发中" : "服务器中转上传中";
      const speedSuffix = speedLabel ? ` · ${speedLabel}` : "";
      uploadStatusText.value = `${modeLabel}：${finishedChunks} / ${totalChunks} 片（${formatFileSize(uploadedBytes)} / ${formatFileSize(file.size)}${speedSuffix}）`;
    };

    const uploadOnePartWithRetry = async (
      partNumber: number,
      blob: Blob,
      onPartProgress: (loaded: number) => void
    ): Promise<{ partNumber: number; eTag: string }> => {
      const maxAttempts = 3;
      let fallbackUsedThisPart = false;
      for (let attempt = 1; attempt <= maxAttempts; attempt++) {
        if (abortController.signal.aborted) {
          throw new DOMException("Upload aborted", "AbortError");
        }
        try {
          const directUrl = useDirectOss ? partUrlMap.get(partNumber) : undefined;
          if (directUrl) {
            const directRes = await uploadPartDirectToOss({
              uploadUrl: directUrl,
              partNumber,
              blob,
              contentType: partContentType || "application/octet-stream",
              signal: abortController.signal,
              onProgress: loaded => onPartProgress(Math.min(blob.size, loaded))
            });
            directSuccessCount += 1;
            return directRes;
          }
          return await uploadPartViaServer(
            uploadId,
            objectKey,
            partNumber,
            blob,
            abortController.signal,
            onPartProgress
          );
        } catch (err) {
          const errName = (err as Error)?.name;
          if (abortController.signal.aborted || errName === "AbortError" || errName === "CanceledError") {
            throw err;
          }
          onPartProgress(0);
          if (err instanceof OssDirectNetworkError && directSuccessCount === 0 && !fallbackUsedThisPart) {
            fallbackUsedThisPart = true;
            useDirectOss = false;
            attempt -= 1;
            if (!corsFallbackNotified) {
              corsFallbackNotified = true;
              ElMessage.warning("当前无法浏览器直传 OSS（请检查 OSS 跨域 CORS 配置），已自动切换服务器中转继续上传");
            }
            continue;
          }
          if (attempt === maxAttempts) {
            throw err;
          }
        }
      }
      throw new Error(`分片 ${partNumber} 上传失败`);
    };

    refreshProgress();

    let nextIdx = 0;
    const concurrency = Math.min(useDirectOss ? 4 : 3, totalChunks);
    const worker = async () => {
      while (nextIdx < totalChunks) {
        const idx = nextIdx++;
        if (abortController.signal.aborted) return;
        const start = idx * sliceSize;
        const end = Math.min(file.size, start + sliceSize);
        const chunkBlob = file.slice(start, end);
        const result = await uploadOnePartWithRetry(idx + 1, chunkBlob, loaded => {
          chunkLoadedBytes[idx] = loaded;
          refreshProgress();
        });
        completedParts[idx] = result;
        finishedChunks += 1;
        refreshProgress();
      }
    };

    await Promise.all(Array.from({ length: concurrency }, () => worker()));

    if (abortController.signal.aborted) {
      return;
    }

    uploadProgress.value = 99;
    uploadStatusText.value = `分片上传完成，正在合并 ${totalChunks} 个视频分片...`;
    const completeRes = await completeVideoMultipart({
      uploadId,
      objectKey,
      parts: completedParts
    });

    form.videoKey = completeRes.data.objectKey;
    form.videoPreviewUrl = completeRes.data.previewUrl;
    uploadProgress.value = 100;
    const usedModeText = directSuccessCount > 0 ? "OSS 直传" : "服务器中转";
    uploadStatusText.value = `上传完成（${usedModeText} · ${totalChunks} 片 · ${formatFileSize(file.size)}）`;
    ElMessage.success(`课程视频${usedModeText}上传完成`);
    activeUploadMeta = null;
  } catch (err: any) {
    if (abortController.signal.aborted || err?.name === "AbortError" || err?.name === "CanceledError") {
      uploadStatusText.value = "已取消视频分片上传";
      ElMessage.info("已取消上传");
    } else {
      if (activeUploadMeta) {
        void abortVideoMultipart(activeUploadMeta).catch(() => {});
      }
      const msg = err?.message || "分片上传失败，请重试";
      uploadStatusText.value = msg;
      ElMessage.error(msg);
    }
  } finally {
    videoUploading.value = false;
    activeUploadAbort = null;
    activeUploadMeta = null;
  }
}

function triggerAttachmentPick() {
  attachmentInputRef.value?.click();
}

async function onAttachmentFileChange(evt: Event) {
  const input = evt.target as HTMLInputElement;
  const files = input.files ? Array.from(input.files) : [];
  input.value = "";
  if (files.length === 0) return;

  attachmentUploading.value = true;
  try {
    for (const file of files) {
      const fd = new FormData();
      fd.append("file", file);
      const res = await uploadNoteAttachment(fd);
      form.notesAttachments.push({
        name: res.data.name,
        objectKey: res.data.objectKey,
        url: res.data.previewUrl,
        size: res.data.size,
        contentType: res.data.contentType
      });
    }
    ElMessage.success(`成功上传 ${files.length} 个课堂附件`);
  } finally {
    attachmentUploading.value = false;
  }
}

function removeAttachment(idx: number) {
  form.notesAttachments.splice(idx, 1);
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
      coverImageKey: form.coverImageKey.trim(),
      videoKey: form.videoKey.trim(),
      durationSec: form.durationSec,
      classNotes: form.classNotes,
      notesAttachments: form.notesAttachments.map(att => ({
        name: att.name,
        objectKey: att.objectKey,
        size: att.size,
        contentType: att.contentType
      })),
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

onBeforeUnmount(() => {
  cancelVideoUpload();
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
              <el-tag size="small" type="success">{{ series?.realmName || "全年级通用" }}</el-tag>
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

    <!-- 多节课时列表（5 列宫格） -->
    <el-card shadow="never">
      <div
        v-if="lessons.length > 0"
        class="grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5"
      >
        <div
          v-for="(item, idx) in lessons"
          :key="item.id"
          class="flex flex-col overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm transition hover:border-green-500/60 hover:shadow-md"
        >
          <div class="relative aspect-video w-full overflow-hidden bg-black">
            <video
              v-if="item.videoUrl"
              :src="item.videoUrl"
              :poster="item.coverImageUrl || series?.coverImageUrl || undefined"
              controls
              preload="metadata"
              class="h-full w-full object-contain"
            />
            <div class="pointer-events-none absolute left-2 top-2 rounded bg-black/65 px-2 py-0.5 text-[11px] font-medium text-white">
              第 {{ idx + 1 }} 节
            </div>
            <div class="pointer-events-none absolute right-2 top-2">
              <el-tag size="small" :type="item.enabled === 1 ? 'success' : 'info'">
                {{ item.enabled === 1 ? "已上架" : "已下架" }}
              </el-tag>
            </div>
          </div>

          <div class="flex flex-1 flex-col gap-1.5 p-3">
            <div class="line-clamp-1 text-sm font-bold text-slate-800" :title="item.title">
              {{ item.title }}
            </div>

            <div class="flex flex-wrap items-center gap-1.5 text-[11px] text-slate-500">
              <span>时长 {{ formatDuration(item.durationSec) }}</span>
              <span v-if="item.coverImageUrl" class="rounded bg-green-50 px-1.5 py-0.5 text-green-700">
                小节封面
              </span>
              <span
                v-if="item.notesAttachments && item.notesAttachments.length > 0"
                class="rounded bg-slate-100 px-1.5 py-0.5 text-slate-600"
              >
                {{ item.notesAttachments.length }} 附件
              </span>
            </div>

            <div class="mt-0.5 flex-1 rounded-lg border border-slate-100 bg-slate-50/70 p-2">
              <div class="line-clamp-2 text-xs leading-relaxed text-slate-600">
                <MathFormulaText :text="item.classNotes || '暂未填写课堂笔记'" />
              </div>
              <div
                v-if="item.notesAttachments && item.notesAttachments.length > 0"
                class="mt-1.5 flex flex-wrap gap-1 border-t border-slate-200/70 pt-1.5"
              >
                <a
                  v-for="(att, aIdx) in item.notesAttachments"
                  :key="`${item.id}-att-${aIdx}`"
                  :href="att.url"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="inline-flex max-w-full items-center gap-1 rounded border border-slate-200 bg-white px-1.5 py-0.5 text-[11px] text-slate-700 transition hover:border-green-500 hover:text-green-700"
                >
                  <span class="max-w-[110px] truncate">{{ att.name }}</span>
                </a>
              </div>
            </div>
          </div>

          <div class="mt-auto flex items-center justify-between border-t border-slate-100 bg-slate-50/70 px-3 py-2">
            <el-button link size="small" type="primary" @click="openEditLesson(item)">编辑视频与笔记</el-button>
            <el-button link size="small" type="danger" @click="handleDeleteLesson(item)">删除</el-button>
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
      @closed="onDialogClosed"
    >
      <el-form label-width="92px">
        <el-form-item label="课时标题" required>
          <el-input v-model="form.title" placeholder="例如：第 1 节：有理数混合运算重难点突破" maxlength="100" />
        </el-form-item>

        <el-form-item label="小节封面">
          <div class="flex flex-wrap items-center gap-4">
            <el-image
              v-if="form.coverPreviewUrl"
              :src="form.coverPreviewUrl"
              fit="cover"
              class="h-20 w-36 rounded-lg border border-slate-200"
            />
            <div
              v-else
              class="flex h-20 w-36 items-center justify-center rounded-lg border border-dashed border-slate-300 bg-slate-50 text-xs text-slate-400"
            >
              16:9 小节封面
            </div>
            <div class="space-y-1.5">
              <input
                ref="coverInputRef"
                type="file"
                accept="image/png,image/jpeg,image/webp"
                class="hidden"
                @change="onCoverFileChange"
              />
              <div class="flex flex-wrap items-center gap-2">
                <el-button :loading="coverUploading" plain @click="triggerCoverPick">
                  {{ form.coverImageKey ? "更换小节封面" : "上传小节封面" }}
                </el-button>
                <el-button
                  v-if="lastSelectedVideoFile"
                  :loading="coverUploading"
                  plain
                  type="success"
                  @click="autoGenerateFirstFrameCover(lastSelectedVideoFile, true)"
                >
                  截取视频首帧
                </el-button>
                <el-button v-if="form.coverImageKey" link type="danger" @click="clearLessonCover">
                  清除
                </el-button>
              </div>
              <div class="text-xs text-slate-400">支持 PNG/JPG/WEBP；未手动上传封面时，上传视频将自动截取视频首帧作为封面（系列无封面时也会自动同步）</div>
            </div>
          </div>
        </el-form-item>

        <el-form-item label="上传视频" required>
          <div class="w-full space-y-2.5">
            <div class="flex flex-wrap items-center gap-3">
              <input
                ref="videoInputRef"
                type="file"
                accept="video/mp4,video/webm,video/quicktime,.mp4,.webm,.mov"
                class="hidden"
                @change="onVideoFileChange"
              />
              <el-button type="primary" plain :loading="videoUploading" @click="triggerVideoPick">
                {{ form.videoKey ? "重新分片上传" : "选择本地视频（分片上传）" }}
              </el-button>
              <el-button v-if="videoUploading" type="danger" plain size="small" @click="cancelVideoUpload">
                取消上传
              </el-button>
              <span class="text-xs text-slate-400">支持 MP4 / WEBM / MOV（最大 2GB，自动 5MB 并发分片直传 OSS）</span>
            </div>

            <div v-if="videoUploading || uploadStatusText" class="space-y-1">
              <el-progress v-if="videoUploading || uploadProgress > 0" :percentage="uploadProgress" />
              <div v-if="uploadStatusText" class="text-xs text-slate-500">{{ uploadStatusText }}</div>
            </div>

            <video
              v-if="form.videoPreviewUrl"
              :src="form.videoPreviewUrl"
              controls
              class="h-44 w-full rounded-lg border border-slate-200 bg-black object-contain"
              @loadedmetadata="onPreviewVideoLoaded"
            />
          </div>
        </el-form-item>

        <el-form-item label="笔记备注">
          <div class="w-full space-y-2">
            <div class="flex items-center justify-between">
              <span class="text-xs text-slate-500">学生端在播放本节视频下方同步阅读课堂备注</span>
              <el-button size="small" type="success" plain @click="openNotesFormulaDialog">
                + 插入数学公式
              </el-button>
            </div>
            <el-input
              ref="notesInputRef"
              v-model="form.classNotes"
              type="textarea"
              :rows="5"
              placeholder="编写本节课核心公式、解题步骤口诀与课堂要点（支持 $...$ 与 $$...$$ 数学公式）"
            />
            <div v-if="form.classNotes" class="rounded-lg border border-slate-200 bg-slate-50 p-3 text-xs text-slate-700">
              <div class="mb-1 font-semibold text-slate-500">备注排版预览：</div>
              <div class="whitespace-pre-wrap leading-relaxed">
                <MathFormulaText :text="form.classNotes" />
              </div>
            </div>
          </div>
        </el-form-item>

        <el-form-item label="课堂附件">
          <div class="w-full space-y-2.5">
            <div class="flex flex-wrap items-center gap-3">
              <input
                ref="attachmentInputRef"
                type="file"
                multiple
                accept=".png,.jpg,.jpeg,.webp,.gif,.pdf,.doc,.docx,.ppt,.pptx,.xls,.xlsx,.txt,.md,.zip"
                class="hidden"
                @change="onAttachmentFileChange"
              />
              <el-button plain :loading="attachmentUploading" @click="triggerAttachmentPick">
                + 上传笔记附件
              </el-button>
              <span class="text-xs text-slate-400">
                支持 PDF / Word / PPT / Excel / 图片 / TXT / ZIP（可多选，单个 50MB 内）
              </span>
            </div>

            <div v-if="form.notesAttachments.length > 0" class="space-y-1.5">
              <div
                v-for="(att, idx) in form.notesAttachments"
                :key="`${att.objectKey}-${idx}`"
                class="flex items-center justify-between rounded-lg border border-slate-200 bg-slate-50 px-3 py-2 text-xs"
              >
                <div class="flex min-w-0 items-center gap-2">
                  <span class="truncate font-medium text-slate-800">{{ att.name }}</span>
                  <span class="shrink-0 text-slate-400">{{ formatFileSize(att.size) }}</span>
                </div>
                <div class="flex shrink-0 items-center gap-2">
                  <a
                    v-if="att.url"
                    :href="att.url"
                    target="_blank"
                    rel="noopener noreferrer"
                    class="text-green-600 hover:underline"
                  >
                    预览/下载
                  </a>
                  <el-button link type="danger" size="small" @click="removeAttachment(idx)">移除</el-button>
                </div>
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
        <el-button type="primary" :loading="saving" :disabled="coverUploading || videoUploading || attachmentUploading" @click="handleSaveLesson">
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
