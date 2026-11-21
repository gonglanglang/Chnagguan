<template>
  <view class="draw-root">
    <!-- 离屏完整导出画布：置于不透明主页面背后（视口内避免 Android WebView 离屏裁剪导致导白图） -->
    <canvas
      v-if="exportCanvasW > 0 && exportCanvasH > 0"
      id="drawExportCanvas"
      canvas-id="drawExportCanvas"
      class="draw-export-canvas"
      :style="{ width: `${exportCanvasW}px`, height: `${exportCanvasH}px` }"
    />

    <view class="draw-page">
      <!-- 顶部极简工具栏 -->
      <view class="draw-toolbar">
        <view class="toolbar-left">
          <view class="back-btn" @click="handleBack">
            <app-icon name="back" size="18" color="#111827" />
            <text class="back-btn__text">返回</text>
          </view>

          <view v-if="stem" class="stem-pill" @click="showStemModal = true">
            <text class="stem-pill__tag">题干</text>
            <view class="stem-pill__math">
              <math-text :text="stem" inline />
            </view>
          </view>
        </view>

        <view class="toolbar-right">
          <view class="color-group">
            <view
              v-for="c in PEN_COLORS"
              :key="c"
              class="color-dot"
              :class="{ 'color-dot--active': !handMode && !eraserMode && activeColor === c }"
              :style="{ backgroundColor: c }"
              @click="selectPen(c)"
            />
          </view>

          <view
            class="tool-btn"
            :class="{ 'tool-btn--active': handMode }"
            @click="toggleHandMode"
          >
            <app-icon name="hand" size="13" :color="handMode ? '#16a34a' : '#374151'" />
            <text class="tool-btn__text">移动</text>
          </view>
          <view
            class="tool-btn"
            :class="{ 'tool-btn--active': !handMode && eraserMode }"
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

      <!-- 画布容器：悬浮控制条作为兄弟节点渲染，防止被 canvas-stage 的 @touchstart.prevent 吞掉点击 -->
      <view class="stage-wrap">
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
          <view v-if="!hasDrawn && !handMode" class="canvas-placeholder">
            <text class="canvas-placeholder__text">
              无限纯白画板 · 写至边缘自动扩展 · 双指缩放拖动
            </text>
          </view>
        </view>

        <!-- 左下角无限画布悬浮控制条 -->
        <view class="stage-hud">
          <view class="hud-btn" @click="extendPaper('down')">
            <text class="hud-btn__text">↓ 下移空白</text>
          </view>
          <view class="hud-btn" @click="extendPaper('right')">
            <text class="hud-btn__text">→ 右移空白</text>
          </view>
          <view class="hud-divider" />
          <view class="hud-icon-btn" @click="adjustZoom(-0.2)">
            <app-icon name="zoom-out" size="13" color="#475569" />
          </view>
          <text class="hud-zoom-label">{{ Math.round(camera.zoom * 100) }}%</text>
          <view class="hud-icon-btn" @click="adjustZoom(0.2)">
            <app-icon name="zoom-in" size="13" color="#475569" />
          </view>
          <view class="hud-btn" @click="fitContentOrReset">
            <text class="hud-btn__text">{{ strokes.length > 0 ? "全览" : "复位" }}</text>
          </view>
        </view>

        <!-- 画布自动延申轻量提示 -->
        <view v-if="extendHint" class="extend-toast">
          <text class="extend-toast__text">{{ extendHint }}</text>
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
  </view>
</template>

<script setup lang="ts">
import { onBackPress, onLoad, onShow, onUnload } from "@dcloudio/uni-app";
import { getCurrentInstance, nextTick, reactive } from "vue";
import { AppQuizAPI } from "@/api/guoguanla";
import { getErrorMessage } from "@/utils/error";
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
  eraser?: boolean;
  points: Point[];
}

interface StageRect {
  left: number;
  top: number;
  width: number;
  height: number;
}

interface TouchPointLike {
  x?: number;
  y?: number;
  clientX?: number;
  clientY?: number;
  pageX?: number;
  pageY?: number;
}

const PEN_COLORS = ["#111827", "#2563eb", "#dc2626"];
const ACTIVE_ESSAY_PROMPT_KEY = "ggl_active_essay_prompt";
const MIN_ZOOM = 0.25;
const MAX_ZOOM = 3.0;
const MAX_EXPORT_DIM = 1800;

