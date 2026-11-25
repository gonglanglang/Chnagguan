import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'board_models.dart';

/// 画板手写识题本地极速预检结果（毫秒级，在发起 AI 请求前过滤空白与明显乱涂乱画）。
class BoardHandwritingCheckResult {
  const BoardHandwritingCheckResult({
    required this.valid,
    this.reason = '',
    this.strokeCount = 0,
    this.shapeCount = 0,
    this.scribbleRatio = 0,
  });

  final bool valid;
  final String reason;
  final int strokeCount;
  final int shapeCount;
  final double scribbleRatio;
}

/// 画板手写识题第一层极速校验器（< 5ms，零 Token 消耗）：
/// - 拦截空白画板、寥寥几笔/零散点划、过小书写区域；
/// - 拦截明显来回涂抹、乱画圆圈/锯齿涂鸦、全屏乱划斜线等无效输入；
/// - 放行正常手写算式、方程、函数、应用题文字及几何配图+条件，再由后端视觉 AI 进行语义完整性二次校验。
class BoardHandwritingValidator {
  BoardHandwritingValidator._();

  static BoardHandwritingCheckResult validate(
    List<BoardStroke> strokes,
    List<BoardShape> shapes,
  ) {
    final validStrokes = strokes
        .where((s) => !s.isEraser && !s.isHighlighter && s.points.isNotEmpty)
        .toList();

    if (validStrokes.isEmpty && shapes.isEmpty) {
      return const BoardHandwritingCheckResult(
        valid: false,
        reason: '画板上还没有手写题目，请先清晰写出完整数学题后再点「手写识题」',
      );
    }

    // 每个普通笔画记 1 笔，每个几何图元记 2 笔（直线/圆/坐标系等携带较多信息）
    final effectiveUnits = validStrokes.length + shapes.length * 2;
    if (effectiveUnits < 4) {
      return BoardHandwritingCheckResult(
        valid: false,
        strokeCount: validStrokes.length,
        shapeCount: shapes.length,
        reason: '当前笔迹过少，请完整写出一道数学题（含已知条件与所求问题）后再识别',
      );
    }

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    void expandRect(Rect r) {
      if (r.left < minX) minX = r.left;
      if (r.top < minY) minY = r.top;
      if (r.right > maxX) maxX = r.right;
      if (r.bottom > maxY) maxY = r.bottom;
    }

    double totalInkLen = 0;
    double scribbleInkLen = 0;
    int charLikeStrokeCount = 0;
    int giantSlashCount = 0;
    int severeScribbleStrokeCount = 0;

    for (final s in validStrokes) {
      final b = s.bounds;
      if (b != null) expandRect(b);

      double sLen = 0;
      int sharpReversals = 0;
      Offset? prevDir;

      for (var i = 1; i < s.points.length; i++) {
        final seg = s.points[i] - s.points[i - 1];
        final d = seg.distance;
        if (d < 0.5) continue;
        sLen += d;

        if (d >= 4.0) {
          final dir = seg / d;
          if (prevDir != null) {
            final dot = dir.dx * prevDir.dx + dir.dy * prevDir.dy;
            if (dot < -0.55) {
              sharpReversals++;
            }
          }
          prevDir = dir;
        }
      }

      totalInkLen += sLen;

      final bw = b?.width ?? 0;
      final bh = b?.height ?? 0;
      final diag = math.sqrt(bw * bw + bh * bh);
      final tortuosity = sLen / math.max(12.0, diag);

      // 判定单笔是否属于「来回涂抹 / 乱绕大圈 / 疯狂锯齿涂鸦」
      final isWildScribble =
          (sLen > 240 && tortuosity > 6.0) ||
              (sLen > 320 && sharpReversals >= 10 && tortuosity > 4.2) ||
              (sLen > 900 && tortuosity > 3.8);

      if (isWildScribble) {
        scribbleInkLen += sLen;
        severeScribbleStrokeCount++;
      }

      // 正常文字、数字、运算符号的单笔尺寸区间（兼容手机与平板大字）
      if (diag >= 4 && diag <= 220 && !isWildScribble) {
        charLikeStrokeCount++;
      } else if (diag > 280 && tortuosity < 1.35) {
        giantSlashCount++;
      }
    }

    for (final sh in shapes) {
      expandRect(sh.bounds);
    }

    if (!minX.isFinite || !maxX.isFinite) {
      return const BoardHandwritingCheckResult(
        valid: false,
        reason: '未检测到有效手写内容，请先写出一道完整数学题',
      );
    }

    final totalW = (maxX - minX).abs();
    final totalH = (maxY - minY).abs();
    final totalDiag = math.sqrt(totalW * totalW + totalH * totalH);

    // 拦截过小点划区域
    if ((totalW < 55 && totalH < 35) || totalDiag < 70) {
      return BoardHandwritingCheckResult(
        valid: false,
        strokeCount: validStrokes.length,
        shapeCount: shapes.length,
        reason: '书写区域过小，请写清楚完整题目后再识别',
      );
    }

    // 拦截仅有纯点戳（几乎没有有效线条长度）且无几何图元的情况
    if (shapes.isEmpty && totalInkLen < 95) {
      return BoardHandwritingCheckResult(
        valid: false,
        strokeCount: validStrokes.length,
        shapeCount: shapes.length,
        reason: '笔迹内容过于零散，请完整写出一道数学题后再识别',
      );
    }

    final scribbleRatio = totalInkLen > 0 ? scribbleInkLen / totalInkLen : 0.0;

    // 规则 A：涂鸦/乱绕笔画占比过高，或者寥寥几笔却疯狂绕圈
    if (scribbleRatio >= 0.42 ||
        (severeScribbleStrokeCount >= 2 && validStrokes.length <= 12) ||
        (validStrokes.length <= 6 &&
            shapes.isEmpty &&
            totalInkLen / math.max(1.0, totalDiag) > 8.5)) {
      return BoardHandwritingCheckResult(
        valid: false,
        strokeCount: validStrokes.length,
        shapeCount: shapes.length,
        scribbleRatio: scribbleRatio,
        reason: '检测到疑似乱涂乱画的笔迹，请擦除杂乱线条并工整写出完整数学题',
      );
    }

    // 规则 B：仅画了几条横跨全屏的乱线，没有任何类似文字/数字的笔迹
    if (shapes.isEmpty &&
        charLikeStrokeCount == 0 &&
        giantSlashCount >= 3 &&
        validStrokes.length < 10) {
      return BoardHandwritingCheckResult(
        valid: false,
        strokeCount: validStrokes.length,
        shapeCount: shapes.length,
        scribbleRatio: scribbleRatio,
        reason: '未检测到清晰的算式或文字，请写出完整数学题后再点击识别',
      );
    }

    // 规则 C：仅画了几何图形但完全没写任何条件/问题文字（需要至少写一点文字条件或算式）
    if (shapes.isNotEmpty && validStrokes.length < 3) {
      return BoardHandwritingCheckResult(
        valid: false,
        strokeCount: validStrokes.length,
        shapeCount: shapes.length,
        reason: '只画了几何图形还不够，请写出已知条件与所求问题后再识别',
      );
    }

    return BoardHandwritingCheckResult(
      valid: true,
      strokeCount: validStrokes.length,
      shapeCount: shapes.length,
      scribbleRatio: scribbleRatio,
    );
  }
}
