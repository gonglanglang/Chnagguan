// 「过关啦」数学题库矢量配图生成器 (TASK-20261126-001 / TASK-20261128-002 升级 JSXGraph studioState)
// 统一输出兼容 Flutter BoardDiagramPainter、Admin SVG 渲染器与 MathDiagramStudioDialog 的 BoardDiagramSpec JSON：
// 支持图元类型：line / arrow / circle / arc / rightAngle / polygon / polyline / point / text，并内嵌 studioState。
// 动态模板题支持在 text / label / title 中保留 {{expr}}，由后端 QuestionEngineService 随随机参数实时渲染。

import { compileStudioState, synthesizeStudioStateFromDiagram } from './studio_diagram_compiler.mjs';

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
const FILL_PURPLE = '#A78BFA';
const FILL_RED = '#F87171';

const P = {
  line: (x1, y1, x2, y2, color = INK, dashed = false) => ({
    type: 'line',
    x1,
    y1,
    x2,
    y2,
    color,
    ...(dashed ? { dashed: true } : {}),
  }),
  arrow: (x1, y1, x2, y2, color = INK, dashed = false) => ({
    type: 'arrow',
    x1,
    y1,
    x2,
    y2,
    color,
    ...(dashed ? { dashed: true } : {}),
  }),
  circle: (cx, cy, r, color = INK, fillColor = null, dashed = false) => ({
    type: 'circle',
    cx,
    cy,
    r,
    color,
    ...(fillColor ? { fillColor } : {}),
    ...(dashed ? { dashed: true } : {}),
  }),
  arc: (cx, cy, r, startAngle, sweepAngle, color = RED, fillColor = null, dashed = false) => ({
    type: 'arc',
    cx,
    cy,
    r,
    startAngle,
    sweepAngle,
    color,
    ...(fillColor ? { fillColor } : {}),
    ...(dashed ? { dashed: true } : {}),
  }),
  rightAngle: (vx, vy, ax, ay, bx, by, size = 12, color = BLUE) => ({
    type: 'rightAngle',
    vx,
    vy,
    ax,
    ay,
    bx,
    by,
    size,
    color,
  }),
  polygon: (points, color = INK, fillColor = null, dashed = false) => ({
    type: 'polygon',
    points,
    color,
    ...(fillColor ? { fillColor } : {}),
    ...(dashed ? { dashed: true } : {}),
  }),
  polyline: (points, color = BLUE, dashed = false) => ({
    type: 'polyline',
    points,
    color,
    ...(dashed ? { dashed: true } : {}),
  }),
  point: (x, y, label = '', color = INK) => ({
    type: 'point',
    x,
    y,
    ...(label ? { label } : {}),
    color,
  }),
  text: (x, y, text, color = INK) => ({
    type: 'text',
    x,
    y,
    text,
    color,
  }),
};

function spec(title, primitives, width = 320, height = 210) {
  return { title, width, height, primitives };
}

function axesPrimitives(ox = 160, oy = 112, xMin = 24, xMax = 296, yMin = 18, yMax = 196) {
  return [
    P.arrow(xMin, oy, xMax, oy, MUTED),
    P.arrow(ox, yMax, ox, yMin, MUTED),
    P.text(xMax - 10, oy + 6, 'x', MUTED),
    P.text(ox + 7, yMin - 2, 'y', MUTED),
    P.text(ox - 13, oy + 5, 'O', MUTED),
  ];
}

function sampleCurve(fn, xStart, xEnd, steps, toPx) {
  const pts = [];
  for (let i = 0; i <= steps; i++) {
    const x = xStart + ((xEnd - xStart) * i) / steps;
    const y = fn(x);
    if (Number.isFinite(y)) {
      const [px, py] = toPx(x, y);
      if (px >= 10 && px <= 310 && py >= 10 && py <= 205) {
        pts.push([Math.round(px * 10) / 10, Math.round(py * 10) / 10]);
      }
    }
  }
  return pts;
}

