// 「过关啦」数学题库矢量配图生成器 (TASK-20261126-001)
// 统一输出兼容 Flutter BoardDiagramPainter 与 Admin SVG 渲染器的 BoardDiagramSpec JSON：
// 支持图元类型：line / arrow / circle / arc / rightAngle / polygon / polyline / point / text
// 动态模板题支持在 text / label / title 中保留 {{expr}}，由后端 QuestionEngineService 随随机参数实时渲染。

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
    P.text(ox + 226, oy + 10, 'T', BLUE),
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

/**
 * 根据章节编码、关卡序号、题序与题目内容解析最匹配的矢量配图。
 * 规则：
 * 1. 所有 33 道含“如图”题目强制命中 1:1 精绘配图；
 * 2. 其他几何/函数/坐标系/圆/三角形/四边形/立体几何/圆锥曲线/向量/数轴题目按语义精准配图；
 * 3. 纯代数运算（整式/分式/方程计算/概率枚举等）保持无多余配图，避免喧宾夺主。
 */
export function resolveDiagramForQuestion(chapterCode, gateIndex, qIndex, q) {
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

  // 5) 第10章 统计图表
  if (chapterCode === 'c10' && /扇形/.test(s)) {
    return buildPieChartDiagram();
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
    return null;
  }

  // 17) 第28章 锐角三角函数
  if (chapterCode === 'c28') {
    if (/Rt\\triangle|\\angle C = 90|直角三角形|坡度|仰角|\\triangle/.test(s)) {
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
    if (/正方体|长方体|棱柱|三视图/.test(s)) return buildSolidDiagram('cube');
    return null;
  }

  // 19) 高中图形章节 (h1/h2/h3)
  if (chapterCode === 'c34' && /\\mathrm\{sin\}|正弦|图象|周期/.test(s)) {
    return buildSineWaveDiagram();
  }
  if (chapterCode === 'c35') {
    if (/\\triangle|三角形|正弦定理|余弦定理/.test(s)) return buildTriangleAnglesDiagram(q);
    if (/向量/.test(s)) return buildVectorDiagram();
    return null;
  }
  if (chapterCode === 'c37' || chapterCode === 'c40') {
    if (/球/.test(s)) return buildSolidDiagram('sphere');
    if (/圆锥/.test(s)) return buildSolidDiagram('cone');
    if (/圆柱/.test(s)) return buildSolidDiagram('cylinder');
    if (/棱锥|四面体/.test(s)) return buildSolidDiagram('pyramid');
    if (/正方体|长方体|棱柱|空间|二面角|平面/.test(s)) return buildSolidDiagram('cube');
    return null;
  }
  if (chapterCode === 'c41' && /圆|切线|弦/.test(s)) {
    return buildLineCircleDiagram();
  }
  if (chapterCode === 'c42' || chapterCode === 'c49') {
    if (/椭圆/.test(s)) return buildConicDiagram('ellipse');
    if (/双曲线/.test(s)) return buildConicDiagram('hyperbola');
    if (/抛物线/.test(s)) return buildConicDiagram('parabola');
    if (/圆/.test(s)) return buildLineCircleDiagram();
    return null;
  }
  if (chapterCode === 'c51' && /\\triangle|三角形/.test(s)) {
    return buildTriangleAnglesDiagram(q);
  }

  return null;
}

export { EXACT_DIAGRAMS };