const instance = getCurrentInstance()?.proxy;
const toast = useToast();

const sessionNo = ref("");
const itemIndex = ref(0);
const stem = ref("");
const answerText = ref("");

const activeColor = ref("#111827");
const eraserMode = ref(false);
const handMode = ref(false);
const strokes = ref<Stroke[]>([]);
const hasDrawn = ref(false);
const saving = ref(false);
const showStemModal = ref(false);
const extendHint = ref("");

const canvasWidth = ref(0);
const canvasHeight = ref(0);
const exportCanvasW = ref(0);
const exportCanvasH = ref(0);

const camera = reactive({
  panX: 0,
  panY: 0,
  zoom: 1,
});

let stageRect: StageRect = { left: 0, top: 0, width: 0, height: 0 };
let ctx: UniApp.CanvasContext | null = null;
let drawing = false;
let lastPoint: Point | null = null;
let currentStroke: Stroke | null = null;
let strokeStartedAt = 0;
let strokeMaxWorldX = 0;
let strokeMaxWorldY = 0;
let pendingPoints: Point[] = [];
let flushTimer: ReturnType<typeof setTimeout> | null = null;
let redrawTimer: ReturnType<typeof setTimeout> | null = null;
let extendHintTimer: ReturnType<typeof setTimeout> | null = null;
let lastTouchTs = 0;
let mouseActive = false;
let singlePanning = false;
let singlePanLast: Point | null = null;
let gestureActive = false;
let ignoreRemainingFinger = false;
let gestureStartDist = 1;
let gestureStartZoom = 1;
let gestureAnchorWorld: Point = { x: 0, y: 0 };
let measureTimers: ReturnType<typeof setTimeout>[] = [];

function clearTimers(): void {
  measureTimers.forEach((t) => clearTimeout(t));
  measureTimers = [];
  if (flushTimer !== null) {
    clearTimeout(flushTimer);
    flushTimer = null;
  }
  if (redrawTimer !== null) {
    clearTimeout(redrawTimer);
    redrawTimer = null;
  }
  if (extendHintTimer !== null) {
    clearTimeout(extendHintTimer);
    extendHintTimer = null;
  }
}

function notifyExtend(msg: string): void {
  extendHint.value = msg;
  if (extendHintTimer !== null) {
    clearTimeout(extendHintTimer);
  }
  extendHintTimer = setTimeout(() => {
    extendHint.value = "";
    extendHintTimer = null;
  }, 1600);
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
  handMode.value = false;
}

function toggleEraser(): void {
  eraserMode.value = !eraserMode.value;
  if (eraserMode.value) {
    handMode.value = false;
  }
}

function toggleHandMode(): void {
  handMode.value = !handMode.value;
  if (handMode.value) {
    eraserMode.value = false;
  }
}

function getStrokeColor(): string {
  return eraserMode.value ? "#ffffff" : activeColor.value;
}

function getStrokeWidth(): number {
  return eraserMode.value ? 18 : 3;
}

function screenToWorld(sx: number, sy: number): Point {
  return {
    x: (sx - camera.panX) / camera.zoom,
    y: (sy - camera.panY) / camera.zoom,
  };
}

function worldToScreen(pt: Point): Point {
  return {
    x: camera.panX + pt.x * camera.zoom,
    y: camera.panY + pt.y * camera.zoom,
  };
}

function touchToStagePoint(t: TouchPointLike): Point | null {
  const cx = t.clientX ?? t.pageX;
  const cy = t.clientY ?? t.pageY;
  if (typeof cx === "number" && typeof cy === "number") {
    return { x: cx - stageRect.left, y: cy - stageRect.top };
  }
  if (typeof t.x === "number" && typeof t.y === "number") {
    return { x: t.x, y: t.y };
  }
  return null;
}

