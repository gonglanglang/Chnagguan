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

const IMAGE_PAD = 44;
const MIN_ZOOM = 0.25;
const MAX_ZOOM = 3.5;
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

// 蓝湖风格全铺无限白板 + 视口级透明墨迹离屏层（支持四向无界平移缩放，橡皮仅擦批注不损原卷）
const stageHostRef = ref<HTMLElement | null>(null);
const viewCanvasRef = ref<HTMLCanvasElement | null>(null);

const viewWidth = ref(960);
const viewHeight = ref(640);
const camera = reactive({
  panX: 0,
  panY: 0,
  zoom: 1
});

const imgDrawRect = reactive({
  x: 0,
  y: 0,
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
  const dpr = Math.min(2, window.devicePixelRatio || 1);
  const pw = Math.max(1, Math.round(viewWidth.value * dpr));
  const ph = Math.max(1, Math.round(viewHeight.value * dpr));
  if (!inkCanvas) {
    inkCanvas = document.createElement("canvas");
  }
  if (inkCanvas.width !== pw || inkCanvas.height !== ph) {
    inkCanvas.width = pw;
    inkCanvas.height = ph;
    renderInkLayer();
  }
}

function drawStrokeOnCtx(ctx: CanvasRenderingContext2D, s: Stroke, scale = 1, offsetX = 0, offsetY = 0) {
  if (!s.points.length) return;
  ctx.save();
  ctx.globalCompositeOperation = s.eraser ? "destination-out" : "source-over";
  ctx.strokeStyle = s.eraser ? "#000000" : s.color;
  ctx.fillStyle = s.eraser ? "#000000" : s.color;
  ctx.lineWidth = Math.max(0.8, s.width * scale);
  ctx.lineCap = "round";
  ctx.lineJoin = "round";

  const map = (p: Point): Point => ({
    x: (p.x - offsetX) * scale,
    y: (p.y - offsetY) * scale
  });

  if (s.points.length === 1) {
    const p0 = map(s.points[0]);
    ctx.beginPath();
    ctx.arc(p0.x, p0.y, Math.max(0.8, s.width * scale) / 2, 0, Math.PI * 2);
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

function drawInkSegmentIncremental(fromPt: Point, toPt: Point, s: Stroke) {
  ensureInkCanvasSize();
  if (!inkCanvas) return;
  const dpr = Math.min(2, window.devicePixelRatio || 1);
  const ctx = inkCanvas.getContext("2d");
  if (!ctx) return;
  ctx.save();
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.translate(camera.panX, camera.panY);
  ctx.scale(camera.zoom, camera.zoom);
  ctx.globalCompositeOperation = s.eraser ? "destination-out" : "source-over";
  ctx.strokeStyle = s.eraser ? "#000000" : s.color;
  ctx.lineWidth = Math.max(0.8, s.width);
  ctx.lineCap = "round";
  ctx.lineJoin = "round";
  ctx.beginPath();
  ctx.moveTo(fromPt.x, fromPt.y);
  ctx.lineTo(toPt.x, toPt.y);
  ctx.stroke();
  ctx.restore();
}

function renderInkLayer() {
  ensureInkCanvasSize();
  if (!inkCanvas) return;
  const dpr = Math.min(2, window.devicePixelRatio || 1);
  const ctx = inkCanvas.getContext("2d");
  if (!ctx) return;
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.clearRect(0, 0, inkCanvas.width, inkCanvas.height);

  ctx.save();
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.translate(camera.panX, camera.panY);
  ctx.scale(camera.zoom, camera.zoom);
  for (const s of strokes.value) {
    drawStrokeOnCtx(ctx, s, 1, 0, 0);
  }
  ctx.restore();
}

function drawInfiniteDotGrid(ctx: CanvasRenderingContext2D) {
  // 随相机平移缩放的极淡设计点阵，无边框全屏感
  let stepWorld = 32;
  while (stepWorld * camera.zoom < 18) {
    stepWorld *= 2;
  }
  const stepScreen = stepWorld * camera.zoom;
  const startX = ((camera.panX % stepScreen) + stepScreen) % stepScreen;
  const startY = ((camera.panY % stepScreen) + stepScreen) % stepScreen;

  ctx.fillStyle = "#e2e8f0";
  for (let x = startX; x < viewWidth.value; x += stepScreen) {
    for (let y = startY; y < viewHeight.value; y += stepScreen) {
      ctx.fillRect(x - 0.75, y - 0.75, 1.5, 1.5);
    }
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

  // 纯白画板铺满全区（零外围背景框）
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.fillStyle = "#ffffff";
  ctx.fillRect(0, 0, viewWidth.value, viewHeight.value);

  drawInfiniteDotGrid(ctx);

  // 学生作答原图直接平铺于无限画板世界坐标系中
  ctx.save();
  ctx.translate(camera.panX, camera.panY);
  ctx.scale(camera.zoom, camera.zoom);
  if (baseImageEl.value && imgDrawRect.w > 0 && imgDrawRect.h > 0) {
    ctx.drawImage(baseImageEl.value, imgDrawRect.x, imgDrawRect.y, imgDrawRect.w, imgDrawRect.h);
    ctx.strokeStyle = "#e2e8f0";
    ctx.lineWidth = 1 / camera.zoom;
    ctx.strokeRect(imgDrawRect.x, imgDrawRect.y, imgDrawRect.w, imgDrawRect.h);
    ctx.fillStyle = "#94a3b8";
    ctx.font = `${Math.max(10, Math.round(12 / Math.max(0.5, camera.zoom)))}px sans-serif`;
    ctx.fillText("学生原卷（四周空白处可无限手写批改推导）", imgDrawRect.x, imgDrawRect.y - 8);
  }
  ctx.restore();

  // 叠加视口级透明批注墨迹层
  if (inkCanvas && inkCanvas.width > 0 && inkCanvas.height > 0) {
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.drawImage(inkCanvas, 0, 0);
  }
}

function fitContentToView() {
  let minX = imgDrawRect.w > 0 ? imgDrawRect.x : Number.POSITIVE_INFINITY;
  let minY = imgDrawRect.w > 0 ? imgDrawRect.y : Number.POSITIVE_INFINITY;
  let maxX = imgDrawRect.w > 0 ? imgDrawRect.x + imgDrawRect.w : Number.NEGATIVE_INFINITY;
  let maxY = imgDrawRect.w > 0 ? imgDrawRect.y + imgDrawRect.h : Number.NEGATIVE_INFINITY;

  for (const s of strokes.value) {
    if (s.eraser) continue;
    for (const p of s.points) {
      if (p.x < minX) minX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.x > maxX) maxX = p.x;
      if (p.y > maxY) maxY = p.y;
    }
  }

  if (!Number.isFinite(minX)) {
    camera.zoom = 1;
    camera.panX = 0;
    camera.panY = 0;
    renderInkLayer();
    renderViewport();
    return;
  }

  const contentW = Math.max(300, maxX - minX);
  const contentH = Math.max(240, maxY - minY);
  const nextZoom = Math.max(
    MIN_ZOOM,
    Math.min(1, Number((Math.min((viewWidth.value - 80) / contentW, (viewHeight.value - 80) / contentH)).toFixed(2)))
  );
  camera.zoom = nextZoom;
  camera.panX = Math.round(viewWidth.value / 2 - ((minX + maxX) / 2) * nextZoom);
  camera.panY = Math.max(32, Math.round(viewHeight.value * 0.44 - ((minY + maxY) / 2) * nextZoom));
  renderInkLayer();
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
  renderInkLayer();
  renderViewport();
}

function extendPaper(dir: "down" | "right") {
  if (dir === "down") {
    camera.panY -= Math.round(viewHeight.value * 0.42);
    renderInkLayer();
    renderViewport();
    notifyExtend("已向下平移空出批改区");
  } else {
    camera.panX -= Math.round(viewWidth.value * 0.42);
    renderInkLayer();
    renderViewport();
    notifyExtend("已向右平移空出批改区");
  }
}

function screenToStage(e: MouseEvent | PointerEvent): Point {
  const rect = viewCanvasRef.value!.getBoundingClientRect();
  return { x: e.clientX - rect.left, y: e.clientY - rect.top };
}

function screenToWorld(sx: number, sy: number): Point {
  return {
    x: (sx - camera.panX) / camera.zoom,
    y: (sy - camera.panY) / camera.zoom
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
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    const inkCtx = inkCanvas.getContext("2d");
    if (inkCtx) {
      inkCtx.save();
      inkCtx.setTransform(dpr, 0, 0, dpr, 0, 0);
      inkCtx.translate(camera.panX, camera.panY);
      inkCtx.scale(camera.zoom, camera.zoom);
      drawStrokeOnCtx(inkCtx, currentStroke);
      inkCtx.restore();
    }
  }
  renderViewport();
}

function onPointerMove(e: PointerEvent) {
  const sPt = screenToStage(e);
  if (panning.value) {
    camera.panX += sPt.x - panLastScreen.x;
    camera.panY += sPt.y - panLastScreen.y;
    panLastScreen = sPt;
    renderInkLayer();
    renderViewport();
    return;
  }
  if (!drawing || !currentStroke) return;

  const wPt = screenToWorld(sPt.x, sPt.y);
  const prev = currentStroke.points[currentStroke.points.length - 1];
  if (prev && Math.hypot(wPt.x - prev.x, wPt.y - prev.y) * camera.zoom < 1.5) return;

  if (wPt.x > strokeMaxX) strokeMaxX = wPt.x;
  if (wPt.y > strokeMaxY) strokeMaxY = wPt.y;

  currentStroke.points.push(wPt);
  if (prev) {
    drawInkSegmentIncremental(prev, wPt, currentStroke);
  }
  renderViewport();
}

function onPointerUp(e: PointerEvent) {
  if (panning.value) {
    panning.value = false;
  }
  if (drawing) {
    renderInkLayer();
    if (currentStroke && !currentStroke.eraser) {
      const endScreenY = camera.panY + strokeMaxY * camera.zoom;
      const endScreenX = camera.panX + strokeMaxX * camera.zoom;
      let shifted = false;
      let msg = "";
      if (endScreenY > viewHeight.value - 44) {
        camera.panY -= 180;
        shifted = true;
        msg = "已自动向下延伸空白区";
      } else if (endScreenX > viewWidth.value - 44) {
        camera.panX -= 180;
        shifted = true;
        msg = "已自动向右延伸空白区";
      }
      if (shifted) {
        renderInkLayer();
        notifyExtend(msg);
      }
    }
    renderViewport();
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
  renderInkLayer();
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
    await nextTick();
    fitContentToView();
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
        const drawW = Math.max(720, Math.min(1080, img.naturalWidth || 920));
        const drawH = Math.max(360, Math.round(drawW * (img.naturalHeight / Math.max(1, img.naturalWidth))));
        imgDrawRect.x = 0;
        imgDrawRect.y = 0;
        imgDrawRect.w = drawW;
        imgDrawRect.h = drawH;
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

  await nextTick();
  fitContentToView();
}

async function exportCompositePngBlob(): Promise<Blob | null> {
  if (strokes.value.length === 0) return null;

  // 计算学生原卷与老师所有有效批注（含任意正负坐标方向延申区）的联合外接包围盒
  let minX = imgDrawRect.w > 0 ? imgDrawRect.x - IMAGE_PAD : Number.POSITIVE_INFINITY;
  let minY = imgDrawRect.w > 0 ? imgDrawRect.y - IMAGE_PAD : Number.POSITIVE_INFINITY;
  let maxX = imgDrawRect.w > 0 ? imgDrawRect.x + imgDrawRect.w + IMAGE_PAD : Number.NEGATIVE_INFINITY;
  let maxY = imgDrawRect.w > 0 ? imgDrawRect.y + imgDrawRect.h + IMAGE_PAD : Number.NEGATIVE_INFINITY;

  for (const s of strokes.value) {
    if (s.eraser) continue;
    const pad = s.width + 44;
    for (const p of s.points) {
      if (p.x - pad < minX) minX = p.x - pad;
      if (p.y - pad < minY) minY = p.y - pad;
      if (p.x + pad > maxX) maxX = p.x + pad;
      if (p.y + pad > maxY) maxY = p.y + pad;
    }
  }
  if (!Number.isFinite(minX)) {
    minX = 0;
    minY = 0;
    maxX = 900;
    maxY = 600;
  }

  const originX = Math.floor(minX);
  const originY = Math.floor(minY);
  const rawW = Math.max(640, Math.ceil(maxX - originX));
  const rawH = Math.max(420, Math.ceil(maxY - originY));
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
      drawStrokeOnCtx(inkOutCtx, s, scale, originX, originY);
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
      (imgDrawRect.x - originX) * scale,
      (imgDrawRect.y - originY) * scale,
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
  renderInkLayer();
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

    <!-- 主工作区：左侧全铺纯白无限批改画板 + 右侧题目与评分栏 -->
    <main class="grid min-h-0 flex-1 grid-cols-12 gap-0 overflow-hidden bg-white">
      <section
        ref="stageHostRef"
        class="relative col-span-8 flex min-h-0 overflow-hidden border-r border-slate-200 bg-white"
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

        <!-- 左下角极简浮动控制器（蓝湖画板风格） -->
        <div
          class="absolute bottom-4 left-4 z-20 flex items-center gap-1.5 rounded-full border border-slate-200/90 bg-white/95 px-3 py-1.5 text-xs text-slate-600 shadow-md backdrop-blur-xs"
          @pointerdown.stop
        >
          <el-button size="small" text @click="extendPaper('down')">↓ 下移空白</el-button>
          <el-button size="small" text @click="extendPaper('right')">→ 右移空白</el-button>
          <div class="mx-1 h-3.5 w-px bg-slate-200" />
          <el-button size="small" text @click="adjustZoom(-0.15)">
            <GglIcon name="zoom-out" :size="14" />
          </el-button>
          <span class="w-11 text-center font-semibold text-slate-700">{{ Math.round(camera.zoom * 100) }}%</span>
          <el-button size="small" text @click="adjustZoom(0.15)">
            <GglIcon name="zoom-in" :size="14" />
          </el-button>
          <el-button size="small" text @click="fitContentToView">全览</el-button>
          <div class="mx-1 h-3.5 w-px bg-slate-200" />
          <span class="text-[11px] text-slate-400">
            无限画板 · 滚轮翻页 / Ctrl+滚轮缩放 / 空格拖拽
          </span>
        </div>
      </section>

      <aside class="col-span-4 flex min-h-0 flex-col gap-4 overflow-y-auto bg-white p-5">
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
