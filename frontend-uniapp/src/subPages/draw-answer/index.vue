<template>
  <view class="draw-page">
    <!-- 顶部极简工具栏 -->
    <view class="draw-toolbar">
      <view class="toolbar-left">
        <view class="back-btn" @click="handleBack">
          <wd-icon name="arrow-left" size="18" color="#111827" />
          <text class="back-btn__text">返回</text>
        </view>

        <view v-if="stem" class="stem-pill" @click="showStemModal = true">
          <text class="stem-pill__tag">题干</text>
          <text class="stem-pill__text">{{ singleLineStem }}</text>
        </view>
      </view>

      <view class="toolbar-right">
        <view class="color-group">
          <view
            v-for="c in PEN_COLORS"
            :key="c"
            class="color-dot"
            :class="{ 'color-dot--active': !eraserMode && activeColor === c }"
            :style="{ backgroundColor: c }"
            @click="selectPen(c)"
          />
        </view>

        <view
          class="tool-btn"
          :class="{ 'tool-btn--active': eraserMode }"
          @click="toggleEraser"
        >
          <text class="tool-btn__text">橡皮</text>
        </view>
        <view
          class="tool-btn"
          :class="{ 'tool-btn--disabled': strokes.length === 0 || saving }"
          @click="undoStroke"
        >
          <text class="tool-btn__text">撤销</text>
        </view>
        <view
          class="tool-btn"
          :class="{ 'tool-btn--disabled': strokes.length === 0 || saving }"
          @click="clearBoard"
        >
          <text class="tool-btn__text">清空</text>
        </view>

        <view
          class="save-btn"
          :class="{ 'save-btn--disabled': saving }"
          @click="handleSave"
        >
          <text class="save-btn__text">{{ saving ? "保存中..." : "完成保存" }}</text>
        </view>
      </view>
    </view>

    <!-- 纯净横屏绘制区（事件绑定在外层 view，避免 uni-canvas 修饰符事件对象异常） -->
    <view
      class="canvas-stage"
      @touchstart.stop.prevent="onTouchStart"
      @touchmove.stop.prevent="onTouchMove"
      @touchend.stop="onTouchEnd"
      @touchcancel.stop="onTouchEnd"
      @mousedown="onMouseDown"
      @mousemove="onMouseMove"
      @mouseup="onMouseUp"
      @mouseleave="onMouseUp"
    >
      <canvas
        v-if="canvasWidth > 0 && canvasHeight > 0"
        id="drawAnswerCanvas"
        canvas-id="drawAnswerCanvas"
        class="draw-canvas"
        :style="{ width: `${canvasWidth}px`, height: `${canvasHeight}px` }"
        :disable-scroll="true"
      />
      <view v-if="!hasDrawn" class="canvas-placeholder">
        <text class="canvas-placeholder__text">请在此横屏空白区书写解题过程</text>
      </view>
    </view>

    <!-- 点击顶部题干可查看完整公式排版 -->
    <view v-if="showStemModal" class="stem-modal-mask" @click="showStemModal = false">
      <view class="stem-modal" @click.stop>
        <view class="stem-modal__head">
          <text class="stem-modal__title">当前题目</text>
          <text class="stem-modal__close" @click="showStemModal = false">收起</text>
        </view>
        <view class="stem-modal__body">
          <math-text :text="stem" />
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { onBackPress, onLoad, onShow, onUnload } from "@dcloudio/uni-app";
import { getCurrentInstance, nextTick } from "vue";
import { AppQuizAPI } from "@/api/guoguanla";
import { getErrorMessage } from "@/utils/error";
import { renderMathPlainText } from "@/utils/math";
import { lockLandscapeOrientation, lockPortraitOrientation } from "@/utils/orientation";

definePage({
  name: "draw-answer",
  layout: "blank",
  style: {
    navigationStyle: "custom",
    navigationBarTitleText: "横屏作答",
    pageOrientation: "landscape",
    disableScroll: true,
  },
});

interface Point {
  x: number;
  y: number;
}

interface Stroke {
  color: string;
  width: number;
  points: Point[];
}

interface StageRect {
  left: number;
  top: number;
  width: number;
  height: number;
}

const PEN_COLORS = ["#111827", "#2563eb", "#dc2626"];
const ACTIVE_ESSAY_PROMPT_KEY = "ggl_active_essay_prompt";

const instance = getCurrentInstance()?.proxy;
const toast = useToast();

