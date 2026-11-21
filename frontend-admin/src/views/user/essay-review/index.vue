<script setup lang="ts">
import { ref, reactive, computed, onMounted, onBeforeUnmount, nextTick } from "vue";
import { useRoute, useRouter } from "vue-router";
import { ElMessage } from "element-plus";
import MathFormulaText from "@/components/MathFormulaText.vue";
import GglIcon from "@/components/GglIcon/index.vue";
import {
  getEssayAnswerDetail,
  getEssayAnswerImageBlob,
  uploadEssayReviewImage,
  reviewEssayAnswer,
  type EssayAnswerItem
} from "@/api/guoguanla";

defineOptions({
  name: "UserEssayReview"
});

interface Point {
  x: number;
  y: number;
}

interface Stroke {
  color: string;
  width: number;
  eraser: boolean;
  points: Point[];
}

const PEN_COLORS = [
  { label: "批改红", value: "#ef4444" },
  { label: "讲解蓝", value: "#2563eb" },
  { label: "过关绿", value: "#16a34a" },
  { label: "炭黑", value: "#111827" }
];
const QUICK_COMMENTS = [
  "步骤严谨规范，继续保持！",
  "解题思路正确，注意格式细节。",
  "思路偏差或计算有误，请参考答案重新订正。",
  "缺少关键推导步骤，请补齐后再提交。"
];

const IMAGE_PAD = 40;
const MIN_ZOOM = 0.35;
const MAX_ZOOM = 2.6;
const MAX_WORLD_SIZE = 4400;
const MAX_EXPORT_DIM = 2400;

const route = useRoute();
const router = useRouter();
const essayId = computed(() => Number(route.params.essayId || 0));

const loading = ref(false);
const saving = ref(false);
const essay = ref<EssayAnswerItem | null>(null);

const reviewForm = reactive({
  teacherStatus: 1 as 1 | 2,
  teacherComment: ""
});

// 无限自动延申批改视口 + 独立墨迹离屏画布（橡皮擦仅擦除老师批注，不损学生原卷）
const stageHostRef = ref<HTMLElement | null>(null);
const viewCanvasRef = ref<HTMLCanvasElement | null>(null);

const viewWidth = ref(960);
const viewHeight = ref(640);
const worldWidth = ref(1200);
const worldHeight = ref(900);
const camera = reactive({
  panX: 24,
  panY: 20,
  zoom: 1
});

const imgDrawRect = reactive({
  x: IMAGE_PAD,
  y: IMAGE_PAD,
  w: 0,
  h: 0
});
const baseImageEl = ref<HTMLImageElement | null>(null);
const baseObjectUrl = ref("");

const activeColor = ref("#ef4444");
const lineWidth = ref(4);
const eraserMode = ref(false);
const handMode = ref(false);
const spacePressed = ref(false);
const panning = ref(false);
const extendHint = ref("");
const strokes = ref<Stroke[]>([]);

let inkCanvas: HTMLCanvasElement | null = null;
let resizeObserver: ResizeObserver | null = null;
let drawing = false;
let currentStroke: Stroke | null = null;
let strokeMaxX = 0;
let strokeMaxY = 0;
let panLastScreen: Point = { x: 0, y: 0 };
let extendTimer: ReturnType<typeof setTimeout> | null = null;

const effectiveHandMode = computed(() => handMode.value || spacePressed.value);

function notifyExtend(msg: string) {
  extendHint.value = msg;
  if (extendTimer) clearTimeout(extendTimer);
  extendTimer = setTimeout(() => {
    extendHint.value = "";
    extendTimer = null;
  }, 1800);
}

function revokeObjectUrl() {
  if (baseObjectUrl.value) {
    URL.revokeObjectURL(baseObjectUrl.value);
    baseObjectUrl.value = "";
  }
}

function ensureInkCanvasSize() {
  if (!inkCanvas) {
    inkCanvas = document.createElement("canvas");
  }
  if (inkCanvas.width !== worldWidth.value || inkCanvas.height !== worldHeight.value) {
    inkCanvas.width = worldWidth.value;
    inkCanvas.height = worldHeight.value;
    renderInkLayer();
  }
}

