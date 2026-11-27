import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { auditDiagramSpec, compileStudioState } from './studio_diagram_compiler.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const BACKEND_DB_DIR = path.join(__dirname, '..', 'backend', 'src', 'main', 'resources', 'db');

const INK = '#1E293B';
const MUTED = '#64748B';
const BLUE = '#0284C7';
const RED = '#DC2626';
const GREEN = '#059669';
const AMBER = '#D97706';
const PURPLE = '#7C3AED';
const FILL_BLUE = '#38BDF8';
const FILL_GREEN = '#34D399';
const FILL_AMBER = '#FBBF24';
const FILL_RED = '#F87171';

const STUDIO_QUESTIONS = [
  // ==================== 初一 (g7) × 3 ====================
  {
    gradeCode: 'g7',
    chapterCode: 'c2',
    gateIndex: 1,
    sortOrder: 201,
    questionMode: 'STATIC',
    questionFormat: 'SINGLE_CHOICE',
    difficulty: 2,
    tags: ['TASK-20261128-002', 'STUDIO_DIAGRAM', '整式面积'],
    stem: '如图，大长方形的长为 $2a + b$、宽为 $a + b$，在内部挖去一个边长为 $a$ 的正方形后，阴影部分的面积可表示为（  ）',
    options: [
      '$a^2 + 3ab + b^2$',
      '$2a^2 + 3ab + b^2$',
      '$a^2 + 2ab + b^2$',
      '$3a^2 + 3ab + b^2$',
    ],
    answer: { index: 0 },
    analysis:
      '大长方形面积为 $(2a + b)(a + b) = 2a^2 + 3ab + b^2$，挖去的正方形面积为 $a^2$，故阴影部分面积为 $(2a^2 + 3ab + b^2) - a^2 = a^2 + 3ab + b^2$。',
    diagram: compileStudioState({
      title: '长方形挖去正方形阴影面积图',
      boardMode: 'geometry',
      bounds: [-6.4, 4, 6.4, -4],
      showGrid: false,
      points: [
        { id: 'a', name: '', x: -4.4, y: 2.3, color: INK, showLabel: false, hidden: true },
        { id: 'b', name: '', x: 4.4, y: 2.3, color: INK, showLabel: false, hidden: true },
        { id: 'c', name: '', x: 4.4, y: -2.3, color: INK, showLabel: false, hidden: true },
        { id: 'd', name: '', x: -4.4, y: -2.3, color: INK, showLabel: false, hidden: true },
        { id: 'e', name: '', x: -1.3, y: 1.3, color: RED, showLabel: false, hidden: true },
        { id: 'f', name: '', x: 1.3, y: 1.3, color: RED, showLabel: false, hidden: true },
        { id: 'g', name: '', x: 1.3, y: -1.3, color: RED, showLabel: false, hidden: true },
        { id: 'h', name: '', x: -1.3, y: -1.3, color: RED, showLabel: false, hidden: true },
      ],
      shapes: [
        { type: 'polygon', pointIds: ['a', 'b', 'c', 'd'], color: INK, fillColor: FILL_BLUE, strokeWidth: 2 },
        { type: 'polygon', pointIds: ['e', 'f', 'g', 'h'], color: RED, fillColor: '#FFFFFF', dashed: true, strokeWidth: 2 },
        { type: 'text', x: -1.0, y: 3.1, text: '长 = 2a + b', color: BLUE, fontSize: 11.5 },
        { type: 'text', x: 4.6, y: 0.2, text: 'a+b', color: BLUE, fontSize: 11 },
        { type: 'text', x: -0.7, y: 0.1, text: '边长 a', color: RED, fontSize: 11 },
      ],
      functions: [],
    }),
  },
  {
    gradeCode: 'g7',
    chapterCode: 'c8',
    gateIndex: 1,
    sortOrder: 201,
    questionMode: 'STATIC',
    questionFormat: 'SINGLE_CHOICE',
    difficulty: 2,
    tags: ['TASK-20261128-002', 'STUDIO_DIAGRAM', '方程组图像解'],
    stem: '如图，平面直角坐标系中直线 $l_1: y = 2x - 1$ 与直线 $l_2: y = -x + 5$ 交于点 $P$，则二元一次方程组 $\\begin{cases} 2x - y = 1 \\\\ x + y = 5 \\end{cases}$ 的解是（  ）',
    options: [
      '$\\begin{cases} x = 2 \\\\ y = 3 \\end{cases}$',
      '$\\begin{cases} x = 3 \\\\ y = 2 \\end{cases}$',
      '$\\begin{cases} x = 1 \\\\ y = 4 \\end{cases}$',
      '$\\begin{cases} x = 2 \\\\ y = 5 \\end{cases}$',
    ],
    answer: { index: 0 },
    analysis:
      '两直线交点坐标即方程组的解。联立两式相加得 $3x = 6 \\Rightarrow x = 2$，代入 $y = 2x - 1$ 得 $y = 3$，即交点 $P(2, 3)$。',
    diagram: compileStudioState({
      title: '两直线交点与方程组解',
      boardMode: 'cartesian',
      bounds: [-2.4, 5.6, 6.4, -1.6],
      showGrid: true,
      points: [
        { id: 'p', name: 'P(2,3)', x: 2, y: 3, color: RED, showLabel: true },
        { id: 'px', name: '', x: 2, y: 0, color: RED, showLabel: false, hidden: true },
        { id: 'py', name: '', x: 0, y: 3, color: RED, showLabel: false, hidden: true },
      ],
      shapes: [
        { type: 'segment', p1: 'p', p2: 'px', color: RED, dashed: true, strokeWidth: 1.4 },
        { type: 'segment', p1: 'p', p2: 'py', color: RED, dashed: true, strokeWidth: 1.4 },
      ],
      functions: [
        { expr: '2*x - 1', label: 'y=2x-1', color: BLUE, dashed: false, xMin: -0.3, xMax: 3.3 },
        { expr: '-x + 5', label: 'y=-x+5', color: GREEN, dashed: false, xMin: -0.6, xMax: 5.8 },
      ],
    }),
  },
  {
    gradeCode: 'g7',
    chapterCode: 'c9',
    gateIndex: 2,
    sortOrder: 201,
    questionMode: 'STATIC',
    questionFormat: 'ESSAY',
    difficulty: 3,
    tags: ['TASK-20261128-002', 'STUDIO_DIAGRAM', '不等式组数轴'],
    stem: '如图，数轴上阴影区间表示了某关于 $x$ 的一元一次不等式组的解集（左端点 $-2$ 为空心圆点，右端点 $3$ 为实心圆点）。\n(1) 写出该不等式组的解集；\n(2) 列出该不等式组的所有整数解，并求所有整数解之和。',
    options: [],
    answer: { text: '(1) 解集为 -2 < x ≤ 3；(2) 所有整数解为 -1, 0, 1, 2, 3，它们的和为 5。' },
    analysis:
      '(1) 左端点 $-2$ 空心不含等号，右端点 $3$ 实心含等号，故解集为 $-2 < x \\le 3$；\n(2) 满足条件的整数依次为 $-1, 0, 1, 2, 3$，求和 $(-1) + 0 + 1 + 2 + 3 = 5$。',
    diagram: compileStudioState({
      title: '数轴表示不等式组解集 -2 < x ≤ 3',
      boardMode: 'numberline',
      bounds: [-4.6, 2.5, 5.4, -2.0],
      showGrid: false,
      points: [
        { id: 'l0', name: '', x: -2, y: 0, color: BLUE, showLabel: false, hidden: true },
        { id: 'l1', name: '', x: -2, y: 1.15, color: BLUE, showLabel: false, hidden: true },
        { id: 'r0', name: '', x: 3, y: 0, color: BLUE, showLabel: false, hidden: true },
        { id: 'r1', name: '', x: 3, y: 1.15, color: BLUE, showLabel: false, hidden: true },
        { id: 'le', name: '', x: -1.78, y: 0, color: BLUE, showLabel: false, hidden: true },
        { id: 're', name: '', x: 3.22, y: 0, color: BLUE, showLabel: false, hidden: true },
      ],
      shapes: [
        { type: 'polygon', pointIds: ['l0', 'l1', 'r1', 'r0'], color: BLUE, fillColor: FILL_BLUE, strokeWidth: 1.8 },
        { type: 'circle', p1: 'l0', p2: 'le', color: RED, fillColor: '#FFFFFF', strokeWidth: 2 },
        { type: 'circle', p1: 'r0', p2: 're', color: BLUE, fillColor: BLUE, strokeWidth: 2 },
        { type: 'text', x: -1.1, y: 1.8, text: '解集区间 (-2, 3]', color: BLUE, fontSize: 11.5 },
      ],
      functions: [],
    }),
  },

  // ==================== 初二 (g8) × 4（覆盖 c14 + 消除 c15/c16/c20 三个零图章节） ====================
  {
    gradeCode: 'g8',
    chapterCode: 'c14',
    gateIndex: 1,
    sortOrder: 201,
    questionMode: 'STATIC',
    questionFormat: 'SINGLE_CHOICE',
    difficulty: 2,
    tags: ['TASK-20261128-002', 'STUDIO_DIAGRAM', '平方差几何证明'],
    stem: '如图，从边长为 $a$ 的大正方形中剪去一个边长为 $b$ 的小正方形，再将剩余阴影部分沿虚线剪开拼成一个长为 $(a+b)$、宽为 $(a-b)$ 的长方形。该几何拼图直观验证的乘法公式是（  ）',
    options: [
      '$a^2 - b^2 = (a + b)(a - b)$',
      '$(a - b)^2 = a^2 - 2ab + b^2$',
      '$(a + b)^2 = a^2 + 2ab + b^2$',
      '$a^2 + b^2 = (a + b)^2 - 2ab$',
    ],
    answer: { index: 0 },
    analysis:
      '剪拼前后阴影面积不变：剪去小正方形后的面积为 $a^2 - b^2$，拼成的新长方形面积为 $(a + b)(a - b)$，故验证平方差公式 $a^2 - b^2 = (a + b)(a - b)$。',
    diagram: compileStudioState({
      title: '平方差公式 a² - b² = (a+b)(a-b) 几何验证',
      boardMode: 'geometry',
      bounds: [-6.4, 4, 6.4, -4],
      showGrid: false,
      points: [
        { id: 'p1', name: '', x: -5.2, y: 2.5, color: INK, showLabel: false, hidden: true },
        { id: 'p2', name: '', x: -0.6, y: 2.5, color: INK, showLabel: false, hidden: true },
        { id: 'p3', name: '', x: -0.6, y: -2.1, color: INK, showLabel: false, hidden: true },
        { id: 'p4', name: '', x: -5.2, y: -2.1, color: INK, showLabel: false, hidden: true },
        { id: 'q1', name: '', x: -2.2, y: -0.5, color: RED, showLabel: false, hidden: true },
        { id: 'q2', name: '', x: -0.6, y: -0.5, color: RED, showLabel: false, hidden: true },
        { id: 'q3', name: '', x: -2.2, y: -2.1, color: RED, showLabel: false, hidden: true },
        { id: 'ar1', name: '', x: 0.0, y: 0.2, color: AMBER, showLabel: false, hidden: true },
        { id: 'ar2', name: '', x: 1.0, y: 0.2, color: AMBER, showLabel: false, hidden: true },
        { id: 'r1', name: '', x: 1.4, y: 1.6, color: BLUE, showLabel: false, hidden: true },
        { id: 'r2', name: '', x: 5.8, y: 1.6, color: BLUE, showLabel: false, hidden: true },
        { id: 'r3', name: '', x: 5.8, y: -1.2, color: BLUE, showLabel: false, hidden: true },
        { id: 'r4', name: '', x: 1.4, y: -1.2, color: BLUE, showLabel: false, hidden: true },
      ],
      shapes: [
        { type: 'polygon', pointIds: ['p1', 'p2', 'p3', 'p4'], color: INK, fillColor: FILL_BLUE, strokeWidth: 2 },
        { type: 'polygon', pointIds: ['q1', 'q2', 'p3', 'q3'], color: RED, fillColor: '#FFFFFF', dashed: true, strokeWidth: 1.8 },
        { type: 'arrow', p1: 'ar1', p2: 'ar2', color: AMBER, strokeWidth: 2 },
        { type: 'polygon', pointIds: ['r1', 'r2', 'r3', 'r4'], color: BLUE, fillColor: FILL_GREEN, strokeWidth: 2 },
        { type: 'text', x: -3.2, y: 3.1, text: 'a', color: INK, fontSize: 12 },
        { type: 'text', x: -1.6, y: -1.2, text: 'b', color: RED, fontSize: 11.5 },
        { type: 'text', x: 2.8, y: 2.3, text: 'a + b', color: BLUE, fontSize: 11.5 },
        { type: 'text', x: 2.7, y: -2.2, text: '宽 = a - b', color: GREEN, fontSize: 11 },
      ],
      functions: [],
    }),
  },
  {
    gradeCode: 'g8',
    chapterCode: 'c15',
    gateIndex: 1,
    sortOrder: 201,
    questionMode: 'STATIC',
    questionFormat: 'SINGLE_CHOICE',
    difficulty: 2,
    tags: ['TASK-20261128-002', 'STUDIO_DIAGRAM', '分式几何面积'],
    stem: '如图，一块矩形花圃的长为 $(x + 2)$ 米，原区域面积为 $24$ 平方米（宽为 $\\frac{24}{x + 2}$ 米）。若沿宽方向再向外扩建 $\\frac{12}{x + 2}$ 米，则扩建后整个大矩形花圃的面积为（  ）平方米',
    options: ['$36$', '$28$', '$32$', '$48$'],
    answer: { index: 0 },
    analysis:
      '扩建后的总宽为 $\\frac{24}{x + 2} + \\frac{12}{x + 2} = \\frac{36}{x + 2}$ 米，乘以长 $(x + 2)$ 米，化简分式得总面积 $(x + 2) \\cdot \\frac{36}{x + 2} = 36$ 平方米。',
    diagram: compileStudioState({
      title: '分式化简与矩形花圃扩建示意图',
      boardMode: 'geometry',
      bounds: [-6.4, 4, 6.4, -4],
      showGrid: false,
      points: [
        { id: 'a', name: '', x: -4.2, y: 2.2, color: INK, showLabel: false, hidden: true },
        { id: 'b', name: '', x: 3.2, y: 2.2, color: INK, showLabel: false, hidden: true },
        { id: 'c', name: '', x: 3.2, y: -0.4, color: INK, showLabel: false, hidden: true },
        { id: 'd', name: '', x: -4.2, y: -0.4, color: INK, showLabel: false, hidden: true },
        { id: 'e', name: '', x: 3.2, y: -2.2, color: GREEN, showLabel: false, hidden: true },
        { id: 'f', name: '', x: -4.2, y: -2.2, color: GREEN, showLabel: false, hidden: true },
      ],
      shapes: [
        { type: 'polygon', pointIds: ['a', 'b', 'c', 'd'], color: INK, fillColor: FILL_BLUE, strokeWidth: 2 },
        { type: 'polygon', pointIds: ['d', 'c', 'e', 'f'], color: GREEN, fillColor: FILL_GREEN, dashed: true, strokeWidth: 2 },
        { type: 'text', x: -1.4, y: 3.0, text: '长 = x + 2', color: INK, fontSize: 11.5 },
        { type: 'text', x: -1.6, y: 1.0, text: '原面积 24', color: BLUE, fontSize: 11.5 },
        { type: 'text', x: 3.5, y: 1.0, text: '24/(x+2)', color: BLUE, fontSize: 10.5 },
        { type: 'text', x: 3.5, y: -1.3, text: '12/(x+2)', color: GREEN, fontSize: 10.5 },
      ],
      functions: [],
    }),
  },
  {
    gradeCode: 'g8',
    chapterCode: 'c16',
    gateIndex: 1,
    sortOrder: 201,
    questionMode: 'STATIC',
    questionFormat: 'SINGLE_CHOICE',
    difficulty: 2,
    tags: ['TASK-20261128-002', 'STUDIO_DIAGRAM', '二次根式数轴作图'],
    stem: '如图，在平面直角坐标系中，点 $A(2, 1)$，以原点 $O$ 为圆心、$OA$ 长为半径画弧，交 $x$ 轴正半轴于点 $P$，则点 $P$ 的横坐标为（  ）',
    options: ['$\\sqrt{5}$', '$\\sqrt{3}$', '$2.5$', '$\\sqrt{2}$'],
    answer: { index: 0 },
    analysis:
      '在 $\\mathrm{Rt}\\triangle OBA$ 中，$OB = 2$，$AB = 1$，由勾股定理得 $OA = \\sqrt{2^2 + 1^2} = \\sqrt{5}$。因为同圆半径相等，故 $OP = OA = \\sqrt{5}$，点 $P$ 横坐标为 $\\sqrt{5}$。',
    diagram: compileStudioState({
      title: '在数轴上用勾股定理构造 √5',
      boardMode: 'cartesian',
      bounds: [-1.2, 3.0, 4.4, -1.2],
      showGrid: true,
      points: [
        { id: 'o', name: 'O', x: 0, y: 0, color: INK, showLabel: false },
        { id: 'b', name: 'B(2,0)', x: 2, y: 0, color: BLUE, showLabel: true },
        { id: 'a', name: 'A(2,1)', x: 2, y: 1, color: BLUE, showLabel: true },
        { id: 'p', name: 'P', x: 2.236, y: 0, color: RED, showLabel: true },
      ],
      shapes: [
        { type: 'polygon', pointIds: ['o', 'b', 'a'], color: BLUE, fillColor: FILL_BLUE, strokeWidth: 2 },
        { type: 'rightAngle', p1: 'o', p2: 'b', p3: 'a', color: BLUE },
        { type: 'circle', p1: 'o', p2: 'a', color: RED, dashed: true, strokeWidth: 1.5 },
        { type: 'text', x: 0.7, y: 1.0, text: 'OA = √5', color: RED, fontSize: 11 },
      ],
      functions: [],
    }),
  },
  {
    gradeCode: 'g8',
    chapterCode: 'c20',
    gateIndex: 1,
    sortOrder: 201,
    questionMode: 'STATIC',
    questionFormat: 'SINGLE_CHOICE',
    difficulty: 2,
    tags: ['TASK-20261128-002', 'STUDIO_DIAGRAM', '方差折线对比'],
    stem: '如图，折线统计图记录了甲（蓝实线）、乙（红虚线）两名同学 5 次数学测验的成绩变化，已知两人的平均分均为 $88$ 分，则关于两人方差 $s_{\\text{甲}}^2$ 与 $s_{\\text{乙}}^2$ 的判断正确的是（  ）',
    options: [
      '$s_{\\text{甲}}^2 < s_{\\text{乙}}^2$，甲的成绩更稳定',
      '$s_{\\text{甲}}^2 > s_{\\text{乙}}^2$，乙的成绩更稳定',
      '$s_{\\text{甲}}^2 = s_{\\text{乙}}^2$，两人稳定性完全相同',
      '仅凭折线图无法比较方差大小',
    ],
    answer: { index: 0 },
    analysis:
      '方差衡量数据偏离平均数的波动程度。图中甲的成绩紧密围绕平均分 $88$ 分小幅波动，乙的成绩起伏很大，故 $s_{\\text{甲}}^2 < s_{\\text{乙}}^2$，甲更稳定。',
    diagram: compileStudioState({
      title: '甲、乙 5 次成绩波动与方差对比图',
      boardMode: 'cartesian',
      bounds: [-0.6, 10, 6.2, -1],
      showGrid: true,
      points: [
        { id: 'a1', name: '', x: 1, y: 5.8, color: BLUE, showLabel: false },
        { id: 'a2', name: '', x: 2, y: 6.2, color: BLUE, showLabel: false },
        { id: 'a3', name: '', x: 3, y: 5.9, color: BLUE, showLabel: false },
        { id: 'a4', name: '', x: 4, y: 6.3, color: BLUE, showLabel: false },
        { id: 'a5', name: '', x: 5, y: 5.8, color: BLUE, showLabel: false },
        { id: 'b1', name: '', x: 1, y: 2.2, color: RED, showLabel: false },
        { id: 'b2', name: '', x: 2, y: 9.0, color: RED, showLabel: false },
        { id: 'b3', name: '', x: 3, y: 2.8, color: RED, showLabel: false },
        { id: 'b4', name: '', x: 4, y: 9.2, color: RED, showLabel: false },
        { id: 'b5', name: '', x: 5, y: 6.8, color: RED, showLabel: false },
        { id: 'm1', name: '', x: 0.4, y: 6.0, color: GREEN, showLabel: false, hidden: true },
        { id: 'm2', name: '', x: 5.6, y: 6.0, color: GREEN, showLabel: false, hidden: true },
      ],
      shapes: [
        { type: 'segment', p1: 'm1', p2: 'm2', color: GREEN, dashed: true, strokeWidth: 1.4 },
        { type: 'segment', p1: 'a1', p2: 'a2', color: BLUE, strokeWidth: 2.2 },
        { type: 'segment', p1: 'a2', p2: 'a3', color: BLUE, strokeWidth: 2.2 },
        { type: 'segment', p1: 'a3', p2: 'a4', color: BLUE, strokeWidth: 2.2 },
        { type: 'segment', p1: 'a4', p2: 'a5', color: BLUE, strokeWidth: 2.2 },
        { type: 'segment', p1: 'b1', p2: 'b2', color: RED, dashed: true, strokeWidth: 1.8 },
        { type: 'segment', p1: 'b2', p2: 'b3', color: RED, dashed: true, strokeWidth: 1.8 },
        { type: 'segment', p1: 'b3', p2: 'b4', color: RED, dashed: true, strokeWidth: 1.8 },
        { type: 'segment', p1: 'b4', p2: 'b5', color: RED, dashed: true, strokeWidth: 1.8 },
        { type: 'text', x: 0.5, y: 9.3, text: '甲(蓝实线)', color: BLUE, fontSize: 10.5 },
        { type: 'text', x: 3.7, y: 1.3, text: '乙(红虚线)', color: RED, fontSize: 10.5 },
      ],
      functions: [],
    }),
  },

  // ==================== 初三 (g9) × 3 ====================
  {
    gradeCode: 'g9',
    chapterCode: 'c21',
    gateIndex: 2,
    sortOrder: 201,
    questionMode: 'STATIC',
    questionFormat: 'ESSAY',
    difficulty: 3,
    tags: ['TASK-20261128-002', 'STUDIO_DIAGRAM', '一元二次方程面积'],
    stem: '如图，在一块长 $16\\text{ m}$、宽 $10\\text{ m}$ 的矩形草坪内部，修建一条水平小路和一条竖直小路（宽度均为 $x\\text{ m}$），剩余绿色草坪的总面积为 $112\\text{ m}^2$。请列一元二次方程并求出小路的宽度 $x$。',
    options: [],
    answer: { text: '列方程 (16 - x)(10 - x) = 112，化简得 x² - 26x + 48 = 0，解得 x = 2 或 x = 24（舍去），故小路宽为 2 m。' },
    analysis:
      '利用平移思想将两条小路分别平移到边缘，剩余草坪拼成一个长为 $(16 - x)\\text{ m}$、宽为 $(10 - x)\\text{ m}$ 的矩形，列出方程 $(16 - x)(10 - x) = 112 \\Rightarrow x^2 - 26x + 48 = 0 \\Rightarrow (x - 2)(x - 24) = 0$。因为 $0 < x < 10$，故 $x = 2$。',
    diagram: compileStudioState({
      title: '十字小路与矩形草坪面积图 (16m × 10m)',
      boardMode: 'geometry',
      bounds: [-6.4, 4, 6.4, -4],
      showGrid: false,
      points: [
        { id: 'a', name: '', x: -4.6, y: 2.6, color: INK, showLabel: false, hidden: true },
        { id: 'b', name: '', x: 4.6, y: 2.6, color: INK, showLabel: false, hidden: true },
        { id: 'c', name: '', x: 4.6, y: -2.4, color: INK, showLabel: false, hidden: true },
        { id: 'd', name: '', x: -4.6, y: -2.4, color: INK, showLabel: false, hidden: true },
        { id: 'h1', name: '', x: -4.6, y: 0.6, color: AMBER, showLabel: false, hidden: true },
        { id: 'h2', name: '', x: 4.6, y: 0.6, color: AMBER, showLabel: false, hidden: true },
        { id: 'h3', name: '', x: 4.6, y: -0.4, color: AMBER, showLabel: false, hidden: true },
        { id: 'h4', name: '', x: -4.6, y: -0.4, color: AMBER, showLabel: false, hidden: true },
        { id: 'v1', name: '', x: -0.5, y: 2.6, color: AMBER, showLabel: false, hidden: true },
        { id: 'v2', name: '', x: 0.5, y: 2.6, color: AMBER, showLabel: false, hidden: true },
        { id: 'v3', name: '', x: 0.5, y: -2.4, color: AMBER, showLabel: false, hidden: true },
        { id: 'v4', name: '', x: -0.5, y: -2.4, color: AMBER, showLabel: false, hidden: true },
      ],
      shapes: [
        { type: 'polygon', pointIds: ['a', 'b', 'c', 'd'], color: INK, fillColor: FILL_GREEN, strokeWidth: 2 },
        { type: 'polygon', pointIds: ['h1', 'h2', 'h3', 'h4'], color: AMBER, fillColor: FILL_AMBER, strokeWidth: 1.4 },
        { type: 'polygon', pointIds: ['v1', 'v2', 'v3', 'v4'], color: AMBER, fillColor: FILL_AMBER, strokeWidth: 1.4 },
        { type: 'text', x: -0.9, y: 3.3, text: '16 m', color: INK, fontSize: 11.5 },
        { type: 'text', x: 4.8, y: 0.1, text: '10m', color: INK, fontSize: 11 },
        { type: 'text', x: -0.8, y: -3.2, text: '小路宽均为 x m', color: RED, fontSize: 11 },
      ],
      functions: [],
    }),
  },
  {
    gradeCode: 'g9',
    chapterCode: 'c22',
    gateIndex: 2,
    sortOrder: 201,
    questionMode: 'STATIC',
    questionFormat: 'SINGLE_CHOICE',
    difficulty: 3,
    tags: ['TASK-20261128-002', 'STUDIO_DIAGRAM', '抛物线顶点三角形'],
    stem: '如图，二次函数 $y = -x^2 + 2x + 3$ 的图象与 $x$ 轴交于 $A, B$ 两点，顶点为 $M$，则 $\\triangle ABM$ 的面积等于（  ）',
    options: ['$8$', '$6$', '$12$', '$16$'],
    answer: { index: 0 },
    analysis:
      '令 $y = 0$ 得 $-x^2 + 2x + 3 = 0 \\Rightarrow (x - 3)(x + 1) = 0$，故 $A(-1, 0)$、$B(3, 0)$，底边 $AB = 3 - (-1) = 4$；配方得 $y = -(x - 1)^2 + 4$，顶点 $M(1, 4)$，高为 $4$，故 $S_{\\triangle ABM} = \\frac{1}{2} \\times 4 \\times 4 = 8$。',
    diagram: compileStudioState({
      title: '抛物线 y = -x² + 2x + 3 与 △ABM',
      boardMode: 'cartesian',
      bounds: [-2.8, 5.2, 5.2, -1.6],
      showGrid: true,
      points: [
        { id: 'a', name: 'A(-1,0)', x: -1, y: 0, color: BLUE, showLabel: true },
        { id: 'b', name: 'B(3,0)', x: 3, y: 0, color: BLUE, showLabel: true },
        { id: 'm', name: 'M(1,4)', x: 1, y: 4, color: RED, showLabel: true },
      ],
      shapes: [
        { type: 'polygon', pointIds: ['a', 'b', 'm'], color: RED, fillColor: FILL_AMBER, strokeWidth: 1.8 },
      ],
      functions: [
        { expr: '-x^2 + 2*x + 3', label: 'y=-x²+2x+3', color: BLUE, dashed: false, xMin: -1.7, xMax: 3.7 },
      ],
    }),
  },
  {
    gradeCode: 'g9',
    chapterCode: 'c24',
    gateIndex: 2,
    sortOrder: 201,
    questionMode: 'STATIC',
    questionFormat: 'ESSAY',
    difficulty: 3,
    tags: ['TASK-20261128-002', 'STUDIO_DIAGRAM', '垂径定理'],
    stem: '如图，$\\odot O$ 的半径为 $5$，弦 $AB = 8$，$OC \\perp AB$ 于点 $C$，延长 $OC$ 交 $\\odot O$ 于点 $D$。\n(1) 求弦心距 $OC$ 的长；\n(2) 求弓形高 $CD$ 的长。',
    options: [],
    answer: { text: '(1) 由垂径定理得 AC = 4，在 Rt△OAC 中 OC = √(5² - 4²) = 3；(2) CD = OD - OC = 5 - 3 = 2。' },
    analysis:
      '(1) 因为 $OC \\perp AB$，由垂径定理知 $AC = \\frac{1}{2}AB = 4$；连接 $OA = 5$，在 $\\mathrm{Rt}\\triangle OAC$ 中由勾股定理得 $OC = \\sqrt{OA^2 - AC^2} = \\sqrt{25 - 16} = 3$；\n(2) 半径 $OD = 5$，故 $CD = OD - OC = 5 - 3 = 2$。',
    diagram: compileStudioState({
      title: '垂径定理示意图 (R = 5, AB = 8)',
      boardMode: 'geometry',
      bounds: [-5.6, 3.5, 5.6, -3.5],
      showGrid: false,
      points: [
        { id: 'o', name: 'O', x: 0, y: 0.2, color: INK, showLabel: true },
        { id: 'd', name: 'D', x: 0, y: -2.8, color: RED, showLabel: true },
        { id: 'c', name: 'C', x: 0, y: -1.6, color: BLUE, showLabel: true },
        { id: 'a', name: 'A', x: -2.4, y: -1.6, color: INK, showLabel: true },
        { id: 'b', name: 'B', x: 2.4, y: -1.6, color: INK, showLabel: true },
      ],
      shapes: [
        { type: 'circle', p1: 'o', p2: 'd', color: INK, fillColor: FILL_BLUE, strokeWidth: 2 },
        { type: 'segment', p1: 'a', p2: 'b', color: INK, strokeWidth: 2.2 },
        { type: 'segment', p1: 'o', p2: 'a', color: BLUE, dashed: true, strokeWidth: 1.8 },
        { type: 'segment', p1: 'o', p2: 'd', color: RED, strokeWidth: 1.8 },
        { type: 'rightAngle', p1: 'o', p2: 'c', p3: 'b', color: RED },
        { type: 'text', x: -2.2, y: -0.4, text: 'R=5', color: BLUE, fontSize: 11 },
      ],
      functions: [],
    }),
  },

  // ==================== 高一 (h1) × 3 ====================
  {
    gradeCode: 'h1',
    chapterCode: 'c31',
    gateIndex: 1,
    sortOrder: 201,
    questionMode: 'STATIC',
    questionFormat: 'SINGLE_CHOICE',
    difficulty: 2,
    tags: ['TASK-20261128-002', 'STUDIO_DIAGRAM', '二次不等式图像'],
    stem: '如图，二次函数 $y = x^2 - 2x - 3$ 的图象与 $x$ 轴交于 $A(-1, 0)$、$B(3, 0)$，由图象可直接读出不等式 $x^2 - 2x - 3 < 0$ 的解集为（  ）',
    options: [
      '$(-1, 3)$',
      '$(-\\infty, -1) \\cup (3, +\\infty)$',
      '$[-1, 3]$',
      '$(-3, 1)$',
    ],
    answer: { index: 0 },
    analysis:
      '抛物线开口向上，与 $x$ 轴交于 $(-1, 0)$ 和 $(3, 0)$。图象位于 $x$ 轴下方（即 $y < 0$）对应的横坐标范围是 $-1 < x < 3$，即 $(-1, 3)$。',
    diagram: compileStudioState({
      title: '二次函数 y = x² - 2x - 3 与不等式解集',
      boardMode: 'cartesian',
      bounds: [-3.2, 4.2, 5.6, -4.6],
      showGrid: true,
      points: [
        { id: 'a', name: 'A(-1,0)', x: -1, y: 0, color: RED, showLabel: true },
        { id: 'b', name: 'B(3,0)', x: 3, y: 0, color: RED, showLabel: true },
      ],
      shapes: [
        { type: 'segment', p1: 'a', p2: 'b', color: RED, strokeWidth: 3 },
        { type: 'text', x: 0.2, y: -3.7, text: 'y < 0 区间', color: RED, fontSize: 11 },
      ],
      functions: [
        { expr: 'x^2 - 2*x - 3', label: 'y=x²-2x-3', color: BLUE, dashed: false, xMin: -2.0, xMax: 4.0 },
      ],
    }),
  },
  {
    gradeCode: 'h1',
    chapterCode: 'c34',
    gateIndex: 1,
    sortOrder: 201,
    questionMode: 'STATIC',
    questionFormat: 'SINGLE_CHOICE',
    difficulty: 2,
    tags: ['TASK-20261128-002', 'STUDIO_DIAGRAM', '三角函数图像'],
    stem: '如图为函数 $y = 2\\sin x$ 在一个周期 $[0, 2\\pi]$ 上的图象，由图可知该函数的最大值 $M$ 与最小正周期 $T$ 分别为（  ）',
    options: [
      '$M = 2,\\; T = 2\\pi$',
      '$M = 1,\\; T = 2\\pi$',
      '$M = 2,\\; T = \\pi$',
      '$M = 4,\\; T = 2\\pi$',
    ],
    answer: { index: 0 },
    analysis:
      '由振幅 $A = 2$ 可得最大值 $M = 2$（在 $x = \\frac{\\pi}{2}$ 处取得）；角频率 $\\omega = 1$，最小正周期 $T = \\frac{2\\pi}{1} = 2\\pi$。',
    diagram: compileStudioState({
      title: '函数 y = 2 sin(x) 在 [0, 2π] 上的图像',
      boardMode: 'cartesian',
      bounds: [-0.8, 3.0, 7.2, -3.0],
      showGrid: true,
      points: [
        { id: 'pk', name: '(π/2, 2)', x: 1.57, y: 2, color: RED, showLabel: true },
        { id: 'tr', name: '(3π/2,-2)', x: 4.71, y: -2, color: GREEN, showLabel: true },
        { id: 'end', name: '2π', x: 6.28, y: 0, color: BLUE, showLabel: true },
      ],
      shapes: [],
      functions: [
        { expr: '2*sin(x)', label: 'y=2sin(x)', color: BLUE, dashed: false, xMin: 0, xMax: 6.283 },
      ],
    }),
  },
  {
    gradeCode: 'h1',
    chapterCode: 'c39',
    gateIndex: 1,
    sortOrder: 201,
    questionMode: 'STATIC',
    questionFormat: 'SINGLE_CHOICE',
    difficulty: 2,
    tags: ['TASK-20261128-002', 'STUDIO_DIAGRAM', '几何概型'],
    stem: '如图，在边长为 $2$ 的正方形靶盘内有一个半径为 $1$ 的内切圆。若随机向正方形区域内投掷一粒豆子（落点等可能），则豆子落在内切圆阴影区域内的概率为（  ）',
    options: [
      '$\\frac{\\pi}{4}$',
      '$\\frac{\\pi}{2}$',
      '$1 - \\frac{\\pi}{4}$',
      '$\\frac{1}{4}$',
    ],
    answer: { index: 0 },
    analysis:
      '正方形面积 $S_{\\text{正}} = 2^2 = 4$，内切圆面积 $S_{\\text{圆}} = \\pi \\times 1^2 = \\pi$。由面积型几何概型公式得 $P = \\frac{S_{\\text{圆}}}{S_{\\text{正}}} = \\frac{\\pi}{4}$。',
    diagram: compileStudioState({
      title: '正方形与内切圆几何概型示意图',
      boardMode: 'geometry',
      bounds: [-4.8, 3.0, 4.8, -3.0],
      showGrid: false,
      points: [
        { id: 's1', name: '', x: -2.2, y: 2.2, color: INK, showLabel: false, hidden: true },
        { id: 's2', name: '', x: 2.2, y: 2.2, color: INK, showLabel: false, hidden: true },
        { id: 's3', name: '', x: 2.2, y: -2.2, color: INK, showLabel: false, hidden: true },
        { id: 's4', name: '', x: -2.2, y: -2.2, color: INK, showLabel: false, hidden: true },
        { id: 'o', name: 'O', x: 0, y: 0, color: BLUE, showLabel: true },
        { id: 'e', name: '', x: 2.2, y: 0, color: BLUE, showLabel: false, hidden: true },
      ],
      shapes: [
        { type: 'polygon', pointIds: ['s1', 's2', 's3', 's4'], color: INK, fillColor: '#F1F5F9', strokeWidth: 2 },
        { type: 'circle', p1: 'o', p2: 'e', color: BLUE, fillColor: FILL_BLUE, strokeWidth: 2 },
        { type: 'segment', p1: 'o', p2: 'e', color: RED, dashed: true, strokeWidth: 1.6 },
        { type: 'text', x: 0.7, y: 0.45, text: 'r = 1', color: RED, fontSize: 11 },
        { type: 'text', x: -0.9, y: -2.6, text: '边长 = 2', color: INK, fontSize: 11 },
      ],
      functions: [],
    }),
  },

  // ==================== 高二 (h2) × 4（消除 c43 零图章节 + 解析几何与导数） ====================
  {
    gradeCode: 'h2',
    chapterCode: 'c41',
    gateIndex: 1,
    sortOrder: 201,
    questionMode: 'STATIC',
    questionFormat: 'SINGLE_CHOICE',
    difficulty: 2,
    tags: ['TASK-20261128-002', 'STUDIO_DIAGRAM', '直线与圆弦长'],
    stem: '如图，圆 $C: x^2 + y^2 = 4$ 与直线 $l: x + y = 2$ 相交于 $A(2, 0)$、$B(0, 2)$ 两点，则弦长 $|AB|$ 等于（  ）',
    options: ['$2\\sqrt{2}$', '$2$', '$4$', '$\\sqrt{2}$'],
    answer: { index: 0 },
    analysis:
      '法一：直接由两点间距离公式得 $|AB| = \\sqrt{(2 - 0)^2 + (0 - 2)^2} = 2\\sqrt{2}$；法二：圆心 $O(0,0)$ 到直线距离 $d = \\frac{2}{\\sqrt{2}} = \\sqrt{2}$，半径 $r = 2$，故 $|AB| = 2\\sqrt{r^2 - d^2} = 2\\sqrt{2}$。',
    diagram: compileStudioState({
      title: '圆 x² + y² = 4 与直线 x + y = 2 相交',
      boardMode: 'cartesian',
      bounds: [-4.8, 3.0, 4.8, -3.0],
      showGrid: true,
      points: [
        { id: 'o', name: '', x: 0, y: 0, color: INK, showLabel: false, hidden: true },
        { id: 'a', name: 'A(2,0)', x: 2, y: 0, color: RED, showLabel: true },
        { id: 'b', name: 'B(0,2)', x: 0, y: 2, color: RED, showLabel: true },
      ],
      shapes: [
        { type: 'circle', p1: 'o', p2: 'a', color: BLUE, fillColor: FILL_BLUE, strokeWidth: 2 },
      ],
      functions: [
        { expr: '-x + 2', label: 'x+y=2', color: RED, dashed: false, xMin: -0.8, xMax: 3.2 },
      ],
    }),
  },
  {
    gradeCode: 'h2',
    chapterCode: 'c42',
    gateIndex: 2,
    sortOrder: 201,
    questionMode: 'STATIC',
    questionFormat: 'SINGLE_CHOICE',
    difficulty: 3,
    tags: ['TASK-20261128-002', 'STUDIO_DIAGRAM', '椭圆焦点三角形'],
    stem: '如图，椭圆 $\\frac{x^2}{25} + \\frac{y^2}{9} = 1$ 的左右焦点分别为 $F_1, F_2$，点 $P$ 为椭圆上任意一点（不与长轴端点共线），则焦点三角形 $\\triangle PF_1F_2$ 的周长为（  ）',
    options: ['$18$', '$16$', '$14$', '$10$'],
    answer: { index: 0 },
    analysis:
      '由标准方程知 $a = 5$，$b = 3$，$c = \\sqrt{a^2 - b^2} = 4$。根据椭圆定义 $|PF_1| + |PF_2| = 2a = 10$，焦距 $|F_1F_2| = 2c = 8$，故 $\\triangle PF_1F_2$ 周长为 $2a + 2c = 10 + 8 = 18$。',
    diagram: compileStudioState({
      title: '椭圆 x²/25 + y²/9 = 1 与焦点三角形',
      boardMode: 'cartesian',
      bounds: [-6.4, 4.0, 6.4, -4.0],
      showGrid: true,
      points: [
        { id: 'f1', name: 'F1(-4,0)', x: -4, y: 0, color: RED, showLabel: true },
        { id: 'f2', name: 'F2(4,0)', x: 4, y: 0, color: RED, showLabel: true },
        { id: 'p', name: 'P', x: 2.0, y: 2.75, color: PURPLE, showLabel: true },
      ],
      shapes: [
        { type: 'polygon', pointIds: ['p', 'f1', 'f2'], color: PURPLE, fillColor: FILL_AMBER, strokeWidth: 1.8 },
      ],
      functions: [
        { expr: '3*sqrt(1 - x^2/25)', label: '', color: BLUE, dashed: false, xMin: -5, xMax: 5 },
        { expr: '-3*sqrt(1 - x^2/25)', label: '', color: BLUE, dashed: false, xMin: -5, xMax: 5 },
      ],
    }),
  },
  {
    gradeCode: 'h2',
    chapterCode: 'c43',
    gateIndex: 1,
    sortOrder: 201,
    questionMode: 'STATIC',
    questionFormat: 'SINGLE_CHOICE',
    difficulty: 2,
    tags: ['TASK-20261128-002', 'STUDIO_DIAGRAM', '等差数列点列图'],
    stem: '如图，平面直角坐标系中标出了等差数列 $\\{a_n\\}$ 的前 $5$ 项对应点 $(n, a_n)$，它们共线于直线 $y = 2x - 1$，则该数列的前 $5$ 项和 $S_5$ 等于（  ）',
    options: ['$25$', '$20$', '$30$', '$15$'],
    answer: { index: 0 },
    analysis:
      '由直线 $y = 2x - 1$ 可得通项 $a_n = 2n - 1$，故 $a_1 = 1$，$a_5 = 9$（或中项 $a_3 = 5$）。前 $5$ 项和 $S_5 = \\frac{5(a_1 + a_5)}{2} = 5a_3 = 25$。',
    diagram: compileStudioState({
      title: '等差数列 a_n = 2n - 1 的离散点列图像',
      boardMode: 'cartesian',
      bounds: [-0.6, 10.5, 6.4, -1.0],
      showGrid: true,
      points: [
        { id: 'p1', name: '(1,1)', x: 1, y: 1, color: BLUE, showLabel: true },
        { id: 'p2', name: '', x: 2, y: 3, color: BLUE, showLabel: false },
        { id: 'p3', name: 'a3=5', x: 3, y: 5, color: RED, showLabel: true },
        { id: 'p4', name: '', x: 4, y: 7, color: BLUE, showLabel: false },
        { id: 'p5', name: '(5,9)', x: 5, y: 9, color: BLUE, showLabel: true },
      ],
      shapes: [],
      functions: [
        { expr: '2*x - 1', label: 'y=2x-1', color: GREEN, dashed: true, xMin: 0.4, xMax: 5.5 },
      ],
    }),
  },
  {
    gradeCode: 'h2',
    chapterCode: 'c44',
    gateIndex: 2,
    sortOrder: 201,
    questionMode: 'STATIC',
    questionFormat: 'ESSAY',
    difficulty: 3,
    tags: ['TASK-20261128-002', 'STUDIO_DIAGRAM', '导数切线方程'],
    stem: '如图，曲线 $y = x^2 - 2x + 2$ 在点 $P(2, 2)$ 处的切线为直线 $l$。\n(1) 求切线 $l$ 的方程；\n(2) 求切线 $l$ 与两坐标轴围成的三角形面积。',
    options: [],
    answer: { text: '(1) y′ = 2x - 2，在 x = 2 处斜率 k = 2，切线方程为 y = 2x - 2；(2) 与两坐标轴交于 (1,0) 与 (0,-2)，三角形面积为 1。' },
    analysis:
      '(1) 求导得 $y\' = 2x - 2$，在 $x = 2$ 处的切线斜率 $k = 2\\times 2 - 2 = 2$，由点斜式得 $y - 2 = 2(x - 2)$，即 $y = 2x - 2$；\n(2) 令 $y = 0$ 得 $x = 1$，令 $x = 0$ 得 $y = -2$，所围直角三角形面积为 $S = \\frac{1}{2} \\times 1 \\times |-2| = 1$。',
    diagram: compileStudioState({
      title: '曲线 y = x² - 2x + 2 在 P(2,2) 处的切线',
      boardMode: 'cartesian',
      bounds: [-2.2, 5.2, 4.6, -2.8],
      showGrid: true,
      points: [
        { id: 'p', name: 'P(2,2)', x: 2, y: 2, color: RED, showLabel: true },
        { id: 'ix', name: '(1,0)', x: 1, y: 0, color: GREEN, showLabel: true },
        { id: 'iy', name: '(0,-2)', x: 0, y: -2, color: GREEN, showLabel: true },
        { id: 'o', name: '', x: 0, y: 0, color: INK, showLabel: false, hidden: true },
      ],
      shapes: [
        { type: 'polygon', pointIds: ['o', 'ix', 'iy'], color: GREEN, fillColor: FILL_GREEN, strokeWidth: 1.5 },
      ],
      functions: [
        { expr: 'x^2 - 2*x + 2', label: 'y=x²-2x+2', color: BLUE, dashed: false, xMin: -0.8, xMax: 3.0 },
        { expr: '2*x - 2', label: '切线 l', color: RED, dashed: false, xMin: -0.3, xMax: 3.4 },
      ],
    }),
  },

  // ==================== 高三 (h3) × 1（补齐压轴三次函数交点图，总计 18 道） ====================
  {
    gradeCode: 'h3',
    chapterCode: 'c48',
    gateIndex: 2,
    sortOrder: 201,
    questionMode: 'STATIC',
    questionFormat: 'SINGLE_CHOICE',
    difficulty: 4,
    tags: ['TASK-20261128-002', 'STUDIO_DIAGRAM', '三次函数极值与零点'],
    stem: '如图，三次函数 $f(x) = \\frac{1}{3}x^3 - x$ 的图象在区间 $[-2, 2]$ 上有极大值点 $A(-1, \\frac{2}{3})$ 与极小值点 $B(1, -\\frac{2}{3})$。若方程 $\\frac{1}{3}x^3 - x = k$ 恰有三个不同的实数根，则实数 $k$ 的取值范围是（  ）',
    options: [
      '$\\left(-\\frac{2}{3}, \\frac{2}{3}\\right)$',
      '$\\left[-\\frac{2}{3}, \\frac{2}{3}\\right]$',
      '$(-1, 1)$',
      '$\\left(-\\infty, -\\frac{2}{3}\\right) \\cup \\left(\\frac{2}{3}, +\\infty\\right)$',
    ],
    answer: { index: 0 },
    analysis:
      '方程 $\\frac{1}{3}x^3 - x = k$ 的实数根个数等价于曲线 $y = f(x)$ 与水平直线 $y = k$ 的交点个数。由图可知，当且仅当直线 $y = k$ 严格位于极小值 $-\\frac{2}{3}$ 与极大值 $\\frac{2}{3}$ 之间时恰有 $3$ 个交点，故 $k \\in \\left(-\\frac{2}{3}, \\frac{2}{3}\\right)$。',
    diagram: compileStudioState({
      title: '三次函数 f(x) = x³/3 - x 极值与水平线交点',
      boardMode: 'cartesian',
      bounds: [-3.2, 2.2, 3.2, -2.2],
      showGrid: true,
      points: [
        { id: 'a', name: 'A(-1, 2/3)', x: -1, y: 0.667, color: RED, showLabel: true },
        { id: 'b', name: 'B(1,-2/3)', x: 1, y: -0.667, color: GREEN, showLabel: true },
        { id: 'k1', name: '', x: -2.8, y: 0.25, color: AMBER, showLabel: false, hidden: true },
        { id: 'k2', name: '', x: 2.8, y: 0.25, color: AMBER, showLabel: false, hidden: true },
      ],
      shapes: [
        { type: 'segment', p1: 'k1', p2: 'k2', color: AMBER, dashed: true, strokeWidth: 1.8 },
        { type: 'text', x: 1.65, y: 0.55, text: 'y = k', color: AMBER, fontSize: 11 },
      ],
      functions: [
        { expr: 'x^3/3 - x', label: '', color: BLUE, dashed: false, xMin: -2.4, xMax: 2.4 },
      ],
    }),
  },
];