const sessionNo = ref("");
const itemIndex = ref(0);
const stem = ref("");
const answerText = ref("");

const activeColor = ref("#111827");
const eraserMode = ref(false);
const strokes = ref<Stroke[]>([]);
const hasDrawn = ref(false);
const saving = ref(false);
const showStemModal = ref(false);

const canvasWidth = ref(0);
const canvasHeight = ref(0);
let stageRect: StageRect = { left: 0, top: 0, width: 0, height: 0 };
let ctx: UniApp.CanvasContext | null = null;
let drawing = false;
let lastPoint: Point | null = null;
let currentStroke: Stroke | null = null;
let pendingPoints: Point[] = [];
let flushTimer: ReturnType<typeof setTimeout> | null = null;
let lastTouchTs = 0;
let mouseActive = false;
let measureTimers: ReturnType<typeof setTimeout>[] = [];

const singleLineStem = computed(() => renderMathPlainText(stem.value) || stem.value);

function clearTimers(): void {
  measureTimers.forEach((t) => clearTimeout(t));
  measureTimers = [];
  if (flushTimer !== null) {
    clearTimeout(flushTimer);
    flushTimer = null;
  }
}

function refreshStageRect(): void {
  if (!instance) return;
  uni
    .createSelectorQuery()
    .in(instance)
    .select(".canvas-stage")
    .boundingClientRect((rect) => {
      const target = Array.isArray(rect) ? rect[0] : rect;
      if (!target || !target.width || !target.height) return;
      stageRect = {
        left: target.left || 0,
        top: target.top || 0,
        width: Math.floor(target.width),
        height: Math.floor(target.height),
      };
    })
    .exec();
}

function measureCanvas(): void {
  if (!instance) return;
  uni
    .createSelectorQuery()
    .in(instance)
    .select(".canvas-stage")
    .boundingClientRect((rect) => {
      const target = Array.isArray(rect) ? rect[0] : rect;
      if (!target || !target.width || !target.height) return;
      const w = Math.floor(target.width);
      const h = Math.floor(target.height);
      stageRect = {
        left: target.left || 0,
        top: target.top || 0,
        width: w,
        height: h,
      };
      if (w !== canvasWidth.value || h !== canvasHeight.value) {
        canvasWidth.value = w;
        canvasHeight.value = h;
        void nextTick(() => {
          ctx = uni.createCanvasContext("drawAnswerCanvas", instance);
          redrawAll();
        });
      }
    })
    .exec();
}

function onWindowResize(): void {
  measureCanvas();
}

function selectPen(color: string): void {
  activeColor.value = color;
  eraserMode.value = false;
}

function toggleEraser(): void {
  eraserMode.value = !eraserMode.value;
}

function getStrokeColor(): string {
  return eraserMode.value ? "#ffffff" : activeColor.value;
}

function getStrokeWidth(): number {
  return eraserMode.value ? 18 : 3;
}

function clampPoint(x: number, y: number): Point {
  const maxX = canvasWidth.value > 0 ? canvasWidth.value : 9999;
  const maxY = canvasHeight.value > 0 ? canvasHeight.value : 9999;
  return {
    x: Math.max(0, Math.min(maxX, x)),
    y: Math.max(0, Math.min(maxY, y)),
  };
}

function extractPoint(e: unknown): Point | null {
  const evt = e as {
    touches?: Array<{ x?: number; y?: number; clientX?: number; clientY?: number; pageX?: number; pageY?: number }>;
    changedTouches?: Array<{ x?: number; y?: number; clientX?: number; clientY?: number; pageX?: number; pageY?: number }>;
    detail?: { x?: number; y?: number };
    clientX?: number;
    clientY?: number;
    pageX?: number;
    pageY?: number;
  };
  const touch = evt?.touches?.[0] || evt?.changedTouches?.[0];
  if (touch) {
    const cx = touch.clientX ?? touch.pageX;
    const cy = touch.clientY ?? touch.pageY;
    if (typeof cx === "number" && typeof cy === "number") {
      return clampPoint(cx - stageRect.left, cy - stageRect.top);
    }
    if (typeof touch.x === "number" && typeof touch.y === "number") {
      return clampPoint(touch.x, touch.y);
    }
  }
  if (typeof evt?.clientX === "number" && typeof evt?.clientY === "number") {
    return clampPoint(evt.clientX - stageRect.left, evt.clientY - stageRect.top);
  }
  if (typeof evt?.pageX === "number" && typeof evt?.pageY === "number") {
    return clampPoint(evt.pageX - stageRect.left, evt.pageY - stageRect.top);
  }
  if (evt?.detail && typeof evt.detail.x === "number" && typeof evt.detail.y === "number") {
    return clampPoint(evt.detail.x - stageRect.left, evt.detail.y - stageRect.top);
  }
  return null;
}