// ============================================================================
// 1. 全部 33 道明确含“如图”题目的 1:1 精绘矢量几何/函数图（严格对齐顶点、条件与标注）
// ============================================================================
const EXACT_DIAGRAMS = {
  // c11-g1-q3: 如图，在 △ABC 中，∠A = {{a}}°，∠B = {{b}}°，延长 BC 到 D，求外角 ∠ACD
  'c11-g1-q3': () =>
    spec('△ABC 外角示意图', [
      P.polygon([[128, 38], [52, 162], [202, 162]], INK, FILL_BLUE),
      P.line(202, 162, 286, 162, INK),
      P.arc(202, 162, 26, -121, 121, RED, FILL_RED),
      P.point(128, 38, '', INK),
      P.point(52, 162, '', INK),
      P.point(202, 162, '', INK),
      P.point(278, 162, '', INK),
      P.text(122, 18, 'A ({{a}}°)', BLUE),
      P.text(30, 168, 'B ({{b}}°)', BLUE),
      P.text(196, 170, 'C', INK),
      P.text(274, 170, 'D', INK),
      P.text(222, 128, '∠ACD = ?', RED),
    ]),

  // c12-g1-q2: 如图，AB = AC，E 在 AC 上，D 在 AB 上，公共角 ∠A，△ABE ≅ △ACD
  'c12-g1-q2': () =>
    spec('公共角全等模型 (AB = AC)', [
      P.polygon([[160, 26], [70, 176], [250, 176]], INK, FILL_BLUE),
      P.line(70, 176, 214, 116, BLUE),
      P.line(250, 176, 106, 116, RED),
      P.point(160, 26, '', INK),
      P.point(70, 176, '', INK),
      P.point(250, 176, '', INK),
      P.point(106, 116, '', RED),
      P.point(214, 116, '', BLUE),
      P.text(154, 8, 'A', INK),
      P.text(54, 178, 'B', INK),
      P.text(254, 178, 'C', INK),
      P.text(88, 106, 'D', RED),
      P.text(220, 106, 'E', BLUE),
      P.text(20, 30, '已知 AB = AC', MUTED),
    ]),

  // c12-g3-q1: 手拉手模型：△ABC 和 △ADE 都是等腰直角三角形 (∠BAC = ∠DAE = 90°)，连接 BD、CE
  'c12-g3-q1': () =>
    spec('手拉手模型（等腰直角三角形）', [
      P.polygon([[138, 114], [52, 164], [88, 28]], INK, FILL_BLUE),
      P.polygon([[138, 114], [220, 66], [268, 148]], BLUE, FILL_GREEN),
      P.rightAngle(138, 114, 52, 164, 88, 28, 11, INK),
      P.rightAngle(138, 114, 220, 66, 268, 148, 11, BLUE),
      P.line(52, 164, 220, 66, RED, true),
      P.line(88, 28, 268, 148, AMBER, true),
      P.point(138, 114, '', INK),
      P.point(52, 164, '', INK),
      P.point(88, 28, '', INK),
      P.point(220, 66, '', BLUE),
      P.point(268, 148, '', BLUE),
      P.text(132, 126, 'A', INK),
      P.text(36, 168, 'B', INK),
      P.text(78, 10, 'C', INK),
      P.text(222, 48, 'D', BLUE),
      P.text(272, 146, 'E', BLUE),
    ]),

  // c13-g2-q3: 将军饮马：∠AOB = 30°，点 P 在内部，OP = {{a}}，M 在 OA 上，N 在 OB 上，△PMN 周长最小
  'c13-g2-q3': () =>
    spec('将军饮马模型 (∠AOB = 30°)', [
      P.arrow(42, 168, 288, 168, INK),
      P.arrow(42, 168, 268, 38, INK),
      P.arc(42, 168, 38, -30, 30, BLUE),
      P.line(42, 168, 198, 122, MUTED, true),
      P.polygon([[198, 122], [148, 107], [210, 168]], RED, FILL_RED),
      P.point(42, 168, '', INK),
      P.point(198, 122, '', RED),
      P.point(148, 107, '', BLUE),
      P.point(210, 168, '', BLUE),
      P.text(26, 170, 'O', INK),
      P.text(272, 26, 'A', INK),
      P.text(286, 174, 'B', INK),
      P.text(204, 112, 'P', RED),
      P.text(134, 88, 'M', BLUE),
      P.text(206, 174, 'N', BLUE),
      P.text(84, 148, '30°', BLUE),
      P.text(112, 128, 'OP={{a}}', MUTED),
    ]),

  // c13-g3-q5: 等边 △ABC 内一点 O，旋转 60° 得 △ADC，连接 OD
  'c13-g3-q5': () =>
    spec('等边三角形旋转模型', [
      P.polygon([[155, 24], [72, 172], [238, 172]], INK, FILL_BLUE),
      P.polygon([[155, 24], [238, 172], [282, 82]], BLUE, FILL_GREEN),
      P.line(155, 24, 168, 122, INK),
      P.line(72, 172, 168, 122, INK),
      P.line(238, 172, 168, 122, RED),
      P.line(238, 172, 282, 82, RED),
      P.line(168, 122, 282, 82, AMBER, true),
      P.point(155, 24, '', INK),
      P.point(72, 172, '', INK),
      P.point(238, 172, '', INK),
      P.point(168, 122, '', RED),
      P.point(282, 82, '', BLUE),
      P.text(150, 6, 'A', INK),
      P.text(56, 174, 'B', INK),
      P.text(242, 174, 'C', INK),
      P.text(162, 130, 'O', RED),
      P.text(286, 76, 'D', BLUE),
    ]),

  // c17-g1-q2: 5m 梯子斜靠在墙上，底端距墙角 3m，顶端下滑 1m
  'c17-g1-q2': () =>
    spec('梯子靠墙下滑示意图', [
      P.line(74, 24, 74, 176, INK),
      P.line(54, 176, 284, 176, INK),
      P.rightAngle(74, 176, 74, 24, 284, 176, 12, MUTED),
      P.line(74, 48, 170, 176, BLUE),
      P.line(74, 80, 202, 176, RED, true),
      P.point(74, 48, '', BLUE),
      P.point(170, 176, '', BLUE),
      P.point(74, 80, '', RED),
      P.point(202, 176, '', RED),
      P.text(52, 42, 'A', BLUE),
      P.text(46, 76, "A'", RED),
      P.text(56, 180, 'O', INK),
      P.text(164, 181, 'B', BLUE),
      P.text(198, 181, "B'", RED),
      P.text(124, 92, '5m', BLUE),
      P.text(108, 182, '3m', MUTED),
      P.text(24, 58, '↓1m', RED),
    ]),

  // c17-g2-q3: 勾股树基本模型：直角三角形三边向外作三个正方形
  'c17-g2-q3': () =>
    spec('“勾股树”基本模型', [
      P.polygon([[120, 146], [120, 86], [200, 146]], INK, FILL_AMBER),
      P.rightAngle(120, 146, 120, 86, 200, 146, 10, INK),
      // 左直角边正方形
      P.polygon([[120, 146], [120, 86], [60, 86], [60, 146]], BLUE, FILL_BLUE),
      // 下直角边正方形
      P.polygon([[120, 146], [200, 146], [200, 198], [120, 198]], GREEN, FILL_GREEN),
      // 斜边正方形
      P.polygon([[120, 86], [200, 146], [244, 88], [164, 28]], RED, FILL_RED),
      P.text(72, 110, '{{s*s}}', BLUE),
      P.text(150, 168, '16', GREEN),
      P.text(176, 80, 'S = ?', RED),
    ], 320, 210),

  // c17-g3-q1: 赵爽弦图：大正方形内4个全等直角三角形与中间小正方形
  'c17-g3-q1': () =>
    spec('赵爽弦图示意图', [
      P.polygon([[84, 22], [236, 22], [236, 174], [84, 174]], INK, FILL_BLUE),
      P.polygon([[144, 82], [176, 82], [176, 114], [144, 114]], RED, FILL_AMBER),
      P.line(84, 22, 176, 82, INK),
      P.line(236, 22, 176, 114, INK),
      P.line(236, 174, 144, 114, INK),
      P.line(84, 174, 144, 82, INK),
      P.text(148, 92, 'S=1', RED),
      P.text(112, 38, 'a', BLUE),
      P.text(204, 52, 'b', BLUE),
      P.text(98, 182, '大正方形面积 = 25', MUTED),
    ]),

  // c17-g3-q5: 四边形 ABCD，∠B = 90°，AB = 3, BC = 4, CD = 12, AD = 13
  'c17-g3-q5': () =>
    spec('四边形 ABCD (∠B = 90°)', [
      P.polygon([[68, 168], [68, 102], [254, 42], [156, 168]], INK, FILL_BLUE),
      P.line(68, 102, 156, 168, RED, true),
      P.rightAngle(68, 168, 68, 102, 156, 168, 11, BLUE),
      P.point(68, 102, '', INK),
      P.point(68, 168, '', INK),
      P.point(156, 168, '', INK),
      P.point(254, 42, '', INK),
      P.text(50, 94, 'A', INK),
      P.text(50, 170, 'B', INK),
      P.text(154, 174, 'C', INK),
      P.text(258, 34, 'D', INK),
      P.text(44, 130, '3', BLUE),
      P.text(106, 174, '4', BLUE),
      P.text(210, 112, '12', BLUE),
      P.text(152, 54, '13', BLUE),
    ]),

  // c18-g3-q1: 正方形 ABCD 半角模型，E 在 BC 上，F 在 CD 上，∠EAF = 45°
  'c18-g3-q1': () =>
    spec('正方形半角模型 (∠EAF = 45°)', [
      P.polygon([[84, 28], [84, 174], [230, 174], [230, 28]], INK, FILL_BLUE),
      P.polygon([[84, 28], [146, 174], [230, 110]], BLUE, FILL_AMBER),
      P.arc(84, 28, 32, 34, 33, RED),
      P.point(84, 28, '', INK),
      P.point(84, 174, '', INK),
      P.point(230, 174, '', INK),
      P.point(230, 28, '', INK),
      P.point(146, 174, '', RED),
      P.point(230, 110, '', RED),
      P.text(68, 16, 'A', INK),
      P.text(68, 176, 'B', INK),
      P.text(234, 176, 'C', INK),
      P.text(234, 16, 'D', INK),
      P.text(142, 180, 'E', RED),
      P.text(236, 104, 'F', RED),
      P.text(106, 62, '45°', RED),
    ]),

  // c22-g3-q2: 抛物线 y = ax² + bx + c，经过 (-1,0)，对称轴 x=1，开口向下
  'c22-g3-q2': () => {
    const ox = 128;
    const oy = 148;
    const sx = 32;
    const sy = 22;
    const toPx = (x, y) => [ox + x * sx, oy - y * sy];
    const curve = sampleCurve((x) => -0.8 * (x - 1) * (x - 1) + 3.2, -1.5, 3.5, 40, toPx);
    return spec('二次函数图象示意图', [
      ...axesPrimitives(ox, oy, 26, 292, 18, 194),
      P.line(ox + 1 * sx, 26, ox + 1 * sx, 190, RED, true),
      P.polyline(curve, BLUE),
      P.point(...toPx(-1, 0), '(-1,0)', RED),
      P.point(...toPx(3, 0), '(3,0)', GREEN),
      P.text(ox + 1 * sx + 4, 26, 'x = 1', RED),
    ]);
  },

  // c23-g1-q4: 正方形 ABCD 绕 A 逆时针旋转 45° 得 AB'C'D'
  'c23-g1-q4': () =>
    spec('正方形绕顶点 A 逆时针旋转 45°', [
      P.polygon([[130, 166], [216, 166], [216, 80], [130, 80]], INK, FILL_BLUE),
      P.polygon([[130, 166], [191, 105], [130, 44], [69, 105]], BLUE, FILL_GREEN),
      P.line(130, 166, 130, 44, RED, true),
      P.arc(130, 166, 30, -45, 45, AMBER),
      P.point(130, 166, '', INK),
      P.text(122, 174, 'A', INK),
      P.text(220, 170, 'B', INK),
      P.text(220, 72, 'C', INK),
      P.text(112, 72, 'D', INK),
      P.text(124, 26, "C'", BLUE),
      P.text(196, 102, "B'", BLUE),
      P.text(50, 102, "D'", BLUE),
      P.text(162, 146, '45°', AMBER),
      P.text(170, 174, '边长={{k}}', MUTED),
    ]),

  // c23-g2-q2: △ABC 绕 A 逆时针旋转得 △AB'C'，使 CC' ∥ AB，∠CAB = 65°
  'c23-g2-q2': () =>
    spec('三角形旋转 (CC\' ∥ AB)', [
      P.polygon([[76, 158], [244, 158], [166, 74]], INK, FILL_BLUE),
      P.polygon([[76, 158], [202, 74], [98, 44]], BLUE, FILL_GREEN),
      P.line(166, 74, 98, 44, RED, true),
      P.line(98, 74, 224, 74, RED, true),
      P.point(76, 158, '', INK),
      P.point(244, 158, '', INK),
      P.point(166, 74, '', INK),
      P.point(202, 74, '', BLUE),
      P.point(98, 44, '', BLUE),
      P.text(60, 160, 'A', INK),
      P.text(248, 160, 'B', INK),
      P.text(168, 56, 'C', INK),
      P.text(208, 66, "B'", BLUE),
      P.text(84, 28, "C'", BLUE),
      P.text(114, 140, '65°', AMBER),
    ]),

  // c23-g2-q3: 正方形中心 O，直角三角板交 BC、CD 于 E、F，重叠四边形 OECF
  'c23-g2-q3': () =>
    spec('正方形中心旋转重叠面积', [
      P.polygon([[90, 32], [90, 172], [230, 172], [230, 32]], INK, FILL_BLUE),
      P.line(90, 32, 230, 172, MUTED, true),
      P.line(230, 32, 90, 172, MUTED, true),
      P.polygon([[160, 102], [186, 172], [230, 172], [230, 128]], RED, FILL_AMBER),
      P.rightAngle(160, 102, 186, 172, 230, 128, 10, RED),
      P.point(160, 102, '', RED),
      P.text(74, 22, 'A', INK),
      P.text(74, 174, 'B', INK),
      P.text(234, 174, 'C', INK),
      P.text(234, 22, 'D', INK),
      P.text(146, 86, 'O', RED),
      P.text(182, 178, 'E', RED),
      P.text(236, 122, 'F', RED),
      P.text(22, 100, '边长={{2*a}}', MUTED),
    ]),

  // c23-g2-q4: 坐标系中 △ABC：A(1,3), B(4,1), C(2,0)
  'c23-g2-q4': () => {
    const ox = 152;
    const oy = 132;
    const s = 26;
    const p = (x, y) => [ox + x * s, oy - y * s];
    return spec('平面直角坐标系中 △ABC', [
      ...axesPrimitives(ox, oy, 26, 294, 18, 194),
      P.polygon([p(1, 3), p(4, 1), p(2, 0)], BLUE, FILL_BLUE),
      P.point(...p(1, 3), 'A(1,3)', BLUE),
      P.point(...p(4, 1), 'B(4,1)', BLUE),
      P.point(...p(2, 0), 'C(2,0)', BLUE),
    ]);
  },

  // c23-g3-q1: 正方形内点 P，PA=1, PB=2, PC=3，将 △ABP 绕 B 顺时针旋转 90° 到 △CBP'
  'c23-g3-q1': () =>
    spec('正方形内点旋转 (PA=1, PB=2, PC=3)', [
      P.polygon([[84, 30], [84, 170], [224, 170], [224, 30]], INK, FILL_BLUE),
      P.line(84, 30, 134, 108, BLUE),
      P.line(84, 170, 134, 108, RED),
      P.line(224, 170, 134, 108, GREEN),
      P.line(84, 170, 146, 120, AMBER, true),
      P.line(224, 170, 268, 120, RED, true),
      P.line(134, 108, 268, 120, PURPLE, true),
      P.point(134, 108, '', RED),
      P.point(268, 120, '', PURPLE),
      P.text(68, 18, 'A', INK),
      P.text(68, 174, 'B', INK),
      P.text(226, 174, 'C', INK),
      P.text(226, 18, 'D', INK),
      P.text(136, 92, 'P', RED),
      P.text(272, 114, "P'", PURPLE),
      P.text(94, 62, '1', BLUE),
      P.text(98, 134, '2', RED),
      P.text(174, 144, '3', GREEN),
    ]),

  // c23-g3-q5: 正方形内点 P，PA=2, PB=4, PC=6
  'c23-g3-q5': () =>
    spec('正方形内点旋转 (PA=2, PB=4, PC=6)', [
      P.polygon([[88, 30], [88, 170], [228, 170], [228, 30]], INK, FILL_BLUE),
      P.line(88, 30, 140, 104, BLUE),
      P.line(88, 170, 140, 104, RED),
      P.line(228, 170, 140, 104, GREEN),
      P.point(140, 104, '', RED),
      P.text(72, 18, 'A', INK),
      P.text(72, 174, 'B', INK),
      P.text(232, 174, 'C', INK),
      P.text(232, 18, 'D', INK),
      P.text(146, 94, 'P', RED),
      P.text(102, 58, '2', BLUE),
      P.text(100, 134, '4', RED),
      P.text(182, 144, '6', GREEN),
    ]),

  // c24-g1-q1: AB 是 ⊙O 直径，C 在圆上，∠ABC = 28°，求 ∠BAC
  'c24-g1-q1': () =>
    spec('直径所对圆周角示意图', [
      P.circle(160, 108, 74, INK, FILL_BLUE),
      P.line(86, 108, 234, 108, INK),
      P.line(86, 108, 126, 42, BLUE),
      P.line(234, 108, 126, 42, BLUE),
      P.rightAngle(126, 42, 86, 108, 234, 108, 11, RED),
      P.point(160, 108, 'O', INK),
      P.point(86, 108, '', INK),
      P.point(234, 108, '', INK),
      P.point(126, 42, '', BLUE),
      P.text(68, 104, 'A', INK),
      P.text(240, 104, 'B', INK),
      P.text(118, 22, 'C', BLUE),
      P.text(192, 90, '28°', RED),
    ]),

  // c24-g2-q4: AB 是直径，C 在圆上，过 C 作切线交 AB 延长线于 D，∠CAB = 25°
  'c24-g2-q4': () =>
    spec('圆的切线与圆心角模型', [
      P.circle(124, 112, 66, INK, FILL_BLUE),
      P.line(58, 112, 286, 112, INK),
      P.line(124, 112, 166, 61, MUTED, true),
      P.line(58, 112, 166, 61, BLUE),
      P.line(166, 61, 260, 112, RED),
      P.rightAngle(166, 61, 124, 112, 260, 112, 10, RED),
      P.point(124, 112, 'O', INK),
      P.point(58, 112, '', INK),
      P.point(190, 112, '', INK),
      P.point(166, 61, '', RED),
      P.point(260, 112, '', RED),
      P.text(42, 108, 'A', INK),
      P.text(186, 118, 'B', INK),
      P.text(164, 42, 'C', RED),
      P.text(262, 118, 'D', RED),
      P.text(84, 96, '25°', BLUE),
    ]),

  // c24-g3-q5: △ABC 中 AB=AC，以 AB 为直径的 ⊙O 交 BC 于 D，DE ⊥ AC
  'c24-g3-q5': () =>
    spec('等腰三角形与圆切线证明图', [
      P.circle(118, 96, 58, INK, FILL_BLUE),
      P.polygon([[152, 48], [84, 144], [220, 144]], INK),
      P.line(152, 48, 152, 144, MUTED, true),
      P.line(118, 96, 152, 144, BLUE, true),
      P.line(152, 144, 198, 112, RED),
      P.rightAngle(198, 112, 152, 144, 152, 48, 9, RED),
      P.point(118, 96, 'O', INK),
      P.point(152, 48, '', INK),
      P.point(84, 144, '', INK),
      P.point(220, 144, '', INK),
      P.point(152, 144, '', BLUE),
      P.point(198, 112, '', RED),
      P.text(148, 28, 'A', INK),
      P.text(68, 148, 'B', INK),
      P.text(224, 148, 'C', INK),
      P.text(148, 152, 'D', BLUE),
      P.text(204, 104, 'E', RED),
    ]),

  // c25-g3-q1: 4x4 网格大正方形与内切圆几何概型
  'c25-g3-q1': () => {
    const x0 = 92;
    const y0 = 32;
    const step = 36;
    const prims = [P.polygon([[x0, y0], [x0 + 4 * step, y0], [x0 + 4 * step, y0 + 4 * step], [x0, y0 + 4 * step]], INK)];
    for (let i = 1; i < 4; i++) {
      prims.push(P.line(x0 + i * step, y0, x0 + i * step, y0 + 4 * step, MUTED, true));
      prims.push(P.line(x0, y0 + i * step, x0 + 4 * step, y0 + i * step, MUTED, true));
    }
    prims.push(P.circle(x0 + 2 * step, y0 + 2 * step, 2 * step, RED, FILL_BLUE));
    prims.push(P.point(x0 + 2 * step, y0 + 2 * step, 'O', RED));
    prims.push(P.text(246, 98, 'r = 2', RED));
    return spec('4×4 网格与内切圆几何概型', prims);
  },

  // c26-g2-q4: 一次函数与反比例函数交于 A(-2,1), B(1,n)
  'c26-g2-q4': () => {
    const ox = 160;
    const oy = 108;
    const sx = 34;
    const sy = 28;
    const p = (x, y) => [ox + x * sx, oy - y * sy];
    const b1 = sampleCurve((x) => -2 / x, -3.4, -0.65, 28, p);
    const b2 = sampleCurve((x) => -2 / x, 0.65, 3.4, 28, p);
    return spec('一次函数与反比例函数交点图', [
      ...axesPrimitives(ox, oy, 26, 294, 16, 196),
      P.polyline(b1, BLUE),
      P.polyline(b2, BLUE),
      P.line(...p(-3.2, 2.2), ...p(2.2, -3.2), RED),
      P.point(...p(-2, 1), 'A(-2,1)', RED),
      P.point(...p(1, -2), 'B(1,n)', RED),
    ]);
  },

  // c26-g3-q1: A、B 在 y=6/x (x>0) 上，AC⊥x 于 C，BD⊥x 于 D，OC=CD，梯形 ABDC
  'c26-g3-q1': () => {
    const ox = 54;
    const oy = 176;
    const sx = 46;
    const sy = 22;
    const p = (x, y) => [ox + x * sx, oy - y * sy];
    const curve = sampleCurve((x) => 6 / x, 0.9, 4.8, 36, p);
    return spec('反比例函数与梯形 ABDC', [
      ...axesPrimitives(ox, oy, 26, 294, 18, 196),
      P.polygon([p(1.5, 4), p(3, 2), p(3, 0), p(1.5, 0)], RED, FILL_AMBER),
      P.polyline(curve, BLUE),
      P.point(...p(1.5, 4), 'A', RED),
      P.point(...p(3, 2), 'B', RED),
      P.point(...p(1.5, 0), '', INK),
      P.point(...p(3, 0), '', INK),
      P.text(ox + 1.5 * sx - 4, oy + 6, 'C', INK),
      P.text(ox + 3 * sx - 4, oy + 6, 'D', INK),
      P.text(226, 46, 'y = 6/x', BLUE),
    ]);
  },

  // c26-g3-q5: y = (1/2)x 与 y = k/x 交于 A(4, a)，第一象限取 B(2, b)，△OAB
  'c26-g3-q5': () => {
    const ox = 52;
    const oy = 176;
    const sx = 42;
    const sy = 28;
    const p = (x, y) => [ox + x * sx, oy - y * sy];
    const curve = sampleCurve((x) => 8 / x, 1.5, 5.4, 32, p);
    return spec('正比例函数与反比例函数综合', [
      ...axesPrimitives(ox, oy, 24, 294, 16, 196),
      P.polygon([p(0, 0), p(4, 2), p(2, 4)], GREEN, FILL_GREEN),
      P.line(...p(0, 0), ...p(5.2, 2.6), RED),
      P.polyline(curve, BLUE),
      P.point(...p(4, 2), 'A(4,a)', RED),
      P.point(...p(2, 4), 'B(2,b)', GREEN),
    ]);
  },

  // c27-g1-q2: X字型/8字型相似：AB ∥ CD，AC 与 BD 交于 O，AO=3, OC=6
  'c27-g1-q2': () =>
    spec('“8字型”相似模型 (AB ∥ CD)', [
      P.line(74, 46, 206, 46, BLUE),
      P.line(58, 166, 266, 166, BLUE),
      P.line(74, 46, 266, 166, INK),
      P.line(206, 46, 58, 166, INK),
      P.point(144, 90, 'O', RED),
      P.text(58, 34, 'A', INK),
      P.text(210, 34, 'B', INK),
      P.text(268, 168, 'C', INK),
      P.text(42, 168, 'D', INK),
      P.text(98, 72, '3', BLUE),
      P.text(204, 134, '6', BLUE),
    ]),

  // c27-g2-q4: Rt△ABC，∠ACB = 90°，CD ⊥ AB 于 D，AD = 9, BD = 4
  'c27-g2-q4': () =>
    spec('射影定理（子母型相似）', [
      P.polygon([[42, 166], [278, 166], [202, 46]], INK, FILL_BLUE),
      P.line(202, 46, 202, 166, RED),
      P.rightAngle(202, 46, 42, 166, 278, 166, 11, BLUE),
      P.rightAngle(202, 166, 202, 46, 42, 166, 11, RED),
      P.point(42, 166, '', INK),
      P.point(278, 166, '', INK),
      P.point(202, 46, '', INK),
      P.point(202, 166, '', RED),
      P.text(26, 168, 'A', INK),
      P.text(282, 168, 'B', INK),
      P.text(196, 26, 'C', INK),
      P.text(196, 174, 'D', RED),
      P.text(114, 174, 'AD = 9', BLUE),
      P.text(230, 174, 'BD = 4', BLUE),
    ]),

  // c27-g3-q1: 位似变换 △OAB 缩小 1/2 得 △OA'B'
  'c27-g3-q1': () => {
    const ox = 72;
    const oy = 168;
    const sx = 34;
    const sy = 20;
    const p = (x, y) => [ox + x * sx, oy - y * sy];
    return spec('位似变换示意图（相似比 1:2）', [
      ...axesPrimitives(ox, oy, 26, 294, 18, 194),
      P.polygon([p(0, 0), p(4, 6), p(5, 1)], BLUE, FILL_BLUE),
      P.polygon([p(0, 0), p(2, 3), p(2.5, 0.5)], RED, FILL_AMBER),
      P.point(...p(4, 6), 'A(4,6)', BLUE),
      P.point(...p(2, 3), "A'", RED),
      P.point(...p(5, 1), 'B', BLUE),
      P.point(...p(2.5, 0.5), "B'", RED),
    ]);
  },

  // c27-g3-q5: 矩形 ABCD，AB=6, BC=8, E 是 BC 中点，F 在 CD 上，EF ⊥ AE
  'c27-g3-q5': () =>
    spec('矩形中的相似三角形 (一线三垂直)', [
      P.polygon([[68, 42], [68, 164], [248, 164], [248, 42]], INK, FILL_BLUE),
      P.line(68, 42, 158, 164, BLUE),
      P.line(158, 164, 248, 96, RED),
      P.rightAngle(158, 164, 68, 42, 248, 96, 10, RED),
      P.point(158, 164, '', RED),
      P.point(248, 96, '', RED),
      P.text(52, 34, 'A', INK),
      P.text(52, 166, 'B', INK),
      P.text(252, 166, 'C', INK),
      P.text(252, 34, 'D', INK),
      P.text(154, 172, 'E(中点)', RED),
      P.text(254, 90, 'F', RED),
      P.text(46, 98, '6', BLUE),
      P.text(148, 24, 'BC = 8', MUTED),
    ]),

  // c28-g3-q5: 测信号塔 AB 高度，C 处仰角 30°，前进 20m 到 D 处仰角 60°
  'c28-g3-q5': () =>
    spec('双仰角测信号塔高度示意图', [
      P.line(74, 34, 74, 172, BLUE),
      P.line(48, 172, 286, 172, INK),
      P.line(74, 34, 154, 172, RED),
      P.line(74, 34, 268, 172, GREEN),
      P.rightAngle(74, 172, 74, 34, 286, 172, 11, BLUE),
      P.arc(154, 172, 24, -180, 60, RED),
      P.arc(268, 172, 30, -180, 30, GREEN),
      P.point(74, 34, '', BLUE),
      P.point(74, 172, '', INK),
      P.point(154, 172, '', RED),
      P.point(268, 172, '', GREEN),
      P.text(68, 14, 'A(塔顶)', BLUE),
      P.text(68, 178, 'B', INK),
      P.text(150, 178, 'D', RED),
      P.text(264, 178, 'C', GREEN),
      P.text(118, 152, '60°', RED),
      P.text(216, 154, '30°', GREEN),
      P.text(196, 180, '20m', AMBER),
    ]),

  // c29-g3-q5: 圆锥三视图（主视图、左视图等腰三角形底4高6，俯视图直径4圆含圆心）
  'c29-g3-q5': () =>
    spec('几何体三视图（单位：cm）', [
      // 主视图
      P.polygon([[76, 30], [44, 112], [108, 112]], INK, FILL_BLUE),
      P.line(76, 30, 76, 112, MUTED, true),
      P.text(56, 118, '主视图', MUTED),
      P.text(80, 66, '6', BLUE),
      P.text(72, 100, '4', BLUE),
      // 左视图
      P.polygon([[220, 30], [188, 112], [252, 112]], INK, FILL_BLUE),
      P.line(220, 30, 220, 112, MUTED, true),
      P.text(200, 118, '左视图', MUTED),
      // 俯视图
      P.circle(76, 164, 30, INK, FILL_GREEN),
      P.point(76, 164, '', RED),
      P.text(114, 158, '俯视图 (d=4)', MUTED),
    ]),

  // c37-g3-q5: 直三棱柱 ABC-A₁B₁C₁，AA₁ ⊥ 底面，∠ACB = 90°
  'c37-g3-q5': () =>
    spec('直三棱柱 ABC-A₁B₁C₁', [
      // 顶面 A1B1C1
      P.polygon([[84, 52], [218, 66], [168, 28]], INK, FILL_BLUE),
      // 底面可见边与隐藏边
      P.line(84, 162, 218, 176, INK),
      P.line(84, 162, 168, 138, MUTED, true),
      P.line(218, 176, 168, 138, MUTED, true),
      // 侧棱
      P.line(84, 52, 84, 162, INK),
      P.line(218, 66, 218, 176, INK),
      P.line(168, 28, 168, 138, MUTED, true),
      // 截面 A1BC
      P.line(84, 52, 218, 176, RED, true),
      P.line(84, 52, 168, 138, RED, true),
      P.text(64, 42, 'A₁', INK),
      P.text(224, 56, 'B₁', INK),
      P.text(170, 12, 'C₁', INK),
      P.text(66, 164, 'A', INK),
      P.text(224, 172, 'B', INK),
      P.text(174, 132, 'C', MUTED),
    ]),

  // c40-g2-q4: 正方体 ABCD-A₁B₁C₁D₁，E 为 DD₁ 中点，BD₁ 与 CE
  'c40-g2-q4': () =>
    spec('正方体 ABCD-A₁B₁C₁D₁', [
      // 前面 ABB1A1
      P.polygon([[76, 72], [186, 72], [186, 174], [76, 174]], INK),
      // 顶面 A1B1C1D1
      P.line(76, 72, 126, 36, INK),
      P.line(186, 72, 236, 36, INK),
      P.line(126, 36, 236, 36, INK),
      // 右面
      P.line(236, 36, 236, 138, INK),
      P.line(186, 174, 236, 138, INK),
      // 隐藏棱
      P.line(126, 36, 126, 138, MUTED, true),
      P.line(76, 174, 126, 138, MUTED, true),
      P.line(126, 138, 236, 138, MUTED, true),
      // BD1 与 CE
      P.line(186, 174, 126, 36, BLUE, true),
      P.line(236, 138, 126, 87, RED, true),
      P.point(126, 87, 'E', RED),
      P.text(60, 174, 'A', INK),
      P.text(190, 176, 'B', INK),
      P.text(242, 136, 'C', INK),
      P.text(112, 134, 'D', MUTED),
      P.text(56, 62, 'A₁', INK),
      P.text(190, 66, 'B₁', INK),
      P.text(240, 26, 'C₁', INK),
      P.text(114, 18, 'D₁', INK),
    ]),

  // c40-g3-q5: 四棱锥 P-ABCD，PA ⊥ 底面，底面为直角梯形 AD ∥ BC，∠ABC = 90°
  'c40-g3-q5': () =>
    spec('四棱锥 P-ABCD (PA ⊥ 底面)', [
      P.line(106, 30, 106, 146, BLUE),
      P.line(106, 146, 62, 182, INK),
      P.line(62, 182, 232, 182, INK),
      P.line(232, 182, 198, 146, INK),
      P.line(106, 146, 198, 146, MUTED, true),
      P.line(106, 30, 62, 182, INK),
      P.line(106, 30, 232, 182, INK),
      P.line(106, 30, 198, 146, RED),
      P.rightAngle(106, 146, 106, 30, 198, 146, 10, BLUE),
      P.point(106, 30, '', BLUE),
      P.text(98, 12, 'P', BLUE),
      P.text(90, 142, 'A', INK),
      P.text(46, 182, 'B', INK),
      P.text(236, 182, 'C', INK),
      P.text(204, 140, 'D', INK),
    ]),

  // ==========================================================================
  // 1.2 二次全库审计补齐的 65 道场景/几何/图像/统计/导数/概率 1:1 精绘配图 (TASK-20261126-002)
  // ==========================================================================

  // c2-g3-q3: 火柴棒摆图形规律
  'c2-g3-q3': () =>
    spec('火柴棒摆图形规律示意', [
      // 图1（1个基本单元）
      P.polygon([[34, 62], [74, 62], [74, 102], [34, 102]], BLUE),
      P.text(38, 114, '图1 ({{m}}根)', BLUE),
      // 图2（2个单元）
      P.polygon([[112, 62], [152, 62], [152, 102], [112, 102]], BLUE),
      P.line(152, 62, 192, 62, RED),
      P.line(192, 62, 192, 102, RED),
      P.line(152, 102, 192, 102, RED),
      P.text(122, 114, '图2 (+{{k}}根)', RED),
      // 省略号与第10个
      P.text(218, 76, '···', MUTED),
      P.text(248, 74, '第10个', INK),
      P.text(252, 94, '? 根', RED),
      P.text(36, 152, '每增加 1 个基本单元，多用 {{k}} 根火柴棒', MUTED),
    ]),

  // c3-g1-q4: 相向相遇行程图
  'c3-g1-q4': () =>
    spec('相向而行相遇行程示意图', [
      P.line(36, 124, 284, 124, INK),
      P.line(36, 112, 36, 136, INK),
      P.line(284, 112, 284, 136, INK),
      P.arrow(48, 96, 152, 96, BLUE),
      P.arrow(272, 96, 200, 96, GREEN),
      P.point(180, 124, '相遇', RED),
      P.text(26, 142, '甲地', BLUE),
      P.text(268, 142, '乙地', GREEN),
      P.text(56, 74, '甲 4 km/h', BLUE),
      P.text(204, 74, '乙 2 km/h', GREEN),
      P.text(114, 154, '总距离 = {{6 * t}} 千米', RED),
    ]),

  // c3-g3-q4: 时针分针旋转速度示意图
  'c3-g3-q4': () =>
    spec('钟表时针与分针旋转示意', [
      P.circle(160, 106, 72, INK, FILL_BLUE),
      P.line(160, 34, 160, 44, INK),
      P.line(232, 106, 222, 106, INK),
      P.line(160, 178, 160, 168, INK),
      P.line(88, 106, 98, 106, INK),
      P.arrow(160, 106, 160, 48, RED),
      P.arrow(160, 106, 204, 106, BLUE),
      P.arc(160, 106, 44, -90, 62, RED, null, true),
      P.point(160, 106, '', INK),
      P.text(152, 18, '12', INK),
      P.text(238, 100, '3', INK),
      P.text(156, 184, '6', INK),
      P.text(72, 100, '9', INK),
      P.text(16, 26, '分针 6°/分', RED),
      P.text(16, 46, '时针 0.5°/分', BLUE),
      P.text(216, 26, 't={{t}}×10分', MUTED),
    ]),

  // c3-g3-q5: 火车过桥与过电线杆示意图
  'c3-g3-q5': () =>
    spec('火车过桥与过电线杆模型', [
      // 桥梁
      P.line(24, 114, 296, 114, INK),
      P.polygon([[94, 114], [244, 114], [244, 126], [94, 126]], BLUE, FILL_BLUE),
      P.text(136, 134, '桥长 300 m', BLUE),
      // 火车（入桥前与完全出桥）
      P.polygon([[34, 92], [94, 92], [94, 112], [34, 112]], RED, FILL_AMBER),
      P.polygon([[244, 92], [296, 92], [296, 112], [244, 112]], RED, null, true),
      P.arrow(98, 80, 240, 80, RED),
      P.text(46, 96, '车长 L', RED),
      P.text(122, 58, '完全过桥 20s（路程 300+L）', RED),
      // 电线杆
      P.line(74, 152, 74, 186, GREEN),
      P.text(84, 166, '过电线杆 5s（路程 = 车长 L）', GREEN),
    ]),

  // c4-g2-q2: 直线 l 上四点 A, B, C, D
  'c4-g2-q2': () =>
    spec('直线 l 上的四个点 A、B、C、D', [
      P.line(26, 108, 294, 108, INK),
      P.point(68, 108, '', BLUE),
      P.point(130, 108, '', BLUE),
      P.point(192, 108, '', BLUE),
      P.point(254, 108, '', BLUE),
      P.text(63, 122, 'A', INK),
      P.text(125, 122, 'B', INK),
      P.text(187, 122, 'C', INK),
      P.text(249, 122, 'D', INK),
      P.text(282, 88, 'l', MUTED),
      P.arc(99, 108, 31, -180, 180, BLUE, null, true),
      P.arc(161, 108, 31, -180, 180, RED, null, true),
      P.arc(223, 108, 31, -180, 180, GREEN, null, true),
    ]),

  // c4-g2-q3: 平角双角平分线（严禁标 90° 泄密！）
  'c4-g2-q3': () =>
    spec('平角与双角平分线模型', [
      P.line(30, 164, 290, 164, INK),
      P.arrow(160, 164, 114, 42, INK),
      P.arrow(160, 164, 70, 96, BLUE, true),
      P.arrow(160, 164, 232, 72, RED, true),
      P.arc(160, 164, 42, -142, 90, AMBER),
      P.point(160, 164, '', INK),
      P.text(24, 170, 'A', INK),
      P.text(154, 172, 'O', INK),
      P.text(286, 170, 'B', INK),
      P.text(104, 24, 'C', INK),
      P.text(44, 82, 'D(平分∠AOC)', BLUE),
      P.text(230, 56, 'E(平分∠BOC)', RED),
      P.text(146, 102, '∠DOE = ?', AMBER),
      P.text(32, 34, '∠AOC = {{a}}°', MUTED),
    ]),

  // c4-g3-q1: 从 O 点引出 n 条射线
  'c4-g3-q1': () =>
    spec('同端点 O 引出多条射线示意图', [
      P.arrow(52, 164, 276, 164, INK),
      P.arrow(52, 164, 266, 120, BLUE),
      P.arrow(52, 164, 242, 74, GREEN),
      P.arrow(52, 164, 198, 40, AMBER),
      P.arrow(52, 164, 134, 26, RED),
      P.point(52, 164, '', INK),
      P.text(36, 166, 'O', INK),
      P.text(204, 180, '共引出 n 条射线', MUTED),
      P.text(136, 128, '···', MUTED),
    ]),

  // c4-g3-q2: 钟表 8 点 30 分时针与分针夹角
  'c4-g3-q2': () => {
    const cx = 160;
    const cy = 108;
    const r = 74;
    // 8:30: 分针指向 6 (90°), 时针指向 8.5 (165°)
    const minRad = (90 * Math.PI) / 180;
    const hrRad = (165 * Math.PI) / 180;
    return spec('钟表 8:30 时针与分针夹角', [
      P.circle(cx, cy, r, INK, FILL_BLUE),
      P.line(cx, cy - r, cx, cy - r + 8, INK),
      P.line(cx + r, cy, cx + r - 8, cy, INK),
      P.line(cx, cy + r, cx, cy + r - 8, INK),
      P.line(cx - r, cy, cx - r + 8, cy, INK),
      // 8 点刻度 (150°)
      P.line(cx + (r - 7) * Math.cos((150 * Math.PI) / 180), cy + (r - 7) * Math.sin((150 * Math.PI) / 180), cx + r * Math.cos((150 * Math.PI) / 180), cy + r * Math.sin((150 * Math.PI) / 180), MUTED),
      P.arc(cx, cy, 34, 90, 75, AMBER, FILL_AMBER),
      P.arrow(cx, cy, cx + 58 * Math.cos(minRad), cy + 58 * Math.sin(minRad), RED),
      P.arrow(cx, cy, cx + 42 * Math.cos(hrRad), cy + 42 * Math.sin(hrRad), BLUE),
      P.point(cx, cy, '', INK),
      P.text(152, 16, '12', INK),
      P.text(240, 102, '3', INK),
      P.text(156, 186, '6', INK),
      P.text(70, 102, '9', INK),
      P.text(78, 142, '8', MUTED),
      P.text(114, 134, '?', RED),
    ]);
  },

  // c4-g3-q4: 长方形纸片一角沿折痕向内折叠
  'c4-g3-q4': () =>
    spec('长方形纸片折角重叠示意图', [
      P.polygon([[48, 36], [272, 36], [272, 166], [48, 166]], INK, FILL_BLUE),
      // 原角虚线
      P.line(186, 166, 272, 166, MUTED, true),
      P.line(272, 166, 272, 92, MUTED, true),
      // 折痕与折叠后三角形
      P.line(186, 166, 272, 92, RED),
      P.polygon([[186, 166], [272, 92], [198, 86]], BLUE, FILL_AMBER),
      P.arc(186, 166, 30, -40, 40, RED),
      P.arc(186, 166, 36, -80, 40, BLUE),
      P.text(218, 146, '{{k}}°', RED),
      P.text(192, 118, '{{k}}°', BLUE),
      P.text(124, 148, '剩余 = ?', GREEN),
    ]),

  // c5-g1-q3: △ABC 沿 BC 方向平移得到 △DEF
  'c5-g1-q3': () =>
    spec('三角形沿 BC 方向平移示意', [
      P.polygon([[106, 40], [42, 162], [164, 162]], INK, FILL_BLUE),
      P.polygon([[198, 40], [134, 162], [256, 162]], BLUE, FILL_GREEN),
      P.arrow(106, 40, 198, 40, RED, true),
      P.text(94, 20, 'A({{a}}°)', INK),
      P.text(22, 168, 'B(55°)', INK),
      P.text(162, 168, 'C', INK),
      P.text(196, 20, 'D', BLUE),
      P.text(124, 168, 'E', BLUE),
      P.text(254, 168, 'F(?)', RED),
      P.text(132, 24, '平移 4cm', RED),
    ]),

  // c5-g3-q4: 长方形草坪与垂直弯曲小路
  'c5-g3-q4': () =>
    spec('草坪弯曲小路平移拼接模型', [
      P.polygon([[48, 42], [272, 42], [272, 164], [48, 164]], GREEN, FILL_GREEN),
      // 弯曲小路
      P.polygon(
        [
          [144, 42],
          [166, 42],
          [184, 84],
          [156, 126],
          [176, 164],
          [154, 164],
          [134, 126],
          [162, 84],
        ],
        AMBER,
        FILL_AMBER,
      ),
      P.text(136, 22, '长 {{w}} 米', INK),
      P.text(14, 98, '宽 {{h}} 米', INK),
      P.text(142, 174, '路宽 {{s}} 米', RED),
    ]),

  // c8-g3-q4: 400m 环形跑道反向相遇
  'c8-g3-q4': () =>
    spec('400 米环形跑道反向相遇', [
      P.circle(160, 108, 66, INK, FILL_BLUE),
      P.circle(160, 108, 48, MUTED, null, true),
      P.point(160, 42, '起点', RED),
      P.arrow(146, 36, 114, 48, BLUE),
      P.arrow(174, 36, 206, 48, GREEN),
      P.text(62, 44, '甲', BLUE),
      P.text(244, 44, '乙', GREEN),
      P.text(118, 102, '全长 400 米', INK),
      P.text(106, 182, '每 {{k}} 分钟相遇一次', RED),
    ]),

  // c10-g3-q5: 七年级垃圾分类成绩频数直方图
  'c10-g3-q5': () => {
    const ox = 46;
    const oy = 168;
    const bars = [
      { label: '60~70', val: 6, h: 32, color: BLUE, fill: FILL_BLUE, text: '6' },
      { label: '70~80', val: 14, h: 74, color: BLUE, fill: FILL_BLUE, text: '14' },
      { label: '80~90', val: 18, h: 92, color: RED, fill: FILL_AMBER, text: 'a = ?', dashed: true },
      { label: '90~100', val: 12, h: 64, color: GREEN, fill: FILL_GREEN, text: '12' },
    ];
    const prims = [
      P.arrow(ox, oy, 294, oy, INK),
      P.arrow(ox, oy, ox, 22, INK),
      P.text(22, 20, '人数', MUTED),
      P.text(268, 174, '分数', MUTED),
    ];
    bars.forEach((b, i) => {
      const x1 = ox + 22 + i * 54;
      const x2 = x1 + 42;
      const y1 = oy - b.h;
      prims.push(P.polygon([[x1, oy], [x1, y1], [x2, y1], [x2, oy]], b.color, b.fill, !!b.dashed));
      prims.push(P.text(x1 + 8, y1 - 16, b.text, b.color));
      prims.push(P.text(x1 + 2, oy + 6, b.label, MUTED));
    });
    return spec('成绩频数分布直方图（总 50 人）', prims);
  },

  // c11-g3-q4: 凸 n 边形对角线
  'c11-g3-q4': () =>
    spec('凸 {{n}} 边形对角线示意', [
      P.polygon(
        [
          [160, 26],
          [232, 56],
          [250, 128],
          [202, 180],
          [118, 180],
          [70, 128],
          [88, 56],
        ],
        INK,
        FILL_BLUE,
      ),
      P.line(160, 26, 250, 128, RED, true),
      P.line(160, 26, 202, 180, RED, true),
      P.line(160, 26, 118, 180, RED, true),
      P.line(160, 26, 70, 128, RED, true),
      P.point(160, 26, 'A₁', RED),
      P.text(104, 190, '凸 {{n}} 边形对角线总数 = ?', BLUE),
    ]),

  // c12-g2-q2: 角尺平分任意角 ∠AOB
  'c12-g2-q2': () =>
    spec('工人用角尺平分 ∠AOB', [
      P.arrow(48, 166, 280, 166, INK),
      P.arrow(48, 166, 224, 34, INK),
      P.arrow(48, 166, 264, 96, RED, true),
      P.line(146, 92, 192, 119, BLUE),
      P.line(170, 166, 192, 119, BLUE),
      P.point(48, 166, '', INK),
      P.point(146, 92, 'M', BLUE),
      P.point(170, 166, 'N', BLUE),
      P.point(192, 119, 'C', RED),
      P.text(32, 168, 'O', INK),
      P.text(228, 22, 'A', INK),
      P.text(282, 168, 'B', INK),
      P.text(20, 24, 'OM = ON, CM = CN', MUTED),
    ]),

  // c12-g2-q4: A, E, F, C 共线，DE⊥AC，BF⊥AC，BD 交 EF 于 G
  'c12-g2-q4': () =>
    spec('共线垂直全等证明图', [
      P.line(32, 108, 288, 108, INK),
      P.line(124, 108, 124, 36, BLUE),
      P.line(196, 108, 196, 180, BLUE),
      P.line(54, 108, 196, 180, INK),
      P.line(266, 108, 124, 36, INK),
      P.line(124, 36, 196, 180, RED),
      P.rightAngle(124, 108, 124, 36, 288, 108, 9, BLUE),
      P.rightAngle(196, 108, 196, 180, 32, 108, 9, BLUE),
      P.point(54, 108, '', INK),
      P.point(124, 108, '', BLUE),
      P.point(160, 108, '', RED),
      P.point(196, 108, '', BLUE),
      P.point(266, 108, '', INK),
      P.text(44, 116, 'A', INK),
      P.text(110, 116, 'E', BLUE),
      P.text(164, 92, 'G', RED),
      P.text(200, 92, 'F', BLUE),
      P.text(264, 116, 'C', INK),
      P.text(118, 18, 'D', BLUE),
      P.text(192, 184, 'B', BLUE),
    ]),

  // c13-g3-q1: 坐标系将军饮马 A(1,2), B(4,3), P 在 x 轴
  'c13-g3-q1': () => {
    const ox = 54;
    const oy = 148;
    const sx = 46;
    const sy = 26;
    const p = (x, y) => [ox + x * sx, oy - y * sy];
    return spec('坐标系“将军饮马”最短路径', [
      ...axesPrimitives(ox, oy, 24, 294, 18, 196),
      P.line(...p(1, 2), ...p(2.2, 0), RED),
      P.line(...p(2.2, 0), ...p(4, 3), RED),
      P.line(...p(1, 2), ...p(1, -1.6), MUTED, true),
      P.point(...p(1, 2), 'A(1,2)', BLUE),
      P.point(...p(4, 3), 'B(4,3)', BLUE),
      P.point(...p(2.2, 0), 'P(?,0)', RED),
    ]);
  },

  // c14-g3-q2: △ABC 三边 a, b, c（用不等边示意，不泄密等边答案！）
  'c14-g3-q2': () =>
    spec('△ABC 三边长 a、b、c 示意', [
      P.polygon([[128, 34], [54, 168], [262, 168]], INK, FILL_BLUE),
      P.text(122, 14, 'A', INK),
      P.text(38, 170, 'B', INK),
      P.text(266, 170, 'C', INK),
      P.text(152, 174, 'a', BLUE),
      P.text(204, 90, 'b', BLUE),
      P.text(74, 92, 'c', BLUE),
    ]),

  // c17-g0-q4: 坐标系 A({{a}},0) 与 B(0,{{a}})
  'c17-g0-q4': () => {
    const ox = 72;
    const oy = 166;
    return spec('坐标轴上两点距离 AB', [
      ...axesPrimitives(ox, oy, 30, 286, 20, 194),
      P.polygon([[ox, oy], [202, oy], [ox, 48]], BLUE, FILL_BLUE),
      P.line(202, oy, ox, 48, RED),
      P.rightAngle(ox, oy, ox, 48, 202, oy, 10, INK),
      P.point(202, oy, 'A({{a}},0)', BLUE),
      P.point(ox, 48, 'B(0,{{a}})', BLUE),
      P.text(146, 94, 'AB = ?', RED),
    ]);
  },

  // c17-g2-q4: 《九章算术》折竹抵地（高10尺，去本3尺）
  'c17-g2-q4': () =>
    spec('《九章算术》“折竹抵地”模型', [
      P.line(48, 172, 276, 172, INK),
      // 原直立竹子虚线
      P.line(106, 26, 106, 96, MUTED, true),
      // 折断后剩余高度与斜下竹梢
      P.line(106, 96, 106, 172, GREEN),
      P.line(106, 96, 206, 172, RED),
      P.rightAngle(106, 172, 106, 96, 206, 172, 10, BLUE),
      P.point(106, 96, '折点', RED),
      P.text(68, 128, 'x 尺', GREEN),
      P.text(162, 114, '(10-x) 尺', RED),
      P.text(142, 178, '3 尺', BLUE),
      P.text(114, 44, '原高 10 尺', MUTED),
    ]),

  // c17-g3-q4: 矩形 8×6 按 {{b}} 倍放大对角线
  'c17-g3-q4': () =>
    spec('矩形按 {{b}} 倍缩放对角线示意', [
      P.polygon([[68, 46], [252, 46], [252, 164], [68, 164]], INK, FILL_BLUE),
      P.line(68, 164, 252, 46, RED),
      P.rightAngle(68, 164, 68, 46, 252, 164, 11, BLUE),
      P.text(136, 172, '长 = 8 × {{b}}', BLUE),
      P.text(14, 98, '宽 6×{{b}}', BLUE),
      P.text(146, 86, 'd = ?', RED),
    ]),

  // c18-g0-q3: △ABC 中位线 DE，BC = {{2 * a}}
  'c18-g0-q3': () =>
    spec('△ABC 中位线 DE 示意', [
      P.polygon([[158, 28], [56, 170], [264, 170]], INK, FILL_BLUE),
      P.line(107, 99, 211, 99, RED),
      P.point(107, 99, '', RED),
      P.point(211, 99, '', RED),
      P.text(152, 10, 'A', INK),
      P.text(40, 172, 'B', INK),
      P.text(268, 172, 'C', INK),
      P.text(88, 92, 'D', RED),
      P.text(218, 92, 'E', RED),
      P.text(132, 178, 'BC = {{2 * a}}', BLUE),
    ]),

  // c18-g2-q1: 任意四边形中点四边形
  'c18-g2-q1': () =>
    spec('任意四边形各边中点连线', [
      P.polygon([[94, 30], [258, 52], [234, 174], [52, 148]], INK),
      // 中点: (176,41), (246,113), (143,161), (73,89)
      P.polygon([[176, 41], [246, 113], [143, 161], [73, 89]], RED, FILL_AMBER),
      P.line(94, 30, 234, 174, MUTED, true),
      P.line(258, 52, 52, 148, MUTED, true),
      P.point(176, 41, 'E', RED),
      P.point(246, 113, 'F', RED),
      P.point(143, 161, 'G', RED),
      P.point(73, 89, 'H', RED),
    ]),

  // c19-g3-q5: 甲乙两车追及路程-时间函数图
  'c19-g3-q5': () => {
    const ox = 52;
    const oy = 172;
    const sx = 46; // 1h = 46px (0..5h)
    const sy = 0.44; // 300km = 132px
    const p = (t, y) => [ox + t * sx, oy - y * sy];
    return spec('甲乙两车路程-时间函数示意', [
      P.arrow(30, oy, 294, oy, INK),
      P.arrow(ox, 192, ox, 20, INK),
      P.line(...p(0, 300), ...p(4.8, 300), MUTED, true),
      P.line(...p(0, 0), ...p(4.6, 276), BLUE),
      P.line(...p(1, 0), ...p(4.2, 288), RED),
      P.point(...p(1, 0), '1', RED),
      P.point(...p(3, 180), '追上?', AMBER),
      P.text(58, 16, 'y(km)', MUTED),
      P.text(266, 178, 't(h)', MUTED),
      P.text(14, 36, '300', MUTED),
      P.text(224, 72, '甲(60km/h)', BLUE),
      P.text(176, 44, '乙(90km/h)', RED),
    ]);
  },

  // c21-g3-q3: 等腰三角形两边长 {{a}} 与 {{2*a + 1}}
  'c21-g3-q3': () =>
    spec('等腰三角形边长分类示意', [
      P.polygon([[160, 28], [86, 170], [234, 170]], INK, FILL_BLUE),
      P.text(154, 10, 'A', INK),
      P.text(70, 172, 'B', INK),
      P.text(238, 172, 'C', INK),
      P.text(56, 94, '边长 {{a}} 与 {{2*a + 1}}', BLUE),
      P.text(112, 180, '注意满足两边之和大于第三边', MUTED),
    ]),

  // c22-g2-q3: 一面靠墙矩形菜园
  'c22-g2-q3': () =>
    spec('一面靠墙的矩形菜园示意图', [
      // 墙壁
      P.line(34, 48, 286, 48, INK),
      P.line(48, 38, 60, 48, MUTED),
      P.line(88, 38, 100, 48, MUTED),
      P.line(128, 38, 140, 48, MUTED),
      P.line(168, 38, 180, 48, MUTED),
      P.line(208, 38, 220, 48, MUTED),
      P.line(248, 38, 260, 48, MUTED),
      P.text(136, 20, '墙（足够长）', MUTED),
      // 三面篱笆
      P.polygon([[76, 48], [244, 48], [244, 152], [76, 152]], GREEN, FILL_GREEN),
      P.line(76, 48, 76, 152, RED),
      P.line(76, 152, 244, 152, RED),
      P.line(244, 152, 244, 48, RED),
      P.text(48, 96, 'x', RED),
      P.text(252, 96, 'x', RED),
      P.text(116, 162, '篱笆总长 = {{2*a}} 米', RED),
    ]),

  // c25-g2-q2: 6等分数字转盘 (1~6)
  'c25-g2-q2': () => {
    const cx = 160;
    const cy = 108;
    const r = 72;
    const prims = [P.circle(cx, cy, r, INK, FILL_BLUE)];
    for (let i = 0; i < 6; i++) {
      const a = (i * 60 - 90) * (Math.PI / 180);
      prims.push(P.line(cx, cy, cx + r * Math.cos(a), cy + r * Math.sin(a), INK));
      const ma = (i * 60 - 60) * (Math.PI / 180);
      prims.push(P.text(cx + 46 * Math.cos(ma) - 4, cy + 46 * Math.sin(ma) - 7, String(i + 1), i % 2 === 0 ? BLUE : RED));
    }
    prims.push(P.arrow(cx, cy, cx + 38, cy - 22, RED));
    prims.push(P.point(cx, cy, '', INK));
    return spec('六等分数字转盘（1~6）', prims);
  },

  // c25-g2-q3: 90° 阴影圆形转盘
  'c25-g2-q3': () =>
    spec('圆形转盘（阴影圆心角 90°）', [
      P.circle(160, 108, 70, INK),
      P.arc(160, 108, 70, -90, 90, RED, FILL_AMBER),
      P.line(160, 108, 160, 38, INK),
      P.line(160, 108, 230, 108, INK),
      P.rightAngle(160, 108, 160, 38, 230, 108, 11, RED),
      P.point(160, 108, '', INK),
      P.text(176, 70, '90°阴影', RED),
      P.text(98, 132, '白色区域', MUTED),
    ]),

  // c25-g2-q4: 不放回摸球树状图骨架（不泄密最终概率）
  'c25-g2-q4': () =>
    spec('不放回摸球树状图模型（1~4）', [
      P.point(40, 106, '开始', INK),
      P.line(40, 106, 126, 42, BLUE),
      P.line(40, 106, 126, 84, BLUE),
      P.line(40, 106, 126, 128, BLUE),
      P.line(40, 106, 126, 170, BLUE),
      P.point(126, 42, '甲:1', BLUE),
      P.point(126, 84, '甲:2', BLUE),
      P.point(126, 128, '甲:3', BLUE),
      P.point(126, 170, '甲:4', BLUE),
      // 第一支展开示意
      P.line(126, 42, 224, 24, GREEN),
      P.line(126, 42, 224, 42, GREEN),
      P.line(126, 42, 224, 60, GREEN),
      P.text(230, 18, '乙:2', GREEN),
      P.text(230, 36, '乙:3', GREEN),
      P.text(230, 54, '乙:4', GREEN),
      P.text(192, 118, '其余分支同理（不放回）', MUTED),
    ]),

  // c25-g3-q2: 反比例函数 y = 2/x 与格点
  'c25-g3-q2': () => {
    const ox = 160;
    const oy = 108;
    const s = 34;
    const p = (x, y) => [ox + x * s, oy - y * s];
    const b1 = sampleCurve((x) => 2 / x, 0.7, 3.2, 24, p);
    const b2 = sampleCurve((x) => 2 / x, -3.2, -0.7, 24, p);
    return spec('反比例函数 y = 2/x 与格点示意', [
      ...axesPrimitives(ox, oy, 28, 292, 16, 196),
      P.polyline(b1, BLUE),
      P.polyline(b2, BLUE),
      P.point(...p(1, 2), '(1,2)', RED),
      P.point(...p(2, 1), '(2,1)', RED),
      P.point(...p(-1, -2), '(-1,-2)', RED),
      P.point(...p(-2, -1), '(-2,-1)', RED),
      P.text(226, 36, 'y = 2/x', BLUE),
    ]);
  },

  // c27-g1-q3: 竹竿影长与教学楼影长平行投影相似模型
  'c27-g1-q3': () =>
    spec('同一时刻竹竿与教学楼影长模型', [
      P.line(24, 170, 296, 170, INK),
      // 竹竿
      P.line(68, 122, 68, 170, GREEN),
      P.line(68, 122, 102, 170, AMBER, true),
      P.rightAngle(68, 170, 68, 122, 102, 170, 8, GREEN),
      P.text(32, 136, '1.5m', GREEN),
      P.text(74, 176, '1m', GREEN),
      // 教学楼
      P.polygon([[166, 46], [190, 46], [190, 170], [166, 170]], BLUE, FILL_BLUE),
      P.line(190, 46, 276, 170, AMBER, true),
      P.rightAngle(190, 170, 190, 46, 276, 170, 10, BLUE),
      P.text(142, 92, 'H=?', RED),
      P.text(204, 176, '影长 {{2*h}}m', BLUE),
      P.text(196, 34, '太阳平行光线', AMBER),
    ]),

  // c27-g2-q2: 线段 AB = 2 黄金分割点 C
  'c27-g2-q2': () =>
    spec('线段 AB 黄金分割点示意 (AC > BC)', [
      P.line(48, 114, 272, 114, INK),
      P.line(48, 114, 186, 114, BLUE),
      P.line(186, 114, 272, 114, RED),
      P.point(48, 114, '', INK),
      P.point(186, 114, '', RED),
      P.point(272, 114, '', INK),
      P.text(42, 126, 'A', INK),
      P.text(182, 126, 'C', RED),
      P.text(266, 126, 'B', INK),
      P.text(102, 90, 'AC = ?', BLUE),
      P.text(218, 90, 'BC', RED),
      P.text(124, 152, 'AB = 2，AC/AB = BC/AC', MUTED),
    ]),

  // c28-g3-q2: 灯塔 P 航海方位角模型（A 北偏东 60°，B 南偏东 30°）
  'c28-g3-q2': () =>
    spec('灯塔 P 方位角航海示意图', [
      // 正北正南方向线
      P.arrow(78, 178, 78, 24, MUTED, true),
      P.text(68, 10, '北', MUTED),
      P.text(68, 184, '南', MUTED),
      // P(78, 116), A(214, 48), B(214, 176)
      P.polygon([[78, 116], [214, 48], [214, 176]], BLUE, FILL_BLUE),
      P.arrow(214, 48, 214, 176, RED),
      P.point(78, 116, '', INK),
      P.point(214, 48, '', BLUE),
      P.point(214, 176, '', RED),
      P.text(56, 110, 'P', INK),
      P.text(220, 42, 'A', BLUE),
      P.text(220, 172, 'B', RED),
      P.text(88, 66, '60°', BLUE),
      P.text(88, 146, '30°', RED),
      P.text(124, 64, '40海里', BLUE),
      P.text(222, 106, '正南', RED),
    ]),

  // c29-g1-q1: 路灯下远离路灯的影子变化
  'c29-g1-q1': () =>
    spec('路灯下中心投影影长变化', [
      P.line(26, 174, 294, 174, INK),
      P.line(62, 34, 62, 174, INK),
      P.circle(62, 34, 6, AMBER, FILL_AMBER),
      // 位置1（近）
      P.line(124, 124, 124, 174, BLUE),
      P.line(62, 34, 152, 174, AMBER, true),
      P.line(124, 174, 152, 174, RED),
      // 位置2（远）
      P.line(206, 124, 206, 174, GREEN),
      P.line(62, 34, 274, 174, AMBER, true),
      P.line(206, 174, 274, 174, RED),
      P.text(72, 26, '路灯', AMBER),
      P.text(114, 108, '位置1', BLUE),
      P.text(196, 108, '位置2', GREEN),
      P.text(128, 180, '影1', RED),
      P.text(228, 180, '影2', RED),
    ]),

  // c29-g2-q4: 路灯测高（人高1.6m，距灯杆4m，影长2m）
  'c29-g2-q4': () =>
    spec('路灯中心投影相似模型', [
      P.line(26, 172, 294, 172, INK),
      P.line(66, 36, 66, 172, BLUE),
      P.circle(66, 36, 6, AMBER, FILL_AMBER),
      P.line(178, 118, 178, 172, GREEN),
      P.line(66, 36, 250, 172, RED, true),
      P.rightAngle(66, 172, 66, 36, 250, 172, 9, BLUE),
      P.rightAngle(178, 172, 178, 118, 250, 172, 8, GREEN),
      P.text(28, 92, 'H = ?', BLUE),
      P.text(148, 134, '1.6m', GREEN),
      P.text(110, 178, '4m', INK),
      P.text(204, 178, '2m', RED),
    ]),

  // c30-g3-q2: 数学/物理竞赛双圆韦恩图
  'c30-g3-q2': () =>
    spec('容斥原理韦恩图（全班 45 人）', [
      P.polygon([[28, 24], [292, 24], [292, 184], [28, 184]], INK),
      P.circle(124, 104, 54, BLUE, FILL_BLUE),
      P.circle(196, 104, 54, GREEN, FILL_GREEN),
      P.text(78, 94, '数学', BLUE),
      P.text(80, 112, '28人', BLUE),
      P.text(204, 94, '物理', GREEN),
      P.text(204, 112, '22人', GREEN),
      P.text(154, 100, '?', RED),
      P.text(178, 162, '都不参加: 5人', MUTED),
      P.text(36, 32, '全集 U (45人)', INK),
    ]),

  // c31-g3-q5: 无盖长方体储水池（容积48m³，深3m）
  'c31-g3-q5': () =>
    spec('无盖长方体储水池示意图', [
      // 前面与侧面
      P.polygon([[72, 86], [202, 86], [202, 166], [72, 166]], INK, FILL_BLUE),
      P.line(72, 86, 116, 48, INK),
      P.line(202, 86, 246, 48, INK),
      P.line(116, 48, 246, 48, BLUE, true),
      P.line(246, 48, 246, 128, INK),
      P.line(202, 166, 246, 128, INK),
      P.line(116, 48, 116, 128, MUTED, true),
      P.line(72, 166, 116, 128, MUTED, true),
      P.line(116, 128, 246, 128, MUTED, true),
      P.text(124, 174, '底长 x m', RED),
      P.text(230, 150, '宽 16/x', BLUE),
      P.text(252, 84, '深 3m', GREEN),
      P.text(136, 24, '无盖（V = 48 m³）', MUTED),
    ]),

  // c33-g3-q2: f(x) = |lg x| 翻折图象
  'c33-g3-q2': () => {
    const ox = 48;
    const oy = 166;
    const sx = 54;
    const sy = 56;
    const p = (x, y) => [ox + x * sx, oy - y * sy];
    const left = sampleCurve((x) => Math.abs(Math.log10(x)), 0.12, 1.0, 26, p);
    const right = sampleCurve((x) => Math.abs(Math.log10(x)), 1.0, 4.4, 26, p);
    return spec('函数 f(x) = |lg x| 翻折图象', [
      ...axesPrimitives(ox, oy, 26, 294, 18, 194),
      P.polyline(left, BLUE),
      P.polyline(right, BLUE),
      P.line(ox, oy - 0.5 * sy, 286, oy - 0.5 * sy, RED, true),
      P.point(...p(1, 0), '1', INK),
      P.point(...p(0.32, 0.5), 'a', RED),
      P.point(...p(3.16, 0.5), 'b', RED),
      P.text(206, 42, 'y = |lg x|', BLUE),
    ]);
  },

  // c34-g0-q3: 弧度制扇形（半径 {{r}}，圆心角 {{theta}} rad）
  'c34-g0-q3': () =>
    spec('弧度制扇形示意图', [
      P.arc(146, 152, 94, -120, 96, BLUE, FILL_AMBER),
      P.line(146, 152, 146 + 94 * Math.cos((-120 * Math.PI) / 180), 152 + 94 * Math.sin((-120 * Math.PI) / 180), INK),
      P.line(146, 152, 146 + 94 * Math.cos((-24 * Math.PI) / 180), 152 + 94 * Math.sin((-24 * Math.PI) / 180), INK),
      P.point(146, 152, 'O', INK),
      P.text(192, 136, 'r = {{r}}', BLUE),
      P.text(134, 108, 'α = {{theta}} rad', RED),
    ]),

  // c35-g1-q1: 向量数量积夹角 |a|=2, |b|=3, 60°
  'c35-g1-q1': () =>
    spec('平面向量夹角与数量积示意', [
      P.arrow(66, 156, 258, 156, BLUE),
      P.arrow(66, 156, 146, 44, RED),
      P.arc(66, 156, 36, -54, 54, AMBER),
      P.point(66, 156, 'O', INK),
      P.text(152, 164, '|b| = 3', BLUE),
      P.text(78, 86, '|a| = 2', RED),
      P.text(108, 132, '60°', AMBER),
    ]),

  // c35-g2-q4: 向量夹角 π/3 (|a|=1, |b|=2)
  'c35-g2-q4': () =>
    spec('平面向量夹角与垂直模型', [
      P.arrow(66, 158, 246, 158, BLUE),
      P.arrow(66, 158, 126, 68, RED),
      P.arc(66, 158, 34, -56, 56, AMBER),
      P.point(66, 158, 'O', INK),
      P.text(148, 166, '|b| = 2', BLUE),
      P.text(68, 98, '|a| = 1', RED),
      P.text(104, 134, 'π/3', AMBER),
    ]),

  // c36-g2-q2: 复平面向量 (1,2) 绕原点逆时针旋转 90°
  'c36-g2-q2': () => {
    const ox = 160;
    const oy = 148;
    const s = 34;
    const p = (x, y) => [ox + x * s, oy - y * s];
    return spec('复平面向量逆时针旋转 90°', [
      ...axesPrimitives(ox, oy, 28, 292, 18, 192),
      P.arrow(...p(0, 0), ...p(1, 2), BLUE),
      P.arrow(...p(0, 0), ...p(-2, 1), RED, true),
      P.arc(ox, oy, 28, -153, 90, AMBER),
      P.point(...p(1, 2), 'Z₁(1,2)', BLUE),
      P.point(...p(-2, 1), 'Z₂(?)', RED),
      P.text(136, 110, '90°', AMBER),
    ]);
  },

  // c36-g2-q3: 复平面轨迹圆 |z - 3| = {{m}}
  'c36-g2-q3': () => {
    const ox = 88;
    const oy = 108;
    return spec('复平面轨迹圆 |z - 3| = {{m}}', [
      ...axesPrimitives(ox, oy, 26, 294, 18, 194),
      P.circle(178, oy, 56, BLUE, FILL_BLUE),
      P.line(178, oy, 224, oy - 32, RED),
      P.point(178, oy, '(3,0)', INK),
      P.text(196, oy - 32, 'r={{m}}', RED),
    ]);
  },

  // c36-g3-q1: 复平面 |z - 1 - i| = 1 与 |z| 最大值
  'c36-g3-q1': () => {
    const ox = 112;
    const oy = 148;
    const s = 44;
    const p = (x, y) => [ox + x * s, oy - y * s];
    return spec('复平面圆 |z - 1 - i| = 1', [
      ...axesPrimitives(ox, oy, 26, 294, 18, 194),
      P.circle(...p(1, 1), s, BLUE, FILL_BLUE),
      P.line(...p(0, 0), ...p(1.71, 1.71), RED),
      P.point(...p(1, 1), 'C(1,1)', INK),
      P.point(...p(1.71, 1.71), 'P(最大)', RED),
      P.text(168, 76, 'r=1', BLUE),
    ]);
  },

  // c37-g1-q4: 斜二测画法正方形直观图
  'c37-g1-q4': () =>
    spec('斜二测画法直观图（边长 {{2*s}}）', [
      // 左：原正方形
      P.polygon([[30, 62], [116, 62], [116, 148], [30, 148]], INK, FILL_BLUE),
      P.text(44, 156, '原正方形', MUTED),
      P.text(62, 134, '{{2*s}}', BLUE),
      // 箭头
      P.arrow(128, 106, 158, 106, RED),
      // 右：直观图平行四边形
      P.polygon([[172, 148], [258, 148], [288, 118], [202, 118]], BLUE, FILL_AMBER),
      P.arc(172, 148, 22, -45, 45, RED),
      P.text(196, 130, '45°', RED),
      P.text(192, 156, '底不变、斜边减半', MUTED),
    ]),

  // c38-g2-q4: 五组频率分布直方图
  'c38-g2-q4': () => {
    const ox = 40;
    const oy = 166;
    const bars = [
      { l: '50', h: 36, t: '0.01', c: BLUE, f: FILL_BLUE },
      { l: '60', h: 72, t: '0.02', c: BLUE, f: FILL_BLUE },
      { l: '70', h: 108, t: 'a=?', c: RED, f: FILL_AMBER, d: true },
      { l: '80', h: 108, t: '0.03', c: BLUE, f: FILL_BLUE },
      { l: '90', h: 36, t: '0.01', c: BLUE, f: FILL_BLUE },
    ];
    const prims = [
      P.arrow(ox, oy, 296, oy, INK),
      P.arrow(ox, oy, ox, 20, INK),
      P.text(10, 18, '频率/组距', MUTED),
    ];
    bars.forEach((b, i) => {
      const x1 = ox + 16 + i * 44;
      const x2 = x1 + 44;
      const y1 = oy - b.h;
      prims.push(P.polygon([[x1, oy], [x1, y1], [x2, y1], [x2, oy]], b.c, b.f, !!b.d));
      prims.push(P.text(x1 + 6, y1 - 15, b.t, b.c));
      prims.push(P.text(x1 - 4, oy + 6, b.l, MUTED));
    });
    prims.push(P.text(ox + 16 + 5 * 44 - 8, oy + 6, '100', MUTED));
    return spec('成绩频率分布直方图（组距 10）', prims);
  },

  // c38-g3-q5: 居民月用电量 6 组频率分布图
  'c38-g3-q5': () => {
    const ox = 36;
    const oy = 166;
    const bars = [
      { l: '50', h: 34, t: '10%' },
      { l: '100', h: 68, t: '20%' },
      { l: '150', h: 102, t: '30%' },
      { l: '200', h: 82, t: '24%' },
      { l: '250', h: 34, t: '10%' },
      { l: '300', h: 22, t: '6%' },
    ];
    const prims = [
      P.arrow(ox, oy, 298, oy, INK),
      P.arrow(ox, oy, ox, 22, INK),
      P.text(12, 20, '占比', MUTED),
    ];
    bars.forEach((b, i) => {
      const x1 = ox + 12 + i * 40;
      const x2 = x1 + 38;
      const y1 = oy - b.h;
      prims.push(P.polygon([[x1, oy], [x1, y1], [x2, y1], [x2, oy]], BLUE, FILL_BLUE));
      prims.push(P.text(x1 + 4, y1 - 15, b.t, BLUE));
      prims.push(P.text(x1 - 4, oy + 6, b.l, MUTED));
    });
    prims.push(P.text(ox + 12 + 6 * 40 - 8, oy + 6, '350', MUTED));
    return spec('居民月用电量 6 组频率分布图', prims);
  },

  // c39-g3-q1: 两元件并联电路示意图
  'c39-g3-q1': () =>
    spec('双元件并联电路示意（各 P = 0.9）', [
      P.line(36, 108, 92, 108, INK),
      P.line(228, 108, 284, 108, INK),
      P.line(92, 62, 92, 154, INK),
      P.line(228, 62, 228, 154, INK),
      P.line(92, 62, 126, 62, INK),
      P.line(194, 62, 228, 62, INK),
      P.line(92, 154, 126, 154, INK),
      P.line(194, 154, 228, 154, INK),
      P.polygon([[126, 46], [194, 46], [194, 78], [126, 78]], BLUE, FILL_BLUE),
      P.polygon([[126, 138], [194, 138], [194, 170], [126, 170]], GREEN, FILL_GREEN),
      P.point(36, 108, 'A', INK),
      P.point(284, 108, 'B', INK),
      P.text(134, 54, '元件 1', BLUE),
      P.text(134, 146, '元件 2', GREEN),
      P.text(136, 98, '并联', RED),
    ]),

  // c41-g0-q1: 两点 A(1,2) 与 B(3,6) 斜率
  'c41-g0-q1': () => {
    const ox = 64;
    const oy = 172;
    const sx = 46;
    const sy = 22;
    const p = (x, y) => [ox + x * sx, oy - y * sy];
    return spec('过 A(1,2)、B(3,6) 直线斜率示意', [
      ...axesPrimitives(ox, oy, 26, 290, 16, 194),
      P.line(...p(0.2, 0.4), ...p(3.4, 6.8), BLUE),
      P.line(...p(1, 2), ...p(3, 2), RED, true),
      P.line(...p(3, 2), ...p(3, 6), RED, true),
      P.point(...p(1, 2), 'A(1,2)', BLUE),
      P.point(...p(3, 6), 'B(3,6)', BLUE),
      P.text(154, 134, 'Δx', RED),
      P.text(208, 82, 'Δy', RED),
    ]);
  },

  // c41-g0-q3: 点 P(0,{{a}}) 到直线 3x+4y-5=0 距离
  'c41-g0-q3': () =>
    spec('点 P(0,{{a}}) 到直线距离 d', [
      ...axesPrimitives(108, 152, 26, 294, 18, 194),
      P.line(54, 96, 274, 176, BLUE),
      P.line(108, 48, 132, 124, RED),
      P.rightAngle(132, 124, 108, 48, 274, 176, 9, RED),
      P.point(108, 48, 'P(0,{{a}})', RED),
      P.text(130, 82, 'd', RED),
      P.text(176, 124, '3x+4y-5=0', BLUE),
    ]),

  // c41-g1-q2: 两条平行直线距离
  'c41-g1-q2': () =>
    spec('两平行直线间距离示意', [
      P.line(44, 138, 264, 52, BLUE),
      P.line(66, 182, 286, 96, GREEN),
      P.line(156, 94, 174, 140, RED),
      P.rightAngle(174, 140, 156, 94, 286, 96, 9, RED),
      P.text(58, 82, '3x+4y+8=0', BLUE),
      P.text(172, 158, '3x+4y-2=0', GREEN),
      P.text(176, 108, 'd = ?', RED),
    ]),

  // c41-g1-q3: 倾斜角 135° 过 ({{a}},1) 直线
  'c41-g1-q3': () =>
    spec('倾斜角 135° 直线示意图', [
      ...axesPrimitives(128, 152, 26, 294, 18, 194),
      P.line(74, 28, 250, 190, BLUE),
      P.arc(208, 152, 24, -135, 135, RED),
      P.point(128, 78, '(0,b?)', GREEN),
      P.point(172, 118, '({{a}},1)', BLUE),
      P.text(218, 128, '135°', RED),
    ]),

  // c44-g0-q2: 曲线 y = x² + 1 在 (1,2) 处切线
  'c44-g0-q2': () => {
    const ox = 136;
    const oy = 166;
    const sx = 42;
    const sy = 26;
    const p = (x, y) => [ox + x * sx, oy - y * sy];
    const pts = sampleCurve((x) => x * x + 1, -2.0, 2.2, 34, p);
    return spec('曲线 y = x² + 1 在 (1,2) 处切线', [
      ...axesPrimitives(ox, oy, 26, 294, 18, 194),
      P.polyline(pts, BLUE),
      P.line(...p(-0.2, -0.4), ...p(2.2, 4.4), RED),
      P.point(...p(1, 2), '(1,2)', RED),
      P.text(216, 48, '切线 k=?', RED),
    ]);
  },

  // c44-g3-q1: 过原点作曲线 y = e^x 切线
  'c44-g3-q1': () => {
    const ox = 112;
    const oy = 164;
    const sx = 48;
    const sy = 28;
    const p = (x, y) => [ox + x * sx, oy - y * sy];
    const pts = sampleCurve((x) => Math.exp(x), -1.6, 1.55, 34, p);
    return spec('过原点作 y = e^x 的切线', [
      ...axesPrimitives(ox, oy, 26, 294, 18, 194),
      P.polyline(pts, BLUE),
      P.line(...p(-0.2, -0.54), ...p(1.75, 4.76), RED),
      P.point(...p(1, Math.E), '切点', RED),
      P.text(204, 38, 'y = e^x', BLUE),
    ]);
  },

  // c44-g3-q2: 切线放缩 e^x ≥ x + a
  'c44-g3-q2': () => {
    const ox = 128;
    const oy = 158;
    const sx = 46;
    const sy = 28;
    const p = (x, y) => [ox + x * sx, oy - y * sy];
    const pts = sampleCurve((x) => Math.exp(x), -1.8, 1.55, 34, p);
    return spec('切线放缩模型 e^x ≥ x + a', [
      ...axesPrimitives(ox, oy, 26, 294, 18, 194),
      P.polyline(pts, BLUE),
      P.line(...p(-1.6, -0.6), ...p(2.4, 3.4), RED),
      P.point(...p(0, 1), '(0,1)', RED),
      P.text(206, 36, 'y = e^x', BLUE),
      P.text(202, 100, 'y = x + a', RED),
    ]);
  },

  // c45-g0-q3: 甲→乙→丙分步路线示意图
  'c45-g0-q3': () =>
    spec('分步乘法计数原理路线图', [
      P.point(48, 108, '甲地', INK),
      P.point(160, 108, '乙地', BLUE),
      P.point(272, 108, '丙地', GREEN),
      P.polyline([[48, 108], [104, 64], [160, 108]], BLUE),
      P.line(48, 108, 160, 108, BLUE),
      P.polyline([[48, 108], [104, 152], [160, 108]], BLUE),
      P.polyline([[160, 108], [216, 70], [272, 108]], RED),
      P.polyline([[160, 108], [216, 146], [272, 108]], RED),
      P.text(68, 42, '公路 {{a}} 条', BLUE),
      P.text(188, 42, '铁路 {{b}} 条', RED),
    ]),

  // c45-g1-q3: 铁路线 n 个车站往返车票
  'c45-g1-q3': () =>
    spec('铁路线 {{n}} 个车站往返车票', [
      P.line(36, 114, 284, 114, INK),
      P.point(54, 114, '站1', BLUE),
      P.point(112, 114, '站2', BLUE),
      P.point(170, 114, '站3', BLUE),
      P.point(264, 114, '站{{n}}', RED),
      P.text(206, 104, '···', MUTED),
      P.arrow(64, 86, 160, 86, BLUE),
      P.arrow(160, 142, 64, 142, RED),
      P.text(92, 66, '去程', BLUE),
      P.text(92, 150, '返程（票面不同）', RED),
    ]),

  // c46-g0-q2: 正态分布 N(2, σ²) 对称曲线
  'c46-g0-q2': () => {
    const ox = 160;
    const oy = 164;
    const p = (z, y) => [ox + z * 42, oy - y * 116];
    const pts = sampleCurve((z) => Math.exp(-0.5 * z * z), -2.8, 2.8, 44, p);
    return spec('正态分布 N(2, σ²) 对称性示意', [
      P.arrow(26, oy, 294, oy, INK),
      P.polyline(pts, BLUE),
      P.line(ox, 34, ox, oy, RED, true),
      P.line(ox - 42, oy - 70, ox - 42, oy, GREEN, true),
      P.line(ox + 42, oy - 70, ox + 42, oy, GREEN, true),
      P.text(ox - 10, 18, 'μ=2', RED),
      P.text(ox - 46, oy + 8, '0', GREEN),
      P.text(ox - 4, oy + 8, '2', RED),
      P.text(ox + 38, oy + 8, '4', GREEN),
    ]);
  },

  // c46-g3-q1: 正态分布 N(100, 10²) (110, 120] 区间
  'c46-g3-q1': () => {
    const ox = 160;
    const oy = 164;
    const p = (z, y) => [ox + z * 42, oy - y * 116];
    const pts = sampleCurve((z) => Math.exp(-0.5 * z * z), -2.8, 2.8, 44, p);
    const shade = [p(1, 0), ...sampleCurve((z) => Math.exp(-0.5 * z * z), 1, 2, 12, p), p(2, 0)];
    return spec('正态分布 N(100, 10²) 与区间 (110,120]', [
      P.arrow(26, oy, 294, oy, INK),
      P.polygon(shade, AMBER, FILL_AMBER),
      P.polyline(pts, BLUE),
      P.line(ox, 34, ox, oy, RED, true),
      P.text(ox - 16, 18, 'μ=100', RED),
      P.text(ox - 48, oy + 8, '90', MUTED),
      P.text(ox - 10, oy + 8, '100', RED),
      P.text(ox + 34, oy + 8, '110', AMBER),
      P.text(ox + 76, oy + 8, '120', AMBER),
    ]);
  },

  // c47-g2-q4: 5组实测数据散点与回归直线
  'c47-g2-q4': () => {
    const ox = 48;
    const oy = 174;
    const sx = 32;
    const sy = 16;
    const p = (x, y) => [ox + x * sx, oy - y * sy];
    return spec('促销投入 x 与销量 y 散点回归图', [
      ...axesPrimitives(ox, oy, 26, 294, 18, 194),
      P.line(...p(1.4, 1.8), ...p(7.2, 8.9), RED),
      P.point(...p(2, 2.2), '', BLUE),
      P.point(...p(3, 3.8), '', BLUE),
      P.point(...p(4, 5.5), '', BLUE),
      P.point(...p(5, 6.5), '', BLUE),
      P.point(...p(6, 7.0), '', BLUE),
      P.point(...p(4, 5.0), '中心', GREEN),
      P.text(192, 34, 'ŷ = bx + a', RED),
    ]);
  },

  // c48-g2-q1: f(x) = e^x / x 与 y = k 交点
  'c48-g2-q1': () => {
    const ox = 128;
    const oy = 126;
    const sx = 38;
    const sy = 18;
    const p = (x, y) => [ox + x * sx, oy - y * sy];
    const right = sampleCurve((x) => Math.exp(x) / x, 0.25, 2.5, 34, p);
    const left = sampleCurve((x) => Math.exp(x) / x, -2.5, -0.22, 30, p);
    return spec('f(x) = e^x / x 图象与 y = k 交点', [
      ...axesPrimitives(ox, oy, 26, 294, 18, 194),
      P.polyline(right, BLUE),
      P.polyline(left, BLUE),
      P.line(34, oy - 3.6 * sy, 286, oy - 3.6 * sy, RED, true),
      P.point(...p(1, Math.E), '(1,e)', GREEN),
      P.text(224, oy - 3.6 * sy - 16, 'y = k', RED),
    ]);
  },

  // c48-g3-q1: e^(x-1) ≥ ax 切线放缩
  'c48-g3-q1': () => {
    const ox = 76;
    const oy = 166;
    const sx = 54;
    const sy = 34;
    const p = (x, y) => [ox + x * sx, oy - y * sy];
    const curve = sampleCurve((x) => Math.exp(x - 1), -0.3, 2.4, 34, p);
    return spec('切线放缩模型 e^(x-1) ≥ ax', [
      ...axesPrimitives(ox, oy, 26, 294, 18, 194),
      P.polyline(curve, BLUE),
      P.line(...p(0, 0), ...p(3.2, 3.2), RED),
      P.point(...p(1, 1), '(1,1)', RED),
      P.text(182, 34, 'y = e^(x-1)', BLUE),
      P.text(224, 90, 'y = ax', RED),
    ]);
  },

  // c48-g3-q4: y = ln x + {{k}} 与直线 y = x + b 相切
  'c48-g3-q4': () => {
    const ox = 72;
    const oy = 158;
    const sx = 52;
    const sy = 32;
    const p = (x, y) => [ox + x * sx, oy - y * sy];
    const curve = sampleCurve((x) => Math.log(x) + 1.8, 0.22, 3.8, 34, p);
    return spec('y = ln x + {{k}} 与 y = x + b 相切', [
      ...axesPrimitives(ox, oy, 26, 294, 18, 194),
      P.polyline(curve, BLUE),
      P.line(...p(0, 0.8), ...p(2.8, 3.6), RED),
      P.point(...p(1, 1.8), '切点', RED),
      P.text(204, 108, 'y = ln x + {{k}}', BLUE),
      P.text(168, 42, 'y = x + b', RED),
    ]);
  },

  // c50-g0-q4: 正态分布对称性 P(ξ≤{{a}}) = P(ξ≥{{a+6}})
  'c50-g0-q4': () => {
    const ox = 160;
    const oy = 164;
    const p = (z, y) => [ox + z * 42, oy - y * 116];
    const pts = sampleCurve((z) => Math.exp(-0.5 * z * z), -2.8, 2.8, 44, p);
    const lShade = [p(-2.8, 0), ...sampleCurve((z) => Math.exp(-0.5 * z * z), -2.8, -1.2, 12, p), p(-1.2, 0)];
    const rShade = [p(1.2, 0), ...sampleCurve((z) => Math.exp(-0.5 * z * z), 1.2, 2.8, 12, p), p(2.8, 0)];
    return spec('正态分布双尾对称示意图', [
      P.arrow(26, oy, 294, oy, INK),
      P.polygon(lShade, BLUE, FILL_BLUE),
      P.polygon(rShade, BLUE, FILL_BLUE),
      P.polyline(pts, BLUE),
      P.line(ox, 34, ox, oy, RED, true),
      P.text(ox - 12, 18, 'μ = ?', RED),
      P.text(ox - 66, oy + 8, '{{a}}', BLUE),
      P.text(ox + 38, oy + 8, '{{a + 6}}', BLUE),
    ]);
  },

  // c50-g3-q2: 正态分布 N(174, 4²) 男生身高 (178, 182]
  'c50-g3-q2': () => {
    const ox = 160;
    const oy = 164;
    const p = (z, y) => [ox + z * 42, oy - y * 116];
    const pts = sampleCurve((z) => Math.exp(-0.5 * z * z), -2.8, 2.8, 44, p);
    const shade = [p(1, 0), ...sampleCurve((z) => Math.exp(-0.5 * z * z), 1, 2, 12, p), p(2, 0)];
    return spec('男生身高 N(174, 4²) 与 (178,182]', [
      P.arrow(26, oy, 294, oy, INK),
      P.polygon(shade, GREEN, FILL_GREEN),
      P.polyline(pts, BLUE),
      P.line(ox, 34, ox, oy, RED, true),
      P.text(ox - 18, 18, 'μ=174', RED),
      P.text(ox - 48, oy + 8, '170', MUTED),
      P.text(ox - 10, oy + 8, '174', RED),
      P.text(ox + 34, oy + 8, '178', GREEN),
      P.text(ox + 76, oy + 8, '182', GREEN),
    ]);
  },
};

