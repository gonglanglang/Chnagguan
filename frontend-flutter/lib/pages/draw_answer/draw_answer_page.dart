import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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
import '../../widgets/smart_board/board_models.dart';
import '../../widgets/smart_board/smart_board_painter.dart';

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

/// 闯关解答题横屏手写画板（复用新一代矢量平滑画板引擎：
/// 二次贝塞尔平滑笔迹、Undo/Redo、5色3粗细、荧光笔、笔画橡皮、几何辅助线与坐标系、4种纸张切换）。
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
    Color(0xFF059669),
    Color(0xFFD97706),
  ];
  static const List<double> _strokeWidths = <double>[2.2, 3.4, 5.4];
  static const List<String> _strokeLabels = <String>['细', '中', '粗'];
  static const double _minZoom = 0.25;
  static const double _maxZoom = 3.0;
  static const int _maxHistory = 50;

  Color _activeColor = _penColors.first;
  int _widthIdx = 1;
  BoardToolMode _tool = BoardToolMode.pen;
  BoardShapeKind _lastShapeKind = BoardShapeKind.line;
  BoardPaperStyle _paperStyle = BoardPaperStyle.dots;
  bool _showShapePicker = false;
  bool _saving = false;
  String _extendHint = '';
  Timer? _extendTimer;

  final List<BoardStroke> _strokes = <BoardStroke>[];
  final List<BoardShape> _shapes = <BoardShape>[];
  final List<BoardUndoSnapshot> _undoStack = <BoardUndoSnapshot>[];
  final List<BoardUndoSnapshot> _redoStack = <BoardUndoSnapshot>[];
  BoardStroke? _activeStroke;
  BoardShape? _activeShape;
  bool _erasedDuringDrag = false;
  Offset? _eraserCursorWorld;

  double _panX = 0;
  double _panY = 0;
  double _zoom = 1.0;

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

  bool get _hasContent =>
      _strokes.any((s) => !s.isEraser && s.points.isNotEmpty) ||
      _shapes.isNotEmpty;

  bool get _isShapeTool =>
      _tool == BoardToolMode.line ||
      _tool == BoardToolMode.dashedLine ||
      _tool == BoardToolMode.arrow ||
      _tool == BoardToolMode.rect ||
      _tool == BoardToolMode.oval ||
      _tool == BoardToolMode.axes;

  BoardShapeKind _shapeKindForTool(BoardToolMode t) => switch (t) {
        BoardToolMode.line => BoardShapeKind.line,
        BoardToolMode.dashedLine => BoardShapeKind.dashedLine,
        BoardToolMode.arrow => BoardShapeKind.arrow,
        BoardToolMode.rect => BoardShapeKind.rect,
        BoardToolMode.oval => BoardShapeKind.oval,
        BoardToolMode.axes => BoardShapeKind.axes,
        _ => _lastShapeKind,
      };

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

  void _pushUndoCheckpoint() {
    _undoStack.add(BoardUndoSnapshot.capture(_strokes, _shapes));
    if (_undoStack.length > _maxHistory) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _handleUndo() {
    if (_undoStack.isEmpty || _saving) return;
    _redoStack.add(BoardUndoSnapshot.capture(_strokes, _shapes));
    final prev = _undoStack.removeLast();
    setState(() {
      _strokes
        ..clear()
        ..addAll(prev.strokes);
      _shapes
        ..clear()
        ..addAll(prev.shapes);
      _activeStroke = null;
      _activeShape = null;
    });
  }

  void _handleRedo() {
    if (_redoStack.isEmpty || _saving) return;
    _undoStack.add(BoardUndoSnapshot.capture(_strokes, _shapes));
    final next = _redoStack.removeLast();
    setState(() {
      _strokes
        ..clear()
        ..addAll(next.strokes);
      _shapes
        ..clear()
        ..addAll(next.shapes);
      _activeStroke = null;
      _activeShape = null;
    });
  }

  void _eraseAtWorld(Offset worldPt) {
    final threshold = 16.0 / math.max(0.35, _zoom);
    final strokeIdx = _strokes.lastIndexWhere((s) => s.hitTest(worldPt, threshold));
    if (strokeIdx >= 0) {
      if (!_erasedDuringDrag) {
        _pushUndoCheckpoint();
        _erasedDuringDrag = true;
      }
      setState(() => _strokes.removeAt(strokeIdx));
      return;
    }
    final shapeIdx = _shapes.lastIndexWhere((sh) => sh.hitTest(worldPt, threshold));
    if (shapeIdx >= 0) {
      if (!_erasedDuringDrag) {
        _pushUndoCheckpoint();
        _erasedDuringDrag = true;
      }
      setState(() => _shapes.removeAt(shapeIdx));
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (_saving) return;
    if (_showShapePicker) setState(() => _showShapePicker = false);

    final focal = details.localFocalPoint;
    if (details.pointerCount >= 2) {
      _isPinching = true;
      _activeStroke = null;
      _activeShape = null;
      _eraserCursorWorld = null;
      _singlePanLast = null;
      _gestureStartZoom = _zoom;
      _gestureAnchorWorld = _screenToWorld(focal);
      return;
    }

    _isPinching = false;
    final worldPt = _screenToWorld(focal);
    if (_tool == BoardToolMode.hand) {
      _singlePanLast = focal;
      return;
    }
    if (_tool == BoardToolMode.strokeEraser) {
      _erasedDuringDrag = false;
      setState(() => _eraserCursorWorld = worldPt);
      _eraseAtWorld(worldPt);
      return;
    }
    if (_isShapeTool) {
      setState(() {
        _activeShape = BoardShape(
          kind: _shapeKindForTool(_tool),
          start: worldPt,
          end: worldPt,
          colorValue: _activeColor.toARGB32(),
          width: math.max(2.2, _strokeWidths[_widthIdx] * 0.9),
        );
      });
      return;
    }

    final isHighlighter = _tool == BoardToolMode.highlighter;
    setState(() {
      _activeStroke = BoardStroke(
        colorValue: _activeColor.toARGB32(),
        width: isHighlighter ? 15.0 : _strokeWidths[_widthIdx],
        isHighlighter: isHighlighter,
        points: <Offset>[worldPt],
      );
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_saving) return;
    final focal = details.localFocalPoint;

    if (details.pointerCount >= 2 || _isPinching) {
      if (!_isPinching) {
        _isPinching = true;
        _activeStroke = null;
        _activeShape = null;
        _eraserCursorWorld = null;
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

    if (_tool == BoardToolMode.hand && _singlePanLast != null) {
      final delta = focal - _singlePanLast!;
      _singlePanLast = focal;
      setState(() {
        _panX += delta.dx;
        _panY += delta.dy;
      });
      return;
    }

    if (_tool == BoardToolMode.strokeEraser) {
      final worldPt = _screenToWorld(focal);
      setState(() => _eraserCursorWorld = worldPt);
      _eraseAtWorld(worldPt);
      return;
    }

    final shape = _activeShape;
    if (shape != null) {
      final worldPt = _screenToWorld(focal);
      setState(() {
        _activeShape = BoardShape(
          kind: shape.kind,
          start: shape.start,
          end: worldPt,
          colorValue: shape.colorValue,
          width: shape.width,
        );
      });
      return;
    }

    final stroke = _activeStroke;
    if (stroke != null) {
      final worldPt = _screenToWorld(focal);
      final prev = stroke.points.last;
      final d = worldPt - prev;
      if ((d.dx * d.dx + d.dy * d.dy) * _zoom * _zoom < 2.0) return;
      setState(() => stroke.points.add(worldPt));
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _isPinching = false;
    _singlePanLast = null;

    if (_eraserCursorWorld != null) {
      _erasedDuringDrag = false;
      setState(() => _eraserCursorWorld = null);
      return;
    }

    final finishedShape = _activeShape;
    if (finishedShape != null) {
      if ((finishedShape.end - finishedShape.start).distance >= 6) {
        _pushUndoCheckpoint();
        setState(() {
          _shapes.add(finishedShape);
          _activeShape = null;
        });
      } else {
        setState(() => _activeShape = null);
      }
      return;
    }

    final finished = _activeStroke;
    if (finished == null) return;
    _pushUndoCheckpoint();
    setState(() {
      if (finished.points.isNotEmpty) {
        _strokes.add(finished);
      }
      _activeStroke = null;
    });

    if (!finished.isEraser &&
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

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final factor = event.scrollDelta.dy > 0 ? 0.90 : 1.11;
      final anchor = _screenToWorld(event.localPosition);
      final nextZoom = (_zoom * factor).clamp(_minZoom, _maxZoom);
      setState(() {
        _zoom = nextZoom;
        _panX = event.localPosition.dx - anchor.dx * _zoom;
        _panY = event.localPosition.dy - anchor.dy * _zoom;
      });
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
    if (!_hasContent || _canvasSize.isEmpty) {
      setState(() {
        _zoom = 1.0;
        _panX = 0;
        _panY = 0;
      });
      return;
    }
    Rect? union;
    for (final s in _strokes) {
      if (s.isEraser) continue;
      final b = s.bounds;
      if (b != null) union = union == null ? b : union.expandToInclude(b);
    }
    for (final sh in _shapes) {
      union = union == null ? sh.bounds : union.expandToInclude(sh.bounds);
    }
    if (union == null) return;
    const pad = 40.0;
    final boxW = math.max(120.0, union.width + pad * 2);
    final boxH = math.max(100.0, union.height + pad * 2);
    final nextZoom = math
        .min(1.2, math.min(_canvasSize.width / boxW, _canvasSize.height / boxH))
        .clamp(_minZoom, _maxZoom);
    setState(() {
      _zoom = nextZoom;
      _panX = _canvasSize.width / 2 - union!.center.dx * _zoom;
      _panY = _canvasSize.height / 2 - union.center.dy * _zoom;
    });
  }

  Future<void> _handleSave() async {
    if (_saving) return;
    if (!_hasContent) {
      GglFeedback.warning(context, '请先在画板上书写解题过程');
      return;
    }

    setState(() => _saving = true);
    try {
      final pngBytes = await renderSmartBoardToPng(
        strokes: _strokes,
        shapes: _shapes,
        includeProblemCard: false,
        includeAiCards: false,
        maxDimension: 1800,
      );
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
    if (!_hasContent) {
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

  void _cyclePaperStyle() {
    const order = BoardPaperStyle.values;
    final next = order[(order.indexOf(_paperStyle) + 1) % order.length];
    setState(() => _paperStyle = next);
    final label = switch (next) {
      BoardPaperStyle.dots => '点阵纸',
      BoardPaperStyle.grid => '方格纸',
      BoardPaperStyle.lined => '横线纸',
      BoardPaperStyle.plain => '纯白纸',
    };
    _notifyExtend('已切换：$label');
  }

  String _shapeLabel(BoardShapeKind kind) => switch (kind) {
        BoardShapeKind.line => '直线',
        BoardShapeKind.dashedLine => '辅助线',
        BoardShapeKind.arrow => '箭头',
        BoardShapeKind.rect => '矩形',
        BoardShapeKind.oval => '圆',
        BoardShapeKind.axes => '坐标系',
      };

  BoardToolMode _toolForShape(BoardShapeKind kind) => switch (kind) {
        BoardShapeKind.line => BoardToolMode.line,
        BoardShapeKind.dashedLine => BoardToolMode.dashedLine,
        BoardShapeKind.arrow => BoardToolMode.arrow,
        BoardShapeKind.rect => BoardToolMode.rect,
        BoardShapeKind.oval => BoardToolMode.oval,
        BoardShapeKind.axes => BoardToolMode.axes,
      };

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final plainStem = MathParser.renderPlainText(widget.stem);

    return Scaffold(
      backgroundColor: const Color(0xFFFCFDFF),
      body: SafeArea(
        child: Column(
          children: [
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
                  WelkButton(
                    size: WelkButtonSize.small,
                    variant: WelkButtonVariant.success,
                    onPressed: _saving ? null : _handleSave,
                    child: Text(_saving ? '保存中...' : '完成保存'),
                  ),
                ],
              ),
            ),

            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _canvasSize = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  return Stack(
                    children: [
                      Listener(
                        onPointerSignal: _onPointerSignal,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onScaleStart: _onScaleStart,
                          onScaleUpdate: _onScaleUpdate,
                          onScaleEnd: _onScaleEnd,
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: SmartBoardPainter(
                              strokes: _strokes,
                              shapes: _shapes,
                              activeStroke: _activeStroke,
                              activeShape: _activeShape,
                              panX: _panX,
                              panY: _panY,
                              zoom: _zoom,
                              paperStyle: _paperStyle,
                              eraserCursorWorld: _eraserCursorWorld,
                              eraserCursorRadius: 16.0 / math.max(0.4, _zoom),
                            ),
                          ),
                        ),
                      ),
                      if (!_hasContent &&
                          _activeStroke == null &&
                          _activeShape == null &&
                          _tool != BoardToolMode.hand)
                        const IgnorePointer(
                          child: Center(
                            child: Text(
                              '平滑手写画板 · 写至边缘自动延申 · 支持几何辅助线与双指缩放',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ),

                      if (_showShapePicker)
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: 12,
                          child: Center(
                            child: GglComicPanel(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              shadowOffset: const Offset(2, 2),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final kind in BoardShapeKind.values)
                                    _ToolChip(
                                      label: _shapeLabel(kind),
                                      active: _isShapeTool &&
                                          _shapeKindForTool(_tool) == kind,
                                      onTap: () => setState(() {
                                        _lastShapeKind = kind;
                                        _tool = _toolForShape(kind);
                                        _showShapePicker = false;
                                      }),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),

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

            // Bottom professional brush & geometry dock
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: colors.paper,
                border: Border(
                  top: BorderSide(
                    color: colors.outline,
                    width: colors.borderWidth,
                  ),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final c in _penColors)
                      GestureDetector(
                        onTap: () => setState(() {
                          _activeColor = c;
                          if (_tool == BoardToolMode.strokeEraser ||
                              _tool == BoardToolMode.hand) {
                            _tool = BoardToolMode.pen;
                          }
                        }),
                        child: Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: (_tool == BoardToolMode.pen ||
                                          _tool == BoardToolMode.highlighter ||
                                          _isShapeTool) &&
                                      _activeColor == c
                                  ? colors.accent
                                  : colors.outline,
                              width: (_tool == BoardToolMode.pen ||
                                          _tool == BoardToolMode.highlighter ||
                                          _isShapeTool) &&
                                      _activeColor == c
                                  ? 3
                                  : 1.5,
                            ),
                          ),
                        ),
                      ),
                    _ToolChip(
                      label: '粗细:${_strokeLabels[_widthIdx]}',
                      active: false,
                      onTap: () => setState(
                        () => _widthIdx = (_widthIdx + 1) % _strokeWidths.length,
                      ),
                    ),
                    const SizedBox(width: 5),
                    _ToolChip(
                      label: '荧光',
                      active: _tool == BoardToolMode.highlighter,
                      onTap: () => setState(() {
                        _tool = _tool == BoardToolMode.highlighter
                            ? BoardToolMode.pen
                            : BoardToolMode.highlighter;
                        _showShapePicker = false;
                      }),
                    ),
                    const SizedBox(width: 5),
                    _ToolChip(
                      label: _isShapeTool
                          ? '图形:${_shapeLabel(_shapeKindForTool(_tool))}'
                          : '几何图形',
                      active: _isShapeTool || _showShapePicker,
                      onTap: () => setState(
                        () => _showShapePicker = !_showShapePicker,
                      ),
                    ),
                    const SizedBox(width: 5),
                    _ToolChip(
                      label: '纸张',
                      active: false,
                      onTap: _cyclePaperStyle,
                    ),
                    const SizedBox(width: 5),
                    _ToolChip(
                      label: '移动',
                      active: _tool == BoardToolMode.hand,
                      onTap: () => setState(() {
                        _tool = _tool == BoardToolMode.hand
                            ? BoardToolMode.pen
                            : BoardToolMode.hand;
                        _showShapePicker = false;
                      }),
                    ),
                    const SizedBox(width: 5),
                    _ToolChip(
                      label: '笔画擦',
                      active: _tool == BoardToolMode.strokeEraser,
                      onTap: () => setState(() {
                        _tool = _tool == BoardToolMode.strokeEraser
                            ? BoardToolMode.pen
                            : BoardToolMode.strokeEraser;
                        _showShapePicker = false;
                      }),
                    ),
                    const SizedBox(width: 5),
                    _ToolChip(
                      label: '撤销',
                      active: false,
                      disabled: _undoStack.isEmpty || _saving,
                      onTap: _handleUndo,
                    ),
                    const SizedBox(width: 5),
                    _ToolChip(
                      label: '重做',
                      active: false,
                      disabled: _redoStack.isEmpty || _saving,
                      onTap: _handleRedo,
                    ),
                    const SizedBox(width: 5),
                    _ToolChip(
                      label: '清空',
                      active: false,
                      disabled: !_hasContent || _saving,
                      onTap: () {
                        _pushUndoCheckpoint();
                        setState(() {
                          _strokes.clear();
                          _shapes.clear();
                          _activeStroke = null;
                          _activeShape = null;
                        });
                      },
                    ),
                  ],
                ),
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
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: active ? colors.accent : colors.paper,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.outline, width: 1.5),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? colors.onFill(colors.accent) : colors.ink,
              fontSize: 11.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