function redrawAll(): void {
  if (!ctx || canvasWidth.value <= 0 || canvasHeight.value <= 0) return;
  ctx.setFillStyle("#ffffff");
  ctx.fillRect(0, 0, canvasWidth.value, canvasHeight.value);

  for (const s of strokes.value) {
    if (!s.points.length) continue;
    ctx.setStrokeStyle(s.color);
    ctx.setFillStyle(s.color);
    ctx.setLineWidth(s.width);
    ctx.setLineCap("round");
    ctx.setLineJoin("round");

    if (s.points.length === 1) {
      ctx.beginPath();
      ctx.arc(s.points[0].x, s.points[0].y, s.width / 2, 0, Math.PI * 2);
      ctx.fill();
    } else {
      ctx.beginPath();
      ctx.moveTo(s.points[0].x, s.points[0].y);
      for (let i = 1; i < s.points.length; i += 1) {
        ctx.lineTo(s.points[i].x, s.points[i].y);
      }
      ctx.stroke();
    }
  }
  ctx.draw(false);
}

function flushPendingSegments(): void {
  if (flushTimer !== null) {
    clearTimeout(flushTimer);
    flushTimer = null;
  }
  if (!ctx || !lastPoint || !currentStroke || pendingPoints.length === 0) return;

  const pts = pendingPoints;
  pendingPoints = [];

  ctx.setStrokeStyle(currentStroke.color);
  ctx.setLineWidth(currentStroke.width);
  ctx.setLineCap("round");
  ctx.setLineJoin("round");
  ctx.beginPath();
  ctx.moveTo(lastPoint.x, lastPoint.y);
  for (const pt of pts) {
    ctx.lineTo(pt.x, pt.y);
  }
  ctx.stroke();
  ctx.draw(true);
  lastPoint = pts[pts.length - 1];
}

function beginStroke(pt: Point): void {
  if (!ctx) {
    ctx = uni.createCanvasContext("drawAnswerCanvas", instance);
    redrawAll();
  }
  pendingPoints = [];
  if (flushTimer !== null) {
    clearTimeout(flushTimer);
    flushTimer = null;
  }
  drawing = true;
  hasDrawn.value = true;
  lastPoint = pt;
  currentStroke = {
    color: getStrokeColor(),
    width: getStrokeWidth(),
    points: [pt],
  };

  ctx.setFillStyle(currentStroke.color);
  ctx.beginPath();
  ctx.arc(pt.x, pt.y, currentStroke.width / 2, 0, Math.PI * 2);
  ctx.fill();
  ctx.draw(true);
}

function moveStroke(pt: Point): void {
  if (!drawing || !lastPoint || !currentStroke || !ctx) return;
  const refPt = pendingPoints[pendingPoints.length - 1] || lastPoint;
  const dx = pt.x - refPt.x;
  const dy = pt.y - refPt.y;
  if (dx * dx + dy * dy < 2.25) return;

  currentStroke.points.push(pt);
  pendingPoints.push(pt);
  if (flushTimer === null) {
    flushTimer = setTimeout(flushPendingSegments, 16);
  }
}

function endStroke(): void {
  if (!drawing) return;
  flushPendingSegments();
  if (currentStroke && currentStroke.points.length > 0) {
    strokes.value = [...strokes.value, currentStroke];
  }
  drawing = false;
  lastPoint = null;
  currentStroke = null;
}

function onTouchStart(e: unknown): void {
  if (saving.value) return;
  lastTouchTs = Date.now();
  refreshStageRect();
  const pt = extractPoint(e);
  if (pt) beginStroke(pt);
}

function onTouchMove(e: unknown): void {
  if (!drawing || saving.value) return;
  lastTouchTs = Date.now();
  const pt = extractPoint(e);
  if (pt) moveStroke(pt);
}

function onTouchEnd(): void {
  lastTouchTs = Date.now();
  endStroke();
}