function extractScreenPoint(e: unknown): Point | null {
  const evt = e as {
    touches?: TouchPointLike[];
    changedTouches?: TouchPointLike[];
    detail?: { x?: number; y?: number };
    clientX?: number;
    clientY?: number;
    pageX?: number;
    pageY?: number;
  };
  const touch = evt?.touches?.[0] || evt?.changedTouches?.[0];
  if (touch) {
    const pt = touchToStagePoint(touch);
    if (pt) return pt;
  }
  if (typeof evt?.clientX === "number" && typeof evt?.clientY === "number") {
    return { x: evt.clientX - stageRect.left, y: evt.clientY - stageRect.top };
  }
  if (typeof evt?.pageX === "number" && typeof evt?.pageY === "number") {
    return { x: evt.pageX - stageRect.left, y: evt.pageY - stageRect.top };
  }
  if (evt?.detail && typeof evt.detail.x === "number" && typeof evt.detail.y === "number") {
    return { x: evt.detail.x - stageRect.left, y: evt.detail.y - stageRect.top };
  }
  return null;
}

function drawStrokeList(
  targetCtx: UniApp.CanvasContext,
  list: Stroke[],
  mapPoint: (pt: Point) => Point,
  scale: number,
): void {
  for (const s of list) {
    if (!s.points.length) continue;
    const strokeW = Math.max(1, s.width * scale);
    targetCtx.setStrokeStyle(s.color);
    targetCtx.setFillStyle(s.color);
    targetCtx.setLineWidth(strokeW);
    targetCtx.setLineCap("round");
    targetCtx.setLineJoin("round");

    if (s.points.length === 1) {
      const p0 = mapPoint(s.points[0]);
      targetCtx.beginPath();
      targetCtx.arc(p0.x, p0.y, strokeW / 2, 0, Math.PI * 2);
      targetCtx.fill();
    } else {
      const p0 = mapPoint(s.points[0]);
      targetCtx.beginPath();
      targetCtx.moveTo(p0.x, p0.y);
      for (let i = 1; i < s.points.length; i += 1) {
        const pi = mapPoint(s.points[i]);
        targetCtx.lineTo(pi.x, pi.y);
      }
      targetCtx.stroke();
    }
  }
}

function redrawAll(): void {
  if (!ctx || canvasWidth.value <= 0 || canvasHeight.value <= 0) return;

  // 纯白无限画板铺满全屏（无外围背景、无边框限制）
  ctx.setFillStyle("#ffffff");
  ctx.fillRect(0, 0, canvasWidth.value, canvasHeight.value);

  drawStrokeList(ctx, strokes.value, worldToScreen, camera.zoom);
  ctx.draw(false);
}

function scheduleRedraw(): void {
  if (redrawTimer !== null) return;
  redrawTimer = setTimeout(() => {
    redrawTimer = null;
    redrawAll();
  }, 16);
}

function flushPendingSegments(): void {
  if (flushTimer !== null) {
    clearTimeout(flushTimer);
    flushTimer = null;
  }
  if (!ctx || !lastPoint || !currentStroke || pendingPoints.length === 0) return;

  const pts = pendingPoints;
  pendingPoints = [];

  const fromScreen = worldToScreen(lastPoint);
  ctx.setStrokeStyle(currentStroke.color);
  ctx.setLineWidth(Math.max(1, currentStroke.width * camera.zoom));
  ctx.setLineCap("round");
  ctx.setLineJoin("round");
  ctx.beginPath();
  ctx.moveTo(fromScreen.x, fromScreen.y);
  for (const pt of pts) {
    const sp = worldToScreen(pt);
    ctx.lineTo(sp.x, sp.y);
  }
  ctx.stroke();
  ctx.draw(true);
  lastPoint = pts[pts.length - 1];
}

function abortTinyStrokeIfNeeded(): void {
  if (!drawing) return;
  if (Date.now() - strokeStartedAt < 220 && (!currentStroke || currentStroke.points.length <= 4)) {
    if (flushTimer !== null) {
      clearTimeout(flushTimer);
      flushTimer = null;
    }
    drawing = false;
    lastPoint = null;
    currentStroke = null;
    pendingPoints = [];
    hasDrawn.value = strokes.value.length > 0;
    redrawAll();
  } else {
    endStroke();
  }
}

function beginStroke(screenPt: Point): void {
  if (!ctx) {
    ctx = uni.createCanvasContext("drawAnswerCanvas", instance);
    redrawAll();
  }
  const worldPt = screenToWorld(screenPt.x, screenPt.y);

  pendingPoints = [];
  if (flushTimer !== null) {
    clearTimeout(flushTimer);
    flushTimer = null;
  }
  drawing = true;
  strokeStartedAt = Date.now();
  strokeMaxWorldX = worldPt.x;
  strokeMaxWorldY = worldPt.y;
  hasDrawn.value = true;
  lastPoint = worldPt;
  currentStroke = {
    color: getStrokeColor(),
    width: getStrokeWidth(),
    eraser: eraserMode.value,
    points: [worldPt],
  };

  const sp = worldToScreen(worldPt);
  ctx.setFillStyle(currentStroke.color);
  ctx.beginPath();
  ctx.arc(sp.x, sp.y, Math.max(1, currentStroke.width * camera.zoom) / 2, 0, Math.PI * 2);
  ctx.fill();
  ctx.draw(true);
}

