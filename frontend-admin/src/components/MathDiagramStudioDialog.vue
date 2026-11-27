<script setup lang="ts">
import { ref, reactive, computed, watch, nextTick, onBeforeUnmount } from "vue";
import JXG from "jsxgraph";
import { ElMessage } from "element-plus";
import type { DiagramSpec, DiagramPrimitive } from "@/components/QuestionDiagram.vue";

export type BoardMode = "cartesian" | "geometry" | "numberline";

export type DrawTool =
  | "select"
  | "point"
  | "segment"
  | "dashed"
  | "arrow"
  | "polygon"
  | "circle"
  | "midpoint"
  | "perpendicular"
  | "rightAngle"
  | "angle"
  | "text";

interface StudioPoint {
  id: string;
  name: string;
  x: number;
  y: number;
  color: string;
  showLabel: boolean;
}

interface StudioShape {
  id: string;
  type: "segment" | "arrow" | "polygon" | "circle" | "rightAngle" | "angle" | "text";
  p1?: string;
  p2?: string;
  p3?: string;
  pointIds?: string[];
  x?: number;
  y?: number;
  text?: string;
  label?: string;
  color: string;
  fillColor?: string;
  dashed?: boolean;
  strokeWidth?: number;
  fontSize?: number;
}

interface StudioFunction {
  id: string;
  expr: string;
  label: string;
  color: string;
  dashed: boolean;
  xMin: number;
  xMax: number;
}

export interface MathStudioState {
  title: string;
  boardMode: BoardMode;
  bounds: [number, number, number, number]; // [xMin, yMax, xMax, yMin]
  showGrid: boolean;
  snapToGrid: boolean;
  points: StudioPoint[];
  shapes: StudioShape[];
  functions: StudioFunction[];
}

const props = defineProps<{
  modelValue: boolean;
  initialDiagram?: DiagramSpec | null;
}>();

const emit = defineEmits<{
  (e: "update:modelValue", v: boolean): void;
  (e: "save-diagram", spec: DiagramSpec): void;
  (e: "export-image", blob: Blob): void;
}>();

const boardDomId = `ggl-jxg-board-${Math.random().toString(36).slice(2, 9)}`;
let board: any = null;
const jxgPointMap = new Map<string, any>();

const activeTool = ref<DrawTool>("select");
const pendingPointIds = ref<string[]>([]);
const selectedItem = ref<{ kind: "point" | "shape" | "func"; id: string } | null>(null);
const drawColor = ref("#1E293B");
const drawFillColor = ref("#38BDF8");
const drawStrokeWidth = ref(2);
const textDraft = ref("∠1");
const exportingImage = ref(false);

const newFunc = reactive({
  expr: "0.5*x^2 - 2",
  label: "y = 0.5x² - 2",
  color: "#0284C7",
  dashed: false,
  xMin: -6,
  xMax: 6
});

const state = reactive<MathStudioState>({
  title: "数学示意图",
  boardMode: "cartesian",
  bounds: [-6, 4, 6, -4],
  showGrid: true,
  snapToGrid: true,
  points: [],
  shapes: [],
  functions: []
});

const historyStack = ref<string[]>([]);
const historyIndex = ref(-1);

const colorSwatches = ["#1E293B", "#0284C7", "#DC2626", "#059669", "#D97706", "#7C3AED", "#64748B"];

const toolGroups: Array<{
  title: string;
  items: Array<{ id: DrawTool; label: string; hint: string }>;
}> = [
  {
    title: "基础操作",
    items: [
      { id: "select", label: "选择/拖拽", hint: "拖动任意几何点或文字，相连图形实时动态联动" },
      { id: "point", label: "自由点", hint: "点击画布放置顶点（自动按 A/B/C 顺延命名）" }
    ]
  },
  {
    title: "线与多边形",
    items: [
      { id: "segment", label: "线段", hint: "依次点击两个点（或空白处）连成实线线段" },
      { id: "dashed", label: "虚线辅助线", hint: "依次点击两点绘制虚线辅助线" },
      { id: "arrow", label: "向量/箭头", hint: "依次点击起点与终点绘制带箭头向量" },
      { id: "polygon", label: "多边形", hint: "依次点击多个顶点，再次点击首个顶点或点上方按钮闭合" }
    ]
  },
  {
    title: "几何构造",
    items: [
      { id: "circle", label: "圆", hint: "先点圆心，再点圆周上一点构造可调半径的圆" },
      { id: "midpoint", label: "中点", hint: "依次点击两点，自动生成两点的中点" },
      { id: "perpendicular", label: "垂线+直角", hint: "依次点顶点 P → 线段端 A → 线段端 B，自动作垂足与直角标" },
      { id: "rightAngle", label: "直角符号", hint: "依次点边上点 A → 直角顶点 V → 边上点 B" },
      { id: "angle", label: "角弧标注", hint: "依次点边上点 A → 顶点 V → 边上点 B 标注角度圆弧" },
      { id: "text", label: "数学文本", hint: "在左侧填写文字（支持 {{a}} 动态变量）后点击画布放置" }
    ]
  }
];

const currentToolHint = computed(() => {
  for (const g of toolGroups) {
    const found = g.items.find(i => i.id === activeTool.value);
    if (found) return found.hint;
  }
  return "";
});

const selectedPoint = computed(() =>
  selectedItem.value?.kind === "point"
    ? state.points.find(p => p.id === selectedItem.value?.id) || null
    : null
);
const selectedShape = computed(() =>
  selectedItem.value?.kind === "shape"
    ? state.shapes.find(s => s.id === selectedItem.value?.id) || null
    : null
);
const selectedFunc = computed(() =>
  selectedItem.value?.kind === "func"
    ? state.functions.find(f => f.id === selectedItem.value?.id) || null
    : null
);

function uid(prefix: string): string {
  return `${prefix}_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 6)}`;
}

function nextPointLabel(): string {
  const used = new Set(state.points.map(p => p.name));
  const letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  for (const ch of letters) {
    if (!used.has(ch)) return ch;
  }
  for (let i = 1; i <= 50; i++) {
    const cand = `P${i}`;
    if (!used.has(cand)) return cand;
  }
  return "P";
}

function snapVal(v: number): number {
  if (!state.snapToGrid) return Math.round(v * 20) / 20;
  return Math.round(v * 2) / 2;
}

function pushHistory() {
  const snap = JSON.stringify({
    title: state.title,
    boardMode: state.boardMode,
    bounds: [...state.bounds],
    showGrid: state.showGrid,
    snapToGrid: state.snapToGrid,
    points: state.points,
    shapes: state.shapes,
    functions: state.functions
  });
  if (historyIndex.value >= 0 && historyStack.value[historyIndex.value] === snap) return;
  historyStack.value = historyStack.value.slice(0, historyIndex.value + 1);
  historyStack.value.push(snap);
  if (historyStack.value.length > 40) {
    historyStack.value.shift();
  }
  historyIndex.value = historyStack.value.length - 1;
}

function applyHistorySnapshot(raw: string) {
  try {
    const parsed = JSON.parse(raw) as MathStudioState;
    state.title = parsed.title;
    state.boardMode = parsed.boardMode;
    state.bounds = parsed.bounds;
    state.showGrid = parsed.showGrid;
    state.snapToGrid = parsed.snapToGrid;
    state.points = parsed.points || [];
    state.shapes = parsed.shapes || [];
    state.functions = parsed.functions || [];
    pendingPointIds.value = [];
    selectedItem.value = null;
    rebuildBoard();
  } catch {
    // ignore corrupt snapshot
  }
}

function undo() {
  if (historyIndex.value <= 0) return;
  historyIndex.value--;
  applyHistorySnapshot(historyStack.value[historyIndex.value]);
}

function redo() {
  if (historyIndex.value >= historyStack.value.length - 1) return;
  historyIndex.value++;
  applyHistorySnapshot(historyStack.value[historyIndex.value]);
}

