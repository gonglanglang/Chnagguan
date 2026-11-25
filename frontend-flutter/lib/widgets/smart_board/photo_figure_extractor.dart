import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../models/models.dart';

/// 从题目原图中 1:1 精准提取并提纯后的配图数据。
class ExtractedBoardFigure {
  const ExtractedBoardFigure({
    required this.title,
    required this.rawBytes,
    required this.purifiedBytes,
    required this.aspectRatio,
    this.box,
  });

  final String title;
  final Uint8List rawBytes;
  final Uint8List purifiedBytes;
  final double aspectRatio;
  final BoardFigureBox? box;
}

/// 1:1 题目配图裁剪与白板墨迹提纯引擎：
/// - 严格保留原图中几何图形、坐标系、角度标记、弧线与字母标注的 1:1 像素比例；
/// - 通过自适应背景亮度估计，将纸张灰黄底色平滑提纯为干净纯白底，同时保留清晰黑线与彩色标注，
///   支持一键在「白板提纯」与「原图」之间切换。
class PhotoFigureExtractor {
  PhotoFigureExtractor._();

  static Future<List<ExtractedBoardFigure>> extractFromPhoto(
    Uint8List photoBytes,
    List<BoardFigureBox> boxes,
  ) async {
    if (photoBytes.isEmpty || boxes.isEmpty) return const [];
    ui.Image? fullImage;
    try {
      final codec = await ui.instantiateImageCodec(photoBytes);
      final frame = await codec.getNextFrame();
      fullImage = frame.image;

      final out = <ExtractedBoardFigure>[];
      for (final box in boxes) {
        final extracted = await _sliceAndPurify(fullImage, box);
        if (extracted != null) out.add(extracted);
      }
      return out;
    } catch (_) {
      return const [];
    } finally {
      fullImage?.dispose();
    }
  }

  static Future<ExtractedBoardFigure?> buildFromCroppedBytes(
    Uint8List croppedBytes, {
    String title = '原题配图 (1:1)',
    BoardFigureBox? box,
  }) async {
    if (croppedBytes.isEmpty) return null;
    ui.Image? img;
    try {
      final codec = await ui.instantiateImageCodec(croppedBytes);
      final frame = await codec.getNextFrame();
      img = frame.image;
      final aspect = img.height > 0 ? img.width / img.height : 1.0;
      final purified = await _purifyWhiteboardInk(img) ?? croppedBytes;
      return ExtractedBoardFigure(
        title: title,
        rawBytes: croppedBytes,
        purifiedBytes: purified,
        aspectRatio: aspect.clamp(0.25, 4.0),
        box: box,
      );
    } catch (_) {
      return null;
    } finally {
      img?.dispose();
    }
  }