function moveStroke(screenPt: Point): void {
  if (!drawing || !lastPoint || !currentStroke || !ctx) return;
  const worldPt = screenToWorld(screenPt.x, screenPt.y);
  const refPt = pendingPoints[pendingPoints.length - 1] || lastPoint;
  const dx = worldPt.x - refPt.x;
  const dy = worldPt.y - refPt.y;
  if ((dx * dx + dy * dy) * camera.zoom * camera.zoom < 2.25) return;

  if (worldPt.x > strokeMaxWorldX) strokeMaxWorldX = worldPt.x;
  if (worldPt.y > strokeMaxWorldY) strokeMaxWorldY = worldPt.y;

  currentStroke.points.push(worldPt);
  pendingPoints.push(worldPt);
  if (flushTimer === null) {
    flushTimer = setTimeout(flushPendingSegments, 16);
  }
}

function endStroke(): void {
  if (!drawing) return;
  flushPendingSegments();
  const finished = currentStroke;
  if (finished && finished.points.length > 0) {
    strokes.value = [...strokes.value, finished];
  }
  drawing = false;
  lastPoint = null;
  currentStroke = null;

  // 若笔迹贴近底部或右侧视口边缘，自动推进无限画布，释放新书写空间
  if (finished && !finished.eraser && canvasWidth.value > 0 && canvasHeight.value > 0) {
    const endScreen = worldToScreen({ x: strokeMaxWorldX, y: strokeMaxWorldY });
    let shifted = false;
    let hint = "";
    if (endScreen.y > canvasHeight.value - 42) {
      camera.panY -= Math.round(canvasHeight.value * 0.34);
      shifted = true;
      hint = "已自动向下延申书写区";
    } else if (endScreen.x > canvasWidth.value - 48) {
      camera.panX -= Math.round(canvasWidth.value * 0.28);
      shifted = true;
      hint = "已自动向右延申书写区";
    }
    if (shifted) {
      redrawAll();
      notifyExtend(hint);
    }
  }
}

function extendPaper(dir: "down" | "right"): void {
  const cw = canvasWidth.value || 640;
  const ch = canvasHeight.value || 320;
  if (dir === "down") {
    camera.panY -= Math.round(ch * 0.45);
    redrawAll();
    notifyExtend("已向下空出书写区");
  } else {
    camera.panX -= Math.round(cw * 0.42);
    redrawAll();
    notifyExtend("已向右空出书写区");
  }
}

function adjustZoom(delta: number): void {
  const cw = canvasWidth.value || 640;
  const ch = canvasHeight.value || 320;
  const oldZoom = camera.zoom;
  const nextZoom = Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, Number((oldZoom + delta).toFixed(2))));
  if (nextZoom === oldZoom) return;
  const centerWorldX = (cw / 2 - camera.panX) / oldZoom;
  const centerWorldY = (ch / 2 - camera.panY) / oldZoom;
  camera.zoom = nextZoom;
  camera.panX = cw / 2 - centerWorldX * nextZoom;
  camera.panY = ch / 2 - centerWorldY * nextZoom;
  redrawAll();
}

function resetViewport(): void {
  camera.zoom = 1;
  camera.panX = 0;
  camera.panY = 0;
  redrawAll();
}

