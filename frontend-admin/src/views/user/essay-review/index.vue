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

// 画板双层 Canvas（底层原图，顶层批注）
const stageHostRef = ref<HTMLElement | null>(null);
const baseCanvasRef = ref<HTMLCanvasElement | null>(null);
const drawCanvasRef = ref<HTMLCanvasElement | null>(null);

const canvasWidth = ref(960);
const canvasHeight = ref(640);
const baseImageEl = ref<HTMLImageElement | null>(null);
const baseObjectUrl = ref("");

const activeColor = ref("#ef4444");
const lineWidth = ref(4);
const eraserMode = ref(false);
const strokes = ref<Stroke[]>([]);
const drawing = ref(false);
let currentStroke: Stroke | null = null;

function revokeObjectUrl() {
  if (baseObjectUrl.value) {
    URL.revokeObjectURL(baseObjectUrl.value);
    baseObjectUrl.value = "";
  }
}

function renderBaseLayer() {
  const canvas = baseCanvasRef.value;
  if (!canvas) return;
  const ctx = canvas.getContext("2d");
  if (!ctx) return;

  ctx.fillStyle = "#ffffff";
  ctx.fillRect(0, 0, canvasWidth.value, canvasHeight.value);

  const img = baseImageEl.value;
  if (!img) return;
  const scale = Math.min(
    (canvasWidth.value - 32) / img.naturalWidth,
    (canvasHeight.value - 32) / img.naturalHeight
  );
  const w = img.naturalWidth * scale;
  const h = img.naturalHeight * scale;
  const x = (canvasWidth.value - w) / 2;
  const y = (canvasHeight.value - h) / 2;
  ctx.drawImage(img, x, y, w, h);
}

function renderDrawLayer() {
  const canvas = drawCanvasRef.value;
  if (!canvas) return;
  const ctx = canvas.getContext("2d");
  if (!ctx) return;

  ctx.clearRect(0, 0, canvasWidth.value, canvasHeight.value);
  for (const s of strokes.value) {
    drawStrokeOnCtx(ctx, s);
  }
}

function drawStrokeOnCtx(ctx: CanvasRenderingContext2D, s: Stroke) {
  if (!s.points.length) return;
  ctx.save();
  ctx.globalCompositeOperation = s.eraser ? "destination-out" : "source-over";
  ctx.strokeStyle = s.eraser ? "#000000" : s.color;
  ctx.fillStyle = s.eraser ? "#000000" : s.color;
  ctx.lineWidth = s.width;
  ctx.lineCap = "round";
  ctx.lineJoin = "round";

  if (s.points.length === 1) {
    ctx.beginPath();
    ctx.arc(s.points[0].x, s.points[0].y, s.width / 2, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
    return;
  }

  ctx.beginPath();
  ctx.moveTo(s.points[0].x, s.points[0].y);
  for (let i = 1; i < s.points.length - 1; i++) {
    const midX = (s.points[i].x + s.points[i + 1].x) / 2;
    const midY = (s.points[i].y + s.points[i + 1].y) / 2;
    ctx.quadraticCurveTo(s.points[i].x, s.points[i].y, midX, midY);
  }
  const last = s.points[s.points.length - 1];
  ctx.lineTo(last.x, last.y);
  ctx.stroke();
  ctx.restore();
}

function getCanvasPoint(e: PointerEvent): Point {
  const canvas = drawCanvasRef.value!;
  const rect = canvas.getBoundingClientRect();
  const scaleX = canvas.width / Math.max(1, rect.width);
  const scaleY = canvas.height / Math.max(1, rect.height);
  return {
    x: (e.clientX - rect.left) * scaleX,
    y: (e.clientY - rect.top) * scaleY
  };
}

function onPointerDown(e: PointerEvent) {
  if (!drawCanvasRef.value) return;
  drawCanvasRef.value.setPointerCapture(e.pointerId);
  drawing.value = true;
  const pt = getCanvasPoint(e);
  currentStroke = {
    color: activeColor.value,
    width: eraserMode.value ? Math.max(16, lineWidth.value * 4) : lineWidth.value,
    eraser: eraserMode.value,
    points: [pt]
  };
  strokes.value.push(currentStroke);
  renderDrawLayer();
}

function onPointerMove(e: PointerEvent) {
  if (!drawing.value || !currentStroke) return;
  const pt = getCanvasPoint(e);
  const prev = currentStroke.points[currentStroke.points.length - 1];
  if (prev && Math.hypot(pt.x - prev.x, pt.y - prev.y) < 1.5) return;
  currentStroke.points.push(pt);
  renderDrawLayer();
}

function onPointerUp(e: PointerEvent) {
  if (!drawing.value) return;
  drawing.value = false;
  currentStroke = null;
  if (drawCanvasRef.value?.hasPointerCapture(e.pointerId)) {
    drawCanvasRef.value.releasePointerCapture(e.pointerId);
  }
}

function undoStroke() {
  if (strokes.value.length === 0) return;
  strokes.value.pop();
  renderDrawLayer();
}

function clearStrokes() {
  strokes.value = [];
  renderDrawLayer();
}

async function initCanvasImage() {
  if (!essay.value?.answerImageUrl) {
    baseImageEl.value = null;
    await nextTick();
    renderBaseLayer();
    renderDrawLayer();
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
        // 按学生手写图自然比例保持清晰分辨率
        const hostW = stageHostRef.value?.clientWidth ? stageHostRef.value.clientWidth - 40 : 960;
        const w = Math.max(900, Math.min(1400, img.naturalWidth || hostW));
        const h = Math.max(560, Math.round(w * (img.naturalHeight / Math.max(1, img.naturalWidth))));
        canvasWidth.value = w;
        canvasHeight.value = h;
        resolve();
      };
      img.onerror = () => reject(new Error("图片加载失败"));
      img.src = url;
    });
  } catch {
    baseImageEl.value = null;
  }

  await nextTick();
  renderBaseLayer();
  renderDrawLayer();
}

