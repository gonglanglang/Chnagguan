import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../../app/app_theme.dart';
import '../../widgets/ggl_skin_widgets.dart';

/// 裁剪结果：包含裁剪后的 PNG 字节与选区归一化比例。
class PhotoCropResult {
  const PhotoCropResult({
    required this.bytes,
    required this.normalizedRect,
    required this.quarterTurns,
  });

  final Uint8List bytes;
  final Rect normalizedRect;
  final int quarterTurns;
}

enum _CropDragHandle {
  none,
  move,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  top,
  bottom,
  left,
  right,
}

/// 跨端（Android / iOS / Web）交互式拍照选区裁剪页。
/// 支持四角/四边自由拉框、框内拖动平移、90° 旋转、全图重置，
/// 既用于拍照后框选题目范围，也用于手动 1:1 框选题目配图。
class PhotoCropPage extends StatefulWidget {
  const PhotoCropPage({
    super.key,
    required this.imageBytes,
    this.title = '截取题目范围',
    this.confirmLabel = '确认识别',
    this.initialRect,
  });

  final Uint8List imageBytes;
  final String title;
  final String confirmLabel;
  final Rect? initialRect;

  @override
  State<PhotoCropPage> createState() => _PhotoCropPageState();
}

class _PhotoCropPageState extends State<PhotoCropPage> {
  ui.Image? _decodedImage;
  bool _decoding = true;
  bool _cropping = false;
  String? _error;

  int _quarterTurns = 0;

  /// 归一化选区（0.0 ~ 1.0，相对于旋转后的展示图像）
  late Rect _cropNorm;
  Rect _displayImageRect = Rect.zero;

  _CropDragHandle _activeHandle = _CropDragHandle.none;
  Offset _dragStartPos = Offset.zero;
  Rect _dragStartNorm = Rect.zero;

  static const double _minCropFrac = 0.08;

  @override
  void initState() {
    super.initState();
    _cropNorm = widget.initialRect ?? const Rect.fromLTRB(0.05, 0.08, 0.95, 0.92);
    _decode();
  }