function onMouseDown(e: unknown): void {
  if (saving.value || Date.now() - lastTouchTs < 800) return;
  mouseActive = true;
  refreshStageRect();
  const pt = extractPoint(e);
  if (pt) beginStroke(pt);
}

function onMouseMove(e: unknown): void {
  if (!mouseActive || !drawing || saving.value || Date.now() - lastTouchTs < 800) return;
  const pt = extractPoint(e);
  if (pt) moveStroke(pt);
}

function onMouseUp(): void {
  if (!mouseActive) return;
  mouseActive = false;
  endStroke();
}

function undoStroke(): void {
  if (saving.value || strokes.value.length === 0) return;
  strokes.value = strokes.value.slice(0, -1);
  hasDrawn.value = strokes.value.length > 0;
  redrawAll();
}

function clearBoard(): void {
  if (saving.value || (strokes.value.length === 0 && !hasDrawn.value)) return;
  strokes.value = [];
  hasDrawn.value = false;
  redrawAll();
}

function exportCanvasTempFile(): Promise<string> {
  return new Promise((resolve, reject) => {
    const sys = uni.getSystemInfoSync();
    const dpr = Math.min(2, sys.pixelRatio || 2);
    uni.canvasToTempFilePath(
      {
        canvasId: "drawAnswerCanvas",
        x: 0,
        y: 0,
        width: canvasWidth.value,
        height: canvasHeight.value,
        destWidth: Math.round(canvasWidth.value * dpr),
        destHeight: Math.round(canvasHeight.value * dpr),
        fileType: "png",
        quality: 0.92,
        success: (res) => resolve(res.tempFilePath),
        fail: (err) => reject(err),
      },
      instance,
    );
  });
}

function navigateBackPortrait(): void {
  lockPortraitOrientation();
  const pages = getCurrentPages();
  if (pages.length > 1) {
    uni.navigateBack();
  } else {
    uni.switchTab({ url: "/pages/index/index" });
  }
}

function handleBack(): void {
  if (saving.value) return;
  if (strokes.value.length === 0) {
    navigateBackPortrait();
    return;
  }
  uni.showModal({
    title: "返回答题",
    content: "当前画板尚有未保存的手写步骤，确定放弃并返回吗？",
    success: (res) => {
      if (res.confirm) {
        navigateBackPortrait();
      }
    },
  });
}

async function handleSave(): Promise<void> {
  if (saving.value) return;
  endStroke();
  if (strokes.value.length === 0) {
    toast.info("请先书写解题过程后再保存");
    return;
  }
  if (!sessionNo.value) {
    toast.error("缺少答题会话信息，请返回重试");
    return;
  }

  saving.value = true;
  try {
    const tempPath = await exportCanvasTempFile();
    const uploaded = await AppQuizAPI.uploadAnswerImage(
      tempPath,
      sessionNo.value,
      itemIndex.value,
    );
    const feedback = await AppQuizAPI.checkItem({
      sessionNo: sessionNo.value,
      itemIndex: itemIndex.value,
      answerText: answerText.value,
      answerImageKey: uploaded.objectKey,
    });

    uni.$emit("essay-draw-saved", {
      sessionNo: sessionNo.value,
      itemIndex: itemIndex.value,
      answerImageKey: uploaded.objectKey,
      answerText: answerText.value,
      feedback,
    });
    uni.removeStorageSync(ACTIVE_ESSAY_PROMPT_KEY);
    navigateBackPortrait();
  } catch (err) {
    toast.error(getErrorMessage(err, "保存手写解答失败，请重试"));
  } finally {
    saving.value = false;
  }
}

onLoad((query) => {
  lockLandscapeOrientation();

  const cached = uni.getStorageSync(ACTIVE_ESSAY_PROMPT_KEY) as
    | { sessionNo?: string; itemIndex?: number; stem?: string; answerText?: string }
    | undefined;

  sessionNo.value = query?.sessionNo
    ? decodeURIComponent(query.sessionNo)
    : cached?.sessionNo || "";
  itemIndex.value =
    query?.itemIndex !== undefined
      ? Number(query.itemIndex)
      : Number(cached?.itemIndex || 0);
  stem.value = query?.stem ? decodeURIComponent(query.stem) : cached?.stem || "";
  answerText.value = query?.answerText
    ? decodeURIComponent(query.answerText)
    : cached?.answerText || "";

  uni.onWindowResize(onWindowResize);
  clearTimers();
  measureTimers.push(setTimeout(measureCanvas, 80));
  measureTimers.push(setTimeout(measureCanvas, 260));
  measureTimers.push(setTimeout(measureCanvas, 520));
});