function drawStrokeOnCtx(ctx: CanvasRenderingContext2D, s: Stroke, scale = 1, offsetX = 0, offsetY = 0) {
  if (!s.points.length) return;
  ctx.save();
  ctx.globalCompositeOperation = s.eraser ? "destination-out" : "source-over";
  ctx.strokeStyle = s.eraser ? "#000000" : s.color;
  ctx.fillStyle = s.eraser ? "#000000" : s.color;
  ctx.lineWidth = Math.max(1, s.width * scale);
  ctx.lineCap = "round";
  ctx.lineJoin = "round";

  const map = (p: Point): Point => ({
    x: (p.x - offsetX) * scale,
    y: (p.y - offsetY) * scale
  });

  if (s.points.length === 1) {
    const p0 = map(s.points[0]);
    ctx.beginPath();
    ctx.arc(p0.x, p0.y, Math.max(1, s.width * scale) / 2, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
    return;
  }

  const p0 = map(s.points[0]);
  ctx.beginPath();
  ctx.moveTo(p0.x, p0.y);
  for (let i = 1; i < s.points.length - 1; i++) {
    const pi = map(s.points[i]);
    const pNext = map(s.points[i + 1]);
    ctx.quadraticCurveTo(pi.x, pi.y, (pi.x + pNext.x) / 2, (pi.y + pNext.y) / 2);
  }
  const last = map(s.points[s.points.length - 1]);
  ctx.lineTo(last.x, last.y);
  ctx.stroke();
  ctx.restore();
}

function renderInkLayer() {
  if (!inkCanvas) return;
  const ctx = inkCanvas.getContext("2d");
  if (!ctx) return;
  ctx.clearRect(0, 0, inkCanvas.width, inkCanvas.height);
  for (const s of strokes.value) {
    drawStrokeOnCtx(ctx, s);
  }
}

function renderViewport() {
  const canvas = viewCanvasRef.value;
  if (!canvas) return;
  const dpr = Math.min(2, window.devicePixelRatio || 1);
  const pw = Math.max(1, Math.round(viewWidth.value * dpr));
  const ph = Math.max(1, Math.round(viewHeight.value * dpr));
  if (canvas.width !== pw || canvas.height !== ph) {
    canvas.width = pw;
    canvas.height = ph;
  }
  const ctx = canvas.getContext("2d");
  if (!ctx) return;

  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  // 工作台深浅对比底色
  ctx.fillStyle = "#e2e8f0";
  ctx.fillRect(0, 0, viewWidth.value, viewHeight.value);

  ctx.save();
  ctx.translate(camera.panX, camera.panY);
  ctx.scale(camera.zoom, camera.zoom);

  // 可自动延申白纸
  ctx.shadowColor = "rgba(15, 23, 42, 0.10)";
  ctx.shadowBlur = 18;
  ctx.shadowOffsetY = 4;
  ctx.fillStyle = "#ffffff";
  ctx.fillRect(0, 0, worldWidth.value, worldHeight.value);
  ctx.shadowColor = "transparent";
  ctx.shadowBlur = 0;
  ctx.shadowOffsetY = 0;

  ctx.strokeStyle = "#cbd5e1";
  ctx.lineWidth = 1 / camera.zoom;
  ctx.strokeRect(0, 0, worldWidth.value, worldHeight.value);

  // 学生作答原图
  if (baseImageEl.value && imgDrawRect.w > 0 && imgDrawRect.h > 0) {
    ctx.drawImage(baseImageEl.value, imgDrawRect.x, imgDrawRect.y, imgDrawRect.w, imgDrawRect.h);
    const guideY = imgDrawRect.y + imgDrawRect.h + 16;
    ctx.save();
    ctx.strokeStyle = "#e2e8f0";
    ctx.setLineDash([8, 6]);
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(IMAGE_PAD, guideY);
    ctx.lineTo(worldWidth.value - IMAGE_PAD, guideY);
    ctx.stroke();
    ctx.fillStyle = "#94a3b8";
    ctx.font = "12px sans-serif";
    ctx.fillText("以下空白区支持自由书写与自动延申讲解（导出自动包含全部笔迹）", IMAGE_PAD, guideY + 20);
    ctx.restore();
  }

  // 叠加老师批注墨迹层
  if (inkCanvas) {
    ctx.drawImage(inkCanvas, 0, 0);
  }
  ctx.restore();
}

function clampPan() {
  const scaledW = worldWidth.value * camera.zoom;
  const scaledH = worldHeight.value * camera.zoom;
  const padX = Math.max(80, Math.round(viewWidth.value * 0.18));
  const padY = Math.max(80, Math.round(viewHeight.value * 0.18));
  const minX = Math.min(padX, viewWidth.value - scaledW - padX);
  const maxX = Math.max(padX, viewWidth.value - 120);
  const minY = Math.min(padY, viewHeight.value - scaledH - padY);
  const maxY = Math.max(padY, viewHeight.value - 120);
  camera.panX = Math.max(minX, Math.min(maxX, camera.panX));
  camera.panY = Math.max(minY, Math.min(maxY, camera.panY));
}

function fitSheetToView() {
  const fitW = imgDrawRect.w > 0 ? imgDrawRect.w + IMAGE_PAD * 2 + 120 : worldWidth.value;
  const nextZoom = Math.max(
    0.45,
    Math.min(1, Number(((viewWidth.value - 48) / Math.max(400, fitW)).toFixed(2)))
  );
  camera.zoom = nextZoom;
  camera.panX = Math.max(20, Math.round((viewWidth.value - worldWidth.value * nextZoom) / 2));
  camera.panY = 18;
  clampPan();
  renderViewport();
}

function adjustZoom(delta: number, centerX?: number, centerY?: number) {
  const oldZoom = camera.zoom;
  const nextZoom = Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, Number((oldZoom + delta).toFixed(2))));
  if (nextZoom === oldZoom) return;
  const cx = centerX ?? viewWidth.value / 2;
  const cy = centerY ?? viewHeight.value / 2;
  const wx = (cx - camera.panX) / oldZoom;
  const wy = (cy - camera.panY) / oldZoom;
  camera.zoom = nextZoom;
  camera.panX = cx - wx * nextZoom;
  camera.panY = cy - wy * nextZoom;
  clampPan();
  renderViewport();
}