function fitContentOrReset(): void {
  const inkStrokes = strokes.value.filter((s) => !s.eraser && s.points.length > 0);
  if (inkStrokes.length === 0 || canvasWidth.value <= 0 || canvasHeight.value <= 0) {
    resetViewport();
    return;
  }
  let minX = Number.POSITIVE_INFINITY;
  let minY = Number.POSITIVE_INFINITY;
  let maxX = Number.NEGATIVE_INFINITY;
  let maxY = Number.NEGATIVE_INFINITY;
  for (const s of inkStrokes) {
    for (const pt of s.points) {
      if (pt.x < minX) minX = pt.x;
      if (pt.y < minY) minY = pt.y;
      if (pt.x > maxX) maxX = pt.x;
      if (pt.y > maxY) maxY = pt.y;
    }
  }
  const pad = 40;
  const boxW = Math.max(120, maxX - minX + pad * 2);
  const boxH = Math.max(100, maxY - minY + pad * 2);
  const nextZoom = Math.max(
    MIN_ZOOM,
    Math.min(1.2, Math.min(canvasWidth.value / boxW, canvasHeight.value / boxH)),
  );
  camera.zoom = Number(nextZoom.toFixed(2));
  camera.panX = canvasWidth.value / 2 - ((minX + maxX) / 2) * camera.zoom;
  camera.panY = canvasHeight.value / 2 - ((minY + maxY) / 2) * camera.zoom;
  redrawAll();
}

function getTwoTouches(e: unknown): [Point, Point] | null {
  const evt = e as { touches?: TouchPointLike[] };
  if (!evt?.touches || evt.touches.length < 2) return null;
  const p0 = touchToStagePoint(evt.touches[0]);
  const p1 = touchToStagePoint(evt.touches[1]);
  if (!p0 || !p1) return null;
  return [p0, p1];
}

function onTouchStart(e: unknown): void {
  if (saving.value) return;
  lastTouchTs = Date.now();
  refreshStageRect();

  const pair = getTwoTouches(e);
  if (pair) {
    abortTinyStrokeIfNeeded();
    singlePanning = false;
    gestureActive = true;
    ignoreRemainingFinger = false;
    const [p0, p1] = pair;
    const midX = (p0.x + p1.x) / 2;
    const midY = (p0.y + p1.y) / 2;
    gestureStartDist = Math.max(12, Math.hypot(p1.x - p0.x, p1.y - p0.y));
    gestureStartZoom = camera.zoom;
    gestureAnchorWorld = {
      x: (midX - camera.panX) / camera.zoom,
      y: (midY - camera.panY) / camera.zoom,
    };
    return;
  }

  ignoreRemainingFinger = false;
  const pt = extractScreenPoint(e);
  if (!pt) return;
  if (handMode.value) {
    singlePanning = true;
    singlePanLast = pt;
  } else {
    beginStroke(pt);
  }
}

function onTouchMove(e: unknown): void {
  if (saving.value) return;
  lastTouchTs = Date.now();

  const pair = getTwoTouches(e);
  if (pair) {
    if (!gestureActive) {
      abortTinyStrokeIfNeeded();
      gestureActive = true;
      const [p0, p1] = pair;
      const midX = (p0.x + p1.x) / 2;
      const midY = (p0.y + p1.y) / 2;
      gestureStartDist = Math.max(12, Math.hypot(p1.x - p0.x, p1.y - p0.y));
      gestureStartZoom = camera.zoom;
      gestureAnchorWorld = {
        x: (midX - camera.panX) / camera.zoom,
        y: (midY - camera.panY) / camera.zoom,
      };
      return;
    }
    const [p0, p1] = pair;
    const midX = (p0.x + p1.x) / 2;
    const midY = (p0.y + p1.y) / 2;
    const dist = Math.max(12, Math.hypot(p1.x - p0.x, p1.y - p0.y));
    const nextZoom = Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, gestureStartZoom * (dist / gestureStartDist)));
    camera.zoom = nextZoom;
    camera.panX = midX - gestureAnchorWorld.x * nextZoom;
    camera.panY = midY - gestureAnchorWorld.y * nextZoom;
    scheduleRedraw();
    return;
  }

  if (ignoreRemainingFinger || gestureActive) return;

  const pt = extractScreenPoint(e);
  if (!pt) return;
  if (singlePanning && singlePanLast) {
    camera.panX += pt.x - singlePanLast.x;
    camera.panY += pt.y - singlePanLast.y;
    singlePanLast = pt;
    scheduleRedraw();
    return;
  }

  if (drawing) {
    moveStroke(pt);
  }
}

function onTouchEnd(e: unknown): void {
  lastTouchTs = Date.now();
  const evt = e as { touches?: TouchPointLike[] };
  const remaining = evt?.touches?.length || 0;
  if (gestureActive) {
    if (remaining === 0) {
      gestureActive = false;
      ignoreRemainingFinger = false;
    } else {
      gestureActive = false;
      ignoreRemainingFinger = true;
    }
    return;
  }
  if (remaining === 0) {
    ignoreRemainingFinger = false;
    singlePanning = false;
    singlePanLast = null;
    endStroke();
  }
}

