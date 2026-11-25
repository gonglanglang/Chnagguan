<script setup lang="ts">
import { computed } from "vue";

export interface DiagramPrimitive {
  type: string;
  x?: number;
  y?: number;
  x1?: number;
  y1?: number;
  x2?: number;
  y2?: number;
  cx?: number;
  cy?: number;
  r?: number;
  startAngle?: number;
  sweepAngle?: number;
  vx?: number;
  vy?: number;
  ax?: number;
  ay?: number;
  bx?: number;
  by?: number;
  size?: number;
  points?: number[][];
  color?: string;
  fillColor?: string;
  fill?: string;
  strokeWidth?: number;
  dashed?: boolean;
  label?: string;
  text?: string;
  fontSize?: number;
}

export interface DiagramSpec {
  title?: string;
  width?: number;
  height?: number;
  primitives?: DiagramPrimitive[];
}

const props = withDefaults(
  defineProps<{
    diagram?: DiagramSpec | null;
    imageUrl?: string | null;
    compact?: boolean;
  }>(),
  {
    diagram: null,
    imageUrl: "",
    compact: false
  }
);

const viewW = computed(() => Number(props.diagram?.width || 320));
const viewH = computed(() => Number(props.diagram?.height || 210));
const primitives = computed<DiagramPrimitive[]>(() =>
  Array.isArray(props.diagram?.primitives) ? props.diagram!.primitives! : []
);

const hasDiagram = computed(() => primitives.value.length > 0);
const hasImage = computed(() => Boolean(props.imageUrl && props.imageUrl.trim()));

function toPointsAttr(pts?: number[][]): string {
  if (!Array.isArray(pts)) return "";
  return pts
    .filter(p => Array.isArray(p) && p.length >= 2)
    .map(p => `${p[0]},${p[1]}`)
    .join(" ");
}

function buildArrowHead(p: DiagramPrimitive): string {
  const x1 = Number(p.x1 ?? 0);
  const y1 = Number(p.y1 ?? 0);
  const x2 = Number(p.x2 ?? 0);
  const y2 = Number(p.y2 ?? 0);
  const angle = Math.atan2(y2 - y1, x2 - x1);
  const headLen = 8;
  const spread = Math.PI / 6;
  const p1x = x2 - headLen * Math.cos(angle - spread);
  const p1y = y2 - headLen * Math.sin(angle - spread);
  const p2x = x2 - headLen * Math.cos(angle + spread);
  const p2y = y2 - headLen * Math.sin(angle + spread);
  return `${x2.toFixed(1)},${y2.toFixed(1)} ${p1x.toFixed(1)},${p1y.toFixed(1)} ${p2x.toFixed(1)},${p2y.toFixed(1)}`;
}

function buildRightAnglePath(p: DiagramPrimitive): string {
  const vx = Number(p.vx ?? 0);
  const vy = Number(p.vy ?? 0);
  const ax = Number(p.ax ?? 0);
  const ay = Number(p.ay ?? 0);
  const bx = Number(p.bx ?? 0);
  const by = Number(p.by ?? 0);
  const size = Number(p.size ?? 12);
  const da = Math.hypot(ax - vx, ay - vy) || 1;
  const db = Math.hypot(bx - vx, by - vy) || 1;
  const ux = ((ax - vx) / da) * size;
  const uy = ((ay - vy) / da) * size;
  const wx = ((bx - vx) / db) * size;
  const wy = ((by - vy) / db) * size;
  const p1x = vx + ux;
  const p1y = vy + uy;
  const p2x = vx + ux + wx;
  const p2y = vy + uy + wy;
  const p3x = vx + wx;
  const p3y = vy + wy;
  return `M ${p1x.toFixed(1)} ${p1y.toFixed(1)} L ${p2x.toFixed(1)} ${p2y.toFixed(1)} L ${p3x.toFixed(1)} ${p3y.toFixed(1)}`;
}

function buildArcPath(p: DiagramPrimitive, closedSector = false): string {
  const cx = Number(p.cx ?? 0);
  const cy = Number(p.cy ?? 0);
  const r = Number(p.r ?? 20);
  const startDeg = Number(p.startAngle ?? 0);
  const sweepDeg = Number(p.sweepAngle ?? 90);
  const clampedSweep = Math.max(-359.5, Math.min(359.5, sweepDeg));
  const rad1 = (startDeg * Math.PI) / 180;
  const rad2 = ((startDeg + clampedSweep) * Math.PI) / 180;
  const sx = cx + r * Math.cos(rad1);
  const sy = cy + r * Math.sin(rad1);
  const ex = cx + r * Math.cos(rad2);
  const ey = cy + r * Math.sin(rad2);
  const largeArc = Math.abs(clampedSweep) > 180 ? 1 : 0;
  const sweepFlag = clampedSweep >= 0 ? 1 : 0;
  if (closedSector) {
    return `M ${cx.toFixed(1)} ${cy.toFixed(1)} L ${sx.toFixed(1)} ${sy.toFixed(1)} A ${r} ${r} 0 ${largeArc} ${sweepFlag} ${ex.toFixed(1)} ${ey.toFixed(1)} Z`;
  }
  return `M ${sx.toFixed(1)} ${sy.toFixed(1)} A ${r} ${r} 0 ${largeArc} ${sweepFlag} ${ex.toFixed(1)} ${ey.toFixed(1)}`;
}

function resolveFill(p: DiagramPrimitive): string {
  return p.fillColor || p.fill || "none";
}
</script>