function extendPaper(dir: "down" | "right") {
  if (dir === "down") {
    if (worldHeight.value >= MAX_WORLD_SIZE) return;
    worldHeight.value = Math.min(MAX_WORLD_SIZE, worldHeight.value + 480);
    ensureInkCanvasSize();
    camera.panY -= 260;
    clampPan();
    renderViewport();
    notifyExtend(`画板已向下延申（${worldWidth.value}×${worldHeight.value}）`);
  } else {
    if (worldWidth.value >= MAX_WORLD_SIZE) return;
    worldWidth.value = Math.min(MAX_WORLD_SIZE, worldWidth.value + 480);
    ensureInkCanvasSize();
    camera.panX -= 260;
    clampPan();
    renderViewport();
    notifyExtend(`画板已向右延申（${worldWidth.value}×${worldHeight.value}）`);
  }
}

function ensurePaperCovers(wx: number, wy: number): boolean {
  let grew = false;
  if (wx > worldWidth.value - 90 && worldWidth.value < MAX_WORLD_SIZE) {
    worldWidth.value = Math.min(MAX_WORLD_SIZE, Math.max(worldWidth.value + 480, Math.ceil((wx + 480) / 80) * 80));
    grew = true;
  }
  if (wy > worldHeight.value - 90 && worldHeight.value < MAX_WORLD_SIZE) {
    worldHeight.value = Math.min(MAX_WORLD_SIZE, Math.max(worldHeight.value + 480, Math.ceil((wy + 480) / 80) * 80));
    grew = true;
  }
  if (grew) {
    ensureInkCanvasSize();
  }
  return grew;
}

function screenToStage(e: MouseEvent | PointerEvent): Point {
  const rect = viewCanvasRef.value!.getBoundingClientRect();
  return { x: e.clientX - rect.left, y: e.clientY - rect.top };
}