// ============================================================================
// 2. 通用语义几何/函数配图构建器（为初一~高三全库非“如图”但高度依赖图形的题目补齐配图）
// ============================================================================
function buildTriangleAnglesDiagram(q) {
  const s = q.stem;
  if (/角平分线.*交于点\s*\$?I/.test(s) || /双内角平分线/.test((q.tags || []).join())) {
    return spec('三角形双内角平分线模型', [
      P.polygon([[160, 28], [58, 174], [262, 174]], INK, FILL_BLUE),
      P.line(58, 174, 160, 122, RED),
      P.line(262, 174, 160, 122, RED),
      P.point(160, 122, 'I', RED),
      P.text(154, 10, 'A', INK),
      P.text(42, 176, 'B', INK),
      P.text(266, 176, 'C', INK),
      P.text(142, 134, '∠BIC = ?', RED),
    ]);
  }
  if (/外角.*平分线.*交于点\s*\$?P/.test(s) || /一内一外/.test((q.tags || []).join())) {
    return spec('一内一外角平分线模型', [
      P.polygon([[118, 42], [44, 168], [186, 168]], INK, FILL_BLUE),
      P.line(186, 168, 284, 168, INK),
      P.line(44, 168, 256, 84, RED),
      P.line(186, 168, 256, 84, RED),
      P.point(256, 84, 'P', RED),
      P.text(112, 22, 'A', INK),
      P.text(28, 172, 'B', INK),
      P.text(182, 174, 'C', INK),
      P.text(276, 174, 'D', INK),
    ]);
  }
  if (/两个外角.*交于点\s*\$?O/.test(s)) {
    return spec('双外角平分线模型', [
      P.polygon([[160, 24], [102, 106], [218, 106]], INK, FILL_BLUE),
      P.line(102, 106, 62, 164, MUTED, true),
      P.line(218, 106, 258, 164, MUTED, true),
      P.line(102, 106, 160, 176, RED),
      P.line(218, 106, 160, 176, RED),
      P.point(160, 176, 'O', RED),
      P.text(154, 6, 'A', INK),
      P.text(84, 100, 'B', INK),
      P.text(224, 100, 'C', INK),
    ]);
  }
  if (/高.*角平分线/.test(s) || (/AD.*高/.test(s) && /AE/.test(s))) {
    return spec('三角形高与角平分线夹角', [
      P.polygon([[128, 30], [48, 172], [272, 172]], INK, FILL_BLUE),
      P.line(128, 30, 128, 172, BLUE),
      P.line(128, 30, 168, 172, RED),
      P.rightAngle(128, 172, 128, 30, 272, 172, 10, BLUE),
      P.text(122, 12, 'A', INK),
      P.text(32, 174, 'B', INK),
      P.text(276, 174, 'C', INK),
      P.text(122, 178, 'D', BLUE),
      P.text(164, 178, 'E', RED),
    ]);
  }
  if (/中线/.test(s) && /AD/.test(s)) {
    return spec('三角形中线示意图', [
      P.polygon([[136, 30], [52, 172], [268, 172]], INK, FILL_BLUE),
      P.line(136, 30, 160, 172, RED),
      P.point(160, 172, '', RED),
      P.text(130, 12, 'A', INK),
      P.text(36, 174, 'B', INK),
      P.text(272, 174, 'C', INK),
      P.text(154, 178, 'D(中点)', RED),
    ]);
  }
  if (/等腰/.test(s)) {
    return spec('等腰三角形示意图', [
      P.polygon([[160, 26], [82, 174], [238, 174]], INK, FILL_BLUE),
      P.line(160, 26, 160, 174, MUTED, true),
      P.text(154, 8, 'A', INK),
      P.text(66, 176, 'B', INK),
      P.text(242, 176, 'C', INK),
      P.text(98, 96, '腰', BLUE),
      P.text(206, 96, '腰', BLUE),
    ]);
  }
  if (/等边/.test(s)) {
    return spec('等边三角形示意图', [
      P.polygon([[160, 28], [76, 174], [244, 174]], INK, FILL_GREEN),
      P.text(154, 10, 'A', INK),
      P.text(60, 176, 'B', INK),
      P.text(248, 176, 'C', INK),
      P.text(146, 56, '60°', GREEN),
    ]);
  }
  if (/\\angle A = \{\{a\}\}/.test(s) && /\\angle B = \{\{b\}\}/.test(s)) {
    return spec('△ABC 内角和示意图', [
      P.polygon([[150, 32], [56, 172], [264, 172]], INK, FILL_BLUE),
      P.text(134, 12, 'A ({{a}}°)', BLUE),
      P.text(32, 176, 'B ({{b}}°)', BLUE),
      P.text(254, 176, 'C (?)', RED),
    ]);
  }
  return spec('△ABC 示意图', [
    P.polygon([[148, 32], [56, 172], [264, 172]], INK, FILL_BLUE),
    P.text(142, 12, 'A', INK),
    P.text(40, 174, 'B', INK),
    P.text(268, 174, 'C', INK),
  ]);
}