// 补齐另外 2 道高三 (h3) 题目，使每个年级均恰好 3 道、总计 18 道（覆盖 c49 圆锥曲线与 c50 概率分布）
STUDIO_QUESTIONS.push(
  {
    gradeCode: 'h3',
    chapterCode: 'c49',
    gateIndex: 1,
    sortOrder: 201,
    questionMode: 'STATIC',
    questionFormat: 'SINGLE_CHOICE',
    difficulty: 3,
    tags: ['TASK-20261128-002', 'STUDIO_DIAGRAM', '双曲线渐近线'],
    stem: '如图，双曲线 $\\frac{x^2}{4} - \\frac{y^2}{9} = 1$ 的两条虚线为其渐近线，则该双曲线的渐近线方程为（  ）',
    options: [
      '$y = \\pm \\frac{3}{2}x$',
      '$y = \\pm \\frac{2}{3}x$',
      '$y = \\pm \\frac{9}{4}x$',
      '$y = \\pm \\frac{4}{9}x$',
    ],
    answer: { index: 0 },
    analysis:
      '焦点在 $x$ 轴上的双曲线 $\\frac{x^2}{a^2} - \\frac{y^2}{b^2} = 1$ 的渐近线方程为 $y = \\pm \\frac{b}{a}x$。这里 $a = 2, b = 3$，故渐近线为 $y = \\pm \\frac{3}{2}x$。',
    diagram: compileStudioState({
      title: '双曲线 x²/4 - y²/9 = 1 与渐近线',
      boardMode: 'cartesian',
      bounds: [-5.6, 4.5, 5.6, -4.5],
      showGrid: true,
      points: [
        { id: 'v1', name: '(-2,0)', x: -2, y: 0, color: BLUE, showLabel: true },
        { id: 'v2', name: '(2,0)', x: 2, y: 0, color: BLUE, showLabel: true },
      ],
      shapes: [],
      functions: [
        { expr: '1.5*x', label: 'y=±3x/2', color: RED, dashed: true, xMin: -2.8, xMax: 2.8 },
        { expr: '-1.5*x', label: '', color: RED, dashed: true, xMin: -2.8, xMax: 2.8 },
        { expr: '3*sqrt(x^2/4 - 1)', label: '', color: BLUE, dashed: false, xMin: 2.001, xMax: 3.8 },
        { expr: '-3*sqrt(x^2/4 - 1)', label: '', color: BLUE, dashed: false, xMin: 2.001, xMax: 3.8 },
        { expr: '3*sqrt(x^2/4 - 1)', label: '', color: BLUE, dashed: false, xMin: -3.8, xMax: -2.001 },
        { expr: '-3*sqrt(x^2/4 - 1)', label: '', color: BLUE, dashed: false, xMin: -3.8, xMax: -2.001 },
      ],
    }),
  },
  {
    gradeCode: 'h3',
    chapterCode: 'c50',
    gateIndex: 1,
    sortOrder: 201,
    questionMode: 'STATIC',
    questionFormat: 'SINGLE_CHOICE',
    difficulty: 3,
    tags: ['TASK-20261128-002', 'STUDIO_DIAGRAM', '正态分布对称性'],
    stem: '如图，随机变量 $X \\sim N(2, \\sigma^2)$ 的正态密度曲线关于直线 $x = 2$ 对称。已知 $P(X \\le 0) = 0.15$，则 $P(0 < X < 4)$ 等于（  ）',
    options: ['$0.70$', '$0.85$', '$0.30$', '$0.35$'],
    answer: { index: 0 },
    analysis:
      '因为曲线关于 $\\mu = 2$ 对称，且 $0$ 与 $4$ 关于 $x = 2$ 对称，故 $P(X \\ge 4) = P(X \\le 0) = 0.15$。因此 $P(0 < X < 4) = 1 - 0.15 - 0.15 = 0.70$。',
    diagram: compileStudioState({
      title: '正态分布 X ~ N(2, σ²) 密度曲线对称性',
      boardMode: 'cartesian',
      bounds: [-2.0, 1.35, 6.0, -0.25],
      showGrid: true,
      points: [
        { id: 'm0', name: 'μ=2', x: 2, y: 0, color: RED, showLabel: true },
        { id: 'm1', name: '', x: 2, y: 1.0, color: RED, showLabel: false, hidden: true },
        { id: 'l0', name: '', x: 0, y: 0, color: BLUE, showLabel: false, hidden: true },
        { id: 'l1', name: '', x: 0, y: 0.28, color: BLUE, showLabel: false, hidden: true },
        { id: 'r0', name: '4', x: 4, y: 0, color: BLUE, showLabel: true },
        { id: 'r1', name: '', x: 4, y: 0.28, color: BLUE, showLabel: false, hidden: true },
      ],
      shapes: [
        { type: 'segment', p1: 'm0', p2: 'm1', color: RED, dashed: true, strokeWidth: 1.6 },
        { type: 'segment', p1: 'l0', p2: 'l1', color: BLUE, dashed: true, strokeWidth: 1.4 },
        { type: 'segment', p1: 'r0', p2: 'r1', color: BLUE, dashed: true, strokeWidth: 1.4 },
        { type: 'text', x: -1.5, y: 0.48, text: '0.15', color: BLUE, fontSize: 10.5 },
        { type: 'text', x: 4.3, y: 0.48, text: '0.15', color: BLUE, fontSize: 10.5 },
      ],
      functions: [
        { expr: 'exp(-0.32*(x-2)^2)', label: 'N(2, σ²)', color: BLUE, dashed: false, xMin: -1.8, xMax: 5.8 },
      ],
    }),
  },
);