function screenToWorld(sx: number, sy: number): Point {
  return {
    x: Math.max(0, Math.min(MAX_WORLD_SIZE, (sx - camera.panX) / camera.zoom)),
    y: Math.max(0, Math.min(MAX_WORLD_SIZE, (sy - camera.panY) / camera.zoom))
  };
}

function onPointerDown(e: PointerEvent) {
  if (!viewCanvasRef.value) return;
  viewCanvasRef.value.setPointerCapture(e.pointerId);
  const sPt = screenToStage(e);

  if (e.button === 1 || effectiveHandMode.value) {
    panning.value = true;
    panLastScreen = sPt;
    return;
  }
  if (e.button !== 0 && e.pointerType === "mouse") return;

  const wPt = screenToWorld(sPt.x, sPt.y);
  if (!eraserMode.value) {
    ensurePaperCovers(wPt.x, wPt.y);
  }
  drawing = true;
  strokeMaxX = wPt.x;
  strokeMaxY = wPt.y;
  currentStroke = {
    color: activeColor.value,
    width: eraserMode.value ? Math.max(18, lineWidth.value * 4) : lineWidth.value,
    eraser: eraserMode.value,
    points: [wPt]
  };
  strokes.value.push(currentStroke);
  ensureInkCanvasSize();
  if (inkCanvas) {
    const inkCtx = inkCanvas.getContext("2d");
    if (inkCtx) drawStrokeOnCtx(inkCtx, currentStroke);
  }
  renderViewport();
}

function onPointerMove(e: PointerEvent) {
  const sPt = screenToStage(e);
  if (panning.value) {
    camera.panX += sPt.x - panLastScreen.x;
    camera.panY += sPt.y - panLastScreen.y;
    panLastScreen = sPt;
    clampPan();
    renderViewport();
    return;
  }
  if (!drawing || !currentStroke) return;

  const wPt = screenToWorld(sPt.x, sPt.y);
  const prev = currentStroke.points[currentStroke.points.length - 1];
  if (prev && Math.hypot(wPt.x - prev.x, wPt.y - prev.y) < 1.5) return;

  if (!currentStroke.eraser) {
    ensurePaperCovers(wPt.x, wPt.y);
  }
  if (wPt.x > strokeMaxX) strokeMaxX = wPt.x;
  if (wPt.y > strokeMaxY) strokeMaxY = wPt.y;

  currentStroke.points.push(wPt);
  renderInkLayer();
  renderViewport();
}

function onPointerUp(e: PointerEvent) {
  if (panning.value) {
    panning.value = false;
  }
  if (drawing && currentStroke && !currentStroke.eraser) {
    const endScreenY = camera.panY + strokeMaxY * camera.zoom;
    const endScreenX = camera.panX + strokeMaxX * camera.zoom;
    let shifted = false;
    let msg = "";
    if (endScreenY > viewHeight.value - 48 && worldHeight.value < MAX_WORLD_SIZE) {
      worldHeight.value = Math.min(MAX_WORLD_SIZE, Math.max(worldHeight.value + 420, Math.ceil(strokeMaxY + 480)));
      ensureInkCanvasSize();
      camera.panY -= 200;
      shifted = true;
      msg = `已自动向下延申（${worldWidth.value}×${worldHeight.value}）`;
    } else if (endScreenX > viewWidth.value - 48 && worldWidth.value < MAX_WORLD_SIZE) {
      worldWidth.value = Math.min(MAX_WORLD_SIZE, Math.max(worldWidth.value + 420, Math.ceil(strokeMaxX + 480)));
      ensureInkCanvasSize();
      camera.panX -= 200;
      shifted = true;
      msg = `已自动向右延申（${worldWidth.value}×${worldHeight.value}）`;
    }
    if (shifted) {
      clampPan();
      renderViewport();
      notifyExtend(msg);
    }
  }
  drawing = false;
  currentStroke = null;
  if (viewCanvasRef.value?.hasPointerCapture(e.pointerId)) {
    viewCanvasRef.value.releasePointerCapture(e.pointerId);
  }
}