function buildRightTriangleDiagram(labelA = 'A', labelB = 'B', labelC = 'C', extra = []) {
  return spec(`直角三角形 Rt△${labelA}${labelB}${labelC}`, [
    P.polygon([[76, 168], [76, 44], [254, 168]], INK, FILL_BLUE),
    P.rightAngle(76, 168, 76, 44, 254, 168, 12, RED),
    P.text(68, 24, labelA, INK),
    P.text(258, 166, labelB, INK),
    P.text(58, 172, labelC, INK),
    ...extra,
  ]);
}

function buildCongruentTrianglesDiagram() {
  return spec('全等三角形 △ABC ≅ △DEF', [
    P.polygon([[84, 42], [32, 164], [142, 164]], INK, FILL_BLUE),
    P.polygon([[228, 42], [176, 164], [286, 164]], BLUE, FILL_GREEN),
    P.text(78, 22, 'A', INK),
    P.text(18, 166, 'B', INK),
    P.text(144, 166, 'C', INK),
    P.text(222, 22, 'D', BLUE),
    P.text(164, 166, 'E', BLUE),
    P.text(288, 166, 'F', BLUE),
    P.text(148, 102, '≅', RED),
  ]);
}

function buildParallelLinesDiagram(kind) {
  if (kind === 'pig') {
    return spec('平行线“猪蹄模型” (AB ∥ CD)', [
      P.line(44, 44, 276, 44, INK),
      P.line(44, 168, 276, 168, INK),
      P.line(188, 44, 118, 106, RED),
      P.line(118, 106, 202, 168, RED),
      P.line(74, 106, 220, 106, BLUE, true),
      P.point(118, 106, '', RED),
      P.text(44, 26, 'A', INK),
      P.text(266, 26, 'B', INK),
      P.text(44, 174, 'C', INK),
      P.text(266, 174, 'D', INK),
      P.text(98, 98, 'E', RED),
    ]);
  }
  if (kind === 'pencil') {
    return spec('平行线“铅笔头模型” (AB ∥ CD)', [
      P.line(54, 44, 266, 44, INK),
      P.line(54, 168, 266, 168, INK),
      P.line(220, 44, 104, 106, RED),
      P.line(104, 106, 220, 168, RED),
      P.point(104, 106, 'P', RED),
      P.text(54, 26, 'A', INK),
      P.text(258, 26, 'B', INK),
      P.text(54, 174, 'C', INK),
      P.text(258, 174, 'D', INK),
    ]);
  }
  return spec('平行线与截线 (a ∥ b)', [
    P.line(36, 62, 284, 62, INK),
    P.line(36, 148, 284, 148, INK),
    P.line(108, 22, 212, 188, BLUE),
    P.arc(133, 62, 18, 0, 58, RED),
    P.arc(187, 148, 18, -180, 58, GREEN),
    P.text(28, 56, 'a', INK),
    P.text(28, 142, 'b', INK),
    P.text(154, 68, '∠1', RED),
    P.text(146, 128, '∠2', GREEN),
  ]);
}