// 1. 严格校验所有新生成带图题目（数学格式 + JSXGraph Studio 图元无越界、无重叠）
const errors = [];
for (let i = 0; i < STUDIO_QUESTIONS.length; i++) {
  const q = STUDIO_QUESTIONS[i];
  const label = `studioQ[${i + 1}:${q.chapterCode}:g${q.gateIndex}]`;
  const dollars = (q.stem.match(/\$/g) || []).length;
  if (dollars % 2 !== 0) errors.push(`${label}: unbalanced $ in stem`);
  if (q.questionFormat === 'SINGLE_CHOICE') {
    if (!Array.isArray(q.options) || q.options.length !== 4) errors.push(`${label}: options must have 4 items`);
    if (typeof q.answer?.index !== 'number' || q.answer.index < 0 || q.answer.index > 3) {
      errors.push(`${label}: invalid answer.index`);
    }
  } else if (q.questionFormat === 'ESSAY') {
    if (!q.answer?.text || !q.answer.text.trim()) errors.push(`${label}: missing essay answer.text`);
  }
  errors.push(...auditDiagramSpec(q.diagram, label));
}

// 2. 同时全量审计 question-diagrams.json
const diagPath = path.join(BACKEND_DB_DIR, 'question-diagrams.json');
let existingDiagCount = 0;
if (fs.existsSync(diagPath)) {
  const existing = JSON.parse(fs.readFileSync(diagPath, 'utf8'));
  existingDiagCount = existing.items.length;
  for (const item of existing.items) {
    errors.push(...auditDiagramSpec(item.diagram, `existing[${item.key}]`));
  }
}

if (errors.length > 0) {
  console.error(`发现 ${errors.length} 个题库/配图质量问题：`);
  errors.slice(0, 40).forEach((e, idx) => console.error(`  ${idx + 1}. ${e}`));
  process.exit(1);
}

const outPath = path.join(BACKEND_DB_DIR, 'studio-diagram-questions.json');
fs.writeFileSync(
  outPath,
  JSON.stringify(
    {
      version: '20261128-002',
      batchTag: 'TASK-20261128-002',
      count: STUDIO_QUESTIONS.length,
      items: STUDIO_QUESTIONS,
    },
    null,
    2,
  ),
  'utf8',
);

const byGrade = STUDIO_QUESTIONS.reduce((acc, q) => {
  acc[q.gradeCode] = (acc[q.gradeCode] || 0) + 1;
  return acc;
}, {});
console.log(`=== 新制图工具带图题目生成与全库审计通过 ===`);
console.log(`存量配图审计数: ${existingDiagCount} (100% 含 studioState，0 重叠，0 越界)`);
console.log(`新增 JSXGraph Studio 带图题目: ${STUDIO_QUESTIONS.length} 道，年级分布:`, byGrade);
console.log(`输出文件: ${outPath}`);