function onWheel(e: WheelEvent) {
  if (!viewCanvasRef.value) return;
  if (e.ctrlKey || e.metaKey) {
    const sPt = screenToStage(e);
    const delta = e.deltaY < 0 ? 0.14 : -0.14;
    adjustZoom(delta, sPt.x, sPt.y);
    return;
  }
  if (e.shiftKey && e.deltaX === 0) {
    camera.panX -= e.deltaY;
  } else {
    camera.panX -= e.deltaX;
    camera.panY -= e.deltaY;
  }
  clampPan();
  renderViewport();
}

function onKeyDown(e: KeyboardEvent) {
  if (e.code !== "Space") return;
  const tag = (e.target as HTMLElement | null)?.tagName;
  if (tag === "INPUT" || tag === "TEXTAREA" || (e.target as HTMLElement | null)?.isContentEditable) {
    return;
  }
  e.preventDefault();
  spacePressed.value = true;
}

function onKeyUp(e: KeyboardEvent) {
  if (e.code === "Space") {
    spacePressed.value = false;
    panning.value = false;
  }
}

function undoStroke() {
  if (strokes.value.length === 0) return;
  strokes.value.pop();
  renderInkLayer();
  renderViewport();
}

function clearStrokes() {
  strokes.value = [];
  renderInkLayer();
  renderViewport();
}

async function initCanvasImage() {
  if (!essay.value?.answerImageUrl) {
    baseImageEl.value = null;
    imgDrawRect.w = 0;
    imgDrawRect.h = 0;
    worldWidth.value = 1200;
    worldHeight.value = 900;
    ensureInkCanvasSize();
    await nextTick();
    fitSheetToView();
    return;
  }

  try {
    const blob = await getEssayAnswerImageBlob(essayId.value);
    revokeObjectUrl();
    const url = URL.createObjectURL(blob);
    baseObjectUrl.value = url;

    await new Promise<void>((resolve, reject) => {
      const img = new Image();
      img.onload = () => {
        baseImageEl.value = img;
        const drawW = Math.max(760, Math.min(1100, img.naturalWidth || 960));
        const drawH = Math.max(380, Math.round(drawW * (img.naturalHeight / Math.max(1, img.naturalWidth))));
        imgDrawRect.x = IMAGE_PAD;
        imgDrawRect.y = IMAGE_PAD;
        imgDrawRect.w = drawW;
        imgDrawRect.h = drawH;
        // 初始即预留右侧及下方充裕批改与延申推演区
        worldWidth.value = Math.max(1200, drawW + IMAGE_PAD * 2 + 180);
        worldHeight.value = Math.max(880, drawH + IMAGE_PAD * 2 + 360);
        resolve();
      };
      img.onerror = () => reject(new Error("图片加载失败"));
      img.src = url;
    });
  } catch {
    baseImageEl.value = null;
    imgDrawRect.w = 0;
    imgDrawRect.h = 0;
  }

  ensureInkCanvasSize();
  await nextTick();
  fitSheetToView();
}

