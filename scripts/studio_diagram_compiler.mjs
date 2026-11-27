// 「过关啦」新制图工具 (MathDiagramStudioDialog / JSXGraph) 统一编译器与质量审计器
// 严格对齐 frontend-admin/src/components/MathDiagramStudioDialog.vue 的 MathStudioState 与 compileToDiagramSpec()

export function compileMathExpr(rawExpr) {
  let expr = String(rawExpr ?? '').trim();
  if (!expr) return null;
  expr = expr
    .replace(/^y\s*=\s*/i, '')
    .replace(/^f\s*\(\s*x\s*\)\s*=\s*/i, '')
    .replace(/²/g, '^2')
    .replace(/³/g, '^3')
    .replace(/π/g, 'pi')
    .replace(/×/g, '*')
    .replace(/÷/g, '/')
    .replace(/−/g, '-');

  expr = expr
    .replace(/(\d)\s*([a-zA-Z(])/g, '$1*$2')
    .replace(/(\))\s*(\d|[a-zA-Z(])/g, '$1*$2')
    .replace(/\b(x)\s*\(/g, '$1*(');

  if (!/^[0-9a-zA-Z_+\-*/^().,\s]+$/.test(expr)) {
    return null;
  }

  const fnMap = {
    sin: 'Math.sin',
    cos: 'Math.cos',
    tan: 'Math.tan',
    asin: 'Math.asin',
    acos: 'Math.acos',
    atan: 'Math.atan',
    sqrt: 'Math.sqrt',
    abs: 'Math.abs',
    ln: 'Math.log',
    log: 'Math.log10',
    exp: 'Math.exp',
    floor: 'Math.floor',
    ceil: 'Math.ceil',
    pow: 'Math.pow',
    pi: 'Math.PI',
    PI: 'Math.PI',
    e: 'Math.E',
  };

  const tokens = expr.match(/[a-zA-Z_][a-zA-Z0-9_]*/g) || [];
  for (const tok of tokens) {
    if (tok !== 'x' && !(tok in fnMap)) {
      return null;
    }
  }

  const jsExpr = expr
    .replace(/\^/g, '**')
    .replace(/\b([a-zA-Z_][a-zA-Z0-9_]*)\b/g, (m) => (m === 'x' ? 'x' : fnMap[m] || m));

  try {
    // eslint-disable-next-line no-new-func
    const fn = new Function('x', `"use strict"; return (${jsExpr});`);
    const testVal = fn(1);
    if (typeof testVal !== 'number') return null;
    return (x) => {
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

/**
 * 将 MathStudioState 编译为全端通用的 DiagramSpec（320×210），并完整保留 studioState 供后台 JSXGraph 工作台二次拖拽编辑。
 */
export function compileStudioState(rawState) {
  const outW = 320;
  const outH = 210;
  const pad = 16;

  const state = {
    title: String(rawState.title || '数学示意图').trim() || '数学示意图',
    boardMode: rawState.boardMode || 'cartesian',
    bounds: Array.isArray(rawState.bounds) && rawState.bounds.length === 4 ? [...rawState.bounds] : [-6, 4, 6, -4],
    showGrid: rawState.showGrid ?? rawState.boardMode === 'cartesian',
    snapToGrid: rawState.snapToGrid ?? true,
    points: (rawState.points || []).map((pt, idx) => ({
      id: pt.id || `pt_${idx + 1}`,
      name: pt.name ?? '',
      x: Number(pt.x),
      y: Number(pt.y),
      color: pt.color || '#1E293B',
      showLabel: pt.showLabel ?? Boolean(pt.name),
    })),
    shapes: (rawState.shapes || []).map((sh, idx) => ({
      id: sh.id || `sh_${idx + 1}`,
      ...sh,
      color: sh.color || '#1E293B',
    })),
    functions: (rawState.functions || []).map((fn, idx) => ({
      id: fn.id || `fn_${idx + 1}`,
      expr: fn.expr,
      label: fn.label || '',
      color: fn.color || '#0284C7',
      dashed: Boolean(fn.dashed),
      xMin: fn.xMin ?? rawState.bounds?.[0] ?? -6,
      xMax: fn.xMax ?? rawState.bounds?.[2] ?? 6,
    })),
  };

  const [xMin, yMax, xMax, yMin] = state.bounds;
  const spanX = Math.max(0.001, xMax - xMin);
  const spanY = Math.max(0.001, yMax - yMin);

  const toPx = (ux, uy) => {
    const px = pad + ((ux - xMin) / spanX) * (outW - pad * 2);
    const py = pad + ((yMax - uy) / spanY) * (outH - pad * 2);
    return [Math.round(px * 10) / 10, Math.round(py * 10) / 10];
  };

  const pointMap = new Map(state.points.map((p) => [p.id, p]));
  const getPointById = (id) => pointMap.get(id);
  const primitives = [];

  // 1. 坐标系 / 网格 / 数轴
  if (state.boardMode === 'cartesian') {
    if (state.showGrid) {
      const gxStep = spanX > 20 ? Math.ceil(spanX / 12) : 1;
      const gyStep = spanY > 14 ? Math.ceil(spanY / 8) : 1;
      for (let gx = Math.ceil(xMin / gxStep) * gxStep; gx <= Math.floor(xMax); gx += gxStep) {
        if (gx === 0) continue;
        const [px1, py1] = toPx(gx, yMin);
        const [px2, py2] = toPx(gx, yMax);
        primitives.push({ type: 'line', x1: px1, y1: py1, x2: px2, y2: py2, color: '#E2E8F0', strokeWidth: 0.7 });
      }
      for (let gy = Math.ceil(yMin / gyStep) * gyStep; gy <= Math.floor(yMax); gy += gyStep) {
        if (gy === 0) continue;
        const [px1, py1] = toPx(xMin, gy);
        const [px2, py2] = toPx(xMax, gy);
        primitives.push({ type: 'line', x1: px1, y1: py1, x2: px2, y2: py2, color: '#E2E8F0', strokeWidth: 0.7 });
      }
    }
    const [xAxisL, xAxisY] = toPx(xMin, 0);
    const [xAxisR] = toPx(xMax, 0);
    const [yAxisX, yAxisB] = toPx(0, yMin);
    const [, yAxisT] = toPx(0, yMax);

    if (yMin <= 0 && yMax >= 0) {
      primitives.push({ type: 'arrow', x1: xAxisL, y1: xAxisY, x2: xAxisR, y2: xAxisY, color: '#64748B', strokeWidth: 1.4 });
      primitives.push({ type: 'text', x: xAxisR - 8, y: xAxisY + 4, text: 'x', color: '#64748B', fontSize: 11 });
    }
    if (xMin <= 0 && xMax >= 0) {
      primitives.push({ type: 'arrow', x1: yAxisX, y1: yAxisB, x2: yAxisX, y2: yAxisT, color: '#64748B', strokeWidth: 1.4 });
      primitives.push({ type: 'text', x: yAxisX + 5, y: yAxisT - 4, text: 'y', color: '#64748B', fontSize: 11 });
    }
    if (xMin <= 0 && xMax >= 0 && yMin <= 0 && yMax >= 0) {
      primitives.push({ type: 'text', x: yAxisX - 12, y: xAxisY + 3, text: 'O', color: '#64748B', fontSize: 10 });
    }
  } else if (state.boardMode === 'numberline') {
    const [lx, ly] = toPx(xMin + 0.3, 0);
    const [rx] = toPx(xMax - 0.3, 0);
    primitives.push({ type: 'arrow', x1: lx, y1: ly, x2: rx, y2: ly, color: '#334155', strokeWidth: 1.8 });
    for (let gx = Math.ceil(xMin + 0.6); gx <= Math.floor(xMax - 0.8); gx++) {
      const [tx] = toPx(gx, 0);
      primitives.push({ type: 'line', x1: tx, y1: ly - 4, x2: tx, y2: ly + 4, color: '#475569', strokeWidth: 1.2 });
      primitives.push({ type: 'text', x: tx - 3, y: ly + 8, text: String(gx), color: '#475569', fontSize: 10 });
    }
  }

  // 2. 函数曲线
  for (const fnItem of state.functions) {
    const compiled = compileMathExpr(fnItem.expr);
    if (!compiled) continue;
    const lo = Math.max(xMin, fnItem.xMin);
    const hi = Math.min(xMax, fnItem.xMax);
    const steps = 110;
    let currentSeg = [];
    let prevY = null;
    let labelAnchor = null;

    const flushSeg = () => {
      if (currentSeg.length >= 2) {
        primitives.push({
          type: 'polyline',
          points: currentSeg,
          color: fnItem.color || '#0284C7',
          ...(fnItem.dashed ? { dashed: true } : {}),
          strokeWidth: 2,
        });
      }
      currentSeg = [];
    };

    for (let i = 0; i <= steps; i++) {
      const x = lo + ((hi - lo) * i) / steps;
      const y = compiled(x);
      if (!Number.isFinite(y) || y < yMin - spanY * 0.12 || y > yMax + spanY * 0.12) {
        flushSeg();
        prevY = null;
        continue;
      }
      if (prevY !== null && Math.abs(y - prevY) > spanY * 0.75) {
        flushSeg();
      }
      const clampedY = Math.max(yMin, Math.min(yMax, y));
      const pt = toPx(x, clampedY);
      currentSeg.push(pt);
      if (i > steps * 0.64 && !labelAnchor && y >= yMin + spanY * 0.15 && y <= yMax - spanY * 0.18) {
        labelAnchor = pt;
      }
      prevY = y;
    }
    flushSeg();
    if (fnItem.label && labelAnchor) {
      primitives.push({
        type: 'text',
        x: Math.min(outW - 76, Math.max(12, Math.round((labelAnchor[0] - 10) * 10) / 10)),
        y: Math.max(10, Math.round((labelAnchor[1] - 14) * 10) / 10),
        text: fnItem.label,
        color: fnItem.color || '#0284C7',
        fontSize: 10.5,
      });
    }
  }

  // 3. 几何图元
  for (const sh of state.shapes) {
    if (sh.type === 'polygon' && sh.pointIds && sh.pointIds.length >= 3) {
      const pts = sh.pointIds
        .map((id) => getPointById(id))
        .filter(Boolean)
        .map((p) => toPx(p.x, p.y));
      if (pts.length >= 3) {
        primitives.push({
          type: 'polygon',
          points: pts,
          color: sh.color,
          ...(sh.fillColor && sh.fillColor !== 'none' ? { fillColor: sh.fillColor } : {}),
          ...(sh.dashed ? { dashed: true } : {}),
          strokeWidth: sh.strokeWidth || 2,
        });
      }
    } else if ((sh.type === 'segment' || sh.type === 'arrow') && sh.p1 && sh.p2) {
      const a = getPointById(sh.p1);
      const b = getPointById(sh.p2);
      if (a && b) {
        const [x1, y1] = toPx(a.x, a.y);
        const [x2, y2] = toPx(b.x, b.y);
        primitives.push({
          type: sh.type === 'arrow' ? 'arrow' : 'line',
          x1,
          y1,
          x2,
          y2,
          color: sh.color,
          ...(sh.dashed ? { dashed: true } : {}),
          strokeWidth: sh.strokeWidth || 2,
        });
      }
    } else if (sh.type === 'circle' && sh.p1 && sh.p2) {
      const c = getPointById(sh.p1);
      const e = getPointById(sh.p2);
      if (c && e) {
        const [cx, cy] = toPx(c.x, c.y);
        const [ex, ey] = toPx(e.x, e.y);
        const r = Math.round(Math.hypot(ex - cx, ey - cy) * 10) / 10;
        primitives.push({
          type: 'circle',
          cx,
          cy,
          r,
          color: sh.color,
          ...(sh.fillColor && sh.fillColor !== 'none' ? { fillColor: sh.fillColor } : {}),
          ...(sh.dashed ? { dashed: true } : {}),
          strokeWidth: sh.strokeWidth || 2,
        });
      }
    } else if (sh.type === 'rightAngle' && sh.p1 && sh.p2 && sh.p3) {
      const a = getPointById(sh.p1);
      const v = getPointById(sh.p2);
      const b = getPointById(sh.p3);
      if (a && v && b) {
        const [ax, ay] = toPx(a.x, a.y);
        const [vx, vy] = toPx(v.x, v.y);
        const [bx, by] = toPx(b.x, b.y);
        primitives.push({
          type: 'rightAngle',
          vx,
          vy,
          ax,
          ay,
          bx,
          by,
          size: 11,
          color: sh.color || '#0284C7',
        });
      }
    } else if (sh.type === 'angle' && sh.p1 && sh.p2 && sh.p3) {
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
          type: 'arc',
          cx: vx,
          cy: vy,
          r: 18,
          startAngle: Math.round(ang1 * 10) / 10,
          sweepAngle: Math.round(sweep * 10) / 10,
          color: sh.color || '#DC2626',
        });
        if (sh.label) {
          const midRad = ((ang1 + sweep / 2) * Math.PI) / 180;
          primitives.push({
            type: 'text',
            x: Math.round((vx + 24 * Math.cos(midRad) - 4) * 10) / 10,
            y: Math.round((vy + 24 * Math.sin(midRad) - 6) * 10) / 10,
            text: sh.label,
            color: sh.color || '#DC2626',
            fontSize: 11,
          });
        }
      }
    } else if (sh.type === 'text' && typeof sh.x === 'number' && typeof sh.y === 'number') {
      const [px, py] = toPx(sh.x, sh.y);
      primitives.push({
        type: 'text',
        x: px,
        y: Math.max(8, Math.round((py - 6) * 10) / 10),
        text: sh.text || '',
        color: sh.color || '#0F172A',
        fontSize: sh.fontSize || 12,
      });
    }
  }

  // 4. 顶点（仅渲染可见点或带标签点）
  for (const pt of state.points) {
    if (pt.hidden) continue;
    const [px, py] = toPx(pt.x, pt.y);
    primitives.push({
      type: 'point',
      x: px,
      y: py,
      ...(pt.showLabel && pt.name ? { label: pt.name } : {}),
      color: pt.color || '#1E293B',
    });
  }

  // 清理 hidden 辅助标记，保证 studioState 与 MathStudioState 接口严格一致
  const cleanPoints = state.points.map(({ hidden: _hidden, ...rest }) => rest);

  return {
    title: state.title,
    width: outW,
    height: outH,
    primitives,
    studioState: {
      title: state.title,
      boardMode: state.boardMode,
      bounds: state.bounds,
      showGrid: state.showGrid,
      snapToGrid: state.snapToGrid,
      points: cleanPoints,
      shapes: state.shapes,
      functions: state.functions,
    },
  };
}

/**
 * 为存量手绘 primitives DiagramSpec 合成完整可编辑的 studioState（不改动原始精准 primitives），
 * 使管理后台 JSXGraph 制图工作台打开任意存量题图均可直接拖拽、编辑顶点/线段/多边形/圆与标注。
 */
export function synthesizeStudioStateFromDiagram(diagram) {
  if (!diagram || typeof diagram !== 'object') return diagram;
  if (diagram.studioState && typeof diagram.studioState === 'object') {
    return diagram;
  }

  const srcW = Number(diagram.width || 320);
  const srcH = Number(diagram.height || 210);
  const pad = 16;
  const bounds = [-6, 4, 6, -4];
  const [xMin, yMax, xMax, yMin] = bounds;
  const spanX = xMax - xMin;
  const spanY = yMax - yMin;

  const fromPx = (px, py) => [
    Math.round((xMin + ((px - pad) / (srcW - pad * 2)) * spanX) * 100) / 100,
    Math.round((yMax - ((py - pad) / (srcH - pad * 2)) * spanY) * 100) / 100,
  ];

  const points = [];
  const shapes = [];
  let ptSeq = 1;
  let shSeq = 1;

  const findOrCreatePoint = (ux, uy, color = '#1E293B', name = '', showLabel = false) => {
    for (const pt of points) {
      if (Math.hypot(pt.x - ux, pt.y - uy) < 0.22) {
        if (name && !pt.name) {
          pt.name = name;
          pt.showLabel = showLabel;
        }
        return pt;
      }
    }
    const np = {
      id: `pt_${ptSeq++}`,
      name,
      x: ux,
      y: uy,
      color,
      showLabel: Boolean(showLabel && name),
    };
    points.push(np);
    return np;
  };

  const prims = Array.isArray(diagram.primitives) ? diagram.primitives : [];

  // 先注册显式 point 顶点，便于后续多边形/线段复用
  for (const p of prims) {
    if (p.type === 'point' && typeof p.x === 'number' && typeof p.y === 'number') {
      const [ux, uy] = fromPx(p.x, p.y);
      findOrCreatePoint(ux, uy, p.color || '#1E293B', p.label || '', Boolean(p.label));
    }
  }

  for (const p of prims) {
    if (p.type === 'polygon' && Array.isArray(p.points) && p.points.length >= 3) {
      const pointIds = p.points.map(([px, py]) => {
        const [ux, uy] = fromPx(px, py);
        return findOrCreatePoint(ux, uy, p.color || '#1E293B', '', false).id;
      });
      shapes.push({
        id: `poly_${shSeq++}`,
        type: 'polygon',
        pointIds,
        color: p.color || '#1E293B',
        ...(p.fillColor ? { fillColor: p.fillColor } : {}),
        ...(p.dashed ? { dashed: true } : {}),
        strokeWidth: p.strokeWidth || 2,
      });
    } else if ((p.type === 'line' || p.type === 'arrow') && typeof p.x1 === 'number' && typeof p.y1 === 'number') {
      const [ux1, uy1] = fromPx(p.x1, p.y1);
      const [ux2, uy2] = fromPx(Number(p.x2 ?? 0), Number(p.y2 ?? 0));
      const a = findOrCreatePoint(ux1, uy1, p.color || '#1E293B', '', false);
      const b = findOrCreatePoint(ux2, uy2, p.color || '#1E293B', '', false);
      shapes.push({
        id: `seg_${shSeq++}`,
        type: p.type === 'arrow' ? 'arrow' : 'segment',
        p1: a.id,
        p2: b.id,
        color: p.color || '#1E293B',
        ...(p.dashed ? { dashed: true } : {}),
        strokeWidth: p.strokeWidth || 2,
      });
    } else if (p.type === 'circle' && typeof p.cx === 'number' && typeof p.cy === 'number' && typeof p.r === 'number') {
      const [cx, cy] = fromPx(p.cx, p.cy);
      const [ex, ey] = fromPx(p.cx + p.r, p.cy);
      const cPt = findOrCreatePoint(cx, cy, p.color || '#1E293B', '', false);
      const ePt = findOrCreatePoint(ex, ey, p.color || '#1E293B', '', false);
      shapes.push({
        id: `cir_${shSeq++}`,
        type: 'circle',
        p1: cPt.id,
        p2: ePt.id,
        color: p.color || '#1E293B',
        ...(p.fillColor ? { fillColor: p.fillColor } : {}),
        ...(p.dashed ? { dashed: true } : {}),
        strokeWidth: p.strokeWidth || 2,
      });
    } else if (p.type === 'rightAngle' && typeof p.vx === 'number' && typeof p.vy === 'number') {
      const [ax, ay] = fromPx(p.ax, p.ay);
      const [vx, vy] = fromPx(p.vx, p.vy);
      const [bx, by] = fromPx(p.bx, p.by);
      const pa = findOrCreatePoint(ax, ay, p.color || '#0284C7', '', false);
      const pv = findOrCreatePoint(vx, vy, p.color || '#0284C7', '', false);
      const pb = findOrCreatePoint(bx, by, p.color || '#0284C7', '', false);
      shapes.push({
        id: `ra_${shSeq++}`,
        type: 'rightAngle',
        p1: pa.id,
        p2: pv.id,
        p3: pb.id,
        color: p.color || '#0284C7',
      });
    } else if (p.type === 'polyline' && Array.isArray(p.points) && p.points.length >= 2) {
      // 将长折线采样为关键连接线段以便工作台可视化编辑
      const step = Math.max(1, Math.floor(p.points.length / 8));
      const sampled = [];
      for (let i = 0; i < p.points.length; i += step) sampled.push(p.points[i]);
      if (sampled[sampled.length - 1] !== p.points[p.points.length - 1]) {
        sampled.push(p.points[p.points.length - 1]);
      }
      for (let i = 0; i < sampled.length - 1; i++) {
        const [ux1, uy1] = fromPx(sampled[i][0], sampled[i][1]);
        const [ux2, uy2] = fromPx(sampled[i + 1][0], sampled[i + 1][1]);
        const a = findOrCreatePoint(ux1, uy1, p.color || '#0284C7', '', false);
        const b = findOrCreatePoint(ux2, uy2, p.color || '#0284C7', '', false);
        shapes.push({
          id: `seg_${shSeq++}`,
          type: 'segment',
          p1: a.id,
          p2: b.id,
          color: p.color || '#0284C7',
          ...(p.dashed ? { dashed: true } : {}),
          strokeWidth: p.strokeWidth || 2,
        });
      }
    } else if (p.type === 'text' && typeof p.x === 'number' && typeof p.y === 'number') {
      const [ux, uy] = fromPx(p.x, p.y);
      shapes.push({
        id: `txt_${shSeq++}`,
        type: 'text',
        x: ux,
        y: uy,
        text: p.text || '',
        color: p.color || '#1E293B',
        fontSize: p.fontSize || 12,
      });
    }
  }

  return {
    ...diagram,
    studioState: {
      title: diagram.title || '数学示意图',
      boardMode: 'geometry',
      bounds,
      showGrid: true,
      snapToGrid: false,
      points,
      shapes,
      functions: [],
    },
  };
}

/**
 * 质量校验：检查图元非空、studioState 合法性、坐标是否越界 [0..320]x[0..210]、文本标注是否重叠。
 */
export function auditDiagramSpec(spec, label = '') {
  const errors = [];
  if (!spec || typeof spec !== 'object') {
    return [`${label}: diagram is empty`];
  }
  const w = Number(spec.width || 320);
  const h = Number(spec.height || 210);
  const prims = Array.isArray(spec.primitives) ? spec.primitives : [];
  if (prims.length === 0) {
    errors.push(`${label}: primitives is empty`);
  }
  if (!spec.studioState || !Array.isArray(spec.studioState.bounds) || spec.studioState.bounds.length !== 4) {
    errors.push(`${label}: missing valid studioState`);
  }

  const checkPt = (x, y, ctx) => {
    if (!Number.isFinite(x) || !Number.isFinite(y) || x < -6 || x > w + 6 || y < -6 || y > h + 6) {
      errors.push(`${label}: out of bounds (${x}, ${y}) at ${ctx}`);
    }
  };

  const texts = [];
  for (const p of prims) {
    if (p.type === 'line' || p.type === 'arrow') {
      checkPt(p.x1, p.y1, p.type);
      checkPt(p.x2, p.y2, p.type);
    } else if (p.type === 'point') {
      checkPt(p.x, p.y, 'point');
    } else if (p.type === 'text') {
      checkPt(p.x, p.y, `text(${p.text})`);
      if (p.text) texts.push(p);
    } else if (p.type === 'polygon' || p.type === 'polyline') {
      for (const pair of p.points || []) checkPt(pair[0], pair[1], p.type);
    }
  }

  for (let i = 0; i < texts.length; i++) {
    for (let j = i + 1; j < texts.length; j++) {
      const dx = Math.abs(texts[i].x - texts[j].x);
      const dy = Math.abs(texts[i].y - texts[j].y);
      if (dx < 14 && dy < 11) {
        errors.push(`${label}: overlapping texts "${texts[i].text}"(${texts[i].x},${texts[i].y}) vs "${texts[j].text}"(${texts[j].x},${texts[j].y})`);
      }
    }
  }
  return errors;
}