async function exportCompositePngBlob(): Promise<Blob | null> {
  if (strokes.value.length === 0) return null;
  const off = document.createElement("canvas");
  off.width = canvasWidth.value;
  off.height = canvasHeight.value;
  const ctx = off.getContext("2d");
  if (!ctx) return null;

  if (baseCanvasRef.value) {
    ctx.drawImage(baseCanvasRef.value, 0, 0);
  } else {
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, off.width, off.height);
  }
  if (drawCanvasRef.value) {
    ctx.drawImage(drawCanvasRef.value, 0, 0);
  }

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

onMounted(async () => {
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

      <!-- 画笔工具组 -->
      <div class="flex items-center gap-3">
        <div class="flex items-center gap-1.5 rounded-full border border-slate-200 bg-slate-50 px-2.5 py-1">
          <button
            v-for="c in PEN_COLORS"
            :key="c.value"
            type="button"
            class="h-5 w-5 rounded-full border-2 transition"
            :class="!eraserMode && activeColor === c.value ? 'scale-115 border-slate-800' : 'border-transparent'"
            :style="{ backgroundColor: c.value }"
            :title="c.label"
            @click="eraserMode = false; activeColor = c.value"
          />
        </div>

        <el-radio-group v-model="lineWidth" size="small">
          <el-radio-button :value="2">细</el-radio-button>
          <el-radio-button :value="4">中</el-radio-button>
          <el-radio-button :value="8">粗</el-radio-button>
        </el-radio-group>

        <el-button :type="eraserMode ? 'warning' : 'default'" plain size="small" @click="eraserMode = !eraserMode">
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

    <!-- 主工作区：左侧交互批改画板 + 右侧题目与评分栏 -->
    <main class="grid min-h-0 flex-1 grid-cols-12 gap-4 overflow-hidden p-4">
      <section
        ref="stageHostRef"
        class="col-span-8 flex min-h-0 items-center justify-center overflow-auto rounded-xl border border-slate-200 bg-slate-200/70 p-4"
      >
        <div
          class="relative shrink-0 overflow-hidden rounded-lg bg-white shadow-md"
          :style="{ width: '100%', maxWidth: `${canvasWidth}px`, aspectRatio: `${canvasWidth} / ${canvasHeight}` }"
        >
          <canvas
            ref="baseCanvasRef"
            :width="canvasWidth"
            :height="canvasHeight"
            class="absolute inset-0 h-full w-full"
          />
          <canvas
            ref="drawCanvasRef"
            :width="canvasWidth"
            :height="canvasHeight"
            class="relative z-10 h-full w-full touch-none select-none"
            :class="eraserMode ? 'cursor-cell' : 'cursor-crosshair'"
            @pointerdown="onPointerDown"
            @pointermove="onPointerMove"
            @pointerup="onPointerUp"
            @pointercancel="onPointerUp"
          />
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