async function exportCompositePngBlob(): Promise<Blob | null> {
  if (strokes.value.length === 0) return null;

  // 计算学生原卷与老师所有有效批注笔迹的联合外接范围，避免遗漏延申区批注
  let maxX = imgDrawRect.w > 0 ? imgDrawRect.x + imgDrawRect.w + IMAGE_PAD : 900;
  let maxY = imgDrawRect.h > 0 ? imgDrawRect.y + imgDrawRect.h + IMAGE_PAD : 600;
  for (const s of strokes.value) {
    if (s.eraser) continue;
    const pad = s.width + 44;
    for (const p of s.points) {
      if (p.x + pad > maxX) maxX = p.x + pad;
      if (p.y + pad > maxY) maxY = p.y + pad;
    }
  }
  const rawW = Math.min(worldWidth.value, Math.max(800, Math.ceil(maxX)));
  const rawH = Math.min(worldHeight.value, Math.max(560, Math.ceil(maxY)));
  const scale = Math.min(1, MAX_EXPORT_DIM / Math.max(rawW, rawH));
  const outW = Math.round(rawW * scale);
  const outH = Math.round(rawH * scale);

  // 先在透明墨迹离屏画布重放笔迹，保持橡皮擦仅擦批注、不擦原图
  const inkOut = document.createElement("canvas");
  inkOut.width = outW;
  inkOut.height = outH;
  const inkOutCtx = inkOut.getContext("2d");
  if (inkOutCtx) {
    for (const s of strokes.value) {
      drawStrokeOnCtx(inkOutCtx, s, scale, 0, 0);
    }
  }

  const off = document.createElement("canvas");
  off.width = outW;
  off.height = outH;
  const ctx = off.getContext("2d");
  if (!ctx) return null;

  ctx.fillStyle = "#ffffff";
  ctx.fillRect(0, 0, outW, outH);
  if (baseImageEl.value && imgDrawRect.w > 0 && imgDrawRect.h > 0) {
    ctx.drawImage(
      baseImageEl.value,
      imgDrawRect.x * scale,
      imgDrawRect.y * scale,
      imgDrawRect.w * scale,
      imgDrawRect.h * scale
    );
  }
  ctx.drawImage(inkOut, 0, 0);

  return new Promise<Blob | null>(resolve => {
    off.toBlob(blob => resolve(blob), "image/png");
  });
}

async function handleSaveReview() {
  if (!essay.value) return;
  saving.value = true;
  try {
    let teacherImageKey: string | undefined;
    const blob = await exportCompositePngBlob();
    if (blob) {
      const fd = new FormData();
      fd.append("file", blob, `review_${essay.value.id}.png`);
      const upRes = await uploadEssayReviewImage(essay.value.id, fd);
      teacherImageKey = upRes.data.objectKey;
    }

    await reviewEssayAnswer(essay.value.id, {
      teacherStatus: reviewForm.teacherStatus,
      teacherComment: reviewForm.teacherComment.trim(),
      ...(teacherImageKey ? { teacherImageKey } : {})
    });

    ElMessage.success("批改结果与画板批注已保存同步");
    goBack();
  } finally {
    saving.value = false;
  }
}

function goBack() {
  if (essay.value?.userId) {
    router.push(`/user/detail/${essay.value.userId}`);
  } else {
    router.push("/user/index");
  }
}

function syncStageSize() {
  if (!stageHostRef.value) return;
  viewWidth.value = Math.max(320, stageHostRef.value.clientWidth);
  viewHeight.value = Math.max(320, stageHostRef.value.clientHeight);
  clampPan();
  renderViewport();
}

onMounted(async () => {
  window.addEventListener("keydown", onKeyDown);
  window.addEventListener("keyup", onKeyUp);
  if (stageHostRef.value) {
    resizeObserver = new ResizeObserver(() => syncStageSize());
    resizeObserver.observe(stageHostRef.value);
    syncStageSize();
  }

  loading.value = true;
  try {
    const res = await getEssayAnswerDetail(essayId.value);
    essay.value = res.data;
    reviewForm.teacherStatus = res.data.teacherStatus === 2 ? 2 : 1;
    reviewForm.teacherComment = res.data.teacherComment || "";
  } finally {
    loading.value = false;
  }
  await initCanvasImage();
});

onBeforeUnmount(() => {
  window.removeEventListener("keydown", onKeyDown);
  window.removeEventListener("keyup", onKeyUp);
  resizeObserver?.disconnect();
  if (extendTimer) clearTimeout(extendTimer);
  revokeObjectUrl();
});
</script>

