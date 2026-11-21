<template>
  <view class="board-card">
    <view class="board-header">
      <text class="board-header__title">题目绘制面板</text>
      <text class="board-header__hint">可用手指/触控笔书写过程，或拍照上传草稿纸</text>
    </view>

    <!-- 工具栏：颜色、粗细、橡皮与控制 -->
    <view v-if="!pickedImagePath" class="toolbar">
      <view class="toolbar__row">
        <view class="color-group">
          <view
            v-for="c in COLORS"
            :key="c.value"
            class="color-dot"
            :class="{ 'color-dot--active': !eraser && activeColor === c.value }"
            :style="{ backgroundColor: c.value }"
            @click="selectColor(c.value)"
          />
        </view>

        <view class="size-group">
          <view
            v-for="s in SIZES"
            :key="s.width"
            class="tool-chip"
            :class="{ 'tool-chip--active': !eraser && activeWidth === s.width }"
            @click="selectWidth(s.width)"
          >
            {{ s.label }}
          </view>
          <view
            class="tool-chip"
            :class="{ 'tool-chip--active': eraser }"
            @click="toggleEraser"
          >
            橡皮
          </view>
        </view>
      </view>

      <view class="toolbar__row toolbar__row--actions">
        <view class="tool-btn" :class="{ 'tool-btn--disabled': strokes.length === 0 }" @click="undoStroke">
          撤销
        </view>
        <view class="tool-btn" :class="{ 'tool-btn--disabled': strokes.length === 0 }" @click="clearBoard">
          清空
        </view>
        <view class="tool-btn" @click="toggleExpand">
          {{ expanded ? "标准高度" : "放大画板" }}
        </view>
        <view class="tool-btn tool-btn--accent" @click="choosePaperPhoto">
          拍照/传图
        </view>
      </view>
    </view>

    <view v-else class="toolbar toolbar--photo">
      <text class="toolbar__photo-tip">已选作答照片，保存后将上传至云端</text>
      <view class="tool-btn" @click="clearPickedPhoto">改回画板手写</view>
    </view>

    <!-- 画布或图片预览区 -->
    <view class="canvas-stage">
      <image
        v-if="pickedImagePath"
        :src="pickedImagePath"
        mode="aspectFit"
        class="picked-preview"
        :style="{ height: boardHeight + 'px' }"
        @click="previewPicked"
      />
      <canvas
        v-else
        :id="canvasId"
        :canvas-id="canvasId"
        :disable-scroll="true"
        class="drawing-canvas"
        :style="{ width: boardWidth + 'px', height: boardHeight + 'px' }"
        @touchstart.stop.prevent="onTouchStart"
        @touchmove.stop.prevent="onTouchMove"
        @touchend.stop.prevent="onTouchEnd"
        @mousedown="onMouseDown"
        @mousemove="onMouseMove"
        @mouseup="onMouseUp"
        @mouseleave="onMouseUp"
      />
    </view>
  </view>
</template>

<script setup lang="ts">
import { computed, getCurrentInstance, nextTick, onMounted, ref } from "vue";

interface Point {
  x: number;
  y: number;
}

interface Stroke {
  color: string;
  width: number;
  points: Point[];
}

const COLORS = [
  { label: "黑", value: "#111827" },
  { label: "绿", value: "#16a34a" },
  { label: "蓝", value: "#2563eb" },
  { label: "红", value: "#dc2626" },
];

const SIZES = [
  { label: "细", width: 2 },
  { label: "中", width: 4 },
  { label: "粗", width: 7 },
];

const emit = defineEmits<{
  (e: "change", hasContent: boolean): void;
}>();

const instance = getCurrentInstance();
const canvasId = `essayCanvas_${Math.random().toString(36).slice(2, 9)}`;

const sys = uni.getSystemInfoSync();
const boardWidth = ref(Math.max(260, Math.floor((sys.windowWidth || 375) - 48)));
const expanded = ref(false);
const boardHeight = computed(() => (expanded.value ? 420 : 280));

const activeColor = ref("#111827");
const activeWidth = ref(4);
const eraser = ref(false);
const strokes = ref<Stroke[]>([]);
const pickedImagePath = ref("");

let drawing = false;
let currentStroke: Stroke | null = null;
const boardRect = { left: 0, top: 0 };

function getProxy(): any {
  return instance?.proxy ?? undefined;
}

function getCtx(): UniApp.CanvasContext {
  return uni.createCanvasContext(canvasId, getProxy());
}

function measureRect(): void {
  const proxy = getProxy();
  if (!proxy) return;
  uni
    .createSelectorQuery()
    .in(proxy)
    .select(`#${canvasId}`)
    .boundingClientRect((rect: any) => {
      if (rect && typeof rect.left === "number") {
        boardRect.left = rect.left;
        boardRect.top = rect.top;
        if (rect.width && Math.abs(rect.width - boardWidth.value) > 4) {
          boardWidth.value = Math.floor(rect.width);
        }
      }
    })
    .exec();
}

