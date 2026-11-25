import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../../app/app_theme.dart';
import '../../core/cache/global_cache.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/math_parser.dart';
import '../../models/models.dart';
import '../../services/guoguanla_api.dart';
import '../../widgets/ggl_comic_panel.dart';
import '../../widgets/ggl_feedback.dart';
import '../../widgets/smart_board/board_models.dart';
import '../../widgets/smart_board/smart_board_painter.dart';

/// 首页独立「AI 智能手写画板」：
/// 支持拍照/相册识别数学题自动绘制到画板、AI 生成解题思路绘制到画板、
/// AI 结合手写过程分析并绘制规范解题板书，同时配备专业级手写与几何绘图体验。
class SmartBoardPage extends StatefulWidget {
  const SmartBoardPage({
    super.key,
    this.autoOpenCapture = false,
  });

  final bool autoOpenCapture;

  @override
  State<SmartBoardPage> createState() => _SmartBoardPageState();
}

class _SmartBoardPageState extends State<SmartBoardPage>
    with TickerProviderStateMixin {
  static const List<Color> _penColors = <Color>[
    Color(0xFF111827), // 墨黑
    Color(0xFF2563EB), // 宝蓝
    Color(0xFFDC2626), // 批注红
    Color(0xFF059669), // 翠绿
    Color(0xFFD97706), // 橘橙
  ];
  static const List<double> _strokeWidths = <double>[2.2, 3.4, 5.4];
  static const List<String> _strokeLabels = <String>['细', '中', '粗'];
  static const double _minZoom = 0.25;
  static const double _maxZoom = 3.0;
  static const int _maxHistory = 60;

  final ImagePicker _picker = ImagePicker();

  // 画板数据与历史栈
  final List<BoardStroke> _strokes = <BoardStroke>[];
  final List<BoardShape> _shapes = <BoardShape>[];
  final List<BoardUndoSnapshot> _undoStack = <BoardUndoSnapshot>[];
  final List<BoardUndoSnapshot> _redoStack = <BoardUndoSnapshot>[];

  BoardStroke? _activeStroke;
  BoardShape? _activeShape;
  bool _erasedDuringDrag = false;
  Offset? _eraserCursorWorld;

  // 工具与偏好
  BoardToolMode _tool = BoardToolMode.pen;
  BoardShapeKind _lastShapeKind = BoardShapeKind.line;
  Color _activeColor = _penColors.first;
  int _widthIdx = 1;
  BoardPaperStyle _paperStyle = BoardPaperStyle.dots;
  bool _isLandscape = false;
  bool _showShapePicker = false;

  // AI 状态与板书卡片
  AiBoardStatus? _aiStatus;
  SmartBoardCardState _cards = const SmartBoardCardState();
  BoardLayerVisibility _visibility = const BoardLayerVisibility();
  Uint8List? _problemPhotoBytes;
  ui.Image? _problemPhotoImage;
  bool _busyAi = false;
  String _busyAiLabel = '';

  // 逐行板书书写动画
  late final AnimationController _ideasRevealCtrl;
  late final AnimationController _solutionRevealCtrl;

  // 视口变换（世界坐标 -> 屏幕坐标）
  double _panX = 0;
  double _panY = 0;
  double _zoom = 1.0;
  Size _canvasSize = Size.zero;

  // 手势状态
  double _gestureStartZoom = 1.0;
  Offset _gestureAnchorWorld = Offset.zero;
  Offset? _singlePanLast;
  bool _isPinching = false;
  BoardCardId? _draggingCardId;
  Offset? _cardDragLastWorld;

  // 提示与防抖草稿保存
  String _floatingHint = '';
  Timer? _hintTimer;
  Timer? _draftSaveTimer;

  @override
  void initState() {
    super.initState();
    _ideasRevealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
      value: 1.0,
    )..addListener(() {
        if (mounted) setState(() {});
      });
    _solutionRevealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
      value: 1.0,
    )..addListener(() {
        if (mounted) setState(() {});
      });

    _restorePrefsAndDraft();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadAiStatus());
      if (widget.autoOpenCapture && mounted) {
        unawaited(_openProblemCaptureSheet());
      }
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _draftSaveTimer?.cancel();
    _ideasRevealCtrl.dispose();
    _solutionRevealCtrl.dispose();
    _problemPhotoImage?.dispose();
    if (!kIsWeb && _isLandscape) {
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
    }
    super.dispose();
  }

  void _restorePrefsAndDraft() {
    try {
      final cache = context.read<GlobalCache>();
      final prefs = cache.smartBoardPrefs;
      final paperName = prefs['paper']?.toString();
      if (paperName != null) {
        _paperStyle = BoardPaperStyle.values.firstWhere(
          (p) => p.name == paperName,
          orElse: () => BoardPaperStyle.dots,
        );
      }
      final wIdx = prefs['widthIdx'];
      if (wIdx is int && wIdx >= 0 && wIdx < _strokeWidths.length) {
        _widthIdx = wIdx;
      }

      final draft = cache.smartBoardDraft;
      if (draft != null) {
        final rawStrokes = draft['strokes'];
        if (rawStrokes is List) {
          for (final item in rawStrokes) {
            if (item is Map<String, dynamic>) {
              final s = BoardStroke.fromJson(item);
              if (s != null) _strokes.add(s);
            }
          }
        }
        final rawShapes = draft['shapes'];
        if (rawShapes is List) {
          for (final item in rawShapes) {
            if (item is Map<String, dynamic>) {
              final sh = BoardShape.fromJson(item);
              if (sh != null) _shapes.add(sh);
            }
          }
        }
        AiRecognizeResult? problem;
        if (draft['problem'] is Map<String, dynamic>) {
          problem = AiRecognizeResult.fromJson(
            draft['problem'] as Map<String, dynamic>,
          );
        }
        AiBoardGuidance? ideas;
        if (draft['ideas'] is Map<String, dynamic>) {
          ideas = AiBoardGuidance.fromJson(
            draft['ideas'] as Map<String, dynamic>,
          );
        }
        AiBoardGuidance? solution;
        if (draft['solution'] is Map<String, dynamic>) {
          solution = AiBoardGuidance.fromJson(
            draft['solution'] as Map<String, dynamic>,
          );
        }
        Offset readOffset(String key, Offset fallback) {
          final v = draft[key];
          if (v is List && v.length >= 2) {
            final dx = (v[0] as num?)?.toDouble();
            final dy = (v[1] as num?)?.toDouble();
            if (dx != null && dy != null) return Offset(dx, dy);
          }
          return fallback;
        }

        _cards = SmartBoardCardState(
          problem: problem,
          ideas: ideas,
          solution: solution,
          problemPos: readOffset('problemPos', const Offset(28, 24)),
          ideasPos: readOffset('ideasPos', const Offset(28, 320)),
          solutionPos: readOffset('solutionPos', const Offset(480, 24)),
        );
      }
    } catch (_) {
      // 忽略首次读取异常
    }
  }

  void _savePrefs() {
    try {
      unawaited(
        context.read<GlobalCache>().setSmartBoardPrefs({
          'paper': _paperStyle.name,
          'widthIdx': _widthIdx,
        }),
      );
    } catch (_) {}
  }

  void _scheduleDraftSave() {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      try {
        final cache = context.read<GlobalCache>();
        final hasAnything = _strokes.isNotEmpty ||
            _shapes.isNotEmpty ||
            _cards.problem != null ||
            _cards.ideas != null ||
            _cards.solution != null;
        if (!hasAnything) {
          unawaited(cache.setSmartBoardDraft(null));
          return;
        }
        unawaited(
          cache.setSmartBoardDraft({
            'strokes': _strokes.map((s) => s.toJson()).toList(),
            'shapes': _shapes.map((s) => s.toJson()).toList(),
            if (_cards.problem != null) 'problem': _cards.problem!.toJson(),
            if (_cards.ideas != null) 'ideas': _cards.ideas!.toJson(),
            if (_cards.solution != null) 'solution': _cards.solution!.toJson(),
            'problemPos': [_cards.problemPos.dx, _cards.problemPos.dy],
            'ideasPos': [_cards.ideasPos.dx, _cards.ideasPos.dy],
            'solutionPos': [_cards.solutionPos.dx, _cards.solutionPos.dy],
          }),
        );
      } catch (_) {}
    });
  }

  Future<void> _loadAiStatus() async {
    try {
      final status = await context.read<GuoguanlaApi>().getAiBoardStatus();
      if (mounted) {
        setState(() => _aiStatus = status);
      }
    } catch (_) {
      // 网络离线时保持纯手写可用
    }
  }

  void _showHint(String text) {
    _hintTimer?.cancel();
    setState(() => _floatingHint = text);
    _hintTimer = Timer(const Duration(milliseconds: 1900), () {
      if (mounted) setState(() => _floatingHint = '');
    });
  }

  Offset _screenToWorld(Offset screen) =>
      Offset((screen.dx - _panX) / _zoom, (screen.dy - _panY) / _zoom);

  Offset _worldToScreen(Offset world) =>
      Offset(_panX + world.dx * _zoom, _panY + world.dy * _zoom);

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

  void _pushUndoCheckpoint() {
    _undoStack.add(BoardUndoSnapshot.capture(_strokes, _shapes));
    if (_undoStack.length > _maxHistory) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void _handleUndo() {
    if (_undoStack.isEmpty) return;
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
    _scheduleDraftSave();
  }

  void _handleRedo() {
    if (_redoStack.isEmpty) return;
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
    _scheduleDraftSave();
  }

  BoardCardId? _hitTestCardHeader(Offset worldPt, {bool wholeCard = false}) {
    final metrics = SmartBoardLayoutMetrics.compute(
      cards: _cards,
      visibility: _visibility,
      problemPhoto: _problemPhotoImage,
    );
    const order = <BoardCardId>[
      BoardCardId.solution,
      BoardCardId.ideas,
      BoardCardId.problem,
    ];
    for (final id in order) {
      final rect = metrics.rectOf(id);
      if (rect == null) continue;
      final hitRect = wholeCard
          ? rect
          : Rect.fromLTWH(rect.left, rect.top, rect.width, 40);
      if (hitRect.contains(worldPt)) return id;
    }
    return null;
  }

  void _moveCardBy(BoardCardId id, Offset deltaWorld) {
    setState(() {
      switch (id) {
        case BoardCardId.problem:
          _cards = _cards.copyWith(problemPos: _cards.problemPos + deltaWorld);
        case BoardCardId.ideas:
          _cards = _cards.copyWith(ideasPos: _cards.ideasPos + deltaWorld);
        case BoardCardId.solution:
          _cards =
              _cards.copyWith(solutionPos: _cards.solutionPos + deltaWorld);
      }
    });
  }

  void _eraseAtWorld(Offset worldPt) {
    final threshold = 16.0 / math.max(0.35, _zoom);
    var removed = false;
    final strokeIdx = _strokes.lastIndexWhere(
      (s) => s.hitTest(worldPt, threshold),
    );
    if (strokeIdx >= 0) {
      if (!_erasedDuringDrag) {
        _pushUndoCheckpoint();
        _erasedDuringDrag = true;
      }
      _strokes.removeAt(strokeIdx);
      removed = true;
    } else {
      final shapeIdx = _shapes.lastIndexWhere(
        (sh) => sh.hitTest(worldPt, threshold),
      );
      if (shapeIdx >= 0) {
        if (!_erasedDuringDrag) {
          _pushUndoCheckpoint();
          _erasedDuringDrag = true;
        }
        _shapes.removeAt(shapeIdx);
        removed = true;
      }
    }
    if (removed) {
      setState(() {});
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (_showShapePicker) {
      setState(() => _showShapePicker = false);
    }
    final focal = details.localFocalPoint;
    if (details.pointerCount >= 2) {
      _isPinching = true;
      // 丢弃双指误触刚落下的微小单点
      _activeStroke = null;
      _activeShape = null;
      _draggingCardId = null;
      _eraserCursorWorld = null;
      _singlePanLast = null;
      _gestureStartZoom = _zoom;
      _gestureAnchorWorld = _screenToWorld(focal);
      return;
    }

    _isPinching = false;
    final worldPt = _screenToWorld(focal);

    // 任意模式下按住卡片标题栏都可直接拖动板书卡；移动模式下按住整张卡可拖动
    final hitCard = _hitTestCardHeader(
      worldPt,
      wholeCard: _tool == BoardToolMode.hand,
    );
    if (hitCard != null) {
      setState(() {
        _draggingCardId = hitCard;
        _cardDragLastWorld = worldPt;
      });
      return;
    }

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

    final isPixelEraser = _tool == BoardToolMode.pixelEraser;
    final isHighlighter = _tool == BoardToolMode.highlighter;
    final width = isPixelEraser
        ? 22.0
        : (isHighlighter ? 16.0 : _strokeWidths[_widthIdx]);

    setState(() {
      _activeStroke = BoardStroke(
        colorValue: isPixelEraser ? 0xFFFCFDFF : _activeColor.toARGB32(),
        width: width,
        isEraser: isPixelEraser,
        isHighlighter: isHighlighter,
        points: <Offset>[worldPt],
      );
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final focal = details.localFocalPoint;

    if (details.pointerCount >= 2 || _isPinching) {
      if (!_isPinching) {
        _isPinching = true;
        _activeStroke = null;
        _activeShape = null;
        _draggingCardId = null;
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

    if (_draggingCardId != null && _cardDragLastWorld != null) {
      final worldPt = _screenToWorld(focal);
      final delta = worldPt - _cardDragLastWorld!;
      _cardDragLastWorld = worldPt;
      _moveCardBy(_draggingCardId!, delta);
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

    if (_draggingCardId != null) {
      setState(() {
        _draggingCardId = null;
        _cardDragLastWorld = null;
      });
      _scheduleDraftSave();
      return;
    }

    if (_eraserCursorWorld != null) {
      final didErase = _erasedDuringDrag;
      _erasedDuringDrag = false;
      setState(() => _eraserCursorWorld = null);
      if (didErase) _scheduleDraftSave();
      return;
    }

    final finishedShape = _activeShape;
    if (finishedShape != null) {
      final dist = (finishedShape.end - finishedShape.start).distance;
      if (dist >= 6) {
        _pushUndoCheckpoint();
        setState(() {
          _shapes.add(finishedShape);
          _activeShape = null;
        });
        _scheduleDraftSave();
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
    _scheduleDraftSave();

    // 写至边缘自动延申无限书写区
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
      if (endScreen.dy > _canvasSize.height - 68) {
        setState(() => _panY -= (_canvasSize.height * 0.30).roundToDouble());
        _showHint('已自动向下延申书写区');
      } else if (endScreen.dx > _canvasSize.width - 52) {
        setState(() => _panX -= (_canvasSize.width * 0.25).roundToDouble());
        _showHint('已自动向右延申书写区');
      }
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final factor = event.scrollDelta.dy > 0 ? 0.90 : 1.11;
      _zoomAtFocal(event.localPosition, (_zoom * factor).clamp(_minZoom, _maxZoom));
    }
  }

  void _zoomAtFocal(Offset screenFocal, double targetZoom) {
    final anchorWorld = _screenToWorld(screenFocal);
    setState(() {
      _zoom = targetZoom.clamp(_minZoom, _maxZoom);
      _panX = screenFocal.dx - anchorWorld.dx * _zoom;
      _panY = screenFocal.dy - anchorWorld.dy * _zoom;
    });
  }

  void _stepZoom(double delta) {
    if (_canvasSize.isEmpty) return;
    _zoomAtFocal(
      Offset(_canvasSize.width / 2, _canvasSize.height / 2),
      (_zoom + delta).clamp(_minZoom, _maxZoom),
    );
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
    _zoomAtFocal(Offset(_canvasSize.width / 2, _canvasSize.height / 2), 1.0);
  }

  void _focusOnRect(Rect rect, {double maxZoom = 1.05}) {
    if (_canvasSize.isEmpty) return;
    const pad = 32.0;
    final boxW = math.max(180.0, rect.width + pad * 2);
    final boxH = math.max(160.0, rect.height + pad * 2);
    final nextZoom = math
        .min(
          maxZoom,
          math.min(_canvasSize.width / boxW, _canvasSize.height / boxH),
        )
        .clamp(_minZoom, _maxZoom);
    setState(() {
      _zoom = nextZoom;
      _panX = _canvasSize.width / 2 - rect.center.dx * _zoom;
      _panY = math.min(
        _canvasSize.height / 2 - rect.center.dy * _zoom,
        24 - rect.top * _zoom,
      );
    });
  }

  void _fitAllContent() {
    if (_canvasSize.isEmpty) return;
    Rect? union;
    void addRect(Rect r) {
      union = union == null ? r : union!.expandToInclude(r);
    }

    for (final s in _strokes) {
      if (s.isEraser) continue;
      final b = s.bounds;
      if (b != null) addRect(b);
    }
    for (final sh in _shapes) {
      addRect(sh.bounds);
    }
    final metrics = SmartBoardLayoutMetrics.compute(
      cards: _cards,
      visibility: _visibility,
      problemPhoto: _problemPhotoImage,
    );
    if (metrics.problemRect != null) addRect(metrics.problemRect!);
    if (metrics.ideasRect != null) addRect(metrics.ideasRect!);
    if (metrics.solutionRect != null) addRect(metrics.solutionRect!);

    if (union == null) {
      setState(() {
        _zoom = 1.0;
        _panX = 0;
        _panY = 0;
      });
      return;
    }
    _focusOnRect(union!, maxZoom: 1.12);
  }

  Rect? _computeHandwritingBounds() {
    Rect? union;
    for (final s in _strokes) {
      if (s.isEraser) continue;
      final b = s.bounds;
      if (b != null) union = union == null ? b : union.expandToInclude(b);
    }
    for (final sh in _shapes) {
      union = union == null ? sh.bounds : union.expandToInclude(sh.bounds);
    }
    return union;
  }

  bool get _hasHandwriting =>
      _strokes.any((s) => !s.isEraser && s.points.isNotEmpty) ||
      _shapes.isNotEmpty;

  // ==================== 拍照/相册识题与 AI 绘图联动 ====================

  Future<void> _openProblemCaptureSheet() async {
    if (_busyAi) return;
    await showWelkDrawer<void>(
      context: context,
      position: WelkDrawerPosition.bottom,
      closeOnTapOutside: true,
      builder: (drawerCtx) {
        final colors = WelkTheme.of(drawerCtx).resolveColors(drawerCtx);
        return WelkDrawer(
          title: const Text('导入数学题目到画板'),
          closeLabel: '取消',
          onClose: () => Navigator.of(drawerCtx).pop(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '拍一张数学大题照片，AI 将自动识别题干、已知条件、求解目标与几何示意图，直接排版绘制到画板中。',
                style: TextStyle(
                  color: AppTheme.mutedText(drawerCtx),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (!kIsWeb) ...[
                    Expanded(
                      child: _CaptureOptionTile(
                        icon: Icons.photo_camera_rounded,
                        label: '拍照识题',
                        subtitle: '拍摄纸质/屏幕数学题',
                        accent: colors.accent,
                        onTap: () {
                          Navigator.of(drawerCtx).pop();
                          unawaited(_pickAndRecognize(ImageSource.camera));
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: _CaptureOptionTile(
                      icon: Icons.photo_library_rounded,
                      label: kIsWeb ? '上传题目图片' : '相册选图',
                      subtitle: '从本地图片识别解析',
                      accent: colors.success,
                      onTap: () {
                        Navigator.of(drawerCtx).pop();
                        unawaited(_pickAndRecognize(ImageSource.gallery));
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GglBlockButton(
                label: '手动输入 / 编辑数学题干',
                variant: WelkButtonVariant.secondary,
                onPressed: () {
                  Navigator.of(drawerCtx).pop();
                  unawaited(_openManualProblemDialog());
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndRecognize(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty || !mounted) return;

      // 解码用于画板贴图预览
      ui.Image? decoded;
      try {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        decoded = frame.image;
      } catch (_) {}

      if (!mounted) {
        decoded?.dispose();
        return;
      }

      final api = context.read<GuoguanlaApi>();
      setState(() {
        _problemPhotoBytes = bytes;
        _problemPhotoImage?.dispose();
        _problemPhotoImage = decoded;
        _busyAi = true;
        _busyAiLabel = 'AI 正在识别数学题目并解析到画板...';
      });

      final result = await api.recognizeMathProblem(
        imageBytes: bytes,
        filename: picked.name.isNotEmpty ? picked.name : 'math-problem.jpg',
      );
      if (!mounted) return;

      final cardWidth = _canvasSize.width > 0
          ? math.min(440.0, math.max(320.0, _canvasSize.width * 0.48))
          : 400.0;

      setState(() {
        _cards = _cards.copyWith(
          problem: result,
          problemPos: const Offset(28, 24),
          problemWidth: cardWidth,
          clearIdeas: true,
          clearSolution: true,
        );
        _visibility = _visibility.copyWith(
          showProblemCard: true,
          showPhotoCard: result.hasFigure,
        );
      });
      _scheduleDraftSave();

      final metrics = SmartBoardLayoutMetrics.compute(
        cards: _cards,
        visibility: _visibility,
        problemPhoto: _problemPhotoImage,
      );
      if (metrics.problemRect != null) {
        _focusOnRect(metrics.problemRect!, maxZoom: 1.0);
      }
      _showHint('题目已解析并绘制到画板（${result.latencyMs}ms）');
    } catch (e) {
      if (mounted) {
        GglFeedback.error(context, friendlyErrorMessage(e, '拍照识别题目失败'));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busyAi = false;
          _busyAiLabel = '';
        });
      }
    }
  }

  Future<void> _openManualProblemDialog() async {
    final titleCtrl = TextEditingController(
      text: _cards.problem?.title ?? '',
    );
    final stemCtrl = TextEditingController(
      text: _cards.problem?.problemText ?? '',
    );

    await showWelkDialog<void>(
      context: context,
      closeOnTapOutside: true,
      builder: (ctx) => WelkDialog(
        title: Text(_cards.problem == null ? '输入数学题目到画板' : '编辑画板题目'),
        variant: WelkDialogVariant.info,
        buttonText: '绘制到画板',
        onClose: () => Navigator.of(ctx).pop(),
        onPressed: () {
          final text = stemCtrl.text.trim();
          if (text.isEmpty) {
            GglFeedback.warning(ctx, '请输入数学题目内容');
            return;
          }
          final updated = (_cards.problem ??
                  const AiRecognizeResult(
                    title: '数学解答题',
                    problemText: '',
                    subjectTag: '自由练习',
                    questionType: '解答题',
                    difficulty: '自选',
                  ))
              .copyWith(
            title: titleCtrl.text.trim().isEmpty
                ? '数学解答题'
                : titleCtrl.text.trim(),
            problemText: text,
          );
          setState(() {
            _cards = _cards.copyWith(problem: updated);
            _visibility = _visibility.copyWith(showProblemCard: true);
          });
          _scheduleDraftSave();
          Navigator.of(ctx).pop();
          final metrics = SmartBoardLayoutMetrics.compute(
            cards: _cards,
            visibility: _visibility,
            problemPhoto: _problemPhotoImage,
          );
          if (metrics.problemRect != null) {
            _focusOnRect(metrics.problemRect!, maxZoom: 1.0);
          }
          _showHint('题目已更新并绘制到画板');
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                hintText: '题目标题（选填，如：二次函数综合）',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: stemCtrl,
              minLines: 4,
              maxLines: 8,
              decoration: InputDecoration(
                hintText:
                    '输入或粘贴数学题目（支持 LaTeX 如 \$x^2-3x+2=0\$、\$\\frac{1}{2}\$）...',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestAiGuidance({required bool isIdeas}) async {
    if (_busyAi) return;
    final problemText = _cards.problem?.problemText.trim() ?? '';
    final hasDrawing = _hasHandwriting;
    if (problemText.isEmpty && !hasDrawing && _problemPhotoBytes == null) {
      GglFeedback.warning(context, '请先拍照识别题目、输入题干或在画板上写下题目');
      await _openProblemCaptureSheet();
      return;
    }

    setState(() {
      _busyAi = true;
      _busyAiLabel = isIdeas
          ? 'AI 正在提炼解题思路并准备板书绘制...'
          : (hasDrawing
              ? 'AI 正在识别你的手写过程并生成分析板书...'
              : 'AI 正在推导规范解题过程并绘制到画板...');
    });

    try {
      String? boardBase64;
      if (hasDrawing) {
        final pngBytes = await renderSmartBoardToPng(
          strokes: _strokes,
          shapes: _shapes,
          cards: _cards,
          visibility: _visibility,
          problemPhoto: _problemPhotoImage,
          includeProblemCard: _cards.problem != null,
          includeAiCards: false,
          maxDimension: 1400,
        );
        boardBase64 = 'data:image/png;base64,${base64Encode(pngBytes)}';
      }

      String? photoBase64;
      if (_problemPhotoBytes != null &&
          (_cards.problem?.hasFigure == true || problemText.isEmpty)) {
        photoBase64 =
            'data:image/jpeg;base64,${base64Encode(_problemPhotoBytes!)}';
      }

      if (!mounted) return;
      final api = context.read<GuoguanlaApi>();
      final guidance = isIdeas
          ? await api.generateBoardIdeas(
              problemText: problemText,
              boardImageBase64: boardBase64,
              problemImageBase64: photoBase64,
              hasHandwriting: hasDrawing,
            )
          : await api.analyzeBoardSolution(
              problemText: problemText,
              boardImageBase64: boardBase64,
              problemImageBase64: photoBase64,
              hasHandwriting: hasDrawing,
            );
      if (!mounted) return;

      // 计算不与题目和手写区域重叠的黄金绘制坐标
      final metricsBefore = SmartBoardLayoutMetrics.compute(
        cards: _cards,
        visibility: _visibility,
        problemPhoto: _problemPhotoImage,
      );
      final inkBounds = _computeHandwritingBounds();
      final pRect = metricsBefore.problemRect;

      Offset targetPos;
      if (isIdeas) {
        final baseY = pRect != null ? pRect.bottom + 24 : 24.0;
        final baseX = pRect != null ? pRect.left : 28.0;
        targetPos = Offset(baseX, baseY);
      } else {
        double rightEdge = 28.0;
        if (pRect != null) rightEdge = math.max(rightEdge, pRect.right + 28);
        if (metricsBefore.ideasRect != null) {
          rightEdge = math.max(rightEdge, metricsBefore.ideasRect!.right + 28);
        }
        if (inkBounds != null && inkBounds.right < 900) {
          rightEdge = math.max(rightEdge, inkBounds.right + 28);
        }
        targetPos = Offset(rightEdge, pRect?.top ?? 24.0);
      }

      setState(() {
        if (isIdeas) {
          _cards = _cards.copyWith(ideas: guidance, ideasPos: targetPos);
          _visibility = _visibility.copyWith(showIdeasCard: true);
        } else {
          _cards = _cards.copyWith(solution: guidance, solutionPos: targetPos);
          _visibility = _visibility.copyWith(showSolutionCard: true);
        }
      });
      _scheduleDraftSave();

      // 聚焦到新绘制的 AI 板书卡，并播放逐行书写动画
      final metricsAfter = SmartBoardLayoutMetrics.compute(
        cards: _cards,
        visibility: _visibility,
        problemPhoto: _problemPhotoImage,
      );
      final newRect = isIdeas ? metricsAfter.ideasRect : metricsAfter.solutionRect;
      if (newRect != null) {
        _focusOnRect(newRect, maxZoom: 1.0);
      }

      if (isIdeas) {
        _ideasRevealCtrl.forward(from: 0.08);
        _showHint('AI 解题思路已绘制到画板（可拖动标题栏调整位置）');
      } else {
        _solutionRevealCtrl.forward(from: 0.08);
        _showHint('AI 解题过程分析已绘制到画板（可拖动标题栏调整位置）');
      }
    } catch (e) {
      if (mounted) {
        GglFeedback.error(
          context,
          friendlyErrorMessage(e, isIdeas ? '生成解题思路失败' : 'AI 分析解题过程失败'),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busyAi = false;
          _busyAiLabel = '';
        });
      }
    }
  }

  Future<void> _toggleOrientation() async {
    if (kIsWeb) {
      _showHint('桌面/Web 端已自动适配当前窗口宽度');
      return;
    }
    final nextLandscape = !_isLandscape;
    setState(() => _isLandscape = nextLandscape);
    await SystemChrome.setPreferredOrientations(
      nextLandscape
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const [DeviceOrientation.portraitUp],
    );
    _showHint(nextLandscape ? '已切换横屏大画板' : '已切换竖屏便携模式');
  }

  Future<void> _previewExportFullBoard() async {
    try {
      final png = await renderSmartBoardToPng(
        strokes: _strokes,
        shapes: _shapes,
        cards: _cards,
        visibility: _visibility,
        problemPhoto: _problemPhotoImage,
        includeProblemCard: true,
        includeAiCards: true,
        maxDimension: 2000,
      );
      if (!mounted) return;
      await showWelkDialog<void>(
        context: context,
        closeOnTapOutside: true,
        builder: (ctx) => WelkDialog(
          title: const Text('高清完整板书快照'),
          variant: WelkDialogVariant.success,
          buttonText: '关闭预览',
          onClose: () => Navigator.of(ctx).pop(),
          onPressed: () => Navigator.of(ctx).pop(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '包含题目板书、你的手写与几何辅助线以及 AI 思路/解题过程（${(png.length / 1024).round()} KB）',
                style: TextStyle(
                  color: AppTheme.mutedText(ctx),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.memory(png, fit: BoxFit.contain),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        GglFeedback.warning(context, friendlyErrorMessage(e, '画板暂无可导出内容'));
      }
    }
  }

  Future<void> _openBoardSettingsDrawer() async {
    await showWelkDrawer<void>(
      context: context,
      position: WelkDrawerPosition.bottom,
      closeOnTapOutside: true,
      builder: (drawerCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          void updateState(VoidCallback fn) {
            setState(fn);
            setSheetState(() {});
          }

          return WelkDrawer(
            title: const Text('画板图层与纸张设置'),
            closeLabel: '完成',
            onClose: () => Navigator.of(ctx).pop(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '画板底纹纸张',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in const [
                      (BoardPaperStyle.dots, '点阵纸'),
                      (BoardPaperStyle.grid, '数学方格'),
                      (BoardPaperStyle.lined, '横线作业'),
                      (BoardPaperStyle.plain, '纯白纸'),
                    ])
                      _BoardChip(
                        label: entry.$2,
                        active: _paperStyle == entry.$1,
                        onTap: () {
                          updateState(() => _paperStyle = entry.$1);
                          _savePrefs();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  '板书图层显隐控制',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                _LayerToggleRow(
                  label: '题目板书卡',
                  available: _cards.problem != null,
                  value: _visibility.showProblemCard,
                  onChanged: (v) => updateState(
                    () => _visibility = _visibility.copyWith(showProblemCard: v),
                  ),
                ),
                _LayerToggleRow(
                  label: '原拍题目照片贴图',
                  available: _problemPhotoImage != null,
                  value: _visibility.showPhotoCard,
                  onChanged: (v) => updateState(
                    () => _visibility = _visibility.copyWith(showPhotoCard: v),
                  ),
                ),
                _LayerToggleRow(
                  label: 'AI 解题思路板书',
                  available: _cards.ideas != null,
                  value: _visibility.showIdeasCard,
                  onChanged: (v) => updateState(
                    () => _visibility = _visibility.copyWith(showIdeasCard: v),
                  ),
                ),
                _LayerToggleRow(
                  label: 'AI 解题过程与诊断板书',
                  available: _cards.solution != null,
                  value: _visibility.showSolutionCard,
                  onChanged: (v) => updateState(
                    () =>
                        _visibility = _visibility.copyWith(showSolutionCard: v),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    WelkButton(
                      size: WelkButtonSize.small,
                      variant: WelkButtonVariant.secondary,
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        unawaited(_previewExportFullBoard());
                      },
                      child: const Text('导出高清板书图'),
                    ),
                    if (!kIsWeb)
                      WelkButton(
                        size: WelkButtonSize.small,
                        variant: WelkButtonVariant.secondary,
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          unawaited(_toggleOrientation());
                        },
                        child: Text(_isLandscape ? '切回竖屏' : '切为横屏画板'),
                      ),
                    if (_cards.ideas != null || _cards.solution != null)
                      WelkButton(
                        size: WelkButtonSize.small,
                        variant: WelkButtonVariant.warning,
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          setState(() {
                            _cards = _cards.copyWith(
                              clearIdeas: true,
                              clearSolution: true,
                            );
                          });
                          _scheduleDraftSave();
                          _showHint('已清空 AI 思路与解析图层');
                        },
                        child: const Text('仅清空 AI 板书'),
                      ),
                    WelkButton(
                      size: WelkButtonSize.small,
                      variant: WelkButtonVariant.error,
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await _confirmClearAll();
                      },
                      child: const Text('清空整块画板'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmClearAll() async {
    final ok = await GglFeedback.confirm(
      context,
      title: '清空整块智能画板？',
      content: '将清除当前画板上的题目、手写笔迹、几何图形及 AI 板书内容。',
      yesText: '确认清空',
      noText: '取消',
    );
    if (!ok || !mounted) return;
    _pushUndoCheckpoint();
    setState(() {
      _strokes.clear();
      _shapes.clear();
      _activeStroke = null;
      _activeShape = null;
      _problemPhotoBytes = null;
      _problemPhotoImage?.dispose();
      _problemPhotoImage = null;
      _cards = const SmartBoardCardState();
      _zoom = 1.0;
      _panX = 0;
      _panY = 0;
    });
    _scheduleDraftSave();
    _showHint('画板已全部清空');
  }

  void _clearHandwritingOnly() {
    if (!_hasHandwriting) return;
    _pushUndoCheckpoint();
    setState(() {
      _strokes.clear();
      _shapes.clear();
      _activeStroke = null;
      _activeShape = null;
    });
    _scheduleDraftSave();
    _showHint('已清空手写与几何笔迹');
  }

  String _shapeLabel(BoardShapeKind kind) => switch (kind) {
        BoardShapeKind.line => '直线',
        BoardShapeKind.dashedLine => '辅助虚线',
        BoardShapeKind.arrow => '箭头',
        BoardShapeKind.rect => '矩形',
        BoardShapeKind.oval => '圆/椭圆',
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
    final plainProblem = _cards.problem != null
        ? MathParser.renderPlainText(_cards.problem!.problemText)
        : '';
    final aiAnimating =
        _ideasRevealCtrl.isAnimating || _solutionRevealCtrl.isAnimating;

    return Scaffold(
      backgroundColor: const Color(0xFFFCFDFF),
      body: SafeArea(
        child: Column(
          children: [
            // 1. 顶部 AI 与画板主工具栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: colors.paper,
                border: Border(
                  bottom: BorderSide(
                    color: colors.outline,
                    width: colors.borderWidth,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      WelkButton(
                        size: WelkButtonSize.small,
                        variant: WelkButtonVariant.secondary,
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('返回'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: _cards.problem == null
                              ? _openProblemCaptureSheet
                              : _openManualProblemDialog,
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
                                GglStatusTag(
                                  label: _cards.problem == null ? 'AI画板' : '题干',
                                  variant: _cards.problem == null
                                      ? WelkBadgeVariant.defaultStyle
                                      : WelkBadgeVariant.info,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    plainProblem.isNotEmpty
                                        ? plainProblem
                                        : '拍照或输入数学题目，开始智能解答',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.ink,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.edit_note_rounded,
                                  size: 16,
                                  color: AppTheme.mutedText(context),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      WelkIconButton(
                        icon: const Icon(Icons.layers_rounded, size: 18),
                        label: '图层与纸张',
                        onPressed: _openBoardSettingsDrawer,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // AI 核心能力快捷条
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        WelkButton(
                          size: WelkButtonSize.small,
                          variant: WelkButtonVariant.primary,
                          onPressed: _busyAi ? null : _openProblemCaptureSheet,
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.photo_camera_rounded, size: 15),
                              SizedBox(width: 4),
                              Text('拍照识题'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        WelkButton(
                          size: WelkButtonSize.small,
                          variant: WelkButtonVariant.warning,
                          onPressed: _busyAi
                              ? null
                              : () => _requestAiGuidance(isIdeas: true),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lightbulb_rounded, size: 15),
                              SizedBox(width: 4),
                              Text('AI 解题思路'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        WelkButton(
                          size: WelkButtonSize.small,
                          variant: WelkButtonVariant.success,
                          onPressed: _busyAi
                              ? null
                              : () => _requestAiGuidance(isIdeas: false),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_awesome_rounded, size: 15),
                              const SizedBox(width: 4),
                              Text(_hasHandwriting ? 'AI 诊断并解析' : 'AI 解题过程'),
                            ],
                          ),
                        ),
                        if (_aiStatus != null) ...[
                          const SizedBox(width: 8),
                          GglStatusTag(
                            label: _aiStatus!.ready
                                ? '模型 ${_aiStatus!.modelName}'
                                : 'AI待配置',
                            variant: _aiStatus!.ready
                                ? WelkBadgeVariant.info
                                : WelkBadgeVariant.warning,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. 无限矢量画板主舞台
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
                              cards: _cards,
                              visibility: _visibility,
                              problemPhoto: _problemPhotoImage,
                              ideasReveal: _ideasRevealCtrl.value,
                              solutionReveal: _solutionRevealCtrl.value,
                              draggingCardId: _draggingCardId,
                              eraserCursorWorld: _eraserCursorWorld,
                              eraserCursorRadius: 16.0 / math.max(0.4, _zoom),
                            ),
                          ),
                        ),
                      ),

                      // 空画板欢迎引导
                      if (_strokes.isEmpty &&
                          _shapes.isEmpty &&
                          _cards.problem == null &&
                          _cards.ideas == null &&
                          _cards.solution == null &&
                          _activeStroke == null &&
                          !_busyAi)
                        IgnorePointer(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.draw_rounded,
                                    size: 40,
                                    color: const Color(0xFF94A3B8)
                                        .withValues(alpha: 0.7),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'AI 智能手写画板 · 无限矢量书写空间',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    '点击上方「拍照识题」自动解析数学题到画板，支持 AI 思路与过程直接板书绘制\n双指缩放平移 · 拖动卡片标题栏自由排版 · 支持几何辅助线与坐标系',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 12.2,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // 几何工具二级弹出选择条
                      if (_showShapePicker)
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 66,
                          child: Center(
                            child: GglComicPanel(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              shadowOffset: const Offset(2, 2),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final kind in BoardShapeKind.values)
                                    _BoardChip(
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

                      // 左下角缩放与视野 HUD
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: GglComicPanel(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          shadowOffset: const Offset(2, 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () => _stepZoom(-0.2),
                                child: Icon(
                                  Icons.remove_rounded,
                                  size: 16,
                                  color: colors.ink,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: _resetZoomTo100,
                                child: Text(
                                  '${(_zoom * 100).round()}%',
                                  style: TextStyle(
                                    color: colors.ink,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => _stepZoom(0.2),
                                child: Icon(
                                  Icons.add_rounded,
                                  size: 16,
                                  color: colors.ink,
                                ),
                              ),
                              Container(
                                width: 1.5,
                                height: 14,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 7),
                                color: colors.outline.withValues(alpha: 0.35),
                              ),
                              GestureDetector(
                                onTap: _fitAllContent,
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

                      // 右下角状态/动画提示条
                      if (_busyAi)
                        Positioned(
                          right: 12,
                          bottom: 10,
                          child: GglComicPanel(
                            color: const Color(0xFFE0F2FE),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shadowOffset: const Offset(2, 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _busyAiLabel,
                                  style: const TextStyle(
                                    color: Color(0xFF0369A1),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (aiAnimating)
                        Positioned(
                          right: 12,
                          bottom: 10,
                          child: GestureDetector(
                            onTap: () {
                              _ideasRevealCtrl.value = 1.0;
                              _solutionRevealCtrl.value = 1.0;
                            },
                            child: const GglStatusTag(
                              label: 'AI 正在板书绘制... 点此全部展开',
                              variant: WelkBadgeVariant.success,
                            ),
                          ),
                        )
                      else if (_floatingHint.isNotEmpty)
                        Positioned(
                          right: 12,
                          bottom: 10,
                          child: GglStatusTag(
                            label: _floatingHint,
                            variant: WelkBadgeVariant.info,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),

            // 3. 底部专业笔刷与几何工具 Dock
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
                    // 5 色色盘
                    for (final c in _penColors)
                      GestureDetector(
                        onTap: () => setState(() {
                          _activeColor = c;
                          if (_tool == BoardToolMode.strokeEraser ||
                              _tool == BoardToolMode.pixelEraser ||
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

                    // 粗细循环切换
                    _BoardChip(
                      label: '粗细:${_strokeLabels[_widthIdx]}',
                      active: false,
                      onTap: () {
                        setState(() {
                          _widthIdx = (_widthIdx + 1) % _strokeWidths.length;
                        });
                        _savePrefs();
                      },
                    ),
                    const SizedBox(width: 5),

                    _BoardChip(
                      label: '钢笔',
                      active: _tool == BoardToolMode.pen,
                      onTap: () => setState(() {
                        _tool = BoardToolMode.pen;
                        _showShapePicker = false;
                      }),
                    ),
                    const SizedBox(width: 5),
                    _BoardChip(
                      label: '荧光笔',
                      active: _tool == BoardToolMode.highlighter,
                      onTap: () => setState(() {
                        _tool = BoardToolMode.highlighter;
                        _showShapePicker = false;
                      }),
                    ),
                    const SizedBox(width: 5),
                    _BoardChip(
                      label: _isShapeTool
                          ? '图形:${_shapeLabel(_shapeKindForTool(_tool))}'
                          : '几何图形',
                      active: _isShapeTool || _showShapePicker,
                      onTap: () => setState(() {
                        _showShapePicker = !_showShapePicker;
                      }),
                    ),
                    const SizedBox(width: 5),
                    _BoardChip(
                      label: '笔画擦',
                      active: _tool == BoardToolMode.strokeEraser,
                      onTap: () => setState(() {
                        _tool = BoardToolMode.strokeEraser;
                        _showShapePicker = false;
                      }),
                    ),
                    const SizedBox(width: 5),
                    _BoardChip(
                      label: '移动',
                      active: _tool == BoardToolMode.hand,
                      onTap: () => setState(() {
                        _tool = BoardToolMode.hand;
                        _showShapePicker = false;
                      }),
                    ),
                    const SizedBox(width: 6),
                    _BoardChip(
                      label: '撤销',
                      active: false,
                      disabled: _undoStack.isEmpty,
                      onTap: _handleUndo,
                    ),
                    const SizedBox(width: 5),
                    _BoardChip(
                      label: '重做',
                      active: false,
                      disabled: _redoStack.isEmpty,
                      onTap: _handleRedo,
                    ),
                    const SizedBox(width: 5),
                    _BoardChip(
                      label: '清笔迹',
                      active: false,
                      disabled: !_hasHandwriting,
                      onTap: _clearHandwritingOnly,
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

class _BoardChip extends StatelessWidget {
  const _BoardChip({
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
      opacity: disabled ? 0.42 : 1.0,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? colors.accent : colors.paper,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.outline, width: 1.5),
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

class _CaptureOptionTile extends StatelessWidget {
  const _CaptureOptionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    return GglComicPanel(
      color: Color.alphaBlend(accent.withValues(alpha: 0.14), colors.paper),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      shadowOffset: const Offset(2, 2),
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 28, color: colors.ink),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: colors.ink,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.mutedText(context),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _LayerToggleRow extends StatelessWidget {
  const _LayerToggleRow({
    required this.label,
    required this.available,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool available;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              available ? label : '$label（暂无内容）',
              style: TextStyle(
                color: available ? colors.ink : AppTheme.mutedText(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          WelkSwitch(
            value: available && value,
            label: (available && value) ? '显示' : '隐藏',
            onChanged: available ? onChanged : null,
          ),
        ],
      ),
    );
  }
}
