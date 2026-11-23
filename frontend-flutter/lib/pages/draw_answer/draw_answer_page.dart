import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../../core/network/api_client.dart';
import '../../core/utils/math_parser.dart';
import '../../models/models.dart';
import '../../services/guoguanla_api.dart';
import '../../widgets/ggl_comic_panel.dart';
import '../../widgets/ggl_feedback.dart';
import '../../widgets/math_text.dart';

class DrawAnswerResult {
  const DrawAnswerResult({
    required this.sessionNo,
    required this.itemIndex,
    required this.answerImageKey,
    required this.answerText,
    required this.feedback,
  });

  final String sessionNo;
  final int itemIndex;
  final String answerImageKey;
  final String answerText;
  final CheckItemResult feedback;
}

class _DrawStroke {
  _DrawStroke({
    required this.color,
    required this.width,
    required this.eraser,
    required this.points,
  });

  final Color color;
  final double width;
  final bool eraser;
  final List<Offset> points;
}

class DrawAnswerPage extends StatefulWidget {
  const DrawAnswerPage({
    super.key,
    required this.sessionNo,
    required this.itemIndex,
    required this.stem,
    this.initialAnswerText = '',
  });

  final String sessionNo;
  final int itemIndex;
  final String stem;
  final String initialAnswerText;

  @override
  State<DrawAnswerPage> createState() => _DrawAnswerPageState();
}

class _DrawAnswerPageState extends State<DrawAnswerPage> {
  static const List<Color> _penColors = <Color>[
    Color(0xFF111827),
    Color(0xFF2563EB),
    Color(0xFFDC2626),
  ];
  static const double _minZoom = 0.25;
  static const double _maxZoom = 3.0;
  static const double _maxExportDim = 1800.0;

  Color _activeColor = _penColors.first;
  bool _eraserMode = false;
  bool _handMode = false;
  bool _saving = false;
  String _extendHint = '';
  Timer? _extendTimer;

  final List<_DrawStroke> _strokes = <_DrawStroke>[];
  _DrawStroke? _activeStroke;

  double _panX = 0;
  double _panY = 0;
  double _zoom = 1.0;