/** 安全编译数学函数表达式 f(x)（仅允许白名单数学函数与算术运算） */
function compileMathExpr(rawExpr: string): ((x: number) => number) | null {
  let expr = rawExpr.trim();
  if (!expr) return null;
  expr = expr
    .replace(/^y\s*=\s*/i, "")
    .replace(/^f\s*\(\s*x\s*\)\s*=\s*/i, "")
    .replace(/²/g, "^2")
    .replace(/³/g, "^3")
    .replace(/π/g, "pi")
    .replace(/×/g, "*")
    .replace(/÷/g, "/")
    .replace(/−/g, "-");

  // 支持隐式乘法：2x -> 2*x, 2(x+1) -> 2*(x+1), (x+1)(x-1) -> (x+1)*(x-1), x(x+1) -> x*(x+1)
  expr = expr
    .replace(/(\d)\s*([a-zA-Z(])/g, "$1*$2")
    .replace(/(\))\s*(\d|[a-zA-Z(])/g, "$1*$2")
    .replace(/\b(x)\s*\(/g, "$1*(");

  // 白名单字符检查
  if (!/^[0-9a-zA-Z_+\-*/^().,\s]+$/.test(expr)) {
    return null;
  }

  // 替换数学函数与常量
  const fnMap: Record<string, string> = {
    sin: "Math.sin",
    cos: "Math.cos",
    tan: "Math.tan",
    asin: "Math.asin",
    acos: "Math.acos",
    atan: "Math.atan",
    sqrt: "Math.sqrt",
    abs: "Math.abs",
    ln: "Math.log",
    log: "Math.log10",
    exp: "Math.exp",
    floor: "Math.floor",
    ceil: "Math.ceil",
    pow: "Math.pow",
    pi: "Math.PI",
    PI: "Math.PI",
    e: "Math.E"
  };

  const tokens = expr.match(/[a-zA-Z_][a-zA-Z0-9_]*/g) || [];
  for (const tok of tokens) {
    if (tok !== "x" && !(tok in fnMap)) {
      return null;
    }
  }

  const jsExpr = expr
    .replace(/\^/g, "**")
    .replace(/\b([a-zA-Z_][a-zA-Z0-9_]*)\b/g, m => (m === "x" ? "x" : fnMap[m] || m));

  try {
    // eslint-disable-next-line no-new-func
    const fn = new Function("x", `"use strict"; return (${jsExpr});`) as (x: number) => number;
    // 预检
    const testVal = fn(1);
    if (typeof testVal !== "number") return null;
    return (x: number) => {
      try {
        const y = fn(x);
        return Number.isFinite(y) ? y : NaN;
      } catch {
        return NaN;
      }
    };
  } catch {
    return null;
  }
}

function getPointById(id?: string): StudioPoint | undefined {
  if (!id) return undefined;
  return state.points.find(p => p.id === id);
}

function findNearestPoint(ux: number, uy: number, threshold = 0.42): StudioPoint | null {
  let best: StudioPoint | null = null;
  let bestDist = threshold;
  for (const pt of state.points) {
    const d = Math.hypot(pt.x - ux, pt.y - uy);
    if (d < bestDist) {
      bestDist = d;
      best = pt;
    }
  }
  return best;
}

function getOrCreatePointAt(ux: number, uy: number): StudioPoint {
  const near = findNearestPoint(ux, uy);
  if (near) return near;
  const pt: StudioPoint = {
    id: uid("pt"),
    name: nextPointLabel(),
    x: snapVal(ux),
    y: snapVal(uy),
    color: drawColor.value,
    showLabel: true
  };
  state.points.push(pt);
  return pt;
}

function disposeBoard() {
  if (board) {
    try {
      JXG.JSXGraph.freeBoard(board);
    } catch {
      // ignore
    }
    board = null;
  }
  jxgPointMap.clear();
}

function rebuildBoard() {
  disposeBoard();
  const host = document.getElementById(boardDomId);
  if (!host) return;

  board = JXG.JSXGraph.initBoard(boardDomId, {
    boundingbox: [...state.bounds],
    axis: state.boardMode === "cartesian",
    grid: state.showGrid && state.boardMode !== "numberline",
    keepaspectratio: state.boardMode === "geometry",
    showCopyright: false,
    showNavigation: false,
    pan: { enabled: true, needShift: true },
    zoom: { wheel: true, needShift: true },
    defaultAxes: {
      x: {
        strokeColor: "#64748B",
        strokeWidth: 1.5,
        ticks: { label: { fontSize: 11, strokeColor: "#64748B" } }
      },
      y: {
        strokeColor: "#64748B",
        strokeWidth: 1.5,
        ticks: { label: { fontSize: 11, strokeColor: "#64748B" } }
      }
    }
  });

  // 数轴模式绘制主水平数轴与整数刻度
  if (state.boardMode === "numberline") {
    const [xMin, , xMax] = state.bounds;
    const leftPt = board.create("point", [xMin + 0.4, 0], { visible: false, fixed: true });
    const rightPt = board.create("point", [xMax - 0.4, 0], { visible: false, fixed: true });
    board.create("arrow", [leftPt, rightPt], {
      strokeColor: "#334155",
      strokeWidth: 2,
      fixed: true,
      highlight: false
    });
    for (let x = Math.ceil(xMin + 0.6); x <= Math.floor(xMax - 0.8); x++) {
      board.create("segment", [[x, -0.15], [x, 0.15]], {
        strokeColor: "#475569",
        strokeWidth: 1.3,
        fixed: true,
        highlight: false
      });
      board.create("text", [x, -0.45, String(x)], {
        anchorX: "middle",
        fontSize: 11,
        strokeColor: "#475569",
        fixed: true
      });
    }
  }

  // 1. 先绘制所有函数图像
  for (const fnItem of state.functions) {
    const compiled = compileMathExpr(fnItem.expr);
    if (!compiled) continue;
    const graph = board.create("functiongraph", [compiled, fnItem.xMin, fnItem.xMax], {
      strokeColor: fnItem.color || "#0284C7",
      strokeWidth: 2.4,
      dash: fnItem.dashed ? 2 : 0,
      highlightStrokeColor: "#0EA5E9"
    });
    graph.on("down", () => {
      if (activeTool.value === "select") {
        selectedItem.value = { kind: "func", id: fnItem.id };
      }
    });
  }

  // 2. 创建全部交互式可拖拽顶点
  for (const pt of state.points) {
    const jp = board.create("point", [pt.x, pt.y], {
      name: pt.showLabel ? pt.name : "",
      size: 3.5,
      fillColor: pt.color || "#1E293B",
      strokeColor: "#FFFFFF",
      strokeWidth: 1.5,
      snapToGrid: state.snapToGrid,
      snapSizeX: 0.5,
      snapSizeY: 0.5,
      label: {
        offset: [7, 9],
        fontSize: 13,
        strokeColor: pt.color || "#0F172A",
        cssStyle: "font-weight: 700;"
      }
    });
    jp.on("down", () => {
      if (activeTool.value === "select") {
        selectedItem.value = { kind: "point", id: pt.id };
      }
    });
    jp.on("drag", () => {
      pt.x = Math.round(jp.X() * 100) / 100;
      pt.y = Math.round(jp.Y() * 100) / 100;
    });
    jp.on("up", () => {
      pt.x = Math.round(jp.X() * 100) / 100;
      pt.y = Math.round(jp.Y() * 100) / 100;
      pushHistory();
    });
    jxgPointMap.set(pt.id, jp);
  }

  // 3. 绘制所有几何图元（绑定到动态 JSXGraph 顶点，拖拽顶点时自动联动！）
  for (const sh of state.shapes) {
    const dash = sh.dashed ? 2 : 0;
    const sw = sh.strokeWidth || 2;
    let elem: any = null;
    if (sh.type === "segment" && sh.p1 && sh.p2) {
      const a = jxgPointMap.get(sh.p1);
      const b = jxgPointMap.get(sh.p2);
      if (a && b) {
        elem = board.create("segment", [a, b], { strokeColor: sh.color, strokeWidth: sw, dash });
      }
    } else if (sh.type === "arrow" && sh.p1 && sh.p2) {
      const a = jxgPointMap.get(sh.p1);
      const b = jxgPointMap.get(sh.p2);
      if (a && b) {
        elem = board.create("arrow", [a, b], { strokeColor: sh.color, strokeWidth: sw, dash });
      }
    } else if (sh.type === "polygon" && sh.pointIds && sh.pointIds.length >= 3) {
      const pts = sh.pointIds.map(id => jxgPointMap.get(id)).filter(Boolean);
      if (pts.length >= 3) {
        elem = board.create("polygon", pts, {
          fillColor: sh.fillColor || "#38BDF8",
          fillOpacity: sh.fillColor && sh.fillColor !== "none" ? 0.18 : 0,
          borders: { strokeColor: sh.color, strokeWidth: sw, dash }
        });
      }
    } else if (sh.type === "circle" && sh.p1 && sh.p2) {
      const center = jxgPointMap.get(sh.p1);
      const edge = jxgPointMap.get(sh.p2);
      if (center && edge) {
        elem = board.create("circle", [center, edge], {
          strokeColor: sh.color,
          strokeWidth: sw,
          dash,
          fillColor: sh.fillColor || "none",
          fillOpacity: sh.fillColor && sh.fillColor !== "none" ? 0.12 : 0
        });
      }
    } else if (sh.type === "rightAngle" && sh.p1 && sh.p2 && sh.p3) {
      const a = jxgPointMap.get(sh.p1);
      const v = jxgPointMap.get(sh.p2);
      const b = jxgPointMap.get(sh.p3);
      if (a && v && b) {
        elem = board.create("angle", [a, v, b], {
          type: "square",
          orthoType: "square",
          radius: 0.45,
          strokeColor: sh.color || "#0284C7",
          fillColor: sh.color || "#0284C7",
          fillOpacity: 0.12,
          name: ""
        });
      }
    } else if (sh.type === "angle" && sh.p1 && sh.p2 && sh.p3) {
      const a = jxgPointMap.get(sh.p1);
      const v = jxgPointMap.get(sh.p2);
      const b = jxgPointMap.get(sh.p3);
      if (a && v && b) {
        elem = board.create("nonreflexangle", [a, v, b], {
          radius: 0.65,
          strokeColor: sh.color || "#DC2626",
          fillColor: sh.color || "#DC2626",
          fillOpacity: 0.14,
          name: sh.label || ""
        });
      }
    } else if (sh.type === "text" && typeof sh.x === "number" && typeof sh.y === "number") {
      elem = board.create("text", [sh.x, sh.y, sh.text || "标注"], {
        fontSize: sh.fontSize || 14,
        strokeColor: sh.color || "#0F172A",
        fixed: false,
        cssStyle: "font-weight: 700;"
      });
      elem.on("drag", () => {
        sh.x = Math.round(elem.X() * 100) / 100;
        sh.y = Math.round(elem.Y() * 100) / 100;
      });
      elem.on("up", () => {
        sh.x = Math.round(elem.X() * 100) / 100;
        sh.y = Math.round(elem.Y() * 100) / 100;
        pushHistory();
      });
    }

    if (elem && typeof elem.on === "function") {
      elem.on("down", () => {
        if (activeTool.value === "select") {
          selectedItem.value = { kind: "shape", id: sh.id };
        }
      });
    }
  }

  // 4. 画布点击交互（绘制新图元）
  board.on("down", (e: MouseEvent | TouchEvent) => {
    if (activeTool.value === "select") return;
    const coords = board.getUsrCoordsOfMouse(e);
    if (!coords || !Number.isFinite(coords[0]) || !Number.isFinite(coords[1])) return;
    const ux = coords[0];
    const uy = state.boardMode === "numberline" ? 0 : coords[1];
    handleCanvasClick(ux, uy);
  });
}

function handleCanvasClick(ux: number, uy: number) {
  const tool = activeTool.value;

  if (tool === "point") {
    const pt = getOrCreatePointAt(ux, uy);
    selectedItem.value = { kind: "point", id: pt.id };
    pushHistory();
    rebuildBoard();
    return;
  }

  if (tool === "text") {
    const labelText = textDraft.value.trim() || "标注";
    const sh: StudioShape = {
      id: uid("txt"),
      type: "text",
      x: snapVal(ux),
      y: snapVal(uy),
      text: labelText,
      color: drawColor.value,
      fontSize: 13
    };
    state.shapes.push(sh);
    selectedItem.value = { kind: "shape", id: sh.id };
    pushHistory();
    rebuildBoard();
    return;
  }

  if (tool === "segment" || tool === "dashed" || tool === "arrow" || tool === "circle") {
    const pt = getOrCreatePointAt(ux, uy);
    pendingPointIds.value.push(pt.id);
    if (pendingPointIds.value.length === 2) {
      const [p1, p2] = pendingPointIds.value;
      pendingPointIds.value = [];
      if (p1 !== p2) {
        const sh: StudioShape = {
          id: uid(tool),
          type: tool === "dashed" ? "segment" : tool,
          p1,
          p2,
          color: drawColor.value,
          fillColor: tool === "circle" ? "none" : undefined,
          dashed: tool === "dashed",
          strokeWidth: drawStrokeWidth.value
        };
        state.shapes.push(sh);
        selectedItem.value = { kind: "shape", id: sh.id };
        pushHistory();
      }
    }
    rebuildBoard();
    return;
  }

  if (tool === "midpoint") {
    const pt = getOrCreatePointAt(ux, uy);
    pendingPointIds.value.push(pt.id);
    if (pendingPointIds.value.length === 2) {
      const p1 = getPointById(pendingPointIds.value[0]);
      const p2 = getPointById(pendingPointIds.value[1]);
      pendingPointIds.value = [];
      if (p1 && p2 && p1.id !== p2.id) {
        const mid: StudioPoint = {
          id: uid("pt"),
          name: nextPointLabel(),
          x: Math.round(((p1.x + p2.x) / 2) * 100) / 100,
          y: Math.round(((p1.y + p2.y) / 2) * 100) / 100,
          color: "#0284C7",
          showLabel: true
        };
        state.points.push(mid);
        selectedItem.value = { kind: "point", id: mid.id };
        pushHistory();
        ElMessage.success(`已创建 ${p1.name}${p2.name} 的中点 ${mid.name}`);
      }
    }
    rebuildBoard();
    return;
  }

  if (tool === "perpendicular") {
    const pt = getOrCreatePointAt(ux, uy);
    pendingPointIds.value.push(pt.id);
    if (pendingPointIds.value.length === 3) {
      const p = getPointById(pendingPointIds.value[0]);
      const a = getPointById(pendingPointIds.value[1]);
      const b = getPointById(pendingPointIds.value[2]);
      pendingPointIds.value = [];
      if (p && a && b && a.id !== b.id) {
        const dx = b.x - a.x;
        const dy = b.y - a.y;
        const len2 = dx * dx + dy * dy;
        if (len2 > 1e-6) {
          const t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2;
          const hx = Math.round((a.x + t * dx) * 100) / 100;
          const hy = Math.round((a.y + t * dy) * 100) / 100;
          const foot: StudioPoint = {
            id: uid("pt"),
            name: nextPointLabel(),
            x: hx,
            y: hy,
            color: "#0284C7",
            showLabel: true
          };
          state.points.push(foot);
          state.shapes.push({
            id: uid("seg"),
            type: "segment",
            p1: p.id,
            p2: foot.id,
            color: "#0284C7",
            dashed: true,
            strokeWidth: 1.8
          });
          state.shapes.push({
            id: uid("ra"),
            type: "rightAngle",
            p1: b.id,
            p2: foot.id,
            p3: p.id,
            color: "#0284C7"
          });
          pushHistory();
          ElMessage.success(`已作垂足 ${foot.name} 并标注直角`);
        }
      }
    }
    rebuildBoard();
    return;
  }

  if (tool === "rightAngle" || tool === "angle") {
    const pt = getOrCreatePointAt(ux, uy);
    pendingPointIds.value.push(pt.id);
    if (pendingPointIds.value.length === 3) {
      const [p1, p2, p3] = pendingPointIds.value;
      pendingPointIds.value = [];
      if (p1 !== p2 && p2 !== p3 && p1 !== p3) {
        const sh: StudioShape = {
          id: uid(tool),
          type: tool,
          p1,
          p2,
          p3,
          color: tool === "rightAngle" ? "#0284C7" : "#DC2626",
          label: tool === "angle" ? "α" : undefined
        };
        state.shapes.push(sh);
        selectedItem.value = { kind: "shape", id: sh.id };
        pushHistory();
      }
    }
    rebuildBoard();
    return;
  }

  if (tool === "polygon") {
    const near = findNearestPoint(ux, uy);
    if (near && pendingPointIds.value.length >= 3 && pendingPointIds.value[0] === near.id) {
      finishPolygon();
      return;
    }
    const pt = near || getOrCreatePointAt(ux, uy);
    if (!pendingPointIds.value.includes(pt.id)) {
      pendingPointIds.value.push(pt.id);
    }
    rebuildBoard();
  }
}

function finishPolygon() {
  if (pendingPointIds.value.length < 3) {
    ElMessage.warning("多边形至少需要 3 个顶点");
    return;
  }
  const sh: StudioShape = {
    id: uid("poly"),
    type: "polygon",
    pointIds: [...pendingPointIds.value],
    color: drawColor.value,
    fillColor: drawFillColor.value,
    dashed: false,
    strokeWidth: drawStrokeWidth.value
  };
  state.shapes.push(sh);
  pendingPointIds.value = [];
  selectedItem.value = { kind: "shape", id: sh.id };
  pushHistory();
  rebuildBoard();
}

function selectTool(tool: DrawTool) {
  activeTool.value = tool;
  pendingPointIds.value = [];
}

function addFunctionCurve() {
  const compiled = compileMathExpr(newFunc.expr);
  if (!compiled) {
    ElMessage.warning("函数表达式有误，示例：x^2 - 2*x - 3、2*x + 1、3/x、sin(x)");
    return;
  }
  const item: StudioFunction = {
    id: uid("fn"),
    expr: newFunc.expr.trim(),
    label: newFunc.label.trim() || `y = ${newFunc.expr.trim()}`,
    color: newFunc.color,
    dashed: newFunc.dashed,
    xMin: Number(newFunc.xMin),
    xMax: Number(newFunc.xMax)
  };
  state.functions.push(item);
  selectedItem.value = { kind: "func", id: item.id };
  pushHistory();
  rebuildBoard();
}

function removeSelected() {
  if (!selectedItem.value) return;
  const { kind, id } = selectedItem.value;
  if (kind === "point") {
    state.points = state.points.filter(p => p.id !== id);
    state.shapes = state.shapes.filter(sh => {
      if (sh.p1 === id || sh.p2 === id || sh.p3 === id) return false;
      if (sh.pointIds && sh.pointIds.includes(id)) return false;
      return true;
    });
  } else if (kind === "shape") {
    state.shapes = state.shapes.filter(s => s.id !== id);
  } else if (kind === "func") {
    state.functions = state.functions.filter(f => f.id !== id);
  }
  selectedItem.value = null;
  pushHistory();
  rebuildBoard();
}

function clearAll() {
  state.points = [];
  state.shapes = [];
  state.functions = [];
  pendingPointIds.value = [];
  selectedItem.value = null;
  pushHistory();
  rebuildBoard();
}

function zoomBounds(factor: number) {
  const [x1, y2, x2, y1] = state.bounds;
  const cx = (x1 + x2) / 2;
  const cy = (y1 + y2) / 2;
  const hw = Math.max(1.5, Math.min(30, ((x2 - x1) / 2) * factor));
  const hh = Math.max(1, Math.min(20, ((y2 - y1) / 2) * factor));
  state.bounds = [
    Math.round((cx - hw) * 10) / 10,
    Math.round((cy + hh) * 10) / 10,
    Math.round((cx + hw) * 10) / 10,
    Math.round((cy - hh) * 10) / 10
  ];
  rebuildBoard();
}

function resetViewBounds() {
  state.bounds = [-6, 4, 6, -4];
  rebuildBoard();
}

function applyInteractiveTemplate(
  kind:
    | "rt_triangle"
    | "iso_triangle"
    | "parallelogram"
    | "circle_chord"
    | "parabola"
    | "inverse_line"
    | "trig"
    | "numberline"
) {
  pendingPointIds.value = [];
  selectedItem.value = null;
  state.bounds = [-6, 4, 6, -4];
  state.functions = [];
  state.points = [];
  state.shapes = [];

  if (kind === "rt_triangle") {
    state.title = "直角三角形 Rt△ABC";
    state.boardMode = "geometry";
    state.points = [
      { id: "pA", name: "A", x: -3, y: 2.5, color: "#1E293B", showLabel: true },
      { id: "pC", name: "C", x: -3, y: -2, color: "#1E293B", showLabel: true },
      { id: "pB", name: "B", x: 3.5, y: -2, color: "#1E293B", showLabel: true }
    ];
    state.shapes = [
      { id: "s1", type: "polygon", pointIds: ["pA", "pC", "pB"], color: "#1E293B", fillColor: "#38BDF8", strokeWidth: 2 },
      { id: "s2", type: "rightAngle", p1: "pB", p2: "pC", p3: "pA", color: "#0284C7" }
    ];
  } else if (kind === "iso_triangle") {
    state.title = "等腰三角形与底边高";
    state.boardMode = "geometry";
    state.points = [
      { id: "pA", name: "A", x: 0, y: 3, color: "#1E293B", showLabel: true },
      { id: "pB", name: "B", x: -3.5, y: -2, color: "#1E293B", showLabel: true },
      { id: "pC", name: "C", x: 3.5, y: -2, color: "#1E293B", showLabel: true },
      { id: "pD", name: "D", x: 0, y: -2, color: "#0284C7", showLabel: true }
    ];
    state.shapes = [
      { id: "s1", type: "polygon", pointIds: ["pA", "pB", "pC"], color: "#1E293B", fillColor: "#34D399", strokeWidth: 2 },
      { id: "s2", type: "segment", p1: "pA", p2: "pD", color: "#0284C7", dashed: true, strokeWidth: 1.8 },
      { id: "s3", type: "rightAngle", p1: "pC", p2: "pD", p3: "pA", color: "#0284C7" }
    ];
  } else if (kind === "parallelogram") {
    state.title = "平行四边形 ABCD";
    state.boardMode = "geometry";
    state.points = [
      { id: "pA", name: "A", x: -2, y: 2, color: "#1E293B", showLabel: true },
      { id: "pB", name: "B", x: -4, y: -2, color: "#1E293B", showLabel: true },
      { id: "pC", name: "C", x: 2, y: -2, color: "#1E293B", showLabel: true },
      { id: "pD", name: "D", x: 4, y: 2, color: "#1E293B", showLabel: true },
      { id: "pO", name: "O", x: 0, y: 0, color: "#0284C7", showLabel: true }
    ];
    state.shapes = [
      { id: "s1", type: "polygon", pointIds: ["pA", "pB", "pC", "pD"], color: "#1E293B", fillColor: "#38BDF8", strokeWidth: 2 },
      { id: "s2", type: "segment", p1: "pA", p2: "pC", color: "#64748B", dashed: true, strokeWidth: 1.5 },
      { id: "s3", type: "segment", p1: "pB", p2: "pD", color: "#64748B", dashed: true, strokeWidth: 1.5 }
    ];
  } else if (kind === "circle_chord") {
    state.title = "圆 O 与垂径定理";
    state.boardMode = "geometry";
    state.points = [
      { id: "pO", name: "O", x: 0, y: 0, color: "#1E293B", showLabel: true },
      { id: "pA", name: "A", x: -2.4, y: -1.8, color: "#1E293B", showLabel: true },
      { id: "pB", name: "B", x: 2.4, y: -1.8, color: "#1E293B", showLabel: true },
      { id: "pM", name: "M", x: 0, y: -1.8, color: "#DC2626", showLabel: true }
    ];
    state.shapes = [
      { id: "s1", type: "circle", p1: "pO", p2: "pA", color: "#1E293B", strokeWidth: 2 },
      { id: "s2", type: "segment", p1: "pA", p2: "pB", color: "#0284C7", strokeWidth: 2 },
      { id: "s3", type: "segment", p1: "pO", p2: "pM", color: "#DC2626", dashed: true, strokeWidth: 1.8 },
      { id: "s4", type: "segment", p1: "pO", p2: "pA", color: "#059669", strokeWidth: 1.8 },
      { id: "s5", type: "rightAngle", p1: "pB", p2: "pM", p3: "pO", color: "#DC2626" }
    ];
  } else if (kind === "parabola") {
    state.title = "二次函数抛物线";
    state.boardMode = "cartesian";
    state.points = [
      { id: "pV", name: "P", x: 1, y: -2, color: "#DC2626", showLabel: true },
      { id: "pA", name: "A", x: -1, y: 0, color: "#0284C7", showLabel: true },
      { id: "pB", name: "B", x: 3, y: 0, color: "#0284C7", showLabel: true }
    ];
    state.functions = [
      { id: "f1", expr: "0.5*(x-1)^2 - 2", label: "y = ½(x-1)² - 2", color: "#0284C7", dashed: false, xMin: -5, xMax: 6 }
    ];
  } else if (kind === "inverse_line") {
    state.title = "一次函数与反比例函数";
    state.boardMode = "cartesian";
    state.points = [
      { id: "pA", name: "A", x: 1, y: 2, color: "#DC2626", showLabel: true },
      { id: "pB", name: "B", x: -2, y: -1, color: "#DC2626", showLabel: true }
    ];
    state.functions = [
      { id: "f1", expr: "x + 1", label: "y = x + 1", color: "#059669", dashed: false, xMin: -6, xMax: 6 },
      { id: "f2", expr: "2/x", label: "y = 2/x", color: "#0284C7", dashed: false, xMin: -6, xMax: 6 }
    ];
  } else if (kind === "trig") {
    state.title = "三角函数图像";
    state.boardMode = "cartesian";
    state.functions = [
      { id: "f1", expr: "2*sin(x)", label: "y = 2sin(x)", color: "#0284C7", dashed: false, xMin: -6, xMax: 6 },
      { id: "f2", expr: "2*cos(x)", label: "y = 2cos(x)", color: "#D97706", dashed: true, xMin: -6, xMax: 6 }
    ];
  } else if (kind === "numberline") {
    state.title = "数轴与不等式解集";
    state.boardMode = "numberline";
    state.points = [
      { id: "pA", name: "A", x: -2, y: 0, color: "#0284C7", showLabel: true },
      { id: "pB", name: "B", x: 3, y: 0, color: "#DC2626", showLabel: true }
    ];
    state.shapes = [
      { id: "s1", type: "segment", p1: "pA", p2: "pB", color: "#0284C7", strokeWidth: 3.5 }
    ];
  }

  pushHistory();
  rebuildBoard();
}

/** 将 JSXGraph 工作台当前所有图形与函数精准导出为全端通用的 DiagramSpec (320×210) */
function compileToDiagramSpec(): DiagramSpec {
  const outW = 320;
  const outH = 210;
  const pad = 16;
  const [xMin, yMax, xMax, yMin] = state.bounds;
  const spanX = Math.max(0.001, xMax - xMin);
  const spanY = Math.max(0.001, yMax - yMin);

  const toPx = (ux: number, uy: number): [number, number] => {
    const px = pad + ((ux - xMin) / spanX) * (outW - pad * 2);
    const py = pad + ((yMax - uy) / spanY) * (outH - pad * 2);
    return [Math.round(px * 10) / 10, Math.round(py * 10) / 10];
  };

  const primitives: DiagramPrimitive[] = [];

  // 1. 坐标系 / 网格 / 数轴
  if (state.boardMode === "cartesian") {
    if (state.showGrid) {
      for (let gx = Math.ceil(xMin); gx <= Math.floor(xMax); gx++) {
        if (gx === 0) continue;
        const [px1, py1] = toPx(gx, yMin);
        const [px2, py2] = toPx(gx, yMax);
        primitives.push({ type: "line", x1: px1, y1: py1, x2: px2, y2: py2, color: "#E2E8F0", strokeWidth: 0.7 });
      }
      for (let gy = Math.ceil(yMin); gy <= Math.floor(yMax); gy++) {
        if (gy === 0) continue;
        const [px1, py1] = toPx(xMin, gy);
        const [px2, py2] = toPx(xMax, gy);
        primitives.push({ type: "line", x1: px1, y1: py1, x2: px2, y2: py2, color: "#E2E8F0", strokeWidth: 0.7 });
      }
    }
    const [xAxisL, xAxisY] = toPx(xMin, 0);
    const [xAxisR] = toPx(xMax, 0);
    const [yAxisX, yAxisB] = toPx(0, yMin);
    const [, yAxisT] = toPx(0, yMax);

    if (yMin <= 0 && yMax >= 0) {
      primitives.push({ type: "arrow", x1: xAxisL, y1: xAxisY, x2: xAxisR, y2: xAxisY, color: "#64748B", strokeWidth: 1.4 });
      primitives.push({ type: "text", x: xAxisR - 8, y: xAxisY + 4, text: "x", color: "#64748B", fontSize: 11 });
    }
    if (xMin <= 0 && xMax >= 0) {
      primitives.push({ type: "arrow", x1: yAxisX, y1: yAxisB, x2: yAxisX, y2: yAxisT, color: "#64748B", strokeWidth: 1.4 });
      primitives.push({ type: "text", x: yAxisX + 5, y: yAxisT - 4, text: "y", color: "#64748B", fontSize: 11 });
    }
    if (xMin <= 0 && xMax >= 0 && yMin <= 0 && yMax >= 0) {
      primitives.push({ type: "text", x: yAxisX - 12, y: xAxisY + 3, text: "O", color: "#64748B", fontSize: 10 });
    }
  } else if (state.boardMode === "numberline") {
    const [lx, ly] = toPx(xMin + 0.3, 0);
    const [rx] = toPx(xMax - 0.3, 0);
    primitives.push({ type: "arrow", x1: lx, y1: ly, x2: rx, y2: ly, color: "#334155", strokeWidth: 1.8 });
    for (let gx = Math.ceil(xMin + 0.6); gx <= Math.floor(xMax - 0.8); gx++) {
      const [tx] = toPx(gx, 0);
      primitives.push({ type: "line", x1: tx, y1: ly - 4, x2: tx, y2: ly + 4, color: "#475569", strokeWidth: 1.2 });
      primitives.push({ type: "text", x: tx - 3, y: ly + 8, text: String(gx), color: "#475569", fontSize: 10 });
    }
  }

  // 2. 函数曲线（高密度自适应采样 + 渐近线自动断开）
  for (const fnItem of state.functions) {
    const compiled = compileMathExpr(fnItem.expr);
    if (!compiled) continue;
    const lo = Math.max(xMin, fnItem.xMin);
    const hi = Math.min(xMax, fnItem.xMax);
    const steps = 110;
    let currentSeg: number[][] = [];
    let prevY: number | null = null;
    let labelAnchor: [number, number] | null = null;

    const flushSeg = () => {
      if (currentSeg.length >= 2) {
        primitives.push({
          type: "polyline",
          points: currentSeg,
          color: fnItem.color || "#0284C7",
          dashed: fnItem.dashed,
          strokeWidth: 2
        });
      }
      currentSeg = [];
    };

    for (let i = 0; i <= steps; i++) {
      const x = lo + ((hi - lo) * i) / steps;
      const y = compiled(x);
      if (!Number.isFinite(y) || y < yMin - spanY * 0.15 || y > yMax + spanY * 0.15) {
        flushSeg();
        prevY = null;
        continue;
      }
      if (prevY !== null && Math.abs(y - prevY) > spanY * 0.75) {
        flushSeg();
      }
      const pt = toPx(x, y);
      currentSeg.push(pt);
      if (i > steps * 0.68 && !labelAnchor && y >= yMin + 0.4 && y <= yMax - 0.4) {
        labelAnchor = pt;
      }
      prevY = y;
    }
    flushSeg();
    if (fnItem.label && labelAnchor) {
      primitives.push({
        type: "text",
        x: Math.min(outW - 76, Math.max(12, labelAnchor[0] - 10)),
        y: Math.max(8, labelAnchor[1] - 14),
        text: fnItem.label,
        color: fnItem.color || "#0284C7",
        fontSize: 10.5
      });
    }
  }

  // 3. 几何图元
  for (const sh of state.shapes) {
    if (sh.type === "polygon" && sh.pointIds && sh.pointIds.length >= 3) {
      const pts = sh.pointIds
        .map(id => getPointById(id))
        .filter((p): p is StudioPoint => Boolean(p))
        .map(p => toPx(p.x, p.y));
      if (pts.length >= 3) {
        primitives.push({
          type: "polygon",
          points: pts,
          color: sh.color,
          fillColor: sh.fillColor && sh.fillColor !== "none" ? sh.fillColor : undefined,
          dashed: sh.dashed,
          strokeWidth: sh.strokeWidth || 2
        });
      }
    } else if ((sh.type === "segment" || sh.type === "arrow") && sh.p1 && sh.p2) {
      const a = getPointById(sh.p1);
      const b = getPointById(sh.p2);
      if (a && b) {
        const [x1, y1] = toPx(a.x, a.y);
        const [x2, y2] = toPx(b.x, b.y);
        primitives.push({
          type: sh.type === "arrow" ? "arrow" : "line",
          x1,
          y1,
          x2,
          y2,
          color: sh.color,
          dashed: sh.dashed,
          strokeWidth: sh.strokeWidth || 2
        });
      }
    } else if (sh.type === "circle" && sh.p1 && sh.p2) {
      const c = getPointById(sh.p1);
      const e = getPointById(sh.p2);
      if (c && e) {
        const [cx, cy] = toPx(c.x, c.y);
        const [ex, ey] = toPx(e.x, e.y);
        const r = Math.round(Math.hypot(ex - cx, ey - cy) * 10) / 10;
        primitives.push({
          type: "circle",
          cx,
          cy,
          r,
          color: sh.color,
          fillColor: sh.fillColor && sh.fillColor !== "none" ? sh.fillColor : undefined,
          dashed: sh.dashed,
          strokeWidth: sh.strokeWidth || 2
        });
      }
    } else if (sh.type === "rightAngle" && sh.p1 && sh.p2 && sh.p3) {
      const a = getPointById(sh.p1);
      const v = getPointById(sh.p2);
      const b = getPointById(sh.p3);
      if (a && v && b) {
        const [ax, ay] = toPx(a.x, a.y);
        const [vx, vy] = toPx(v.x, v.y);
        const [bx, by] = toPx(b.x, b.y);
        primitives.push({
          type: "rightAngle",
          vx,
          vy,
          ax,
          ay,
          bx,
          by,
          size: 11,
          color: sh.color || "#0284C7"
        });
      }
    } else if (sh.type === "angle" && sh.p1 && sh.p2 && sh.p3) {
      const a = getPointById(sh.p1);
      const v = getPointById(sh.p2);
      const b = getPointById(sh.p3);
      if (a && v && b) {
        const [ax, ay] = toPx(a.x, a.y);
        const [vx, vy] = toPx(v.x, v.y);
        const [bx, by] = toPx(b.x, b.y);
        const ang1 = (Math.atan2(ay - vy, ax - vx) * 180) / Math.PI;
        const ang2 = (Math.atan2(by - vy, bx - vx) * 180) / Math.PI;
        let sweep = ang2 - ang1;
        while (sweep > 180) sweep -= 360;
        while (sweep < -180) sweep += 360;
        primitives.push({
          type: "arc",
          cx: vx,
          cy: vy,
          r: 18,
          startAngle: Math.round(ang1 * 10) / 10,
          sweepAngle: Math.round(sweep * 10) / 10,
          color: sh.color || "#DC2626"
        });
        if (sh.label) {
          const midRad = ((ang1 + sweep / 2) * Math.PI) / 180;
          primitives.push({
            type: "text",
            x: Math.round((vx + 24 * Math.cos(midRad) - 4) * 10) / 10,
            y: Math.round((vy + 24 * Math.sin(midRad) - 6) * 10) / 10,
            text: sh.label,
            color: sh.color || "#DC2626",
            fontSize: 11
          });
        }
      }
    } else if (sh.type === "text" && typeof sh.x === "number" && typeof sh.y === "number") {
      const [px, py] = toPx(sh.x, sh.y);
      primitives.push({
        type: "text",
        x: px,
        y: py - 6,
        text: sh.text || "",
        color: sh.color || "#0F172A",
        fontSize: sh.fontSize || 12
      });
    }
  }

  // 4. 顶点放在最顶层保证清晰可见
  for (const pt of state.points) {
    const [px, py] = toPx(pt.x, pt.y);
    primitives.push({
      type: "point",
      x: px,
      y: py,
      label: pt.showLabel ? pt.name : undefined,
      color: pt.color || "#1E293B"
    });
  }

  return {
    title: state.title.trim() || "数学示意图",
    width: outW,
    height: outH,
    primitives,
    studioState: JSON.parse(
      JSON.stringify({
        title: state.title,
        boardMode: state.boardMode,
        bounds: [...state.bounds],
        showGrid: state.showGrid,
        snapToGrid: state.snapToGrid,
        points: state.points,
        shapes: state.shapes,
        functions: state.functions
      })
    )
  } as DiagramSpec & { studioState?: MathStudioState };
}

function handleSaveVector() {
  const spec = compileToDiagramSpec();
  if (!spec.primitives || spec.primitives.length === 0) {
    ElMessage.warning("请先在画布中绘制数学图形或添加函数曲线");
    return;
  }
  emit("save-diagram", spec);
  emit("update:modelValue", false);
}

async function handleExportPng() {
  const host = document.getElementById(boardDomId);
  const svgEl = host?.querySelector("svg");
  if (!svgEl) {
    ElMessage.warning("画布尚未就绪");
    return;
  }
  exportingImage.value = true;
  try {
    const rect = svgEl.getBoundingClientRect();
    const w = Math.max(640, Math.round(rect.width * 2));
    const h = Math.max(420, Math.round(rect.height * 2));
    const cloned = svgEl.cloneNode(true) as SVGSVGElement;
    cloned.setAttribute("xmlns", "http://www.w3.org/2000/svg");
    cloned.setAttribute("width", String(w));
    cloned.setAttribute("height", String(h));
    const svgStr = new XMLSerializer().serializeToString(cloned);
    const svgBlob = new Blob([svgStr], { type: "image/svg+xml;charset=utf-8" });
    const url = URL.createObjectURL(svgBlob);

    const img = new Image();
    await new Promise<void>((resolve, reject) => {
      img.onload = () => resolve();
      img.onerror = reject;
      img.src = url;
    });
    const canvas = document.createElement("canvas");
    canvas.width = w;
    canvas.height = h;
    const ctx = canvas.getContext("2d")!;
    ctx.fillStyle = "#FFFFFF";
    ctx.fillRect(0, 0, w, h);
    ctx.drawImage(img, 0, 0, w, h);
    URL.revokeObjectURL(url);

    const blob = await new Promise<Blob | null>(resolve => canvas.toBlob(resolve, "image/png"));
    if (!blob) throw new Error("生成 PNG 失败");
    emit("export-image", blob);
    emit("update:modelValue", false);
  } catch (err: any) {
    ElMessage.error(err?.message || "导出图片失败");
  } finally {
    exportingImage.value = false;
  }
}

function hydrateFromInitial() {
  const raw = props.initialDiagram as (DiagramSpec & { studioState?: MathStudioState }) | null | undefined;
  if (raw?.studioState && typeof raw.studioState === "object") {
    const st = raw.studioState;
    state.title = st.title || raw.title || "数学示意图";
    state.boardMode = st.boardMode || "cartesian";
    state.bounds = Array.isArray(st.bounds) && st.bounds.length === 4 ? [...st.bounds] : [-6, 4, 6, -4];
    state.showGrid = st.showGrid ?? true;
    state.snapToGrid = st.snapToGrid ?? true;
    state.points = JSON.parse(JSON.stringify(st.points || []));
    state.shapes = JSON.parse(JSON.stringify(st.shapes || []));
    state.functions = JSON.parse(JSON.stringify(st.functions || []));
  } else if (raw && Array.isArray(raw.primitives) && raw.primitives.length > 0) {
    // 将存量纯 DiagramSpec 反推转换到交互画板（点/线/圆/多边形均可继续拖拽编辑）
    state.title = raw.title || "数学示意图";
    state.boardMode = "geometry";
    state.bounds = [-6, 4, 6, -4];
    state.showGrid = true;
    state.snapToGrid = false;
    const srcW = Number(raw.width || 320);
    const srcH = Number(raw.height || 210);
    const fromPx = (px: number, py: number): [number, number] => [
      Math.round((-5.5 + (px / srcW) * 11) * 100) / 100,
      Math.round((3.5 - (py / srcH) * 7) * 100) / 100
    ];
    state.points = [];
    state.shapes = [];
    state.functions = [];
    for (const p of raw.primitives) {
      if (p.type === "point" && typeof p.x === "number" && typeof p.y === "number") {
        const [ux, uy] = fromPx(p.x, p.y);
        state.points.push({
          id: uid("pt"),
          name: p.label || nextPointLabel(),
          x: ux,
          y: uy,
          color: p.color || "#1E293B",
          showLabel: Boolean(p.label)
        });
      } else if (p.type === "polygon" && Array.isArray(p.points)) {
        const ids: string[] = [];
        for (const pair of p.points) {
          const [ux, uy] = fromPx(pair[0], pair[1]);
          const near = findNearestPoint(ux, uy, 0.25);
          if (near) {
            ids.push(near.id);
          } else {
            const np: StudioPoint = {
              id: uid("pt"),
              name: nextPointLabel(),
              x: ux,
              y: uy,
              color: "#1E293B",
              showLabel: false
            };
            state.points.push(np);
            ids.push(np.id);
          }
        }
        state.shapes.push({
          id: uid("poly"),
          type: "polygon",
          pointIds: ids,
          color: p.color || "#1E293B",
          fillColor: p.fillColor || p.fill,
          dashed: p.dashed,
          strokeWidth: p.strokeWidth || 2
        });
      } else if ((p.type === "line" || p.type === "arrow") && typeof p.x1 === "number" && typeof p.y1 === "number") {
        const [ux1, uy1] = fromPx(p.x1, p.y1);
        const [ux2, uy2] = fromPx(Number(p.x2 ?? 0), Number(p.y2 ?? 0));
        const a = findNearestPoint(ux1, uy1, 0.25) || {
          id: uid("pt"),
          name: "",
          x: ux1,
          y: uy1,
          color: p.color || "#1E293B",
          showLabel: false
        };
        if (!state.points.includes(a)) state.points.push(a);
        const b = findNearestPoint(ux2, uy2, 0.25) || {
          id: uid("pt"),
          name: "",
          x: ux2,
          y: uy2,
          color: p.color || "#1E293B",
          showLabel: false
        };
        if (!state.points.includes(b)) state.points.push(b);
        state.shapes.push({
          id: uid("seg"),
          type: p.type === "arrow" ? "arrow" : "segment",
          p1: a.id,
          p2: b.id,
          color: p.color || "#1E293B",
          dashed: p.dashed,
          strokeWidth: p.strokeWidth || 2
        });
      } else if (p.type === "text" && typeof p.x === "number" && typeof p.y === "number") {
        const [ux, uy] = fromPx(p.x, p.y);
        state.shapes.push({
          id: uid("txt"),
          type: "text",
          x: ux,
          y: uy,
          text: p.text || "",
          color: p.color || "#1E293B",
          fontSize: p.fontSize || 12
        });
      }
    }
  } else {
    applyInteractiveTemplate("rt_triangle");
    return;
  }
  historyStack.value = [];
  historyIndex.value = -1;
  pushHistory();
}

watch(
  () => props.modelValue,
  async open => {
    if (open) {
      hydrateFromInitial();
      await nextTick();
      rebuildBoard();
    } else {
      disposeBoard();
    }
  }
);

watch(
  () => [state.boardMode, state.showGrid, state.snapToGrid],
  () => {
    if (props.modelValue) rebuildBoard();
  }
);

onBeforeUnmount(disposeBoard);
</script>

<template>
  <el-dialog
    :model-value="modelValue"
    title="专业数学图形绘制工作台（JSXGraph 动态几何与函数引擎）"
    width="1260px"
    top="2vh"
    :close-on-click-modal="false"
    @update:model-value="v => emit('update:modelValue', v)"
  >
    <div class="space-y-3">
      <!-- 顶部工作条：画布模式、网格吸附、缩放与模板 -->
      <div class="flex flex-wrap items-center justify-between gap-2 rounded-xl border border-slate-200 bg-slate-50 px-3 py-2">
        <div class="flex flex-wrap items-center gap-2.5">
          <el-input v-model="state.title" size="small" placeholder="图形标题" style="width: 165px" />
          <el-radio-group v-model="state.boardMode" size="small">
            <el-radio-button value="cartesian">直角坐标系</el-radio-button>
            <el-radio-button value="geometry">纯几何白板</el-radio-button>
            <el-radio-button value="numberline">数轴模式</el-radio-button>
          </el-radio-group>
          <el-checkbox v-model="state.showGrid" size="small">网格</el-checkbox>
          <el-checkbox v-model="state.snapToGrid" size="small">0.5格吸附</el-checkbox>
        </div>

        <div class="flex flex-wrap items-center gap-1.5">
          <el-button size="small" plain :disabled="historyIndex <= 0" @click="undo">撤销</el-button>
          <el-button
            size="small"
            plain
            :disabled="historyIndex >= historyStack.length - 1"
            @click="redo"
          >
            重做
          </el-button>
          <el-button size="small" plain @click="zoomBounds(0.8)">放大</el-button>
          <el-button size="small" plain @click="zoomBounds(1.25)">缩小</el-button>
          <el-button size="small" plain @click="resetViewBounds">复位视野</el-button>
          <el-button size="small" type="danger" plain @click="clearAll">清空画布</el-button>
        </div>
      </div>

      <!-- 快捷可编辑模板栏 -->
      <div class="flex flex-wrap items-center gap-1.5 text-xs">
        <span class="font-semibold text-slate-500">导入可拖拽模板：</span>
        <el-button size="small" plain @click="applyInteractiveTemplate('rt_triangle')">直角三角形</el-button>
        <el-button size="small" plain @click="applyInteractiveTemplate('iso_triangle')">等腰三角形</el-button>
        <el-button size="small" plain @click="applyInteractiveTemplate('parallelogram')">平行四边形</el-button>
        <el-button size="small" plain @click="applyInteractiveTemplate('circle_chord')">圆与垂径</el-button>
        <el-button size="small" plain @click="applyInteractiveTemplate('parabola')">二次函数</el-button>
        <el-button size="small" plain @click="applyInteractiveTemplate('inverse_line')">一次+反比例</el-button>
        <el-button size="small" plain @click="applyInteractiveTemplate('trig')">正余弦函数</el-button>
        <el-button size="small" plain @click="applyInteractiveTemplate('numberline')">数轴不等式</el-button>
      </div>

      <!-- 主三栏工作区：左侧绘图工具 + 中间 JSXGraph 交互画板 + 右侧函数与属性面板 -->
      <div class="grid grid-cols-12 gap-3">
        <!-- 左栏：专业几何工具栏 -->
        <aside class="col-span-2 space-y-3 rounded-xl border border-slate-200 bg-white p-2.5">
          <div v-for="group in toolGroups" :key="group.title" class="space-y-1.5">
            <div class="text-[11px] font-bold text-slate-400">{{ group.title }}</div>
            <div class="grid grid-cols-1 gap-1">
              <button
                v-for="t in group.items"
                :key="t.id"
                type="button"
                class="rounded-lg border px-2 py-1.5 text-left text-xs font-semibold transition"
                :class="
                  activeTool === t.id
                    ? 'border-sky-600 bg-sky-50 text-sky-700'
                    : 'border-slate-200 bg-white text-slate-700 hover:border-slate-300'
                "
                @click="selectTool(t.id)"
              >
                {{ t.label }}
              </button>
            </div>
          </div>

          <div v-if="activeTool === 'text'" class="space-y-1 border-t border-slate-100 pt-2">
            <div class="text-[11px] font-semibold text-slate-500">标注文字内容</div>
            <el-input v-model="textDraft" size="small" placeholder="如 ∠1 或 {{a}}" />
          </div>

          <div class="space-y-1.5 border-t border-slate-100 pt-2">
            <div class="text-[11px] font-semibold text-slate-500">画笔颜色</div>
            <div class="flex flex-wrap gap-1.5">
              <button
                v-for="c in colorSwatches"
                :key="c"
                type="button"
                class="h-5 w-5 rounded-full border-2 transition"
                :class="drawColor === c ? 'scale-110 border-slate-900' : 'border-white shadow'"
                :style="{ backgroundColor: c }"
                @click="drawColor = c"
              />
            </div>
          </div>
        </aside>

        <!-- 中栏：JSXGraph 交互绘图画板 -->
        <section class="col-span-7 flex flex-col gap-2">
          <div class="flex items-center justify-between rounded-lg bg-sky-50 px-3 py-1.5 text-xs text-sky-800">
            <span>{{ currentToolHint }}</span>
            <div v-if="activeTool === 'polygon' && pendingPointIds.length > 0" class="flex items-center gap-2">
              <span class="font-bold">已选 {{ pendingPointIds.length }} 点</span>
              <el-button size="small" type="primary" @click="finishPolygon">闭合多边形</el-button>
            </div>
            <span v-else-if="pendingPointIds.length > 0" class="font-bold text-amber-700">
              已选 {{ pendingPointIds.length }} 个锚点，请继续点击目标点
            </span>
          </div>

          <div
            :id="boardDomId"
            class="jxgbox h-[480px] w-full overflow-hidden rounded-xl border border-slate-300 bg-white shadow-inner"
          />
        </section>

        <!-- 右栏：函数解析式绘制 + 选中图元属性 -->
        <aside class="col-span-3 flex max-h-[520px] flex-col gap-3 overflow-y-auto rounded-xl border border-slate-200 bg-slate-50/70 p-3">
          <!-- 函数绘制器 -->
          <div class="space-y-2 rounded-lg border border-slate-200 bg-white p-2.5">
            <div class="text-xs font-bold text-slate-800">绘制数学函数曲线 f(x)</div>
            <el-input
              v-model="newFunc.expr"
              size="small"
              placeholder="如 x^2 - 2*x - 3、3/x、2*sin(x)"
            >
              <template #prepend>y =</template>
            </el-input>
            <el-input v-model="newFunc.label" size="small" placeholder="图上标注（可选）" />
            <div class="grid grid-cols-2 gap-1.5">
              <el-input-number v-model="newFunc.xMin" size="small" controls-position="right" placeholder="x最小" />
              <el-input-number v-model="newFunc.xMax" size="small" controls-position="right" placeholder="x最大" />
            </div>
            <div class="flex items-center justify-between gap-2">
              <div class="flex items-center gap-1.5">
                <el-color-picker v-model="newFunc.color" size="small" />
                <el-checkbox v-model="newFunc.dashed" size="small">虚线</el-checkbox>
              </div>
              <el-button size="small" type="primary" @click="addFunctionCurve">+ 添加函数</el-button>
            </div>

            <div v-if="state.functions.length" class="space-y-1 border-t border-slate-100 pt-2">
              <div
                v-for="f in state.functions"
                :key="f.id"
                class="flex items-center justify-between gap-1 rounded border px-2 py-1 text-xs"
                :class="
                  selectedFunc?.id === f.id
                    ? 'border-sky-500 bg-sky-50'
                    : 'border-slate-200 bg-slate-50'
                "
                @click="selectedItem = { kind: 'func', id: f.id }"
              >
                <span class="truncate font-mono" :style="{ color: f.color }">y = {{ f.expr }}</span>
                <el-button
                  link
                  type="danger"
                  size="small"
                  @click.stop="
                    state.functions = state.functions.filter(i => i.id !== f.id);
                    pushHistory();
                    rebuildBoard();
                  "
                >
                  删
                </el-button>
              </div>
            </div>
          </div>

          <!-- 选中对象属性编辑器 -->
          <div class="space-y-2 rounded-lg border border-slate-200 bg-white p-2.5">
            <div class="flex items-center justify-between">
              <span class="text-xs font-bold text-slate-800">选中图元属性</span>
              <el-button v-if="selectedItem" link type="danger" size="small" @click="removeSelected">
                删除选中
              </el-button>
            </div>

            <template v-if="selectedPoint">
              <div class="space-y-2 text-xs">
                <div class="flex items-center gap-2">
                  <span class="w-10 text-slate-500">标签</span>
                  <el-input v-model="selectedPoint.name" size="small" @change="rebuildBoard" />
                </div>
                <div class="grid grid-cols-2 gap-1.5">
                  <el-input-number
                    v-model="selectedPoint.x"
                    :step="0.5"
                    size="small"
                    controls-position="right"
                    @change="rebuildBoard"
                  />
                  <el-input-number
                    v-model="selectedPoint.y"
                    :step="0.5"
                    size="small"
                    controls-position="right"
                    @change="rebuildBoard"
                  />
                </div>
                <div class="flex items-center justify-between">
                  <el-checkbox v-model="selectedPoint.showLabel" size="small" @change="rebuildBoard">
                    显示字母标签
                  </el-checkbox>
                  <el-color-picker v-model="selectedPoint.color" size="small" @change="rebuildBoard" />
                </div>
              </div>
            </template>

            <template v-else-if="selectedShape">
              <div class="space-y-2 text-xs">
                <div class="text-slate-500">类型：{{ selectedShape.type }}</div>
                <div v-if="selectedShape.type === 'text'" class="flex items-center gap-2">
                  <span class="w-10 text-slate-500">内容</span>
                  <el-input v-model="selectedShape.text" size="small" @change="rebuildBoard" />
                </div>
                <div v-if="selectedShape.type === 'angle'" class="flex items-center gap-2">
                  <span class="w-10 text-slate-500">角名</span>
                  <el-input v-model="selectedShape.label" size="small" @change="rebuildBoard" />
                </div>
                <div class="flex items-center justify-between">
                  <el-checkbox v-model="selectedShape.dashed" size="small" @change="rebuildBoard">
                    虚线样式
                  </el-checkbox>
                  <div class="flex items-center gap-1.5">
                    <span class="text-slate-500">线色</span>
                    <el-color-picker v-model="selectedShape.color" size="small" @change="rebuildBoard" />
                  </div>
                </div>
                <div v-if="selectedShape.type === 'polygon' || selectedShape.type === 'circle'" class="flex items-center justify-between">
                  <span class="text-slate-500">内部填充色</span>
                  <el-color-picker v-model="selectedShape.fillColor" size="small" @change="rebuildBoard" />
                </div>
              </div>
            </template>

            <div v-else class="py-3 text-center text-xs text-slate-400">
              在「选择/拖拽」模式下点击画布中的点、图形或函数可调整其属性与坐标
            </div>
          </div>

          <div class="rounded-lg bg-amber-50 p-2.5 text-[11px] leading-relaxed text-amber-800">
            提示：保存为矢量图后，学生端 App（手机/平板）及错题本 A4 Word 导出均可无损高清渲染，且文本支持动态题变量 <code>&#123;&#123;a&#125;&#125;</code>。
          </div>
        </aside>
      </div>
    </div>

    <template #footer>
      <div class="flex flex-wrap items-center justify-between gap-2">
        <span class="text-xs text-slate-500">
          当前画布：{{ state.points.length }} 个顶点 · {{ state.shapes.length }} 个图元 · {{ state.functions.length }} 条函数曲线
        </span>
        <div class="flex items-center gap-2">
          <el-button @click="emit('update:modelValue', false)">取消</el-button>
          <el-button type="success" plain :loading="exportingImage" @click="handleExportPng">
            导出高清 PNG 上传
          </el-button>
          <el-button type="primary" @click="handleSaveVector">
            保存矢量图到题目
          </el-button>
        </div>
      </div>
    </template>
  </el-dialog>
</template>

<style scoped>
.jxgbox {
  position: relative;
  overflow: hidden;
  user-select: none;
  touch-action: none;
  background-color: #ffffff;
}
.jxgbox :deep(.JXGtext) {
  padding: 0;
  margin: 0;
  line-height: 1.15;
  background: transparent;
  font-family: system-ui, -apple-system, "Microsoft YaHei", sans-serif;
}
</style>