function buildQuadrilateralDiagram(kind) {
  if (kind === 'rhombus') {
    return spec('菱形 ABCD（对角线互相垂直平分）', [
      P.polygon([[160, 26], [62, 106], [160, 186], [258, 106]], INK, FILL_BLUE),
      P.line(62, 106, 258, 106, BLUE, true),
      P.line(160, 26, 160, 186, BLUE, true),
      P.rightAngle(160, 106, 160, 26, 258, 106, 10, RED),
      P.point(160, 106, 'O', RED),
      P.text(154, 8, 'A', INK),
      P.text(46, 100, 'B', INK),
      P.text(154, 190, 'C', INK),
      P.text(262, 100, 'D', INK),
    ]);
  }
  if (kind === 'rectangle') {
    return spec('矩形 ABCD', [
      P.polygon([[68, 42], [252, 42], [252, 166], [68, 166]], INK, FILL_BLUE),
      P.line(68, 42, 252, 166, MUTED, true),
      P.line(252, 42, 68, 166, MUTED, true),
      P.rightAngle(68, 166, 68, 42, 252, 166, 11, BLUE),
      P.point(160, 104, 'O', RED),
      P.text(52, 32, 'A', INK),
      P.text(256, 32, 'D', INK),
      P.text(256, 168, 'C', INK),
      P.text(52, 168, 'B', INK),
    ]);
  }
  if (kind === 'square') {
    return spec('正方形 ABCD', [
      P.polygon([[90, 32], [230, 32], [230, 172], [90, 172]], INK, FILL_BLUE),
      P.line(90, 32, 230, 172, MUTED, true),
      P.line(230, 32, 90, 172, MUTED, true),
      P.rightAngle(90, 172, 90, 32, 230, 172, 11, BLUE),
      P.text(74, 22, 'A', INK),
      P.text(234, 22, 'D', INK),
      P.text(234, 174, 'C', INK),
      P.text(74, 174, 'B', INK),
    ]);
  }
  return spec('平行四边形 ABCD', [
    P.polygon([[96, 42], [264, 42], [224, 168], [56, 168]], INK, FILL_BLUE),
    P.line(96, 42, 224, 168, MUTED, true),
    P.line(264, 42, 56, 168, MUTED, true),
    P.point(160, 105, 'O', RED),
    P.text(84, 24, 'A', INK),
    P.text(266, 24, 'D', INK),
    P.text(228, 170, 'C', INK),
    P.text(42, 170, 'B', INK),
  ]);
}

function buildCircleDiagram(kind) {
  if (kind === 'chord') {
    return spec('垂径定理示意图', [
      P.circle(160, 106, 72, INK, FILL_BLUE),
      P.line(100, 146, 220, 146, BLUE),
      P.line(160, 106, 160, 146, RED),
      P.line(160, 106, 220, 146, MUTED, true),
      P.rightAngle(160, 146, 160, 106, 220, 146, 10, RED),
      P.point(160, 106, 'O', INK),
      P.text(84, 148, 'A', BLUE),
      P.text(224, 148, 'B', BLUE),
      P.text(154, 152, 'C', RED),
      P.text(192, 116, 'r', MUTED),
    ]);
  }
  if (kind === 'inscribed_angle') {
    return spec('圆心角与圆周角关系', [
      P.circle(160, 108, 72, INK, FILL_BLUE),
      P.line(160, 108, 102, 150, RED),
      P.line(160, 108, 218, 150, RED),
      P.line(146, 37, 102, 150, BLUE),
      P.line(146, 37, 218, 150, BLUE),
      P.point(160, 108, 'O', RED),
      P.point(146, 37, '', BLUE),
      P.text(86, 154, 'A', INK),
      P.text(222, 154, 'B', INK),
      P.text(142, 18, 'C', BLUE),
    ]);
  }
  if (kind === 'tangent') {
    return spec('圆的切线与切线长定理', [
      P.circle(124, 108, 60, INK, FILL_BLUE),
      P.line(266, 108, 152, 55, RED),
      P.line(266, 108, 152, 161, RED),
      P.line(124, 108, 152, 55, MUTED, true),
      P.line(124, 108, 152, 161, MUTED, true),
      P.rightAngle(152, 55, 124, 108, 266, 108, 9, RED),
      P.point(124, 108, 'O', INK),
      P.point(266, 108, 'P', RED),
      P.text(148, 36, 'A', RED),
      P.text(148, 168, 'B', RED),
    ]);
  }
  if (kind === 'sector') {
    return spec('扇形弧长与面积示意图', [
      P.arc(146, 148, 96, -125, 100, BLUE, FILL_AMBER),
      P.line(146, 148, 146 + 96 * Math.cos((-125 * Math.PI) / 180), 148 + 96 * Math.sin((-125 * Math.PI) / 180), INK),
      P.line(146, 148, 146 + 96 * Math.cos((-25 * Math.PI) / 180), 148 + 96 * Math.sin((-25 * Math.PI) / 180), INK),
      P.point(146, 148, 'O', INK),
      P.text(192, 134, 'r', BLUE),
      P.text(152, 114, 'n°', RED),
    ]);
  }
  return spec('圆 ⊙O 示意图', [
    P.circle(160, 108, 72, INK, FILL_BLUE),
    P.line(160, 108, 232, 108, BLUE),
    P.point(160, 108, 'O', INK),
    P.text(192, 92, 'r', BLUE),
  ]);
}