  @override
  void dispose() {
    _decodedImage?.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.imageBytes);
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _decodedImage = frame.image;
        _decoding = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '读取图片失败，请重新拍照或选图';
          _decoding = false;
        });
      }
    }
  }

  Size get _rotatedImageSize {
    final img = _decodedImage;
    if (img == null) return const Size(1, 1);
    final odd = _quarterTurns.isOdd;
    return Size(
      (odd ? img.height : img.width).toDouble(),
      (odd ? img.width : img.height).toDouble(),
    );
  }

  Rect _computeImageDisplayRect(Size stageSize) {
    final imgSize = _rotatedImageSize;
    if (stageSize.isEmpty || imgSize.width <= 0 || imgSize.height <= 0) {
      return Rect.zero;
    }
    const pad = 18.0;
    final availW = math.max(40.0, stageSize.width - pad * 2);
    final availH = math.max(40.0, stageSize.height - pad * 2);
    final scale = math.min(availW / imgSize.width, availH / imgSize.height);
    final drawW = imgSize.width * scale;
    final drawH = imgSize.height * scale;
    return Rect.fromLTWH(
      (stageSize.width - drawW) / 2,
      (stageSize.height - drawH) / 2,
      drawW,
      drawH,
    );
  }

  Rect get _cropScreenRect {
    final r = _displayImageRect;
    return Rect.fromLTRB(
      r.left + _cropNorm.left * r.width,
      r.top + _cropNorm.top * r.height,
      r.left + _cropNorm.right * r.width,
      r.top + _cropNorm.bottom * r.height,
    );
  }

  _CropDragHandle _hitTestHandle(Offset localPos) {
    final box = _cropScreenRect;
    if (box.isEmpty) return _CropDragHandle.none;

    const cornerHit = 30.0;
    const edgeHit = 22.0;

    if ((localPos - box.topLeft).distance <= cornerHit) {
      return _CropDragHandle.topLeft;
    }
    if ((localPos - box.topRight).distance <= cornerHit) {
      return _CropDragHandle.topRight;
    }
    if ((localPos - box.bottomLeft).distance <= cornerHit) {
      return _CropDragHandle.bottomLeft;
    }
    if ((localPos - box.bottomRight).distance <= cornerHit) {
      return _CropDragHandle.bottomRight;
    }
    if ((localPos.dy - box.top).abs() <= edgeHit &&
        localPos.dx >= box.left &&
        localPos.dx <= box.right) {
      return _CropDragHandle.top;
    }
    if ((localPos.dy - box.bottom).abs() <= edgeHit &&
        localPos.dx >= box.left &&
        localPos.dx <= box.right) {
      return _CropDragHandle.bottom;
    }
    if ((localPos.dx - box.left).abs() <= edgeHit &&
        localPos.dy >= box.top &&
        localPos.dy <= box.bottom) {
      return _CropDragHandle.left;
    }
    if ((localPos.dx - box.right).abs() <= edgeHit &&
        localPos.dy >= box.top &&
        localPos.dy <= box.bottom) {
      return _CropDragHandle.right;
    }
    if (box.contains(localPos)) {
      return _CropDragHandle.move;
    }
    return _CropDragHandle.none;
  }

  void _onPanStart(DragStartDetails details) {
    final handle = _hitTestHandle(details.localPosition);
    _activeHandle = handle;
    _dragStartPos = details.localPosition;
    _dragStartNorm = _cropNorm;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_activeHandle == _CropDragHandle.none || _displayImageRect.isEmpty) {
      return;
    }
    final dx = (details.localPosition.dx - _dragStartPos.dx) /
        _displayImageRect.width;
    final dy = (details.localPosition.dy - _dragStartPos.dy) /
        _displayImageRect.height;

    var l = _dragStartNorm.left;
    var t = _dragStartNorm.top;
    var r = _dragStartNorm.right;
    var b = _dragStartNorm.bottom;

    switch (_activeHandle) {
      case _CropDragHandle.move:
        final w = r - l;
        final h = b - t;
        l = (l + dx).clamp(0.0, 1.0 - w);
        t = (t + dy).clamp(0.0, 1.0 - h);
        r = l + w;
        b = t + h;
      case _CropDragHandle.topLeft:
        l = (l + dx).clamp(0.0, r - _minCropFrac);
        t = (t + dy).clamp(0.0, b - _minCropFrac);
      case _CropDragHandle.topRight:
        r = (r + dx).clamp(l + _minCropFrac, 1.0);
        t = (t + dy).clamp(0.0, b - _minCropFrac);
      case _CropDragHandle.bottomLeft:
        l = (l + dx).clamp(0.0, r - _minCropFrac);
        b = (b + dy).clamp(t + _minCropFrac, 1.0);
      case _CropDragHandle.bottomRight:
        r = (r + dx).clamp(l + _minCropFrac, 1.0);
        b = (b + dy).clamp(t + _minCropFrac, 1.0);
      case _CropDragHandle.top:
        t = (t + dy).clamp(0.0, b - _minCropFrac);
      case _CropDragHandle.bottom:
        b = (b + dy).clamp(t + _minCropFrac, 1.0);
      case _CropDragHandle.left:
        l = (l + dx).clamp(0.0, r - _minCropFrac);
      case _CropDragHandle.right:
        r = (r + dx).clamp(l + _minCropFrac, 1.0);
      case _CropDragHandle.none:
        return;
    }

    setState(() {
      _cropNorm = Rect.fromLTRB(l, t, r, b);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _activeHandle = _CropDragHandle.none;
  }

  void _rotate90() {
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
      _cropNorm = const Rect.fromLTRB(0.05, 0.08, 0.95, 0.92);
    });
  }

  void _selectFull() {
    setState(() {
      _cropNorm = const Rect.fromLTRB(0.0, 0.0, 1.0, 1.0);
    });
  }

  Future<void> _confirmCrop() async {
    final img = _decodedImage;
    if (img == null || _cropping) return;
    setState(() => _cropping = true);
    try {
      final rotSize = _rotatedImageSize;
      // 1. 若发生旋转，先生成旋转后的完整图
      final ui.Image workingImage;
      final bool shouldDisposeWorking;
      if (_quarterTurns == 0) {
        workingImage = img;
        shouldDisposeWorking = false;
      } else {
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        switch (_quarterTurns) {
          case 1:
            c.translate(rotSize.width, 0);
            c.rotate(math.pi / 2);
          case 2:
            c.translate(rotSize.width, rotSize.height);
            c.rotate(math.pi);
          case 3:
            c.translate(0, rotSize.height);
            c.rotate(-math.pi / 2);
        }
        c.drawImage(img, Offset.zero, Paint()..filterQuality = FilterQuality.high);
        final pic = rec.endRecording();
        workingImage = await pic.toImage(
          rotSize.width.round().clamp(1, 4096),
          rotSize.height.round().clamp(1, 4096),
        );
        pic.dispose();
        shouldDisposeWorking = true;
      }

      // 2. 按归一化选区精确裁剪像素（上限长边 1600px 兼顾 1:1 清晰度与上传速度）
      final srcRect = Rect.fromLTRB(
        (_cropNorm.left * workingImage.width).clamp(0.0, workingImage.width - 1.0),
        (_cropNorm.top * workingImage.height).clamp(0.0, workingImage.height - 1.0),
        (_cropNorm.right * workingImage.width).clamp(1.0, workingImage.width.toDouble()),
        (_cropNorm.bottom * workingImage.height).clamp(1.0, workingImage.height.toDouble()),
      );
      final srcW = math.max(1.0, srcRect.width);
      final srcH = math.max(1.0, srcRect.height);
      const maxDim = 1600.0;
      final scale = math.min(1.0, maxDim / math.max(srcW, srcH));
      final outW = math.max(1, (srcW * scale).round());
      final outH = math.max(1, (srcH * scale).round());

      final cropRec = ui.PictureRecorder();
      final cropCanvas = Canvas(cropRec);
      cropCanvas.drawImageRect(
        workingImage,
        srcRect,
        Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
        Paint()..filterQuality = FilterQuality.high,
      );
      final cropPic = cropRec.endRecording();
      final outImage = await cropPic.toImage(outW, outH);
      cropPic.dispose();
      if (shouldDisposeWorking) {
        workingImage.dispose();
      }
      final byteData = await outImage.toByteData(format: ui.ImageByteFormat.png);
      outImage.dispose();

      if (byteData == null || !mounted) return;
      Navigator.of(context).pop(
        PhotoCropResult(
          bytes: byteData.buffer.asUint8List(),
          normalizedRect: _cropNorm,
          quarterTurns: _quarterTurns,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _cropping = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final overlayStyle = SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Column(
          children: [
            // 顶部安全区栏
            Container(
              color: const Color(0xFF0F172A),
              child: SafeArea(
                top: true,
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      GglButton(
                        label: '取消',
                        variant: WelkButtonVariant.secondary,
                        compact: true,
                        onPressed:
                            _cropping ? null : () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            fontFamilyFallback: AppTheme.cjkFontFallback,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GglButton(
                        label: _cropping ? '裁剪中...' : widget.confirmLabel,
                        variant: WelkButtonVariant.primary,
                        compact: true,
                        onPressed: (_decoding || _cropping || _error != null)
                            ? null
                            : _confirmCrop,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 选区裁剪主视图
            Expanded(
              child: _decoding
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : _error != null
                      ? Center(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final stageSize = Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );
                            _displayImageRect = _computeImageDisplayRect(stageSize);
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanStart: _onPanStart,
                              onPanUpdate: _onPanUpdate,
                              onPanEnd: _onPanEnd,
                              child: CustomPaint(
                                size: stageSize,
                                painter: _PhotoCropOverlayPainter(
                                  image: _decodedImage!,
                                  quarterTurns: _quarterTurns,
                                  imageRect: _displayImageRect,
                                  cropRect: _cropScreenRect,
                                  accent: colors.accent,
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // 底部安全区操作栏
            Container(
              color: const Color(0xFF0F172A),
              child: SafeArea(
                top: false,
                bottom: true,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '拖动四角或边框自由框选目标区域',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GglButton(
                        label: '旋转 90°',
                        icon: Icons.rotate_right_rounded,
                        variant: WelkButtonVariant.secondary,
                        compact: true,
                        onPressed: _cropping ? null : _rotate90,
                      ),
                      const SizedBox(width: 8),
                      GglButton(
                        label: '全图',
                        icon: Icons.crop_free_rounded,
                        variant: WelkButtonVariant.secondary,
                        compact: true,
                        onPressed: _cropping ? null : _selectFull,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoCropOverlayPainter extends CustomPainter {
  const _PhotoCropOverlayPainter({
    required this.image,
    required this.quarterTurns,
    required this.imageRect,
    required this.cropRect,
    required this.accent,
  });

  final ui.Image image;
  final int quarterTurns;
  final Rect imageRect;
  final Rect cropRect;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (imageRect.isEmpty) return;

    // 1. 绘制（可能旋转的）原图
    canvas.save();
    final center = imageRect.center;
    canvas.translate(center.dx, center.dy);
    if (quarterTurns != 0) {
      canvas.rotate(quarterTurns * math.pi / 2);
    }
    final drawW = quarterTurns.isOdd ? imageRect.height : imageRect.width;
    final drawH = quarterTurns.isOdd ? imageRect.width : imageRect.height;
    final dst = Rect.fromCenter(
      center: Offset.zero,
      width: drawW,
      height: drawH,
    );
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();

    // 2. 裁剪框外部暗色遮罩
    final scrimPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(cropRect);
    canvas.drawPath(
      scrimPath,
      Paint()..color = const Color(0xA6000000),
    );

    // 3. 选区九宫格参考线
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.42)
      ..strokeWidth = 0.9;
    final thirdW = cropRect.width / 3;
    final thirdH = cropRect.height / 3;
    for (var i = 1; i <= 2; i++) {
      canvas.drawLine(
        Offset(cropRect.left + thirdW * i, cropRect.top),
        Offset(cropRect.left + thirdW * i, cropRect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(cropRect.left, cropRect.top + thirdH * i),
        Offset(cropRect.right, cropRect.top + thirdH * i),
        gridPaint,
      );
    }

    // 4. 选区外框
    canvas.drawRect(
      cropRect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // 5. 四角高可见度 L 形手柄
    final cornerPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round;
    const len = 20.0;
    // Top-left
    canvas.drawLine(cropRect.topLeft, cropRect.topLeft + const Offset(len, 0), cornerPaint);
    canvas.drawLine(cropRect.topLeft, cropRect.topLeft + const Offset(0, len), cornerPaint);
    // Top-right
    canvas.drawLine(cropRect.topRight, cropRect.topRight + const Offset(-len, 0), cornerPaint);
    canvas.drawLine(cropRect.topRight, cropRect.topRight + const Offset(0, len), cornerPaint);
    // Bottom-left
    canvas.drawLine(cropRect.bottomLeft, cropRect.bottomLeft + const Offset(len, 0), cornerPaint);
    canvas.drawLine(cropRect.bottomLeft, cropRect.bottomLeft + const Offset(0, -len), cornerPaint);
    // Bottom-right
    canvas.drawLine(cropRect.bottomRight, cropRect.bottomRight + const Offset(-len, 0), cornerPaint);
    canvas.drawLine(cropRect.bottomRight, cropRect.bottomRight + const Offset(0, -len), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _PhotoCropOverlayPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.quarterTurns != quarterTurns ||
      oldDelegate.imageRect != imageRect ||
      oldDelegate.cropRect != cropRect ||
      oldDelegate.accent != accent;
}