function replayStrokes(): void {
  const ctx = getCtx();
  ctx.setFillStyle("#ffffff");
  ctx.fillRect(0, 0, boardWidth.value, boardHeight.value);

  for (const stroke of strokes.value) {
    if (stroke.points.length === 0) continue;
    ctx.beginPath();
    ctx.setStrokeStyle(stroke.color);
    ctx.setLineWidth(stroke.width);
    ctx.setLineCap("round");
    ctx.setLineJoin("round");
    ctx.moveTo(stroke.points[0].x, stroke.points[0].y);
    if (stroke.points.length === 1) {
      ctx.lineTo(stroke.points[0].x + 0.5, stroke.points[0].y + 0.5);
    } else {
      for (let i = 1; i < stroke.points.length; i += 1) {
        ctx.lineTo(stroke.points[i].x, stroke.points[i].y);
      }
    }
    ctx.stroke();
  }
  ctx.draw(false);
}

function notifyChange(): void {
  emit("change", hasContent());
}

function selectColor(color: string): void {
  eraser.value = false;
  activeColor.value = color;
}

function selectWidth(w: number): void {
  eraser.value = false;
  activeWidth.value = w;
}

function toggleEraser(): void {
  eraser.value = !eraser.value;
}

function currentBrush(): { color: string; width: number } {
  return eraser.value
    ? { color: "#ffffff", width: 16 }
    : { color: activeColor.value, width: activeWidth.value };
}

function extractTouchPoint(e: any): Point | null {
  const t = e?.touches?.[0] || e?.changedTouches?.[0];
  if (!t) return null;
  if (typeof t.x === "number" && typeof t.y === "number") {
    return { x: t.x, y: t.y };
  }
  const cx = typeof t.clientX === "number" ? t.clientX : t.pageX ?? 0;
  const cy = typeof t.clientY === "number" ? t.clientY : t.pageY ?? 0;
  return { x: cx - boardRect.left, y: cy - boardRect.top };
}

function extractMousePoint(e: any): Point | null {
  if (typeof e?.offsetX === "number" && typeof e?.offsetY === "number") {
    return { x: e.offsetX, y: e.offsetY };
  }
  if (typeof e?.clientX === "number" && typeof e?.clientY === "number") {
    return { x: e.clientX - boardRect.left, y: e.clientY - boardRect.top };
  }
  return null;
}

function startStroke(pt: Point): void {
  drawing = true;
  const brush = currentBrush();
  currentStroke = {
    color: brush.color,
    width: brush.width,
    points: [pt],
  };
  const ctx = getCtx();
  ctx.beginPath();
  ctx.setStrokeStyle(brush.color);
  ctx.setLineWidth(brush.width);
  ctx.setLineCap("round");
  ctx.setLineJoin("round");
  ctx.moveTo(pt.x, pt.y);
  ctx.lineTo(pt.x + 0.5, pt.y + 0.5);
  ctx.stroke();
  ctx.draw(true);
}

function moveStroke(pt: Point): void {
  if (!drawing || !currentStroke) return;
  const prev = currentStroke.points[currentStroke.points.length - 1];
  currentStroke.points.push(pt);
  const ctx = getCtx();
  ctx.beginPath();
  ctx.setStrokeStyle(currentStroke.color);
  ctx.setLineWidth(currentStroke.width);
  ctx.setLineCap("round");
  ctx.setLineJoin("round");
  ctx.moveTo(prev.x, prev.y);
  ctx.lineTo(pt.x, pt.y);
  ctx.stroke();
  ctx.draw(true);
}

function endStroke(): void {
  if (!drawing) return;
  drawing = false;
  if (currentStroke && currentStroke.points.length > 0) {
    strokes.value.push(currentStroke);
    notifyChange();
  }
  currentStroke = null;
}

function onTouchStart(e: any): void {
  measureRect();
  const pt = extractTouchPoint(e);
  if (pt) startStroke(pt);
}

function onTouchMove(e: any): void {
  const pt = extractTouchPoint(e);
  if (pt) moveStroke(pt);
}

function onTouchEnd(): void {
  endStroke();
}

function onMouseDown(e: any): void {
  measureRect();
  const pt = extractMousePoint(e);
  if (pt) startStroke(pt);
}

function onMouseMove(e: any): void {
  if (!drawing) return;
  const pt = extractMousePoint(e);
  if (pt) moveStroke(pt);
}

function onMouseUp(): void {
  endStroke();
}

function undoStroke(): void {
  if (strokes.value.length === 0) return;
  strokes.value.pop();
  replayStrokes();
  notifyChange();
}