function buildConicDiagram(kind) {
  if (kind === 'ellipse') {
    const ox = 160;
    const oy = 108;
    const pts = [];
    for (let i = 0; i <= 48; i++) {
      const t = (i / 48) * Math.PI * 2;
      pts.push([Math.round((ox + 96 * Math.cos(t)) * 10) / 10, Math.round((oy + 56 * Math.sin(t)) * 10) / 10]);
    }
    return spec('椭圆焦点与标准方程示意图', [
      ...axesPrimitives(ox, oy, 24, 296, 18, 194),
      P.polyline(pts, BLUE),
      P.point(ox - 78, oy, 'F₁', RED),
      P.point(ox + 78, oy, 'F₂', RED),
      P.point(ox + 42, oy - 50, 'P', GREEN),
      P.line(ox - 78, oy, ox + 42, oy - 50, GREEN, true),
      P.line(ox + 78, oy, ox + 42, oy - 50, GREEN, true),
    ]);
  }
  if (kind === 'hyperbola') {
    const ox = 160;
    const oy = 108;
    const p = (x, y) => [ox + x * 24, oy - y * 24];
    const rTop = sampleCurve((x) => Math.sqrt(x * x / 2.25 - 1) * 1.4, 1.5, 4.6, 22, p);
    const rBot = sampleCurve((x) => -Math.sqrt(x * x / 2.25 - 1) * 1.4, 1.5, 4.6, 22, p).reverse();
    const lTop = sampleCurve((x) => Math.sqrt(x * x / 2.25 - 1) * 1.4, -4.6, -1.5, 22, p);
    const lBot = sampleCurve((x) => -Math.sqrt(x * x / 2.25 - 1) * 1.4, -4.6, -1.5, 22, p).reverse();
    return spec('双曲线与渐近线示意图', [
      ...axesPrimitives(ox, oy, 24, 296, 18, 194),
      P.line(52, 24, 268, 192, MUTED, true),
      P.line(52, 192, 268, 24, MUTED, true),
      P.polyline([...rBot, ...rTop], BLUE),
      P.polyline([...lTop, ...lBot], BLUE),
      P.point(ox - 54, oy, 'F₁', RED),
      P.point(ox + 54, oy, 'F₂', RED),
    ]);
  }
  // parabola y^2 = 2px
  const ox = 112;
  const oy = 108;
  const pts = [];
  for (let i = -24; i <= 24; i++) {
    const y = (i / 24) * 76;
    const x = (y * y) / 42;
    pts.push([Math.round((ox + x) * 10) / 10, Math.round((oy - y) * 10) / 10]);
  }
  return spec('抛物线焦点与准线示意图', [
    ...axesPrimitives(ox, oy, 26, 294, 18, 194),
    P.polyline(pts, BLUE),
    P.line(ox - 28, 24, ox - 28, 190, RED, true),
    P.point(ox + 28, oy, 'F', RED),
    P.text(ox - 56, 28, '准线 l', RED),
  ]);
}

function buildSolidDiagram(kind) {
  if (kind === 'cone') {
    return spec('圆锥示意图', [
      P.line(160, 28, 94, 158, INK),
      P.line(160, 28, 226, 158, INK),
      P.line(160, 28, 160, 158, RED, true),
      P.line(160, 158, 226, 158, BLUE, true),
      P.arc(160, 158, 66, 0, 180, INK),
      P.arc(160, 158, 66, -180, 180, MUTED, null, true),
      P.text(166, 88, 'h', RED),
      P.text(190, 162, 'r', BLUE),
      P.text(204, 86, 'l', INK),
    ]);
  }
  if (kind === 'cylinder') {
    return spec('圆柱示意图', [
      P.line(104, 52, 104, 164, INK),
      P.line(216, 52, 216, 164, INK),
      P.polygon([[104, 52], [216, 52], [216, 164], [104, 164]], INK, FILL_BLUE),
      P.line(160, 52, 216, 52, BLUE),
      P.text(182, 34, 'r', BLUE),
      P.text(224, 102, 'h', RED),
    ]);
  }
  if (kind === 'pyramid') {
    return spec('棱锥空间示意图', [
      P.line(160, 24, 72, 164, INK),
      P.line(160, 24, 206, 180, INK),
      P.line(160, 24, 258, 146, INK),
      P.line(160, 24, 128, 134, MUTED, true),
      P.line(72, 164, 206, 180, INK),
      P.line(206, 180, 258, 146, INK),
      P.line(72, 164, 128, 134, MUTED, true),
      P.line(128, 134, 258, 146, MUTED, true),
      P.line(160, 24, 162, 154, RED, true),
      P.text(154, 6, 'P', RED),
      P.text(56, 166, 'A', INK),
      P.text(206, 184, 'B', INK),
      P.text(262, 142, 'C', INK),
      P.text(114, 128, 'D', MUTED),
    ]);
  }
  if (kind === 'sphere') {
    return spec('球体与外接球示意图', [
      P.circle(160, 106, 70, INK, FILL_BLUE),
      P.line(90, 106, 230, 106, MUTED, true),
      P.line(160, 106, 210, 56, RED),
      P.point(160, 106, 'O', RED),
      P.text(186, 66, 'R', RED),
    ]);
  }
  // cube / cuboid
  return spec('正方体/长方体示意图', [
    P.polygon([[82, 72], [198, 72], [198, 174], [82, 174]], INK, FILL_BLUE),
    P.line(82, 72, 130, 36, INK),
    P.line(198, 72, 246, 36, INK),
    P.line(130, 36, 246, 36, INK),
    P.line(246, 36, 246, 138, INK),
    P.line(198, 174, 246, 138, INK),
    P.line(130, 36, 130, 138, MUTED, true),
    P.line(82, 174, 130, 138, MUTED, true),
    P.line(130, 138, 246, 138, MUTED, true),
  ]);
}

function buildNumberLineDiagram() {
  return spec('数轴示意图', [
    P.arrow(28, 108, 292, 108, INK),
    P.line(82, 100, 82, 116, INK),
    P.line(122, 100, 122, 116, INK),
    P.line(160, 98, 160, 118, RED),
    P.line(198, 100, 198, 116, INK),
    P.line(238, 100, 238, 116, INK),
    P.point(122, 108, 'A', BLUE),
    P.point(238, 108, 'B', GREEN),
    P.text(74, 124, '-2', MUTED),
    P.text(114, 124, '-1', MUTED),
    P.text(156, 124, '0', RED),
    P.text(194, 124, '1', MUTED),
    P.text(234, 124, '2', MUTED),
  ]);
}

function buildCoordPlaneDiagram(title = '平面直角坐标系', points = []) {
  return spec(title, [
    ...axesPrimitives(160, 108, 26, 294, 18, 194),
    P.text(236, 44, '第一象限 (+,+)', MUTED),
    P.text(34, 44, '第二象限 (-,+)', MUTED),
    P.text(34, 164, '第三象限 (-,-)', MUTED),
    P.text(236, 164, '第四象限 (+,-)', MUTED),
    ...points,
  ]);
}

function buildLinearFuncDiagram() {
  const ox = 148;
  const oy = 122;
  return spec('一次函数 y = kx + b 图象示意', [
    ...axesPrimitives(ox, oy, 26, 294, 18, 194),
    P.line(54, 174, 266, 42, BLUE),
    P.point(ox, 115, '', RED),
    P.point(136, oy, '', GREEN),
    P.text(218, 42, 'y = kx + b', BLUE),
  ]);
}

function buildParabolaDiagram() {
  const ox = 160;
  const oy = 148;
  const p = (x, y) => [ox + x * 28, oy - y * 24];
  const pts = sampleCurve((x) => 0.75 * x * x - 1.2, -2.9, 2.9, 36, p);
  return spec('二次函数抛物线示意图', [
    ...axesPrimitives(ox, oy, 26, 294, 18, 194),
    P.polyline(pts, BLUE),
    P.line(ox, 24, ox, 188, RED, true),
    P.point(...p(0, -1.2), '顶点', RED),
  ]);
}

function buildInverseFuncDiagram() {
  const ox = 160;
  const oy = 108;
  const p = (x, y) => [ox + x * 28, oy - y * 24];
  const b1 = sampleCurve((x) => 3 / x, 0.75, 4.4, 28, p);
  const b2 = sampleCurve((x) => 3 / x, -4.4, -0.75, 28, p);
  return spec('反比例函数 y = k/x 图象示意', [
    ...axesPrimitives(ox, oy, 26, 294, 18, 194),
    P.polyline(b1, BLUE),
    P.polyline(b2, BLUE),
    P.polygon([p(0, 0), p(2, 0), p(2, 1.5), p(0, 1.5)], RED, FILL_AMBER),
    P.point(...p(2, 1.5), 'P(x,y)', RED),
  ]);
}

function buildSimilarityDiagram(kind) {
  if (kind === 'a_model') {
    return spec('“A字型”相似模型 (DE ∥ BC)', [
      P.polygon([[158, 26], [56, 174], [264, 174]], INK, FILL_BLUE),
      P.line(112, 92, 206, 92, RED),
      P.point(112, 92, '', RED),
      P.point(206, 92, '', RED),
      P.text(152, 8, 'A', INK),
      P.text(40, 176, 'B', INK),
      P.text(268, 176, 'C', INK),
      P.text(94, 84, 'D', RED),
      P.text(212, 84, 'E', RED),
    ]);
  }
  return spec('子母型相似（射影定理）', [
    P.polygon([[48, 168], [274, 168], [198, 44]], INK, FILL_BLUE),
    P.line(198, 44, 198, 168, RED),
    P.rightAngle(198, 44, 48, 168, 274, 168, 10, BLUE),
    P.rightAngle(198, 168, 198, 44, 48, 168, 10, RED),
    P.text(32, 170, 'A', INK),
    P.text(278, 170, 'B', INK),
    P.text(192, 24, 'C', INK),
    P.text(192, 174, 'D', RED),
  ]);
}

function buildVectorDiagram() {
  return spec('平面向量平行四边形法则', [
    P.arrow(68, 158, 198, 158, BLUE),
    P.arrow(68, 158, 128, 66, GREEN),
    P.arrow(68, 158, 258, 66, RED),
    P.line(198, 158, 258, 66, MUTED, true),
    P.line(128, 66, 258, 66, MUTED, true),
    P.text(124, 164, 'a', BLUE),
    P.text(80, 102, 'b', GREEN),
    P.text(174, 96, 'a + b', RED),
  ]);
}

function buildSineWaveDiagram() {
  const ox = 46;
  const oy = 108;
  const pts = [];
  for (let i = 0; i <= 48; i++) {
    const t = (i / 48) * Math.PI * 2;
    pts.push([Math.round((ox + (i / 48) * 230) * 10) / 10, Math.round((oy - Math.sin(t) * 58) * 10) / 10]);
  }
  return spec('正弦函数 y = A sin(ωx+φ) 波形示意', [
    ...axesPrimitives(ox, oy, 26, 294, 18, 194),
    P.polyline(pts, BLUE),
    P.text(ox + 52, 34, 'A', RED),
    P.text(ox + 208, oy + 14, 'T', BLUE),
  ]);
}

function buildLineSegmentDiagram() {
  return spec('线段与中点示意图', [
    P.line(36, 108, 284, 108, INK),
    P.point(54, 108, 'A', INK),
    P.point(148, 108, 'M', BLUE),
    P.point(198, 108, 'C', RED),
    P.point(266, 108, 'B', INK),
    P.line(54, 96, 54, 120, INK),
    P.line(266, 96, 266, 120, INK),
  ]);
}

function buildAngleBisectorDiagram() {
  return spec('角与角平分线示意图', [
    P.arrow(58, 162, 272, 162, INK),
    P.arrow(58, 162, 232, 42, INK),
    P.arrow(58, 162, 262, 92, RED, true),
    P.arc(58, 162, 42, -35, 17, BLUE),
    P.arc(58, 162, 50, -18, 18, GREEN),
    P.point(58, 162, '', INK),
    P.text(42, 164, 'O', INK),
    P.text(236, 30, 'A', INK),
    P.text(274, 166, 'B', INK),
    P.text(266, 86, 'C(平分线)', RED),
  ]);
}

function buildPieChartDiagram() {
  return spec('扇形统计图圆心角示意', [
    P.circle(152, 108, 70, INK, FILL_BLUE),
    P.arc(152, 108, 70, -90, 126, RED, FILL_AMBER),
    P.line(152, 108, 152, 38, INK),
    P.line(152, 108, 152 + 70 * Math.cos((36 * Math.PI) / 180), 108 + 70 * Math.sin((36 * Math.PI) / 180), INK),
    P.line(152, 108, 94, 146, INK),
    P.text(182, 76, 'A', RED),
    P.text(104, 96, 'B', BLUE),
    P.text(142, 146, 'C', GREEN),
  ]);
}

function buildLineCircleDiagram() {
  return spec('直线与圆的位置关系示意图', [
    P.circle(138, 108, 62, INK, FILL_BLUE),
    P.line(138, 108, 186, 68, RED),
    P.line(72, 30, 266, 176, BLUE),
    P.rightAngle(186, 68, 138, 108, 266, 176, 9, RED),
    P.point(138, 108, 'C', INK),
    P.text(158, 76, 'd', RED),
    P.text(244, 148, 'l', BLUE),
  ]);
}

function buildInequalityNumberLineDiagram(isSystem = false) {
  if (isSystem) {
    return spec('不等式组数轴公共解集示意', [
      P.arrow(26, 134, 294, 134, INK),
      P.polygon([[106, 96], [218, 96], [218, 134], [106, 134]], BLUE, FILL_BLUE),
      P.polyline([[106, 134], [106, 96], [274, 96]], BLUE),
      P.polyline([[218, 134], [218, 76], [46, 76]], RED),
      P.circle(106, 134, 4, BLUE),
      P.point(218, 134, '', RED),
      P.text(98, 146, 'a', BLUE),
      P.text(212, 146, 'b', RED),
      P.text(134, 108, '公共解集', BLUE),
    ]);
  }
  return spec('一元一次不等式数轴解集示意', [
    P.arrow(26, 128, 294, 128, INK),
    P.polyline([[172, 128], [172, 84], [48, 84]], BLUE),
    P.polygon([[48, 84], [172, 84], [172, 128], [48, 128]], BLUE, FILL_BLUE),
    P.point(172, 128, '', BLUE),
    P.text(164, 142, 'x₀', BLUE),
    P.text(84, 98, '解集区域', BLUE),
  ]);
}

function buildHistogramDiagram(title = '频率分布直方图示意') {
  const ox = 42;
  const oy = 166;
  const hs = [34, 72, 108, 66, 30];
  const prims = [
    P.arrow(ox, oy, 292, oy, INK),
    P.arrow(ox, oy, ox, 22, INK),
    P.text(12, 20, '频率/组距', MUTED),
    P.text(254, 174, '分组', MUTED),
  ];
  hs.forEach((h, i) => {
    const x1 = ox + 16 + i * 44;
    const x2 = x1 + 44;
    const y1 = oy - h;
    prims.push(P.polygon([[x1, oy], [x1, y1], [x2, y1], [x2, oy]], BLUE, i === 2 ? FILL_AMBER : FILL_BLUE));
  });
  return spec(title, prims);
}

function buildLineChartDiagram() {
  const ox = 44;
  const oy = 166;
  const pts = [
    [68, 130],
    [106, 112],
    [144, 78],
    [182, 96],
    [220, 60],
    [258, 82],
  ];
  return spec('折线统计图（变化趋势）示意', [
    P.arrow(ox, oy, 294, oy, INK),
    P.arrow(ox, oy, ox, 22, INK),
    P.polyline(pts, BLUE),
    ...pts.map((pt) => P.point(pt[0], pt[1], '', RED)),
    P.text(14, 22, '数值', MUTED),
    P.text(254, 174, '时间', MUTED),
  ]);
}

function buildVennDiagram(kind = 'inter') {
  if (kind === 'comp') {
    return spec('全集 U 与补集 ∁_U M 韦恩图', [
      P.polygon([[32, 28], [288, 28], [288, 180], [32, 180]], INK, FILL_BLUE),
      P.circle(160, 104, 48, RED, FILL_AMBER),
      P.text(44, 40, '全集 U', INK),
      P.text(152, 98, 'M', RED),
      P.text(218, 148, '∁_U M', BLUE),
    ]);
  }
  if (kind === 'subset') {
    return spec('集合包含关系 B ⊆ A 韦恩图', [
      P.circle(160, 106, 68, BLUE, FILL_BLUE),
      P.circle(168, 112, 36, RED, FILL_AMBER),
      P.text(112, 62, 'A', BLUE),
      P.text(162, 104, 'B', RED),
    ]);
  }
  return spec('集合交集与并集韦恩图', [
    P.circle(126, 106, 58, BLUE, FILL_BLUE),
    P.circle(194, 106, 58, GREEN, FILL_GREEN),
    P.text(88, 98, 'A', BLUE),
    P.text(216, 98, 'B', GREEN),
    P.text(144, 98, 'A∩B', RED),
  ]);
}

function buildIntervalNumberLineDiagram() {
  return spec('数轴区间运算示意图', [
    P.arrow(26, 134, 294, 134, INK),
    P.polyline([[72, 134], [72, 94], [198, 94], [198, 134]], BLUE),
    P.polyline([[134, 134], [134, 68], [254, 68], [254, 134]], GREEN),
    P.polygon([[134, 94], [198, 94], [198, 134], [134, 134]], RED, FILL_AMBER),
    P.text(100, 78, 'A', BLUE),
    P.text(218, 52, 'B', GREEN),
    P.text(148, 108, 'A∩B', RED),
  ]);
}

function buildQuadraticInequalityDiagram() {
  const ox = 160;
  const oy = 136;
  const p = (x, y) => [ox + x * 34, oy - y * 24];
  const pts = sampleCurve((x) => 0.75 * (x - 1.2) * (x + 1.2), -2.4, 2.4, 34, p);
  return spec('二次函数与一元二次不等式解集', [
    ...axesPrimitives(ox, oy, 26, 294, 18, 194),
    P.polyline(pts, BLUE),
    P.line(...p(-1.2, 0), ...p(1.2, 0), RED),
    P.point(...p(-1.2, 0), 'x₁', RED),
    P.point(...p(1.2, 0), 'x₂', RED),
  ]);
}

function buildFunctionFeatureDiagram(kind = 'odd') {
  const ox = 160;
  const oy = 108;
  const sx = 32;
  const sy = 26;
  const p = (x, y) => [ox + x * sx, oy - y * sy];
  if (kind === 'even') {
    const pts = sampleCurve((x) => 0.45 * x * x - 1.2, -3.2, 3.2, 36, p);
    return spec('偶函数图象（关于 y 轴对称）', [
      ...axesPrimitives(ox, oy, 26, 294, 18, 194),
      P.polyline(pts, BLUE),
      P.point(...p(-2, 0.6), '(-x,f(x))', RED),
      P.point(...p(2, 0.6), '(x,f(x))', RED),
      P.line(...p(-2, 0.6), ...p(2, 0.6), RED, true),
    ]);
  }
  if (kind === 'hook') {
    const r = sampleCurve((x) => x + 2.25 / x, 0.42, 3.8, 30, p);
    return spec('对勾函数 y = x + k/x 图象示意', [
      ...axesPrimitives(66, 168, 26, 294, 18, 194),
      P.polyline(
        sampleCurve((x) => x + 2.25 / x, 0.42, 4.2, 34, (x, y) => [66 + x * 46, 168 - y * 24]),
        BLUE,
      ),
      P.point(66 + 1.5 * 46, 168 - 3.0 * 24, '最低点', RED),
      P.text(196, 46, 'y = x + k/x', BLUE),
    ]);
  }
  if (kind === 'piecewise') {
    const l = sampleCurve((x) => 0.45 * x * x + 0.5, -2.6, 0, 20, p);
    return spec('分段函数图象示意图', [
      ...axesPrimitives(ox, oy, 26, 294, 18, 194),
      P.polyline(l, GREEN),
      P.line(...p(0, 1.0), ...p(2.6, 2.8), BLUE),
      P.point(...p(0, 1.0), '', BLUE),
      P.circle(...p(0, 0.5), 4, GREEN),
      P.text(64, 42, '左段', GREEN),
      P.text(216, 42, '右段', BLUE),
    ]);
  }
  const pts = sampleCurve((x) => 0.28 * x * x * x, -2.15, 2.15, 36, p);
  return spec('奇函数图象（关于原点对称）', [
    ...axesPrimitives(ox, oy, 26, 294, 18, 194),
    P.polyline(pts, BLUE),
    P.point(...p(1.6, 1.15), '(x,f(x))', RED),
    P.point(...p(-1.6, -1.15), '(-x,-f(x))', RED),
    P.line(...p(-1.6, -1.15), ...p(1.6, 1.15), MUTED, true),
  ]);
}