  static Future<ExtractedBoardFigure?> _sliceAndPurify(
    ui.Image fullImage,
    BoardFigureBox box,
  ) async {
    final imgW = fullImage.width.toDouble();
    final imgH = fullImage.height.toDouble();
    // 四周轻微外扩 1.8% 防止切掉顶点字母
    const margin = 0.018;
    final left = ((box.x - margin).clamp(0.0, 0.96)) * imgW;
    final top = ((box.y - margin).clamp(0.0, 0.96)) * imgH;
    final right = ((box.x + box.w + margin).clamp(0.04, 1.0)) * imgW;
    final bottom = ((box.y + box.h + margin).clamp(0.04, 1.0)) * imgH;
    final srcW = right - left;
    final srcH = bottom - top;
    if (srcW < 16 || srcH < 16) return null;

    const maxEdge = 960.0;
    final scale = math.min(1.0, maxEdge / math.max(srcW, srcH));
    final outW = math.max(1, (srcW * scale).round());
    final outH = math.max(1, (srcH * scale).round());

    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    canvas.drawImageRect(
      fullImage,
      ui.Rect.fromLTRB(left, top, right, bottom),
      ui.Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    final pic = rec.endRecording();
    final sliced = await pic.toImage(outW, outH);
    pic.dispose();

    try {
      final rawData = await sliced.toByteData(format: ui.ImageByteFormat.png);
      if (rawData == null) return null;
      final rawBytes = rawData.buffer.asUint8List();
      final purifiedBytes = await _purifyWhiteboardInk(sliced) ?? rawBytes;
      return ExtractedBoardFigure(
        title: box.title.isNotEmpty ? box.title : '原题配图 (1:1)',
        rawBytes: rawBytes,
        purifiedBytes: purifiedBytes,
        aspectRatio: (outW / outH).clamp(0.25, 4.0),
        box: box,
      );
    } finally {
      sliced.dispose();
    }
  }

  /// 自适应白板底色提纯：保留清晰线条与色彩，同时将纸面灰黄阴影提纯为纯白底。
  static Future<Uint8List?> _purifyWhiteboardInk(ui.Image img) async {
    try {
      final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (raw == null) return null;
      final bytes = Uint8List.fromList(raw.buffer.asUint8List());
      final pixelCount = img.width * img.height;
      if (pixelCount <= 0) return null;

      // 采样统计纸张背景亮度（取 82% 分位数作为背景白点）
      final hist = List<int>.filled(256, 0);
      final step = math.max(1, pixelCount ~/ 8000);
      var samples = 0;
      for (var p = 0; p < pixelCount; p += step) {
        final idx = p * 4;
        final lum = ((bytes[idx] * 299 +
                    bytes[idx + 1] * 587 +
                    bytes[idx + 2] * 114) ~/
                1000)
            .clamp(0, 255);
        hist[lum]++;
        samples++;
      }
      var acc = 0;
      var paperWhite = 225;
      final target = (samples * 0.80).round();
      for (var v = 0; v < 256; v++) {
        acc += hist[v];
        if (acc >= target) {
          paperWhite = v.clamp(145, 245);
          break;
        }
      }
      final whiteCut = (paperWhite - 18).clamp(120, 232);
      final blackFloor = (whiteCut * 0.42).round().clamp(30, 110);
      final span = math.max(1, whiteCut - blackFloor);

      for (var i = 0; i < bytes.length; i += 4) {
        final r = bytes[i];
        final g = bytes[i + 1];
        final b = bytes[i + 2];
        final maxC = math.max(r, math.max(g, b));
        final minC = math.min(r, math.min(g, b));
        final sat = maxC - minC;
        final lum = (r * 299 + g * 587 + b * 114) ~/ 1000;

        // 亮灰/米黄纸底直接提纯为纯白
        if (lum >= whiteCut && sat < 34) {
          bytes[i] = 255;
          bytes[i + 1] = 255;
          bytes[i + 2] = 255;
          bytes[i + 3] = 255;
          continue;
        }

        // 彩色辅助线/高亮标注：保留鲜明色相，轻度增强对比
        if (sat >= 42 && lum < whiteCut + 15) {
          bytes[i] = (r * 0.92).round().clamp(0, 255);
          bytes[i + 1] = (g * 0.92).round().clamp(0, 255);
          bytes[i + 2] = (b * 0.92).round().clamp(0, 255);
          bytes[i + 3] = 255;
          continue;
        }

        // 墨迹线条：平滑线性拉伸对比度，消除锯齿同时加深字迹线条
        final t = ((lum - blackFloor) / span).clamp(0.0, 1.0);
        final outVal = (t * t * 255.0).round().clamp(0, 255);
        bytes[i] = outVal;
        bytes[i + 1] = outVal;
        bytes[i + 2] = outVal;
        bytes[i + 3] = 255;
      }

      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        bytes,
        img.width,
        img.height,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      final outImg = await completer.future;
      final png = await outImg.toByteData(format: ui.ImageByteFormat.png);
      outImg.dispose();
      return png?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}