function clearBoard(): void {
  strokes.value = [];
  pickedImagePath.value = "";
  replayStrokes();
  notifyChange();
}

function toggleExpand(): void {
  expanded.value = !expanded.value;
  void nextTick(() => {
    setTimeout(() => {
      measureRect();
      replayStrokes();
    }, 60);
  });
}

function choosePaperPhoto(): void {
  uni.chooseImage({
    count: 1,
    sizeType: ["compressed"],
    sourceType: ["camera", "album"],
    success: (res) => {
      const path = res.tempFilePaths?.[0];
      if (path) {
        pickedImagePath.value = path;
        notifyChange();
      }
    },
  });
}

function clearPickedPhoto(): void {
  pickedImagePath.value = "";
  void nextTick(() => {
    setTimeout(() => {
      measureRect();
      replayStrokes();
      notifyChange();
    }, 60);
  });
}

function previewPicked(): void {
  if (!pickedImagePath.value) return;
  uni.previewImage({
    urls: [pickedImagePath.value],
  });
}

function hasContent(): boolean {
  return Boolean(pickedImagePath.value) || strokes.value.length > 0;
}

function exportImage(): Promise<string> {
  if (pickedImagePath.value) {
    return Promise.resolve(pickedImagePath.value);
  }
  return new Promise((resolve, reject) => {
    uni.canvasToTempFilePath(
      {
        canvasId,
        width: boardWidth.value,
        height: boardHeight.value,
        destWidth: boardWidth.value * 2,
        destHeight: boardHeight.value * 2,
        fileType: "png",
        quality: 1,
        success: (res) => resolve(res.tempFilePath),
        fail: (err) => reject(err),
      },
      getProxy(),
    );
  });
}

function resetBoard(): void {
  clearBoard();
}

onMounted(() => {
  void nextTick(() => {
    setTimeout(() => {
      measureRect();
      replayStrokes();
    }, 80);
  });
});

defineExpose({
  hasContent,
  exportImage,
  resetBoard,
});
</script>

<style lang="scss" scoped>
.board-card {
  padding: 20rpx;
  margin-top: 20rpx;
  background: var(--color-bg-card);
  border: 1px solid var(--color-border);
  border-radius: 18rpx;
}

.board-header {
  display: flex;
  flex-wrap: wrap;
  gap: 8rpx;
  align-items: baseline;
  justify-content: space-between;
}

.board-header__title {
  font-size: 26rpx;
  font-weight: 600;
  color: var(--color-text);
}

.board-header__hint {
  font-size: 22rpx;
  color: var(--color-text-muted);
}

.toolbar {
  display: flex;
  flex-direction: column;
  gap: 12rpx;
  margin-top: 14rpx;

  &--photo {
    flex-direction: row;
    align-items: center;
    justify-content: space-between;
  }
}

.toolbar__photo-tip {
  font-size: 24rpx;
  color: var(--color-primary);
}

.toolbar__row {
  display: flex;
  flex-wrap: wrap;
  gap: 12rpx;
  align-items: center;
  justify-content: space-between;
}

.toolbar__row--actions {
  justify-content: flex-start;
}

.color-group {
  display: flex;
  gap: 14rpx;
  align-items: center;
}

.color-dot {
  width: 40rpx;
  height: 40rpx;
  border: 3rpx solid transparent;
  border-radius: 50%;
  box-sizing: border-box;

  &--active {
    border-color: #ffffff;
    box-shadow: 0 0 0 3rpx var(--color-primary);
  }
}

.size-group {
  display: flex;
  gap: 10rpx;
  align-items: center;
}

.tool-chip {
  padding: 8rpx 18rpx;
  font-size: 22rpx;
  color: var(--color-text-secondary);
  background: var(--color-bg-page);
  border: 1px solid var(--color-border);
  border-radius: 12rpx;

  &--active {
    color: var(--color-primary);
    background: var(--color-primary-soft);
    border-color: var(--color-primary);
    font-weight: 600;
  }
}

.tool-btn {
  padding: 10rpx 20rpx;
  font-size: 24rpx;
  color: var(--color-text);
  background: var(--color-bg-page);
  border: 1px solid var(--color-border);
  border-radius: 12rpx;

  &--disabled {
    opacity: 0.45;
  }

  &--accent {
    color: var(--color-primary);
    background: var(--color-primary-soft);
    border-color: #bbf7d0;
  }
}

.canvas-stage {
  margin-top: 14rpx;
  overflow: hidden;
  background: #ffffff;
  border: 1px solid #d1d5db;
  border-radius: 12rpx;
}

.drawing-canvas {
  display: block;
  touch-action: none;
  background: #ffffff;
}

.picked-preview {
  display: block;
  width: 100%;
  background: #ffffff;
}
</style>