function buildExpLogDiagram(kind = 'exp') {
  const ox = 118;
  const oy = 148;
  const sx = 40;
  const sy = 28;
  const p = (x, y) => [ox + x * sx, oy - y * sy];
  if (kind === 'log') {
    const pts = sampleCurve((x) => Math.log2(x), 0.16, 4.2, 34, p);
    return spec('对数函数图象与零点示意', [
      ...axesPrimitives(ox, oy, 26, 294, 18, 194),
      P.polyline(pts, BLUE),
      P.point(...p(1, 0), '(1,0)', RED),
      P.text(218, 46, 'y = log_a x', BLUE),
    ]);
  }
  const pts = sampleCurve((x) => Math.pow(2, x), -2.0, 2.2, 34, p);
  return spec('指数函数图象与定点示意', [
    ...axesPrimitives(ox, oy, 26, 294, 18, 194),
    P.polyline(pts, BLUE),
    P.point(...p(0, 1), '(0,1)', RED),
    P.text(204, 40, 'y = a^x', BLUE),
  ]);
}

function buildComplexPlaneDiagram() {
  const ox = 142;
  const oy = 112;
  return spec('复平面点 Z(a, b) 与模长 |z|', [
    ...axesPrimitives(ox, oy, 26, 294, 18, 194),
    P.arrow(ox, oy, 224, 56, BLUE),
    P.line(224, 56, 224, oy, MUTED, true),
    P.line(224, 56, ox, 56, MUTED, true),
    P.point(224, 56, 'Z(a,b)', BLUE),
    P.text(228, 120, 'a', MUTED),
    P.text(124, 50, 'b', MUTED),
    P.text(176, 72, '|z|', RED),
    P.text(254, oy - 18, '实轴', MUTED),
    P.text(ox - 34, 22, '虚轴', MUTED),
  ]);
}

function buildDerivativeDiagram(kind = 'extrema') {
  const ox = 148;
  const oy = 114;
  const sx = 34;
  const sy = 26;
  const p = (x, y) => [ox + x * sx, oy - y * sy];
  if (kind === 'tangent') {
    const pts = sampleCurve((x) => 0.42 * x * x - 0.6, -2.5, 2.6, 36, p);
    return spec('导数的几何意义：切线斜率', [
      ...axesPrimitives(ox, oy, 26, 294, 18, 194),
      P.polyline(pts, BLUE),
      P.line(...p(0.2, -1.0), ...p(2.7, 2.15), RED),
      P.point(...p(1.5, 0.35), 'P(x₀,f(x₀))', RED),
      P.text(218, 42, "k = f'(x₀)", RED),
    ]);
  }
  const pts = sampleCurve((x) => 0.32 * x * x * x - 1.15 * x, -2.35, 2.35, 42, p);
  return spec('导数与函数单调性/极值示意', [
    ...axesPrimitives(ox, oy, 26, 294, 18, 194),
    P.polyline(pts, BLUE),
    P.line(ox - 1.1 * sx - 20, oy - 0.84 * sy, ox - 1.1 * sx + 20, oy - 0.84 * sy, RED, true),
    P.line(ox + 1.1 * sx - 20, oy + 0.84 * sy, ox + 1.1 * sx + 20, oy + 0.84 * sy, GREEN, true),
    P.point(...p(-1.1, 0.84), '极大值', RED),
    P.point(...p(1.1, -0.84), '极小值', GREEN),
  ]);
}

function buildRegressionScatterDiagram() {
  const ox = 46;
  const oy = 172;
  const pts = [
    [76, 152],
    [114, 128],
    [154, 108],
    [194, 80],
    [234, 62],
    [264, 44],
  ];
  return spec('线性回归散点与残差示意图', [
    ...axesPrimitives(ox, oy, 24, 294, 18, 194),
    P.line(58, 160, 276, 40, RED),
    ...pts.map((pt) => P.point(pt[0], pt[1], '', BLUE)),
    P.line(194, 80, 194, 86, AMBER),
    P.point(168, 99, '(x̄,ȳ)', GREEN),
    P.text(204, 34, 'ŷ = bx + a', RED),
  ]);
}

// ============================================================================
// JSXGraph 新制图工具 (MathStudioState) 原生矢量图构建器 (TASK-20261128-002)
// ============================================================================
function buildStudioSystemLinesDiagram(parallel = false) {
  if (parallel) {
    return compileStudioState({
      title: '平行两直线无交点（方程组无解）',
      boardMode: 'cartesian',
      bounds: [-4.8, 5, 4.8, -3],
      showGrid: true,
      points: [],
      shapes: [
        { type: 'text', x: -3.6, y: 3.7, text: 'l1 // l2 无交点', color: RED, fontSize: 11.5 },
      ],
      functions: [
        { expr: '1.5*x + 1', label: 'l1', color: BLUE, dashed: false, xMin: -4.2, xMax: 3.2 },
        { expr: '1.5*x - 2', label: 'l2', color: RED, dashed: true, xMin: -2.2, xMax: 4.2 },
      ],
    });
  }
  return compileStudioState({
    title: '二元一次方程组与两直线交点示意',
    boardMode: 'cartesian',
    bounds: [-3.2, 5, 6.4, -2],
    showGrid: true,
    points: [
      { id: 'p', name: 'P(x,y)', x: 2, y: 3, color: RED, showLabel: true },
    ],
    shapes: [],
    functions: [
      { expr: '2*x - 1', label: 'l1', color: BLUE, dashed: false, xMin: -1, xMax: 3.5 },
      { expr: '-x + 5', label: 'l2', color: GREEN, dashed: false, xMin: -0.5, xMax: 5.5 },
    ],
  });
}

function buildStudioDataVarianceDiagram() {
  return compileStudioState({
    title: '甲乙成绩波动与方差对比示意',
    boardMode: 'cartesian',
    bounds: [-0.8, 10, 6.2, -1],
    showGrid: true,
    points: [
      { id: 'a1', name: '', x: 1, y: 5.2, color: BLUE, showLabel: false },
      { id: 'a2', name: '', x: 2, y: 5.8, color: BLUE, showLabel: false },
      { id: 'a3', name: '', x: 3, y: 5.5, color: BLUE, showLabel: false },
      { id: 'a4', name: '', x: 4, y: 6.1, color: BLUE, showLabel: false },
      { id: 'a5', name: '', x: 5, y: 5.4, color: BLUE, showLabel: false },
      { id: 'b1', name: '', x: 1, y: 2.5, color: RED, showLabel: false },
      { id: 'b2', name: '', x: 2, y: 8.6, color: RED, showLabel: false },
      { id: 'b3', name: '', x: 3, y: 3.2, color: RED, showLabel: false },
      { id: 'b4', name: '', x: 4, y: 8.8, color: RED, showLabel: false },
      { id: 'b5', name: '', x: 5, y: 4.9, color: RED, showLabel: false },
      { id: 'm1', name: '', x: 0.4, y: 5.6, color: GREEN, showLabel: false, hidden: true },
      { id: 'm2', name: '', x: 5.6, y: 5.6, color: GREEN, showLabel: false, hidden: true },
    ],
    shapes: [
      { type: 'segment', p1: 'm1', p2: 'm2', color: GREEN, dashed: true, strokeWidth: 1.5 },
      { type: 'segment', p1: 'a1', p2: 'a2', color: BLUE, strokeWidth: 2 },
      { type: 'segment', p1: 'a2', p2: 'a3', color: BLUE, strokeWidth: 2 },
      { type: 'segment', p1: 'a3', p2: 'a4', color: BLUE, strokeWidth: 2 },
      { type: 'segment', p1: 'a4', p2: 'a5', color: BLUE, strokeWidth: 2 },
      { type: 'segment', p1: 'b1', p2: 'b2', color: RED, dashed: true, strokeWidth: 1.8 },
      { type: 'segment', p1: 'b2', p2: 'b3', color: RED, dashed: true, strokeWidth: 1.8 },
      { type: 'segment', p1: 'b3', p2: 'b4', color: RED, dashed: true, strokeWidth: 1.8 },
      { type: 'segment', p1: 'b4', p2: 'b5', color: RED, dashed: true, strokeWidth: 1.8 },
      { type: 'text', x: 0.6, y: 9.1, text: '方差小更稳定', color: BLUE, fontSize: 11 },
      { type: 'text', x: 3.8, y: 1.4, text: '波动大方差大', color: RED, fontSize: 11 },
    ],
    functions: [],
  });
}

function buildStudioTournamentGraphDiagram() {
  return compileStudioState({
    title: '单循环赛两两连线模型',
    boardMode: 'geometry',
    bounds: [-6.4, 4, 6.4, -4],
    showGrid: false,
    points: [
      { id: 'v1', name: '队1', x: 0, y: 2.7, color: BLUE, showLabel: true },
      { id: 'v2', name: '队2', x: 2.6, y: 0.8, color: BLUE, showLabel: true },
      { id: 'v3', name: '队3', x: 1.6, y: -2.2, color: BLUE, showLabel: true },
      { id: 'v4', name: '队4', x: -1.6, y: -2.2, color: BLUE, showLabel: true },
      { id: 'v5', name: '队5', x: -2.6, y: 0.8, color: BLUE, showLabel: true },
    ],
    shapes: [
      { type: 'polygon', pointIds: ['v1', 'v2', 'v3', 'v4', 'v5'], color: INK, fillColor: FILL_BLUE, strokeWidth: 1.8 },
      { type: 'segment', p1: 'v1', p2: 'v3', color: RED, dashed: true, strokeWidth: 1.5 },
      { type: 'segment', p1: 'v1', p2: 'v4', color: RED, dashed: true, strokeWidth: 1.5 },
      { type: 'segment', p1: 'v2', p2: 'v4', color: AMBER, dashed: true, strokeWidth: 1.4 },
      { type: 'segment', p1: 'v2', p2: 'v5', color: AMBER, dashed: true, strokeWidth: 1.4 },
      { type: 'segment', p1: 'v3', p2: 'v5', color: GREEN, dashed: true, strokeWidth: 1.4 },
      { type: 'text', x: -5.6, y: -3.2, text: '场次 = n(n-1)/2', color: BLUE, fontSize: 11.5 },
    ],
    functions: [],
  });
}

function buildStudioSymmetryDiagram() {
  return compileStudioState({
    title: '轴对称与中心对称双对称示意',
    boardMode: 'geometry',
    bounds: [-6.4, 4, 6.4, -4],
    showGrid: false,
    points: [
      { id: 'a', name: 'A', x: 0, y: 2.5, color: INK, showLabel: true },
      { id: 'b', name: 'B', x: 3.4, y: 0, color: INK, showLabel: true },
      { id: 'c', name: 'C', x: 0, y: -2.5, color: INK, showLabel: true },
      { id: 'd', name: 'D', x: -3.4, y: 0, color: INK, showLabel: true },
      { id: 'o', name: 'O', x: 0, y: 0, color: RED, showLabel: true },
      { id: 'lx1', name: '', x: -4.8, y: 0, color: BLUE, showLabel: false, hidden: true },
      { id: 'lx2', name: '', x: 4.8, y: 0, color: BLUE, showLabel: false, hidden: true },
      { id: 'ly1', name: '', x: 0, y: -3.3, color: BLUE, showLabel: false, hidden: true },
      { id: 'ly2', name: '', x: 0, y: 3.3, color: BLUE, showLabel: false, hidden: true },
    ],
    shapes: [
      { type: 'polygon', pointIds: ['a', 'b', 'c', 'd'], color: INK, fillColor: FILL_BLUE, strokeWidth: 2 },
      { type: 'segment', p1: 'lx1', p2: 'lx2', color: BLUE, dashed: true, strokeWidth: 1.4 },
      { type: 'segment', p1: 'ly1', p2: 'ly2', color: BLUE, dashed: true, strokeWidth: 1.4 },
      { type: 'text', x: 2.6, y: 2.8, text: '对称中心 O', color: RED, fontSize: 11 },
    ],
    functions: [],
  });
}

function buildStudioUrnProbabilityDiagram() {
  return compileStudioState({
    title: '不透明袋中摸球概率模型',
    boardMode: 'geometry',
    bounds: [-6.4, 4, 6.4, -4],
    showGrid: false,
    points: [
      { id: 'b1', name: '', x: -3.4, y: 2.2, color: INK, showLabel: false, hidden: true },
      { id: 'b2', name: '', x: 3.4, y: 2.2, color: INK, showLabel: false, hidden: true },
      { id: 'b3', name: '', x: 3.4, y: -2.4, color: INK, showLabel: false, hidden: true },
      { id: 'b4', name: '', x: -3.4, y: -2.4, color: INK, showLabel: false, hidden: true },
      { id: 'r1c', name: '', x: -1.8, y: 0.7, color: RED, showLabel: false, hidden: true },
      { id: 'r1e', name: '', x: -1.15, y: 0.7, color: RED, showLabel: false, hidden: true },
      { id: 'r2c', name: '', x: 0.0, y: 0.7, color: RED, showLabel: false, hidden: true },
      { id: 'r2e', name: '', x: 0.65, y: 0.7, color: RED, showLabel: false, hidden: true },
      { id: 'r3c', name: '', x: 1.8, y: 0.7, color: RED, showLabel: false, hidden: true },
      { id: 'r3e', name: '', x: 2.45, y: 0.7, color: RED, showLabel: false, hidden: true },
      { id: 'w1c', name: '', x: -1.0, y: -1.0, color: BLUE, showLabel: false, hidden: true },
      { id: 'w1e', name: '', x: -0.35, y: -1.0, color: BLUE, showLabel: false, hidden: true },
      { id: 'w2c', name: '', x: 1.0, y: -1.0, color: BLUE, showLabel: false, hidden: true },
      { id: 'w2e', name: '', x: 1.65, y: -1.0, color: BLUE, showLabel: false, hidden: true },
    ],
    shapes: [
      { type: 'polygon', pointIds: ['b1', 'b2', 'b3', 'b4'], color: INK, fillColor: '#E2E8F0', strokeWidth: 2 },
      { type: 'circle', p1: 'r1c', p2: 'r1e', color: RED, fillColor: FILL_RED, strokeWidth: 1.8 },
      { type: 'circle', p1: 'r2c', p2: 'r2e', color: RED, fillColor: FILL_RED, strokeWidth: 1.8 },
      { type: 'circle', p1: 'r3c', p2: 'r3e', color: RED, fillColor: FILL_RED, strokeWidth: 1.8 },
      { type: 'circle', p1: 'w1c', p2: 'w1e', color: BLUE, fillColor: FILL_BLUE, strokeWidth: 1.8 },
      { type: 'circle', p1: 'w2c', p2: 'w2e', color: BLUE, fillColor: FILL_BLUE, strokeWidth: 1.8 },
      { type: 'text', x: -3.2, y: 3.1, text: '古典概型：P(A) = m / n', color: BLUE, fontSize: 11.5 },
    ],
    functions: [],
  });
}

function buildStudioTreeProbabilityDiagram() {
  return compileStudioState({
    title: '分步随机事件树状图模型',
    boardMode: 'geometry',
    bounds: [-6.4, 4, 6.4, -4],
    showGrid: false,
    points: [
      { id: 's', name: '起点', x: -5.0, y: 0, color: INK, showLabel: true },
      { id: 'a1', name: '成功', x: -0.8, y: 1.9, color: GREEN, showLabel: true },
      { id: 'a2', name: '失败', x: -0.8, y: -1.9, color: RED, showLabel: true },
      { id: 'b1', name: '胜胜', x: 3.6, y: 2.9, color: GREEN, showLabel: true },
      { id: 'b2', name: '胜负', x: 3.6, y: 0.9, color: BLUE, showLabel: true },
      { id: 'b3', name: '负胜', x: 3.6, y: -0.9, color: BLUE, showLabel: true },
      { id: 'b4', name: '负负', x: 3.6, y: -2.9, color: RED, showLabel: true },
    ],
    shapes: [
      { type: 'arrow', p1: 's', p2: 'a1', color: GREEN, strokeWidth: 1.8 },
      { type: 'arrow', p1: 's', p2: 'a2', color: RED, strokeWidth: 1.8 },
      { type: 'arrow', p1: 'a1', p2: 'b1', color: GREEN, strokeWidth: 1.6 },
      { type: 'arrow', p1: 'a1', p2: 'b2', color: BLUE, strokeWidth: 1.6 },
      { type: 'arrow', p1: 'a2', p2: 'b3', color: BLUE, strokeWidth: 1.6 },
      { type: 'arrow', p1: 'a2', p2: 'b4', color: RED, strokeWidth: 1.6 },
      { type: 'text', x: -3.5, y: 1.7, text: 'P(A)', color: GREEN, fontSize: 10.5 },
      { type: 'text', x: -3.7, y: -2.0, text: '1-P(A)', color: RED, fontSize: 10.5 },
    ],
    functions: [],
  });
}

function buildStudioMapScaleDiagram() {
  return compileStudioState({
    title: '比例尺与实际距离换算示意',
    boardMode: 'geometry',
    bounds: [-6.4, 4, 6.4, -4],
    showGrid: false,
    points: [
      { id: 'a', name: 'A地', x: -4.2, y: 0.5, color: BLUE, showLabel: true },
      { id: 'b', name: 'B地', x: 4.0, y: 0.5, color: RED, showLabel: true },
    ],
    shapes: [
      { type: 'segment', p1: 'a', p2: 'b', color: BLUE, strokeWidth: 2.5 },
      { type: 'text', x: -1.8, y: 1.8, text: '图上距离 d (cm)', color: BLUE, fontSize: 11.5 },
      { type: 'text', x: -3.4, y: -1.6, text: '比例尺 = 图上距离 : 实际距离', color: MUTED, fontSize: 11 },
    ],
    functions: [],
  });
}

function buildStudioProjectionDiagram(kind = 'parallel') {
  if (kind === 'central') {
    return compileStudioState({
      title: '点光源中心投影（皮影/手影）示意',
      boardMode: 'geometry',
      bounds: [-6.4, 4, 6.4, -4],
      showGrid: false,
      points: [
        { id: 'l', name: '光源S', x: -4.8, y: 2.3, color: AMBER, showLabel: true },
        { id: 't', name: 'A', x: -0.8, y: 1.0, color: INK, showLabel: true },
        { id: 'b', name: 'B', x: -0.8, y: -1.6, color: INK, showLabel: true },
        { id: 'st', name: "A'", x: 4.2, y: -0.6, color: BLUE, showLabel: true },
        { id: 'sb', name: "B'", x: 4.2, y: -2.6, color: BLUE, showLabel: true },
        { id: 'g1', name: '', x: -5.4, y: -2.6, color: MUTED, showLabel: false, hidden: true },
        { id: 'g2', name: '', x: 5.4, y: -2.6, color: MUTED, showLabel: false, hidden: true },
      ],
      shapes: [
        { type: 'segment', p1: 'g1', p2: 'g2', color: MUTED, strokeWidth: 1.5 },
        { type: 'segment', p1: 't', p2: 'b', color: INK, strokeWidth: 2.6 },
        { type: 'arrow', p1: 'l', p2: 'st', color: AMBER, dashed: true, strokeWidth: 1.5 },
        { type: 'arrow', p1: 'l', p2: 'sb', color: AMBER, dashed: true, strokeWidth: 1.5 },
        { type: 'segment', p1: 'st', p2: 'sb', color: BLUE, strokeWidth: 3 },
      ],
      functions: [],
    });
  }
  return compileStudioState({
    title: '太阳光平行投影示意（物高与影长成正比）',
    boardMode: 'geometry',
    bounds: [-6.4, 4, 6.4, -4],
    showGrid: false,
    points: [
      { id: 't1', name: 'A', x: -3.6, y: 2.4, color: INK, showLabel: true },
      { id: 'b1', name: 'B', x: -3.6, y: -2.2, color: INK, showLabel: true },
      { id: 's1', name: 'C', x: -0.6, y: -2.2, color: BLUE, showLabel: true },
      { id: 't2', name: 'D', x: 1.4, y: 0.9, color: INK, showLabel: true },
      { id: 'b2', name: 'E', x: 1.4, y: -2.2, color: INK, showLabel: true },
      { id: 's2', name: 'F', x: 3.4, y: -2.2, color: BLUE, showLabel: true },
      { id: 'g1', name: '', x: -5.2, y: -2.2, color: MUTED, showLabel: false, hidden: true },
      { id: 'g2', name: '', x: 5.2, y: -2.2, color: MUTED, showLabel: false, hidden: true },
    ],
    shapes: [
      { type: 'segment', p1: 'g1', p2: 'g2', color: MUTED, strokeWidth: 1.5 },
      { type: 'segment', p1: 't1', p2: 'b1', color: INK, strokeWidth: 2.4 },
      { type: 'segment', p1: 't2', p2: 'b2', color: INK, strokeWidth: 2.4 },
      { type: 'arrow', p1: 't1', p2: 's1', color: AMBER, dashed: true, strokeWidth: 1.6 },
      { type: 'arrow', p1: 't2', p2: 's2', color: AMBER, dashed: true, strokeWidth: 1.6 },
      { type: 'segment', p1: 'b1', p2: 's1', color: BLUE, strokeWidth: 2.6 },
      { type: 'segment', p1: 'b2', p2: 's2', color: BLUE, strokeWidth: 2.6 },
      { type: 'rightAngle', p1: 't1', p2: 'b1', p3: 's1', color: BLUE },
      { type: 'rightAngle', p1: 't2', p2: 'b2', p3: 's2', color: BLUE },
    ],
    functions: [],
  });
}