<template>
  <div v-if="hasDiagram || hasImage" class="space-y-2">
    <div
      v-if="hasDiagram"
      class="overflow-hidden rounded-lg border border-slate-200 bg-white"
      :class="compact ? 'p-1.5' : 'p-2.5'"
    >
      <div
        v-if="diagram?.title && !compact"
        class="mb-1 flex items-center justify-between text-[11px] font-semibold text-slate-500"
      >
        <span>{{ diagram.title }}</span>
        <span class="rounded bg-sky-50 px-1.5 py-0.5 text-[10px] text-sky-700">矢量配图</span>
      </div>
      <svg
        :viewBox="`0 0 ${viewW} ${viewH}`"
        class="mx-auto block w-full"
        :style="{ maxHeight: compact ? '130px' : '210px' }"
        preserveAspectRatio="xMidYMid meet"
      >
        <template v-for="(p, idx) in primitives" :key="idx">
          <!-- 直线 -->
          <line
            v-if="p.type === 'line'"
            :x1="p.x1"
            :y1="p.y1"
            :x2="p.x2"
            :y2="p.y2"
            :stroke="p.color || '#1E293B'"
            :stroke-width="p.strokeWidth || 2"
            :stroke-dasharray="p.dashed ? '5,4' : undefined"
            stroke-linecap="round"
          />

          <!-- 带箭头直线 -->
          <g v-else-if="p.type === 'arrow'">
            <line
              :x1="p.x1"
              :y1="p.y1"
              :x2="p.x2"
              :y2="p.y2"
              :stroke="p.color || '#1E293B'"
              :stroke-width="p.strokeWidth || 1.8"
              :stroke-dasharray="p.dashed ? '5,4' : undefined"
              stroke-linecap="round"
            />
            <polygon :points="buildArrowHead(p)" :fill="p.color || '#1E293B'" />
          </g>

          <!-- 圆 -->
          <circle
            v-else-if="p.type === 'circle'"
            :cx="p.cx"
            :cy="p.cy"
            :r="p.r"
            :stroke="p.color || '#1E293B'"
            :stroke-width="p.strokeWidth || 2"
            :stroke-dasharray="p.dashed ? '5,4' : undefined"
            :fill="resolveFill(p)"
            :fill-opacity="resolveFill(p) === 'none' ? 0 : 0.22"
          />

          <!-- 圆弧 / 扇形角标 -->
          <g v-else-if="p.type === 'arc'">
            <path
              v-if="resolveFill(p) !== 'none'"
              :d="buildArcPath(p, true)"
              :fill="resolveFill(p)"
              fill-opacity="0.22"
              stroke="none"
            />
            <path
              :d="buildArcPath(p, false)"
              fill="none"
              :stroke="p.color || '#DC2626'"
              :stroke-width="p.strokeWidth || 1.8"
              :stroke-dasharray="p.dashed ? '4,3' : undefined"
              stroke-linecap="round"
            />
          </g>

          <!-- 直角符号 -->
          <path
            v-else-if="p.type === 'rightAngle'"
            :d="buildRightAnglePath(p)"
            fill="none"
            :stroke="p.color || '#0284C7'"
            :stroke-width="p.strokeWidth || 1.6"
            stroke-linejoin="miter"
          />

          <!-- 多边形 -->
          <polygon
            v-else-if="p.type === 'polygon'"
            :points="toPointsAttr(p.points)"
            :stroke="p.color || '#1E293B'"
            :stroke-width="p.strokeWidth || 2"
            :stroke-dasharray="p.dashed ? '5,4' : undefined"
            :fill="resolveFill(p)"
            :fill-opacity="resolveFill(p) === 'none' ? 0 : 0.18"
            stroke-linejoin="round"
          />

          <!-- 折线 / 曲线 -->
          <polyline
            v-else-if="p.type === 'polyline'"
            :points="toPointsAttr(p.points)"
            fill="none"
            :stroke="p.color || '#0284C7'"
            :stroke-width="p.strokeWidth || 2"
            :stroke-dasharray="p.dashed ? '5,4' : undefined"
            stroke-linecap="round"
            stroke-linejoin="round"
          />

          <!-- 顶点与标注 -->
          <g v-else-if="p.type === 'point'">
            <circle :cx="p.x" :cy="p.y" r="3.2" :fill="p.color || '#1E293B'" />
            <text
              v-if="p.label"
              :x="(p.x ?? 0) + 6"
              :y="(p.y ?? 0) - 5"
              :fill="p.color || '#1E293B'"
              font-size="12"
              font-weight="600"
              font-family="system-ui, -apple-system, sans-serif"
            >
              {{ p.label }}
            </text>
          </g>

          <!-- 文本标注 -->
          <text
            v-else-if="p.type === 'text'"
            :x="p.x"
            :y="(p.y ?? 0) + 11"
            :fill="p.color || '#1E293B'"
            :font-size="p.fontSize || 12"
            font-weight="600"
            font-family="system-ui, -apple-system, sans-serif"
          >
            {{ p.text }}
          </text>
        </template>
      </svg>
    </div>

    <div
      v-if="hasImage"
      class="overflow-hidden rounded-lg border border-slate-200 bg-white p-2 text-center"
    >
      <img
        :src="imageUrl!"
        alt="题目配图"
        class="mx-auto max-h-48 max-w-full rounded object-contain"
      />
    </div>
  </div>
</template>