<template>
  <div v-loading="loading" class="flex h-screen flex-col overflow-hidden bg-slate-100">
    <!-- 顶部批改画板工具栏 -->
    <header class="flex h-14 shrink-0 items-center justify-between border-b border-slate-200 bg-white px-5">
      <div class="flex items-center gap-3">
        <el-button plain @click="goBack">
          <GglIcon name="back" :size="15" class="mr-1" />
          返回学生详情
        </el-button>
        <div class="h-4 w-px bg-slate-200" />
        <span class="font-bold text-slate-800">
          {{ essay?.studentNickname || "学生" }} · PC 作业画板批改
        </span>
        <el-tag v-if="essay?.realmName" size="small" type="success">{{ essay.realmName }}</el-tag>
        <span v-if="essay" class="text-xs text-slate-500">
          {{ essay.chapterName }} · {{ essay.gateName }}
        </span>
      </div>

      <!-- 画笔与画板工具组 -->
      <div class="flex items-center gap-2.5">
        <div class="flex items-center gap-1.5 rounded-full border border-slate-200 bg-slate-50 px-2.5 py-1">
          <button
            v-for="c in PEN_COLORS"
            :key="c.value"
            type="button"
            class="h-5 w-5 rounded-full border-2 transition"
            :class="!handMode && !eraserMode && activeColor === c.value ? 'scale-115 border-slate-800' : 'border-transparent'"
            :style="{ backgroundColor: c.value }"
            :title="c.label"
            @click="handMode = false; eraserMode = false; activeColor = c.value"
          />
        </div>

        <el-radio-group v-model="lineWidth" size="small">
          <el-radio-button :value="2">细</el-radio-button>
          <el-radio-button :value="4">中</el-radio-button>
          <el-radio-button :value="8">粗</el-radio-button>
        </el-radio-group>

        <el-button
          :type="effectiveHandMode ? 'primary' : 'default'"
          plain
          size="small"
          title="拖拽平移画板（也可直接按住空格键拖拽或滚轮滚动）"
          @click="handMode = !handMode; if (handMode) eraserMode = false"
        >
          <GglIcon name="hand" :size="14" class="mr-1" />
          抓手平移
        </el-button>
        <el-button :type="!handMode && eraserMode ? 'warning' : 'default'" plain size="small" @click="handMode = false; eraserMode = !eraserMode">
          <GglIcon name="eraser" :size="14" class="mr-1" />
          橡皮擦
        </el-button>
        <el-button size="small" plain :disabled="strokes.length === 0" @click="undoStroke">
          <GglIcon name="undo" :size="14" class="mr-1" />
          撤销
        </el-button>
        <el-button size="small" plain :disabled="strokes.length === 0" @click="clearStrokes">
          <GglIcon name="clear" :size="14" class="mr-1" />
          清空批注
        </el-button>

        <el-button type="primary" :loading="saving" @click="handleSaveReview">
          <GglIcon name="check-circle" :size="15" class="mr-1" />
          保存批改结果
        </el-button>
      </div>
    </header>

    <!-- 主工作区：左侧可自动延申无限画板 + 右侧题目与评分栏 -->
    <main class="grid min-h-0 flex-1 grid-cols-12 gap-4 overflow-hidden p-4">
      <section
        ref="stageHostRef"
        class="relative col-span-8 flex min-h-0 overflow-hidden rounded-xl border border-slate-200 bg-slate-200/80"
      >
        <canvas
          ref="viewCanvasRef"
          class="block h-full w-full touch-none select-none"
          :class="panning ? 'cursor-grabbing' : effectiveHandMode ? 'cursor-grab' : eraserMode ? 'cursor-cell' : 'cursor-crosshair'"
          @pointerdown="onPointerDown"
          @pointermove="onPointerMove"
          @pointerup="onPointerUp"
          @pointercancel="onPointerUp"
          @wheel.prevent="onWheel"
        />

        <!-- 顶部自动延申提示 -->
        <div
          v-if="extendHint"
          class="pointer-events-none absolute top-3 left-1/2 z-20 -translate-x-1/2 rounded-full bg-green-600/95 px-3.5 py-1 text-xs font-medium text-white shadow-sm"
        >
          {{ extendHint }}
        </div>

        <!-- 左下角延申与缩放浮动控制器 -->
        <div
          class="absolute bottom-3 left-3 z-20 flex items-center gap-1.5 rounded-full border border-slate-200/90 bg-white/95 px-3 py-1.5 text-xs text-slate-600 shadow-md backdrop-blur-xs"
          @pointerdown.stop
        >
          <el-button size="small" text @click="extendPaper('down')">↓ 向下延申</el-button>
          <el-button size="small" text @click="extendPaper('right')">→ 向右延申</el-button>
          <div class="mx-1 h-3.5 w-px bg-slate-200" />
          <el-button size="small" text @click="adjustZoom(-0.15)">
            <GglIcon name="zoom-out" :size="14" />
          </el-button>
          <span class="w-11 text-center font-semibold text-slate-700">{{ Math.round(camera.zoom * 100) }}%</span>
          <el-button size="small" text @click="adjustZoom(0.15)">
            <GglIcon name="zoom-in" :size="14" />
          </el-button>
          <el-button size="small" text @click="fitSheetToView">自适应</el-button>
          <div class="mx-1 h-3.5 w-px bg-slate-200" />
          <span class="text-[11px] text-slate-400">
            画布 {{ worldWidth }}×{{ worldHeight }} · 滚轮翻页 / Ctrl+滚轮缩放
          </span>
        </div>
      </section>

      <aside class="col-span-4 flex min-h-0 flex-col gap-4 overflow-y-auto rounded-xl border border-slate-200 bg-white p-5">
        <div v-if="essay" class="space-y-4">
          <div>
            <div class="mb-1 text-xs font-bold uppercase tracking-wider text-slate-400">题目内容</div>
            <div class="rounded-lg bg-slate-50 p-3 text-sm font-medium leading-relaxed text-slate-800">
              <MathFormulaText :text="essay.stem" />
            </div>
          </div>

          <div v-if="essay.answerText">
            <div class="mb-1 text-xs font-bold text-slate-400">学生文字作答</div>
            <div class="rounded-lg border border-slate-200 bg-white p-3 text-xs text-slate-700">
              {{ essay.answerText }}
            </div>
          </div>

          <div>
            <div class="mb-1 text-xs font-bold text-green-700">参考答案</div>
            <div class="rounded-lg border border-green-200 bg-green-50 p-3 text-xs leading-relaxed text-green-900">
              <MathFormulaText :text="essay.referenceAnswer || '（本题侧重过程表达）'" />
            </div>
          </div>

          <div v-if="essay.analysis">
            <div class="mb-1 text-xs font-bold text-slate-500">解题思路</div>
            <div class="rounded-lg bg-slate-50 p-3 text-xs leading-relaxed text-slate-600">
              <MathFormulaText :text="essay.analysis" />
            </div>
          </div>

          <div class="border-t border-slate-200 pt-4">
            <div class="mb-2 text-sm font-bold text-slate-800">批改结论</div>
            <el-radio-group v-model="reviewForm.teacherStatus" class="flex gap-2">
              <el-radio :value="1" border>批改通过（计对并同步过关）</el-radio>
              <el-radio :value="2" border>待订正（判错入错题本）</el-radio>
            </el-radio-group>
          </div>

          <div>
            <div class="mb-1.5 text-sm font-bold text-slate-800">老师点评（可选）</div>
            <div class="mb-2 flex flex-wrap gap-1.5">
              <button
                v-for="tip in QUICK_COMMENTS"
                :key="tip"
                type="button"
                class="rounded-full border border-slate-200 bg-slate-50 px-2.5 py-1 text-xs text-slate-600 hover:border-green-500 hover:text-green-700"
                @click="reviewForm.teacherComment = tip"
              >
                {{ tip }}
              </button>
            </div>
            <el-input
              v-model="reviewForm.teacherComment"
              type="textarea"
              :rows="4"
              placeholder="输入对学生过程、思路或易错点的具体点评..."
            />
          </div>

          <div v-if="essay.teacherImageUrl" class="border-t border-slate-100 pt-3">
            <div class="mb-1 text-xs text-slate-500">上次批注成图留存</div>
            <el-image
              :src="essay.teacherImageUrl"
              :preview-src-list="[essay.teacherImageUrl]"
              preview-teleported
              fit="contain"
              class="h-28 w-48 rounded border border-slate-200 bg-white"
            />
          </div>
        </div>
      </aside>
    </main>
  </div>
</template>