function buildStudioLogDomainDiagram() {
  return compileStudioState({
    title: '对数复合函数定义域与图像示意',
    boardMode: 'cartesian',
    bounds: [-5.6, 3.8, 5.6, -3.2],
    showGrid: true,
    points: [
      { id: 'p1', name: 'x=-2', x: -2, y: 0, color: RED, showLabel: true },
      { id: 'p2', name: 'x=2', x: 2, y: 0, color: RED, showLabel: true },
      { id: 'a1', name: '', x: -2, y: -3, color: RED, showLabel: false, hidden: true },
      { id: 'a2', name: '', x: -2, y: 3.4, color: RED, showLabel: false, hidden: true },
      { id: 'b1', name: '', x: 2, y: -3, color: RED, showLabel: false, hidden: true },
      { id: 'b2', name: '', x: 2, y: 3.4, color: RED, showLabel: false, hidden: true },
    ],
    shapes: [
      { type: 'segment', p1: 'a1', p2: 'a2', color: RED, dashed: true, strokeWidth: 1.4 },
      { type: 'segment', p1: 'b1', p2: 'b2', color: RED, dashed: true, strokeWidth: 1.4 },
    ],
    functions: [
      { expr: 'ln(x^2 - 4)/ln(2)', label: 'log2(x²-4)', color: BLUE, dashed: false, xMin: 2.08, xMax: 5.2 },
      { expr: 'ln(x^2 - 4)/ln(2)', label: '', color: BLUE, dashed: false, xMin: -5.2, xMax: -2.08 },
    ],
  });
}

function buildStudioCubicFunctionDiagram(expr, title, centerPt = null) {
  const points = centerPt ? [centerPt] : [];
  return compileStudioState({
    title,
    boardMode: 'cartesian',
    bounds: [-4.2, 6, 4.8, -4],
    showGrid: true,
    points,
    shapes: [],
    functions: [
      { expr, label: 'f(x)', color: BLUE, dashed: false, xMin: -3.2, xMax: 3.8 },
    ],
  });
}

function buildStudioSequencePlotDiagram(kind = 'arithmetic') {
  if (kind === 'geometric') {
    return compileStudioState({
      title: '等比数列 {a_n} 离散点列图像',
      boardMode: 'cartesian',
      bounds: [-0.6, 10, 6.2, -1],
      showGrid: true,
      points: [
        { id: 'p1', name: 'a1', x: 1, y: 1, color: BLUE, showLabel: true },
        { id: 'p2', name: 'a2', x: 2, y: 2, color: BLUE, showLabel: true },
        { id: 'p3', name: 'a3', x: 3, y: 4, color: BLUE, showLabel: true },
        { id: 'p4', name: 'a4', x: 4, y: 8, color: RED, showLabel: true },
      ],
      shapes: [],
      functions: [
        { expr: '2^(x-1)', label: '指数增长', color: AMBER, dashed: true, xMin: 0.5, xMax: 4.3 },
      ],
    });
  }
  return compileStudioState({
    title: '等差数列 {a_n} 离散点列与线性关系',
    boardMode: 'cartesian',
    bounds: [-0.6, 10, 6.4, -1],
    showGrid: true,
    points: [
      { id: 'p1', name: 'a1', x: 1, y: 1.5, color: BLUE, showLabel: true },
      { id: 'p2', name: 'a2', x: 2, y: 3.2, color: BLUE, showLabel: true },
      { id: 'p3', name: 'a3', x: 3, y: 4.9, color: BLUE, showLabel: true },
      { id: 'p4', name: 'a4', x: 4, y: 6.6, color: BLUE, showLabel: true },
      { id: 'p5', name: 'a5', x: 5, y: 8.3, color: RED, showLabel: true },
    ],
    shapes: [],
    functions: [
      { expr: '1.7*x - 0.2', label: 'a_n = a_1+(n-1)d', color: GREEN, dashed: true, xMin: 0.4, xMax: 5.5 },
    ],
  });
}

/**
 * 根据章节编码、关卡序号、题序与题目内容解析最匹配的矢量配图。
 * 规则：
 * 1. 所有含“如图”题目及场景/几何/统计/函数/概率题强制命中 1:1 精绘配图；
 * 2. 其他几何/函数/坐标系/不等式数轴/集合韦恩图/统计直方图/导数/复平面/回归散点/数列点列题按语义精准配图；
 * 3. 所有返回配图均包含可二次拖拽编辑的 JSXGraph `studioState`。
 */
export function resolveDiagramForQuestion(chapterCode, gateIndex, qIndex, q) {
  const raw = _resolveRawDiagramForQuestion(chapterCode, gateIndex, qIndex, q);
  return raw ? synthesizeStudioStateFromDiagram(raw) : null;
}

function _resolveRawDiagramForQuestion(chapterCode, gateIndex, qIndex, q) {
  const key = `${chapterCode}-g${gateIndex}-q${qIndex + 1}`;
  if (EXACT_DIAGRAMS[key]) {
    return EXACT_DIAGRAMS[key](q);
  }

  const s = String(q.stem || '');
  const tags = (q.tags || []).join(' ');

  // 1) 数轴题
  if (/数轴/.test(s)) {
    return buildNumberLineDiagram();
  }

  // 2) 第4章 几何图形初步
  if (chapterCode === 'c4') {
    if (/线段/.test(s) && /中点|AB/.test(s)) return buildLineSegmentDiagram();
    if (/角平分线|\\angle AOB|余角|补角/.test(s)) return buildAngleBisectorDiagram();
    if (/正方体/.test(s)) return buildSolidDiagram('cube');
    return null;
  }

  // 3) 第5章 相交线与平行线
  if (chapterCode === 'c5') {
    if (/猪蹄/.test(s)) return buildParallelLinesDiagram('pig');
    if (/铅笔/.test(s)) return buildParallelLinesDiagram('pencil');
    if (/平行|\\parallel|同旁内角|同位角|内错角|锯齿/.test(s)) return buildParallelLinesDiagram('std');
    if (/相交|对顶角|邻补角|\\perp/.test(s)) {
      return spec('相交线与角关系示意图', [
        P.line(48, 42, 272, 172, INK),
        P.line(48, 172, 272, 42, BLUE),
        P.point(160, 107, 'O', RED),
        P.text(154, 72, '∠1', RED),
        P.text(194, 98, '∠2', BLUE),
      ]);
    }
    return null;
  }

  // 4) 第7章 平面直角坐标系
  if (chapterCode === 'c7') {
    if (/象限|坐标系|平移|距离|原点|横坐标|纵坐标|点\s*\$?[A-Z]\(/.test(s)) {
      return buildCoordPlaneDiagram();
    }
    return null;
  }

  // 4.5) 第9章 不等式与不等式组
  if (chapterCode === 'c9') {
    if (/不等式组|\\begin\{cases\}/.test(s) && !/方程组/.test(s)) {
      return buildInequalityNumberLineDiagram(true);
    }
    if (/解集|整数解/.test(s)) {
      return buildInequalityNumberLineDiagram(false);
    }
    return null;
  }

  // 5) 第10章 统计图表
  if (chapterCode === 'c10') {
    if (/扇形|优秀.*良好/.test(s)) return buildPieChartDiagram();
    if (/变化趋势|折线/.test(s)) return buildLineChartDiagram();
    if (/直方图|组距|频数分布/.test(s)) return buildHistogramDiagram('频数分布直方图示意');
    return null;
  }

  // 6) 第11章 三角形
  if (chapterCode === 'c11') {
    if (/三角形|\\triangle|内角|外角|等腰|中线|高/.test(s) && !/密铺/.test(s)) {
      return buildTriangleAnglesDiagram(q);
    }
    if (/多边形|正八边形/.test(s)) {
      return spec('凸多边形内角与对角线示意', [
        P.polygon([[160, 26], [234, 62], [250, 138], [198, 184], [122, 184], [70, 138], [86, 62]], INK, FILL_BLUE),
        P.line(160, 26, 250, 138, RED, true),
        P.line(160, 26, 198, 184, RED, true),
        P.line(160, 26, 122, 184, RED, true),
        P.line(160, 26, 70, 138, RED, true),
      ]);
    }
    return null;
  }

  // 7) 第12章 全等三角形
  if (chapterCode === 'c12') {
    if (/\\cong|全等/.test(s)) return buildCongruentTrianglesDiagram();
    if (/角平分线/.test(s) && /距离/.test(s)) {
      return spec('角平分线性质示意图', [
        P.arrow(48, 158, 274, 158, INK),
        P.arrow(48, 158, 224, 34, INK),
        P.arrow(48, 158, 258, 86, BLUE, true),
        P.point(168, 117, 'P', RED),
        P.line(168, 117, 168, 158, RED),
        P.line(168, 117, 144, 90, RED),
        P.rightAngle(168, 158, 168, 117, 274, 158, 9, RED),
        P.text(32, 160, 'O', INK),
        P.text(228, 24, 'A', INK),
        P.text(276, 160, 'B', INK),
      ]);
    }
    if (/\\triangle|三角形/.test(s)) return buildTriangleAnglesDiagram(q);
    return null;
  }

  // 8) 第13章 轴对称
  if (chapterCode === 'c13') {
    if (/垂直平分线/.test(s)) {
      return spec('线段垂直平分线性质', [
        P.line(58, 158, 262, 158, INK),
        P.line(160, 24, 160, 186, RED, true),
        P.line(160, 56, 58, 158, BLUE),
        P.line(160, 56, 262, 158, BLUE),
        P.rightAngle(160, 158, 160, 56, 262, 158, 10, RED),
        P.point(160, 56, 'P', RED),
        P.text(42, 160, 'A', INK),
        P.text(266, 160, 'B', INK),
      ]);
    }
    if (/坐标系|关于\s*\$?[xy]\$?\s*轴/.test(s)) return buildCoordPlaneDiagram('平面直角坐标系轴对称');
    if (/等腰|等边|三角形|\\triangle/.test(s)) return buildTriangleAnglesDiagram(q);
    return null;
  }

  // 9) 第17章 勾股定理
  if (chapterCode === 'c17') {
    if (/直角三角形|Rt\\triangle|\\triangle|斜边|直角边|勾股/.test(s)) {
      return buildRightTriangleDiagram('A', 'B', 'C', [
        P.text(56, 104, 'b', BLUE),
        P.text(158, 176, 'a', BLUE),
        P.text(172, 90, 'c', RED),
      ]);
    }
    return null;
  }

  // 10) 第18章 平行四边形
  if (chapterCode === 'c18') {
    if (/菱形/.test(s)) return buildQuadrilateralDiagram('rhombus');
    if (/矩形/.test(s)) return buildQuadrilateralDiagram('rectangle');
    if (/正方形/.test(s)) return buildQuadrilateralDiagram('square');
    if (/中位线/.test(s)) {
      return spec('三角形中位线定理', [
        P.polygon([[158, 28], [58, 174], [262, 174]], INK, FILL_BLUE),
        P.line(108, 101, 210, 101, RED),
        P.point(108, 101, '', RED),
        P.point(210, 101, '', RED),
        P.text(152, 10, 'A', INK),
        P.text(42, 176, 'B', INK),
        P.text(266, 176, 'C', INK),
        P.text(90, 94, 'D', RED),
        P.text(216, 94, 'E', RED),
      ]);
    }
    if (/直角三角形.*斜边.*中线/.test(s)) {
      return buildRightTriangleDiagram('A', 'B', 'C', [
        P.line(76, 168, 165, 106, RED),
        P.point(165, 106, 'M(中点)', RED),
      ]);
    }
    if (/平行四边形/.test(s)) return buildQuadrilateralDiagram('parallelogram');
    return null;
  }

  // 11) 第19章 一次函数
  if (chapterCode === 'c19' && /一次函数|正比例|直线|图象|象限|面积/.test(s)) {
    return buildLinearFuncDiagram();
  }

  // 12) 第22章 二次函数
  if (chapterCode === 'c22' && /抛物线|二次函数|顶点|对称轴|图象/.test(s)) {
    return buildParabolaDiagram();
  }

  // 13) 第23章 旋转
  if (chapterCode === 'c23') {
    if (/坐标系|原点/.test(s)) return buildCoordPlaneDiagram('中心对称与坐标旋转');
    if (/正方形/.test(s)) return buildQuadrilateralDiagram('square');
    if (/三角形|\\triangle|旋转/.test(s)) return buildTriangleAnglesDiagram(q);
    return null;
  }

  // 13.5) 第8章 二元一次方程组 / 第20章 数据的分析 / 第21章 一元二次方程场景 / 第23章 对称 / 第25章 概率初步
  if (chapterCode === 'c8') {
    if (/无解/.test(s)) return buildStudioSystemLinesDiagram(true);
    if (/解为|方程组.*的解/.test(s)) return buildStudioSystemLinesDiagram(false);
    return null;
  }
  if (chapterCode === 'c20') {
    if (/方差|稳定性|波动|模拟成绩/.test(s)) return buildStudioDataVarianceDiagram();
    return null;
  }
  if (chapterCode === 'c21') {
    if (/单循环|两队之间/.test(s)) return buildStudioTournamentGraphDiagram();
    return null;
  }
  if (chapterCode === 'c23' && /轴对称.*中心对称/.test(s)) {
    return buildStudioSymmetryDiagram();
  }
  if (chapterCode === 'c25') {
    if (/摸|袋|暗盒|箱中/.test(s)) return buildStudioUrnProbabilityDiagram();
    if (/扑克|硬币|十字路口/.test(s)) return buildStudioTreeProbabilityDiagram();
    return null;
  }

  // 14) 第24章 圆
  if (chapterCode === 'c24') {
    if (/弦|垂径/.test(s)) return buildCircleDiagram('chord');
    if (/圆周角|圆心角|内接/.test(s)) return buildCircleDiagram('inscribed_angle');
    if (/切线/.test(s)) return buildCircleDiagram('tangent');
    if (/扇形|弧长/.test(s)) return buildCircleDiagram('sector');
    if (/圆锥/.test(s)) return buildSolidDiagram('cone');
    if (/圆|\\odot/.test(s)) return buildCircleDiagram('basic');
    return null;
  }

  // 15) 第26章 反比例函数
  if (chapterCode === 'c26' && /反比例|双曲线|图象|面积/.test(s)) {
    return buildInverseFuncDiagram();
  }

  // 16) 第27章 相似
  if (chapterCode === 'c27') {
    if (/射影|子母|CD \\perp AB/.test(s)) return buildSimilarityDiagram('sub');
    if (/DE \\parallel BC|ADE|相似三角形|\\triangle/.test(s)) return buildSimilarityDiagram('a_model');
    if (/矩形/.test(s)) return buildQuadrilateralDiagram('rectangle');
    if (/比例尺/.test(s)) return buildStudioMapScaleDiagram();
    return null;
  }

  // 17) 第28章 锐角三角函数
  if (chapterCode === 'c28') {
    if (/Rt\\triangle|\\angle C = 90|直角三角形|坡度|仰角|\\triangle|锐角/.test(s)) {
      return buildRightTriangleDiagram('A', 'B', 'C', [
        P.arc(76, 44, 24, 34, 56, BLUE),
        P.text(90, 74, '∠A', BLUE),
      ]);
    }
    return null;
  }

  // 18) 第29章 投影与视图
  if (chapterCode === 'c29') {
    if (/圆锥/.test(s)) return buildSolidDiagram('cone');
    if (/圆柱/.test(s)) return buildSolidDiagram('cylinder');
    if (/球/.test(s)) return buildSolidDiagram('sphere');
    if (/正方体|长方体|棱柱|三视图|视图/.test(s)) return buildSolidDiagram('cube');
    if (/皮影|手影|中心投影/.test(s)) return buildStudioProjectionDiagram('central');
    if (/太阳光|平行投影/.test(s)) return buildStudioProjectionDiagram('parallel');
    return null;
  }

  // 19) 高中集合、不等式、函数、复数、统计、解析几何与导数 (h1/h2/h3)
  if (chapterCode === 'c30') {
    if (/补集|\\complement/.test(s)) return buildVennDiagram('comp');
    if (/\\subseteq/.test(s)) return buildVennDiagram('subset');
    if (/区间|\\le x \\le|-1 < x|x \\le|x \\ge/.test(s)) return buildIntervalNumberLineDiagram();
    if (/\\cap|\\cup/.test(s)) return buildVennDiagram('inter');
    return null;
  }
  if (chapterCode === 'c31') {
    if (/x\^2.*(<|>|\\le|\\ge)|二次函数/.test(s)) return buildQuadraticInequalityDiagram();
    return null;
  }
  if (chapterCode === 'c32') {
    if (/\\begin\{cases\}/.test(s)) return buildFunctionFeatureDiagram('piecewise');
    if (/x \+ \\frac\{4\}\{x\}/.test(s)) return buildFunctionFeatureDiagram('hook');
    if (/偶函数/.test(s)) return buildFunctionFeatureDiagram('even');
    if (/奇函数/.test(s)) return buildFunctionFeatureDiagram('odd');
    if (/单调|减函数|幂函数|对称轴/.test(s)) return buildParabolaDiagram();
    return null;
  }
  if (chapterCode === 'c33') {
    if (/\\begin\{cases\}/.test(s)) return buildFunctionFeatureDiagram('piecewise');
    if (/x\^2 - 4/.test(s)) return buildStudioLogDomainDiagram();
    if (/\\mathrm\{log\}|\\mathrm\{ln\}|\\mathrm\{lg\}/.test(s) && /单调|零点|图象|实数根|不等式|定义域|奇偶/.test(s)) {
      return buildExpLogDiagram('log');
    }
    if (/指数函数|定点|4\^x|a\^\{x/.test(s)) return buildExpLogDiagram('exp');
    return null;
  }
  if (chapterCode === 'c34' && /\\mathrm\{sin\}|正弦|图象|周期/.test(s)) {
    return buildSineWaveDiagram();
  }
  if (chapterCode === 'c35') {
    if (/\\triangle|三角形|正弦定理|余弦定理/.test(s)) return buildTriangleAnglesDiagram(q);
    if (/向量/.test(s)) return buildVectorDiagram();
    return null;
  }
  if (chapterCode === 'c36' && /复平面|模长|\|z\|/.test(s)) {
    return buildComplexPlaneDiagram();
  }
  if (chapterCode === 'c37' || chapterCode === 'c40') {
    if (/球/.test(s)) return buildSolidDiagram('sphere');
    if (/圆锥/.test(s)) return buildSolidDiagram('cone');
    if (/圆柱/.test(s)) return buildSolidDiagram('cylinder');
    if (/棱锥|四面体/.test(s)) return buildSolidDiagram('pyramid');
    if (/正方体|长方体|棱柱|空间|二面角|平面/.test(s)) return buildSolidDiagram('cube');
    return null;
  }
  if (chapterCode === 'c38' && /直方图/.test(s)) {
    return buildHistogramDiagram('频率分布直方图示意');
  }
  if (chapterCode === 'c39') {
    if (/袋|口袋|奖券/.test(s)) return buildStudioUrnProbabilityDiagram();
    if (/三道独立关卡|三轮答题/.test(s)) return buildStudioTreeProbabilityDiagram();
    return null;
  }
  if (chapterCode === 'c41') {
    if (/圆|切线|弦/.test(s)) return buildLineCircleDiagram();
    if (/平行/.test(s)) return buildParallelLinesDiagram('std');
    return null;
  }
  if (chapterCode === 'c42' || chapterCode === 'c49') {
    if (/椭圆/.test(s)) return buildConicDiagram('ellipse');
    if (/双曲线/.test(s)) return buildConicDiagram('hyperbola');
    if (/抛物线/.test(s)) return buildConicDiagram('parabola');
    if (/圆/.test(s)) return buildLineCircleDiagram();
    return null;
  }
  if (chapterCode === 'c43') {
    if (/等差数列/.test(s) && /前.*项和|公差|通项/.test(s)) return buildStudioSequencePlotDiagram('arithmetic');
    if (/等比数列/.test(s)) return buildStudioSequencePlotDiagram('geometric');
    return null;
  }
  if (chapterCode === 'c44' || chapterCode === 'c48') {
    if (/切线|相切/.test(s)) return buildDerivativeDiagram('tangent');
    if (/x\^3 - 3x \+ 2/.test(s)) {
      return buildStudioCubicFunctionDiagram('x^3 - 3*x + 2', '三次函数 f(x) = x³ - 3x + 2 图像');
    }
    if (/\(x - 1\)\^3 \+ 2\(x - 1\) \+ 3/.test(s)) {
      return buildStudioCubicFunctionDiagram('(x-1)^3 + 2*(x-1) + 3', '中心对称函数 (对称中心 (1,3))', {
        id: 'sym',
        name: '(1,3)',
        x: 1,
        y: 3,
        color: RED,
        showLabel: true,
      });
    }
    if (/极大|极小|极值|单调|最小值|最大值|恒成立|导函数|导数值/.test(s)) return buildDerivativeDiagram('extrema');
    return null;
  }
  if (chapterCode === 'c46' || chapterCode === 'c50') {
    if (/盒|袋|箱/.test(s)) return buildStudioUrnProbabilityDiagram();
    if (/两台车床|两轮独立|全概率|条件概率/.test(s)) return buildStudioTreeProbabilityDiagram();
    return null;
  }
  if (chapterCode === 'c47') {
    if (/回归|相关系数|残差|样本中心|离群点/.test(s)) return buildRegressionScatterDiagram();
    return null;
  }
  if (chapterCode === 'c51') {
    if (/\\triangle|三角形/.test(s)) return buildTriangleAnglesDiagram(q);
    if (/等差数列/.test(s)) return buildStudioSequencePlotDiagram('arithmetic');
    if (/等比数列/.test(s)) return buildStudioSequencePlotDiagram('geometric');
    return null;
  }

  return null;
}

export { EXACT_DIAGRAMS };