onShow(() => {
  lockLandscapeOrientation();
  measureCanvas();
});

onBackPress(() => {
  lockPortraitOrientation();
  return false;
});

onUnload(() => {
  clearTimers();
  uni.offWindowResize(onWindowResize);
  lockPortraitOrientation();
});
</script>

<style lang="scss" scoped>
.draw-page {
  display: flex;
  flex-direction: column;
  width: 100vw;
  height: 100vh;
  overflow: hidden;
  background: #ffffff;
}

.draw-toolbar {
  display: flex;
  flex-shrink: 0;
  gap: 12px;
  align-items: center;
  justify-content: space-between;
  height: 48px;
  padding-top: env(safe-area-inset-top);
  padding-right: max(14px, env(safe-area-inset-right));
  padding-left: max(14px, env(safe-area-inset-left));
  background: #f7f8fa;
  border-bottom: 1px solid #e5e7eb;
}

.toolbar-left {
  display: flex;
  flex: 1;
  gap: 10px;
  align-items: center;
  min-width: 0;
}

.back-btn {
  display: flex;
  flex-shrink: 0;
  gap: 3px;
  align-items: center;
  padding: 5px 8px 5px 4px;
  border-radius: 8px;

  &:active {
    background: #e5e7eb;
  }
}

.back-btn__text {
  font-size: 13px;
  font-weight: 500;
  color: #111827;
}

.stem-pill {
  display: flex;
  flex: 1;
  gap: 6px;
  align-items: center;
  min-width: 0;
  max-width: 360px;
  padding: 5px 10px;
  background: #ffffff;
  border: 1px solid #e5e7eb;
  border-radius: 999px;
}

.stem-pill__tag {
  flex-shrink: 0;
  font-size: 11px;
  font-weight: 600;
  color: #16a34a;
}

.stem-pill__text {
  overflow: hidden;
  font-size: 13px;
  color: #1f2937;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.toolbar-right {
  display: flex;
  flex-shrink: 0;
  gap: 8px;
  align-items: center;
}

.color-group {
  display: flex;
  gap: 8px;
  align-items: center;
  padding-right: 4px;
}

.color-dot {
  width: 20px;
  height: 20px;
  border: 2px solid transparent;
  border-radius: 999px;
  box-shadow: inset 0 0 0 1px rgba(0, 0, 0, 0.12);

  &--active {
    border-color: #ffffff;
    box-shadow: 0 0 0 2px #16a34a;
  }
}

.tool-btn {
  padding: 5px 10px;
  background: #ffffff;
  border: 1px solid #d1d5db;
  border-radius: 8px;

  &--active {
    color: #16a34a;
    background: #f0fdf4;
    border-color: #16a34a;

    .tool-btn__text {
      color: #16a34a;
    }
  }

  &--disabled {
    opacity: 0.45;
  }
}

.tool-btn__text {
  font-size: 12px;
  font-weight: 500;
  color: #374151;
}

.save-btn {
  padding: 6px 14px;
  background: #16a34a;
  border-radius: 8px;

  &--disabled {
    opacity: 0.65;
  }
}

.save-btn__text {
  font-size: 13px;
  font-weight: 600;
  color: #ffffff;
}

.canvas-stage {
  position: relative;
  flex: 1;
  width: 100%;
  min-height: 0;
  overflow: hidden;
  background: #ffffff;
}

.draw-canvas {
  display: block;
  width: 100%;
  height: 100%;
  touch-action: none;
}

.canvas-placeholder {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  pointer-events: none;
}

.canvas-placeholder__text {
  font-size: 14px;
  color: #cbd5e1;
}

.stem-modal-mask {
  position: fixed;
  inset: 0;
  z-index: 99;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
  background: rgba(15, 23, 42, 0.45);
}

.stem-modal {
  width: 520px;
  max-width: 90vw;
  padding: 16px 20px;
  background: #ffffff;
  border-radius: 14px;
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.15);
}

.stem-modal__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 10px;
}

.stem-modal__title {
  font-size: 14px;
  font-weight: 600;
  color: #111827;
}

.stem-modal__close {
  font-size: 13px;
  color: #16a34a;
}

.stem-modal__body {
  font-size: 17px;
  line-height: 1.6;
  color: #111827;
}
</style>