function onMouseDown(e: unknown): void {
  if (saving.value || Date.now() - lastTouchTs < 800) return;
  mouseActive = true;
  refreshStageRect();
  const pt = extractScreenPoint(e);
  if (!pt) return;
  if (handMode.value) {
    singlePanning = true;
    singlePanLast = pt;
  } else {
    beginStroke(pt);
  }
}

function onMouseMove(e: unknown): void {
  if (!mouseActive || saving.value || Date.now() - lastTouchTs < 800) return;
  const pt = extractScreenPoint(e);
  if (!pt) return;
  if (singlePanning && singlePanLast) {
    camera.panX += pt.x - singlePanLast.x;
    camera.panY += pt.y - singlePanLast.y;
    singlePanLast = pt;
    scheduleRedraw();
    return;
  }
  if (drawing) {
    moveStroke(pt);
  }
}

function onMouseUp(): void {
  if (!mouseActive) return;
  mouseActive = false;
  singlePanning = false;
  singlePanLast = null;
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
  resetViewport();
}

async function exportCanvasTempFile(): Promise<string> {
  // 计算所有有效笔迹的完整外接包围盒，确保自动延申或缩放后仍导出完整无裁剪解答图
  const inkStrokes = strokes.value.filter((s) => !s.eraser && s.points.length > 0);
  const scanList = inkStrokes.length > 0 ? inkStrokes : strokes.value;

  let minX = Number.POSITIVE_INFINITY;
  let minY = Number.POSITIVE_INFINITY;
  let maxX = Number.NEGATIVE_INFINITY;
  let maxY = Number.NEGATIVE_INFINITY;

  for (const s of scanList) {
    const half = s.width / 2;
    for (const pt of s.points) {
      if (pt.x - half < minX) minX = pt.x - half;
      if (pt.y - half < minY) minY = pt.y - half;
      if (pt.x + half > maxX) maxX = pt.x + half;
      if (pt.y + half > maxY) maxY = pt.y + half;
    }
  }

  if (!Number.isFinite(minX)) {
    minX = 0;
    minY = 0;
    maxX = canvasWidth.value || 800;
    maxY = canvasHeight.value || 420;
  }

  const pad = 40;
  const originX = Math.floor(minX - pad);
  const originY = Math.floor(minY - pad);
  const rawW = Math.max(480, Math.ceil(maxX + pad) - originX);
  const rawH = Math.max(280, Math.ceil(maxY + pad) - originY);
  const scale = Math.min(1, MAX_EXPORT_DIM / Math.max(rawW, rawH));
  const outW = Math.max(120, Math.round(rawW * scale));
  const outH = Math.max(120, Math.round(rawH * scale));

  exportCanvasW.value = outW;
  exportCanvasH.value = outH;
  await nextTick();
  await new Promise((resolve) => setTimeout(resolve, 80));

  const exportCtx = uni.createCanvasContext("drawExportCanvas", instance);
  exportCtx.setFillStyle("#ffffff");
  exportCtx.fillRect(0, 0, outW, outH);
  drawStrokeList(
    exportCtx,
    strokes.value,
    (pt) => ({ x: (pt.x - originX) * scale, y: (pt.y - originY) * scale }),
    scale,
  );

  await new Promise<void>((resolve) => {
    let settled = false;
    const done = () => {
      if (settled) return;
      settled = true;
      resolve();
    };
    const fallback = setTimeout(done, 700);
    exportCtx.draw(false, () => {
      clearTimeout(fallback);
      setTimeout(done, 90);
    });
  });

  return new Promise((resolve, reject) => {
    const sys = uni.getSystemInfoSync();
    const dpr = Math.min(2, sys.pixelRatio || 2);
    uni.canvasToTempFilePath(
      {
        canvasId: "drawExportCanvas",
        x: 0,
        y: 0,
        width: outW,
        height: outH,
        destWidth: Math.round(outW * dpr),
        destHeight: Math.round(outH * dpr),
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
    exportCanvasW.value = 0;
    exportCanvasH.value = 0;
  }
}

function safeDecodeParam(raw?: string): string {
  if (!raw) return "";
  try {
    return decodeURIComponent(raw);
  } catch {
    return raw;
  }
}

onLoad((query) => {
  lockLandscapeOrientation();

  const cached = uni.getStorageSync(ACTIVE_ESSAY_PROMPT_KEY) as
    | { sessionNo?: string; itemIndex?: number; stem?: string; answerText?: string }
    | undefined;

  sessionNo.value = safeDecodeParam(query?.sessionNo) || cached?.sessionNo || "";
  itemIndex.value =
    query?.itemIndex !== undefined
      ? Number(query.itemIndex)
      : Number(cached?.itemIndex || 0);
  const sameCachedItem =
    Boolean(cached) &&
    (!sessionNo.value || cached?.sessionNo === sessionNo.value) &&
    Number(cached?.itemIndex || 0) === itemIndex.value;

  stem.value =
    (sameCachedItem ? cached?.stem : "") || safeDecodeParam(query?.stem) || cached?.stem || "";
  answerText.value =
    (sameCachedItem ? cached?.answerText : "") || safeDecodeParam(query?.answerText) || cached?.answerText || "";

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
.draw-root {
  position: relative;
  width: 100vw;
  height: 100vh;
  overflow: hidden;
  background: #ffffff;
}

.draw-export-canvas {
  position: fixed;
  top: 0;
  left: 0;
  z-index: 0;
  pointer-events: none;
}

.draw-page {
  position: relative;
  z-index: 2;
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
  gap: 8px;
  align-items: center;
  justify-content: space-between;
  height: 48px;
  padding-top: env(safe-area-inset-top);
  padding-right: max(12px, env(safe-area-inset-right));
  padding-left: max(12px, env(safe-area-inset-left));
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
  max-width: 420px;
  max-height: 40px;
  padding: 4px 10px;
  background: #ffffff;
  border: 1px solid #e5e7eb;
  border-radius: 12px;
}

.stem-pill__tag {
  flex-shrink: 0;
  font-size: 11px;
  font-weight: 600;
  color: #16a34a;
}

.stem-pill__math {
  flex: 1;
  min-width: 0;
  overflow-x: auto;
  overflow-y: hidden;
  font-size: 12px;
  line-height: 1.35;
  color: #1f2937;
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
  display: flex;
  gap: 3px;
  align-items: center;
  padding: 5px 9px;
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

.stage-wrap {
  position: relative;
  display: flex;
  flex: 1;
  min-height: 0;
  overflow: hidden;
}

.canvas-stage {
  position: relative;
  flex: 1;
  width: 100%;
  height: 100%;
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
  padding: 0 24px;
  pointer-events: none;
}

.canvas-placeholder__text {
  font-size: 13px;
  color: #94a3b8;
  text-align: center;
}

.stage-hud {
  position: absolute;
  bottom: max(10px, env(safe-area-inset-bottom));
  left: max(14px, env(safe-area-inset-left));
  z-index: 12;
  display: flex;
  gap: 6px;
  align-items: center;
  padding: 5px 10px;
  background: rgba(255, 255, 255, 0.94);
  border: 1px solid #e2e8f0;
  border-radius: 999px;
  box-shadow: 0 4px 12px rgba(15, 23, 42, 0.08);
}

.hud-btn {
  padding: 3px 8px;
  background: #f8fafc;
  border-radius: 999px;

  &:active {
    background: #dcfce7;
  }
}

.hud-btn__text {
  font-size: 11px;
  font-weight: 500;
  color: #334155;
}

.hud-icon-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 24px;
  height: 24px;
  background: #f8fafc;
  border-radius: 999px;

  &:active {
    background: #e2e8f0;
  }
}

.hud-divider {
  width: 1px;
  height: 14px;
  background: #e2e8f0;
}

.hud-zoom-label {
  min-width: 34px;
  font-size: 11px;
  font-weight: 600;
  color: #475569;
  text-align: center;
}

.extend-toast {
  position: absolute;
  top: 10px;
  left: 50%;
  z-index: 15;
  padding: 4px 12px;
  pointer-events: none;
  background: rgba(22, 163, 74, 0.92);
  border-radius: 999px;
  transform: translateX(-50%);
}

.extend-toast__text {
  font-size: 12px;
  font-weight: 500;
  color: #ffffff;
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