  // Gesture state
  double _gestureStartZoom = 1.0;
  Offset _gestureAnchorWorld = Offset.zero;
  Offset? _singlePanLast;
  bool _isPinching = false;
  Size _canvasSize = Size.zero;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  @override
  void dispose() {
    _extendTimer?.cancel();
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
    }
    super.dispose();
  }

  Offset _screenToWorld(Offset screen) =>
      Offset((screen.dx - _panX) / _zoom, (screen.dy - _panY) / _zoom);

  Offset _worldToScreen(Offset world) =>
      Offset(_panX + world.dx * _zoom, _panY + world.dy * _zoom);

  void _notifyExtend(String msg) {
    _extendTimer?.cancel();
    setState(() => _extendHint = msg);
    _extendTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _extendHint = '');
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (_saving) return;
    final focal = details.localFocalPoint;
    if (details.pointerCount >= 2) {
      _isPinching = true;
      _activeStroke = null;
      _singlePanLast = null;
      _gestureStartZoom = _zoom;
      _gestureAnchorWorld = _screenToWorld(focal);
      return;
    }

    _isPinching = false;
    if (_handMode) {
      _singlePanLast = focal;
    } else {
      final worldPt = _screenToWorld(focal);
      setState(() {
        _activeStroke = _DrawStroke(
          color: _eraserMode ? Colors.white : _activeColor,
          width: _eraserMode ? 18.0 : 3.2,
          eraser: _eraserMode,
          points: <Offset>[worldPt],
        );
      });
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_saving) return;
    final focal = details.localFocalPoint;

    if (details.pointerCount >= 2 || _isPinching) {
      if (!_isPinching) {
        _isPinching = true;
        _activeStroke = null;
        _gestureStartZoom = _zoom;
        _gestureAnchorWorld = _screenToWorld(focal);
        return;
      }
      final nextZoom = (_gestureStartZoom * details.scale).clamp(
        _minZoom,
        _maxZoom,
      );
      setState(() {
        _zoom = nextZoom;
        _panX = focal.dx - _gestureAnchorWorld.dx * nextZoom;
        _panY = focal.dy - _gestureAnchorWorld.dy * nextZoom;
      });
      return;
    }

    if (_handMode && _singlePanLast != null) {
      final delta = focal - _singlePanLast!;
      _singlePanLast = focal;
      setState(() {
        _panX += delta.dx;
        _panY += delta.dy;
      });
      return;
    }

    final stroke = _activeStroke;
    if (stroke != null) {
      final worldPt = _screenToWorld(focal);
      final prev = stroke.points.last;
      final d = worldPt - prev;
      if ((d.dx * d.dx + d.dy * d.dy) * _zoom * _zoom < 2.25) return;
      setState(() => stroke.points.add(worldPt));
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _isPinching = false;
    _singlePanLast = null;

    final finished = _activeStroke;
    if (finished == null) return;
    setState(() {
      if (finished.points.isNotEmpty) {
        _strokes.add(finished);
      }
      _activeStroke = null;
    });

    // Auto-extend infinite canvas when stroke ends near bottom or right edge
    if (!finished.eraser &&
        _canvasSize.width > 0 &&
        _canvasSize.height > 0 &&
        finished.points.isNotEmpty) {
      var maxX = finished.points.first.dx;
      var maxY = finished.points.first.dy;
      for (final p in finished.points) {
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy > maxY) maxY = p.dy;
      }
      final endScreen = _worldToScreen(Offset(maxX, maxY));
      if (endScreen.dy > _canvasSize.height - 44) {
        setState(() => _panY -= (_canvasSize.height * 0.34).roundToDouble());
        _notifyExtend('已自动向下延申书写区');
      } else if (endScreen.dx > _canvasSize.width - 48) {
        setState(() => _panX -= (_canvasSize.width * 0.28).roundToDouble());
        _notifyExtend('已自动向右延申书写区');
      }
    }
  }

  void _resetZoomTo100() {
    if (_canvasSize.isEmpty) return;
    if ((_zoom - 1.0).abs() < 0.01) {
      setState(() {
        _panX = 0;
        _panY = 0;
      });
      return;
    }
    final centerWorld = _screenToWorld(
      Offset(_canvasSize.width / 2, _canvasSize.height / 2),
    );
    setState(() {
      _zoom = 1.0;
      _panX = _canvasSize.width / 2 - centerWorld.dx;
      _panY = _canvasSize.height / 2 - centerWorld.dy;
    });
  }

  void _fitContentOrReset() {
    final inkStrokes =
        _strokes.where((s) => !s.eraser && s.points.isNotEmpty).toList();
    if (inkStrokes.isEmpty || _canvasSize.isEmpty) {
      setState(() {
        _zoom = 1.0;
        _panX = 0;
        _panY = 0;
      });
      return;
    }
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final s in inkStrokes) {
      for (final p in s.points) {
        if (p.dx < minX) minX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy > maxY) maxY = p.dy;
      }
    }
    const pad = 40.0;
    final boxW = math.max(120.0, maxX - minX + pad * 2);
    final boxH = math.max(100.0, maxY - minY + pad * 2);
    final nextZoom = math
        .min(1.2, math.min(_canvasSize.width / boxW, _canvasSize.height / boxH))
        .clamp(_minZoom, _maxZoom);
    setState(() {
      _zoom = nextZoom;
      _panX = _canvasSize.width / 2 - ((minX + maxX) / 2) * _zoom;
      _panY = _canvasSize.height / 2 - ((minY + maxY) / 2) * _zoom;
    });
  }

  Future<Uint8List> _renderStrokesToPng() async {
    final inkStrokes =
        _strokes.where((s) => !s.eraser && s.points.isNotEmpty).toList();
    if (inkStrokes.isEmpty) {
      throw const ApiException('请先在画板上书写解题过程');
    }

    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final s in inkStrokes) {
      for (final p in s.points) {
        if (p.dx < minX) minX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy > maxY) maxY = p.dy;
      }
    }

    const pad = 36.0;
    final rawW = math.max(480.0, maxX - minX + pad * 2);
    final rawH = math.max(300.0, maxY - minY + pad * 2);
    final scale = math.min(
      2.0,
      math.min(_maxExportDim / rawW, _maxExportDim / rawH),
    );
    final outW = math.max(1, (rawW * scale).round());
    final outH = math.max(1, (rawH * scale).round());

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
      Paint()..color = Colors.white,
    );

    final offsetX = pad - minX;
    final offsetY = pad - minY;
    for (final s in _strokes) {
      if (s.points.isEmpty) continue;
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = math.max(1.2, s.width * scale)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (s.points.length == 1) {
        final p = Offset(
          (s.points.first.dx + offsetX) * scale,
          (s.points.first.dy + offsetY) * scale,
        );
        canvas.drawCircle(
          p,
          math.max(1.0, s.width * scale / 2),
          Paint()..color = s.color,
        );
      } else {
        final path = Path()
          ..moveTo(
            (s.points.first.dx + offsetX) * scale,
            (s.points.first.dy + offsetY) * scale,
          );
        for (var i = 1; i < s.points.length; i++) {
          path.lineTo(
            (s.points[i].dx + offsetX) * scale,
            (s.points[i].dy + offsetY) * scale,
          );
        }
        canvas.drawPath(path, paint);
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(outW, outH);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) {
      throw const ApiException('生成手写作答图片失败');
    }
    return byteData.buffer.asUint8List();
  }

  Future<void> _handleSave() async {
    if (_saving) return;
    if (_strokes.every((s) => s.eraser)) {
      GglFeedback.warning(context, '请先在画板上书写解题过程');
      return;
    }

    setState(() => _saving = true);
    try {
      final pngBytes = await _renderStrokesToPng();
      if (!mounted) return;
      final api = context.read<GuoguanlaApi>();
      final uploadRes = await api.uploadAnswerImageBytes(
        bytes: pngBytes,
        sessionNo: widget.sessionNo,
        itemIndex: widget.itemIndex,
      );
      final checkRes = await api.checkItem(
        sessionNo: widget.sessionNo,
        itemIndex: widget.itemIndex,
        answerText: widget.initialAnswerText,
        answerImageKey: uploadRes.objectKey,
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        DrawAnswerResult(
          sessionNo: widget.sessionNo,
          itemIndex: widget.itemIndex,
          answerImageKey: uploadRes.objectKey,
          answerText: widget.initialAnswerText,
          feedback: checkRes,
        ),
      );
    } catch (e) {
      if (mounted) {
        GglFeedback.error(context, friendlyErrorMessage(e, '保存手写作答失败'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showStemDialog() {
    showWelkDialog<void>(
      context: context,
      closeOnTapOutside: true,
      builder: (ctx) => WelkDialog(
        title: const Text('当前题目'),
        variant: WelkDialogVariant.info,
        buttonText: '收起',
        onClose: () => Navigator.of(ctx).pop(),
        onPressed: () => Navigator.of(ctx).pop(),
        child: MathText(widget.stem),
      ),
    );
  }

  Future<void> _handleBack() async {
    if (_strokes.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final ok = await GglFeedback.confirm(
      context,
      title: '放弃手写内容？',
      content: '当前笔迹尚未保存上传，确定返回吗？',
      yesText: '放弃并返回',
      noText: '继续书写',
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final plainStem = MathParser.renderPlainText(widget.stem);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Compact comic toolbar
            Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: colors.paper,
                border: Border(
                  bottom: BorderSide(
                    color: colors.outline,
                    width: colors.borderWidth,
                  ),
                ),
              ),
              child: Row(
                children: [
                  WelkButton(
                    size: WelkButtonSize.small,
                    variant: WelkButtonVariant.secondary,
                    onPressed: _saving ? null : _handleBack,
                    child: const Text('返回'),
                  ),
                  const SizedBox(width: 8),
                  if (plainStem.isNotEmpty)
                    Expanded(
                      child: GestureDetector(
                        onTap: _showStemDialog,
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: colors.muted,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: colors.outline,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              const GglStatusTag(
                                label: '题干',
                                variant: WelkBadgeVariant.info,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  plainStem,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.ink,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  const SizedBox(width: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final c in _penColors)
                          GestureDetector(
                            onTap: () => setState(() {
                              _activeColor = c;
                              _eraserMode = false;
                              _handMode = false;
                            }),
                            child: Container(
                              width: 24,
                              height: 24,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: !_handMode &&
                                          !_eraserMode &&
                                          _activeColor == c
                                      ? colors.accent
                                      : colors.outline,
                                  width: !_handMode &&
                                          !_eraserMode &&
                                          _activeColor == c
                                      ? 3
                                      : 1.5,
                                ),
                              ),
                            ),
                          ),
                        _ToolChip(
                          label: '移动',
                          active: _handMode,
                          onTap: () => setState(() {
                            _handMode = !_handMode;
                            if (_handMode) _eraserMode = false;
                          }),
                        ),
                        const SizedBox(width: 4),
                        _ToolChip(
                          label: '橡皮',
                          active: !_handMode && _eraserMode,
                          onTap: () => setState(() {
                            _eraserMode = !_eraserMode;
                            if (_eraserMode) _handMode = false;
                          }),
                        ),
                        const SizedBox(width: 4),
                        _ToolChip(
                          label: '撤销',
                          active: false,
                          disabled: _strokes.isEmpty || _saving,
                          onTap: () => setState(() {
                            if (_strokes.isNotEmpty) _strokes.removeLast();
                          }),
                        ),
                        const SizedBox(width: 4),
                        _ToolChip(
                          label: '清空',
                          active: false,
                          disabled: _strokes.isEmpty || _saving,
                          onTap: () => setState(() {
                            _strokes.clear();
                            _activeStroke = null;
                          }),
                        ),
                        const SizedBox(width: 6),
                        WelkButton(
                          size: WelkButtonSize.small,
                          variant: WelkButtonVariant.success,
                          onPressed: _saving ? null : _handleSave,
                          child: Text(_saving ? '保存中...' : '完成保存'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Infinite white canvas stage
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _canvasSize = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  return Stack(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onScaleStart: _onScaleStart,
                        onScaleUpdate: _onScaleUpdate,
                        onScaleEnd: _onScaleEnd,
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _InfiniteBoardPainter(
                            strokes: _strokes,
                            activeStroke: _activeStroke,
                            panX: _panX,
                            panY: _panY,
                            zoom: _zoom,
                          ),
                        ),
                      ),
                      if (_strokes.isEmpty && _activeStroke == null && !_handMode)
                        const IgnorePointer(
                          child: Center(
                            child: Text(
                              '无限纯白画板 · 写至边缘自动扩展 · 双指缩放拖动',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ),

                      // Bottom-left zoom & fit HUD
                      Positioned(
                        left: 12,
                        bottom: 12,
                        child: GglComicPanel(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          shadowOffset: const Offset(2, 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: _resetZoomTo100,
                                child: Text(
                                  '${(_zoom * 100).round()}%',
                                  style: TextStyle(
                                    color: colors.ink,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Container(
                                width: 1.5,
                                height: 14,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                color: colors.outline.withValues(alpha: 0.4),
                              ),
                              GestureDetector(
                                onTap: _fitContentOrReset,
                                child: Icon(
                                  Icons.fit_screen_rounded,
                                  size: 16,
                                  color: colors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_extendHint.isNotEmpty)
                        Positioned(
                          bottom: 14,
                          right: 14,
                          child: GglStatusTag(
                            label: _extendHint,
                            variant: WelkBadgeVariant.info,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.disabled = false,
  });

  final String label;
  final bool active;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    return Opacity(
      opacity: disabled ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? colors.accent : colors.paper,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.outline, width: 1.6),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? colors.onFill(colors.accent) : colors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfiniteBoardPainter extends CustomPainter {
  const _InfiniteBoardPainter({
    required this.strokes,
    required this.activeStroke,
    required this.panX,
    required this.panY,
    required this.zoom,
  });

  final List<_DrawStroke> strokes;
  final _DrawStroke? activeStroke;
  final double panX;
  final double panY;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);

    // Subtle grid dots for spatial reference while panning
    const step = 40.0;
    final scaledStep = step * zoom;
    if (scaledStep >= 16) {
      final dotPaint = Paint()..color = const Color(0xFFE5E7EB);
      final startX = panX % scaledStep;
      final startY = panY % scaledStep;
      for (var x = startX; x < size.width; x += scaledStep) {
        for (var y = startY; y < size.height; y += scaledStep) {
          canvas.drawCircle(Offset(x, y), 1.0, dotPaint);
        }
      }
    }

    void drawOne(_DrawStroke s) {
      if (s.points.isEmpty) return;
      final sw = math.max(1.0, s.width * zoom);
      if (s.points.length == 1) {
        final sp = Offset(
          panX + s.points.first.dx * zoom,
          panY + s.points.first.dy * zoom,
        );
        canvas.drawCircle(sp, sw / 2, Paint()..color = s.color);
        return;
      }
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(
          panX + s.points.first.dx * zoom,
          panY + s.points.first.dy * zoom,
        );
      for (var i = 1; i < s.points.length; i++) {
        path.lineTo(
          panX + s.points[i].dx * zoom,
          panY + s.points[i].dy * zoom,
        );
      }
      canvas.drawPath(path, paint);
    }

    for (final s in strokes) {
      drawOne(s);
    }
    if (activeStroke != null) {
      drawOne(activeStroke!);
    }
  }

  @override
  bool shouldRepaint(_InfiniteBoardPainter oldDelegate) => true;
}
