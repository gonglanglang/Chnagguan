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

/// 首页「AI 智能手写画板」：
/// - 顶/底安全区满铺无白边，画布严格 ClipRect 不越界覆盖导航；
/// - 极简纯粹白板风，AI 职责三分离：思路(不给答案) / 诊断(批改手写不给答案) / 解题(完整过程与答案)；
/// - 坐标级逐笔自动书写与矢量作图动画（笔尖跟随 + 调速 + 重播）；
/// - 自由横竖屏一键切换 + 手机横屏紧凑大画布 & 沉浸全屏模式。
class SmartBoardPage extends StatefulWidget {
  const SmartBoardPage({
    super.key,
    this.autoOpenCapture = false,
  });

  final bool autoOpenCapture;

  @override
  State<SmartBoardPage> createState() => _SmartBoardPageState();
}

enum _AiActionKind { ideas, diagnose, solve }

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

  final List<BoardStroke> _strokes = <BoardStroke>[];
  final List<BoardShape> _shapes = <BoardShape>[];
  final List<BoardUndoSnapshot> _undoStack = <BoardUndoSnapshot>[];
  final List<BoardUndoSnapshot> _redoStack = <BoardUndoSnapshot>[];

  BoardStroke? _activeStroke;
  BoardShape? _activeShape;
  bool _erasedDuringDrag = false;
  Offset? _eraserCursorWorld;

  BoardToolMode _tool = BoardToolMode.pen;
  BoardShapeKind _lastShapeKind = BoardShapeKind.line;
  Color _activeColor = _penColors.first;
  int _widthIdx = 1;
  BoardPaperStyle _paperStyle = BoardPaperStyle.dots;
  bool _isLandscape = false;
  bool _immersiveDockHidden = false;
  bool _showShapePicker = false;

  // AI 与板书状态
  AiBoardStatus? _aiStatus;
  SmartBoardCardState _cards = const SmartBoardCardState();
  BoardLayerVisibility _visibility = const BoardLayerVisibility();
  Uint8List? _problemPhotoBytes;
  ui.Image? _problemPhotoImage;
  bool _busyAi = false;
  String _busyAiLabel = '';

  // 坐标级逐笔自动绘制动画控制器
  late final AnimationController _ideasRevealCtrl;
  late final AnimationController _diagnosisRevealCtrl;
  late final AnimationController _solutionRevealCtrl;
  double _traceSpeed = 1.0; // 1.0x / 2.0x
  BoardCardId? _lastAnimatedCard;

  // 视口变换
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

  String _floatingHint = '';
  Timer? _hintTimer;
  Timer? _draftSaveTimer;

  @override
  void initState() {
    super.initState();
    _ideasRevealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
      value: 1.0,
    )..addListener(() {
        if (mounted) setState(() {});
      });
    _diagnosisRevealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
      value: 1.0,
    )..addListener(() {
        if (mounted) setState(() {});
      });
    _solutionRevealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6200),
      value: 1.0,
    )..addListener(() {
        if (mounted) setState(() {});
      });

    // 允许用户自由旋转横竖屏
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

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
    _diagnosisRevealCtrl.dispose();
    _solutionRevealCtrl.dispose();
    _problemPhotoImage?.dispose();
    if (!kIsWeb) {
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
        AiBoardGuidance? diagnosis;
        if (draft['diagnosis'] is Map<String, dynamic>) {
          diagnosis = AiBoardGuidance.fromJson(
            draft['diagnosis'] as Map<String, dynamic>,
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
          diagnosis: diagnosis,
          solution: solution,
          problemPos: readOffset('problemPos', const Offset(24, 20)),
          ideasPos: readOffset('ideasPos', const Offset(24, 290)),
          diagnosisPos: readOffset('diagnosisPos', const Offset(430, 20)),
          solutionPos: readOffset('solutionPos', const Offset(430, 290)),
        );
      }
    } catch (_) {}
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
            _cards.diagnosis != null ||
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
            if (_cards.diagnosis != null)
              'diagnosis': _cards.diagnosis!.toJson(),
            if (_cards.solution != null) 'solution': _cards.solution!.toJson(),
            'problemPos': [_cards.problemPos.dx, _cards.problemPos.dy],
            'ideasPos': [_cards.ideasPos.dx, _cards.ideasPos.dy],
            'diagnosisPos': [_cards.diagnosisPos.dx, _cards.diagnosisPos.dy],
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
    } catch (_) {}
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
    if (_undoStack.length > _maxHistory) _undoStack.removeAt(0);
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
      BoardCardId.diagnosis,
      BoardCardId.ideas,
      BoardCardId.problem,
    ];
    for (final id in order) {
      final rect = metrics.rectOf(id);
      if (rect == null) continue;
      final hitRect = wholeCard
          ? rect
          : Rect.fromLTWH(rect.left, rect.top, rect.width, 32);
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
        case BoardCardId.diagnosis:
          _cards =
              _cards.copyWith(diagnosisPos: _cards.diagnosisPos + deltaWorld);
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
    if (removed) setState(() {});
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (_showShapePicker) setState(() => _showShapePicker = false);
    final focal = details.localFocalPoint;
    if (details.pointerCount >= 2) {
      _isPinching = true;
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
      if ((finishedShape.end - finishedShape.start).distance >= 6) {
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
      if (finished.points.isNotEmpty) _strokes.add(finished);
      _activeStroke = null;
    });
    _scheduleDraftSave();

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
      if (endScreen.dy > _canvasSize.height - 54) {
        setState(() => _panY -= (_canvasSize.height * 0.30).roundToDouble());
        _showHint('已向下延申书写区');
      } else if (endScreen.dx > _canvasSize.width - 48) {
        setState(() => _panX -= (_canvasSize.width * 0.25).roundToDouble());
        _showHint('已向右延申书写区');
      }
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final factor = event.scrollDelta.dy > 0 ? 0.90 : 1.11;
      _zoomAtFocal(
        event.localPosition,
        (_zoom * factor).clamp(_minZoom, _maxZoom),
      );
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
    const pad = 26.0;
    final boxW = math.max(160.0, rect.width + pad * 2);
    final boxH = math.max(140.0, rect.height + pad * 2);
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
        18 - rect.top * _zoom,
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
    if (metrics.diagnosisRect != null) addRect(metrics.diagnosisRect!);
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

  bool get _anyAiAnimating =>
      _ideasRevealCtrl.isAnimating ||
      _diagnosisRevealCtrl.isAnimating ||
      _solutionRevealCtrl.isAnimating;

  Duration _estimateTraceDuration(AiBoardGuidance g) {
    var chars = g.summary.length + g.finalAnswer.length;
    for (final s in g.steps) {
      chars += s.title.length + s.content.length + (s.formula.length * 2);
    }
    if (g.studentDiagnosis != null) {
      chars += g.studentDiagnosis!.comment.length +
          g.studentDiagnosis!.mistakePoint.length +
          g.studentDiagnosis!.suggestion.length;
    }
    final diagCount = g.diagrams.fold<int>(0, (a, d) => a + d.primitives.length);
    final baseMs = (2400 + chars * 16 + diagCount * 240).clamp(3200, 9500);
    return Duration(milliseconds: (baseMs / _traceSpeed).round());
  }

  void _startTraceAnimation(BoardCardId cardId, AiBoardGuidance g) {
    final dur = _estimateTraceDuration(g);
    _lastAnimatedCard = cardId;
    switch (cardId) {
      case BoardCardId.ideas:
        _ideasRevealCtrl.duration = dur;
        _ideasRevealCtrl.forward(from: 0.0);
      case BoardCardId.diagnosis:
        _diagnosisRevealCtrl.duration = dur;
        _diagnosisRevealCtrl.forward(from: 0.0);
      case BoardCardId.solution:
        _solutionRevealCtrl.duration = dur;
        _solutionRevealCtrl.forward(from: 0.0);
      case BoardCardId.problem:
        break;
    }
  }

  void _replayLastTrace() {
    BoardCardId? target = _lastAnimatedCard;
    if (target == null) {
      if (_cards.ideas != null) {
        target = BoardCardId.ideas;
      } else if (_cards.solution != null) {
        target = BoardCardId.solution;
      } else if (_cards.diagnosis != null) {
        target = BoardCardId.diagnosis;
      }
    }
    if (target == null) return;
    final guidance = switch (target) {
      BoardCardId.ideas => _cards.ideas,
      BoardCardId.diagnosis => _cards.diagnosis,
      BoardCardId.solution => _cards.solution,
      BoardCardId.problem => null,
    };
    if (guidance == null) return;
    final metrics = SmartBoardLayoutMetrics.compute(
      cards: _cards,
      visibility: _visibility,
      problemPhoto: _problemPhotoImage,
    );
    final rect = metrics.rectOf(target);
    if (rect != null) _focusOnRect(rect, maxZoom: 1.0);
    _startTraceAnimation(target, guidance);
  }

  void _skipAllTraceAnimations() {
    _hintTimer?.cancel();
    setState(() => _floatingHint = '');
    _ideasRevealCtrl.value = 1.0;
    _diagnosisRevealCtrl.value = 1.0;
    _solutionRevealCtrl.value = 1.0;
  }

  void _toggleTraceSpeed() {
    setState(() => _traceSpeed = _traceSpeed >= 1.9 ? 1.0 : 2.0);
    // 若正在播放则按新倍速无缝继续
    for (final entry in [
      (_ideasRevealCtrl, _cards.ideas),
      (_diagnosisRevealCtrl, _cards.diagnosis),
      (_solutionRevealCtrl, _cards.solution),
    ]) {
      final ctrl = entry.$1;
      final g = entry.$2;
      if (ctrl.isAnimating && g != null) {
        final cur = ctrl.value;
        ctrl.duration = _estimateTraceDuration(g);
        ctrl.forward(from: cur);
      }
    }
  }

  // ==================== 拍照/相册识题 & AI 三分模式 ====================

  Future<void> _openProblemCaptureSheet() async {
    if (_busyAi) return;
    await showWelkDrawer<void>(
      context: context,
      position: WelkDrawerPosition.bottom,
      closeOnTapOutside: true,
      builder: (drawerCtx) {
        final colors = WelkTheme.of(drawerCtx).resolveColors(drawerCtx);
        return WelkDrawer(
          title: const Text('导入数学题目'),
          closeLabel: '取消',
          onClose: () => Navigator.of(drawerCtx).pop(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '拍照或上传题目图片，AI 自动解析题干并排版到白板中。',
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
                        subtitle: '拍摄纸质或屏幕题目',
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
                      subtitle: '从本地相册识别',
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
                label: '手动输入 / 编辑题干',
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
        _busyAiLabel = '正在识别数学题目...';
      });

      final result = await api.recognizeMathProblem(
        imageBytes: bytes,
        filename: picked.name.isNotEmpty ? picked.name : 'math-problem.jpg',
      );
      if (!mounted) return;

      final cardWidth = _canvasSize.width > 0
          ? math.min(400.0, math.max(300.0, _canvasSize.width * 0.44))
          : 380.0;

      setState(() {
        _cards = _cards.copyWith(
          problem: result,
          problemPos: const Offset(24, 20),
          problemWidth: cardWidth,
          clearIdeas: true,
          clearDiagnosis: true,
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
      _showHint('题目已解析到画板');
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
    final titleCtrl = TextEditingController(text: _cards.problem?.title ?? '');
    final stemCtrl = TextEditingController(
      text: _cards.problem?.problemText ?? '',
    );

    await showWelkDialog<void>(
      context: context,
      closeOnTapOutside: true,
      builder: (ctx) => WelkDialog(
        title: Text(_cards.problem == null ? '输入数学题目' : '编辑画板题目'),
        variant: WelkDialogVariant.info,
        buttonText: '放入画板',
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
                    subjectTag: '数学',
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
          _showHint('题目已放入画板');
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                hintText: '题目标题（选填）',
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

  Future<void> _runAiAction(_AiActionKind kind) async {
    if (_busyAi) return;
    final problemText = _cards.problem?.problemText.trim() ?? '';
    final hasDrawing = _hasHandwriting;

    // 诊断模式必须要求先有手写过程
    if (kind == _AiActionKind.diagnose && !hasDrawing) {
      GglFeedback.warning(context, '请先在画板上写下你的解题过程，再点击诊断');
      return;
    }

    if (problemText.isEmpty && !hasDrawing && _problemPhotoBytes == null) {
      GglFeedback.warning(context, '请先拍照识别题目、输入题干或在画板上写下题目');
      await _openProblemCaptureSheet();
      return;
    }

    setState(() {
      _busyAi = true;
      _busyAiLabel = switch (kind) {
        _AiActionKind.ideas => 'AI 正在梳理引导思路...',
        _AiActionKind.diagnose => 'AI 正在诊断你的手写过程...',
        _AiActionKind.solve => 'AI 正在生成完整解题过程...',
      };
    });

    try {
      String? boardBase64;
      if (hasDrawing &&
          (kind == _AiActionKind.diagnose || problemText.isEmpty)) {
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
      final AiBoardGuidance guidance;
      switch (kind) {
        case _AiActionKind.ideas:
          guidance = await api.generateBoardIdeas(
            problemText: problemText,
            boardImageBase64: boardBase64,
            problemImageBase64: photoBase64,
            hasHandwriting: hasDrawing,
          );
        case _AiActionKind.diagnose:
          guidance = await api.diagnoseBoardHandwriting(
            problemText: problemText,
            boardImageBase64: boardBase64!,
            problemImageBase64: photoBase64,
          );
        case _AiActionKind.solve:
          guidance = await api.solveBoardProblem(
            problemText: problemText,
            boardImageBase64: boardBase64,
            problemImageBase64: photoBase64,
          );
      }
      if (!mounted) return;

      // 智能排版：横屏优先右侧铺开，竖屏优先下方排列，避开已有区域
      final isWide = _canvasSize.width > _canvasSize.height;
      final metricsBefore = SmartBoardLayoutMetrics.compute(
        cards: _cards,
        visibility: _visibility,
        problemPhoto: _problemPhotoImage,
      );
      final pRect = metricsBefore.problemRect;
      final inkBounds = _computeHandwritingBounds();
      final cardW = _canvasSize.width > 0
          ? math.min(400.0, math.max(300.0, _canvasSize.width * (isWide ? 0.44 : 0.86)))
          : 380.0;

      late final Offset targetPos;
      late final BoardCardId cardId;
      switch (kind) {
        case _AiActionKind.ideas:
          cardId = BoardCardId.ideas;
          targetPos = pRect != null
              ? (isWide
                  ? Offset(pRect.right + 24, pRect.top)
                  : Offset(pRect.left, pRect.bottom + 20))
              : const Offset(24, 20);
        case _AiActionKind.diagnose:
          cardId = BoardCardId.diagnosis;
          final rightX = math.max(
            pRect != null ? pRect.right + 24 : 24.0,
            inkBounds != null && inkBounds.right < 900
                ? inkBounds.right + 24
                : 24.0,
          );
          targetPos = isWide
              ? Offset(rightX, pRect?.top ?? 20.0)
              : Offset(
                  24.0,
                  math.max(
                    pRect?.bottom ?? 20.0,
                    inkBounds?.bottom ?? 20.0,
                  ) +
                      20.0,
                );
        case _AiActionKind.solve:
          cardId = BoardCardId.solution;
          var anchorX = 24.0;
          var anchorY = 20.0;
          if (isWide) {
            if (pRect != null) anchorX = math.max(anchorX, pRect.right + 24);
            if (metricsBefore.ideasRect != null) {
              anchorX = math.max(anchorX, metricsBefore.ideasRect!.right + 24);
            }
            anchorY = pRect?.top ?? 20.0;
          } else {
            if (pRect != null) anchorY = math.max(anchorY, pRect.bottom + 20);
            if (metricsBefore.ideasRect != null) {
              anchorY = math.max(anchorY, metricsBefore.ideasRect!.bottom + 20);
            }
            if (metricsBefore.diagnosisRect != null) {
              anchorY =
                  math.max(anchorY, metricsBefore.diagnosisRect!.bottom + 20);
            }
          }
          targetPos = Offset(anchorX, anchorY);
      }

      setState(() {
        switch (kind) {
          case _AiActionKind.ideas:
            _cards = _cards.copyWith(
              ideas: guidance,
              ideasPos: targetPos,
              ideasWidth: cardW,
            );
            _visibility = _visibility.copyWith(showIdeasCard: true);
          case _AiActionKind.diagnose:
            _cards = _cards.copyWith(
              diagnosis: guidance,
              diagnosisPos: targetPos,
              diagnosisWidth: cardW,
            );
            _visibility = _visibility.copyWith(showDiagnosisCard: true);
          case _AiActionKind.solve:
            _cards = _cards.copyWith(
              solution: guidance,
              solutionPos: targetPos,
              solutionWidth: cardW,
            );
            _visibility = _visibility.copyWith(showSolutionCard: true);
        }
      });
      _scheduleDraftSave();

      final metricsAfter = SmartBoardLayoutMetrics.compute(
        cards: _cards,
        visibility: _visibility,
        problemPhoto: _problemPhotoImage,
      );
      final targetRect = metricsAfter.rectOf(cardId);
      if (targetRect != null) {
        _focusOnRect(targetRect, maxZoom: 1.0);
      }

      // 启动坐标级逐笔自动书写绘制动画！
      _startTraceAnimation(cardId, guidance);
      _showHint(
        switch (kind) {
          _AiActionKind.ideas => '正在逐笔绘制解题思路（引导不剧透答案）',
          _AiActionKind.diagnose => '正在逐笔绘制手写诊断批注',
          _AiActionKind.solve => '正在逐笔绘制完整解题过程与答案',
        },
      );
    } catch (e) {
      if (mounted) {
        GglFeedback.error(
          context,
          friendlyErrorMessage(e, 'AI 处理失败，请稍后重试'),
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
    final currentLandscape =
        MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
    final nextLandscape = !currentLandscape;
    setState(() => _isLandscape = nextLandscape);
    if (kIsWeb) {
      _showHint(nextLandscape ? '已切换横屏紧凑工具栏' : '已切换竖屏标准工具栏');
      return;
    }
    await SystemChrome.setPreferredOrientations(
      nextLandscape
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const [DeviceOrientation.portraitUp],
    );
    // 1.5秒后恢复自由重力旋转，既支持按钮主动横竖屏切换，又支持手机自然翻转
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && !kIsWeb) {
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    });
    _showHint(nextLandscape ? '已切为横屏大画板' : '已切为竖屏模式');
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
          buttonText: '关闭',
          onClose: () => Navigator.of(ctx).pop(),
          onPressed: () => Navigator.of(ctx).pop(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '已导出高清板书图（${(png.length / 1024).round()} KB）',
                style: TextStyle(color: AppTheme.mutedText(ctx), fontSize: 12),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
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
            title: const Text('画板图层与设置'),
            closeLabel: '完成',
            onClose: () => Navigator.of(ctx).pop(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '纸张底纹',
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
                  '白板图层显隐',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                _LayerToggleRow(
                  label: '题目板书',
                  available: _cards.problem != null,
                  value: _visibility.showProblemCard,
                  onChanged: (v) => updateState(
                    () => _visibility = _visibility.copyWith(showProblemCard: v),
                  ),
                ),
                _LayerToggleRow(
                  label: '原题照片',
                  available: _problemPhotoImage != null,
                  value: _visibility.showPhotoCard,
                  onChanged: (v) => updateState(
                    () => _visibility = _visibility.copyWith(showPhotoCard: v),
                  ),
                ),
                _LayerToggleRow(
                  label: 'AI 解题思路',
                  available: _cards.ideas != null,
                  value: _visibility.showIdeasCard,
                  onChanged: (v) => updateState(
                    () => _visibility = _visibility.copyWith(showIdeasCard: v),
                  ),
                ),
                _LayerToggleRow(
                  label: 'AI 手写诊断',
                  available: _cards.diagnosis != null,
                  value: _visibility.showDiagnosisCard,
                  onChanged: (v) => updateState(
                    () => _visibility =
                        _visibility.copyWith(showDiagnosisCard: v),
                  ),
                ),
                _LayerToggleRow(
                  label: 'AI 完整解题',
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
                    if (_cards.ideas != null ||
                        _cards.diagnosis != null ||
                        _cards.solution != null)
                      WelkButton(
                        size: WelkButtonSize.small,
                        variant: WelkButtonVariant.primary,
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _replayLastTrace();
                        },
                        child: const Text('重播逐笔绘制'),
                      ),
                    WelkButton(
                      size: WelkButtonSize.small,
                      variant: WelkButtonVariant.secondary,
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        unawaited(_previewExportFullBoard());
                      },
                      child: const Text('导出板书图'),
                    ),
                    if (_cards.ideas != null ||
                        _cards.diagnosis != null ||
                        _cards.solution != null)
                      WelkButton(
                        size: WelkButtonSize.small,
                        variant: WelkButtonVariant.warning,
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          setState(() {
                            _cards = _cards.copyWith(
                              clearIdeas: true,
                              clearDiagnosis: true,
                              clearSolution: true,
                            );
                          });
                          _scheduleDraftSave();
                          _showHint('已清空 AI 板书图层');
                        },
                        child: const Text('仅清 AI 板书'),
                      ),
                    WelkButton(
                      size: WelkButtonSize.small,
                      variant: WelkButtonVariant.error,
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await _confirmClearAll();
                      },
                      child: const Text('清空画板'),
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
      content: '将清除当前题目、手写笔迹、几何图形及全部 AI 板书内容。',
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
    _showHint('画板已清空');
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

  Widget _buildTopToolbar(
    BuildContext context,
    WelkColors colors,
    String plainProblem, {
    required bool compactLandscape,
  }) {
    final stemWidget = GestureDetector(
      onTap: _cards.problem == null
          ? _openProblemCaptureSheet
          : _openManualProblemDialog,
      child: Container(
        height: compactLandscape ? 32 : 34,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: colors.muted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.outline, width: 1.4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                plainProblem.isNotEmpty
                    ? plainProblem
                    : (compactLandscape ? '点此拍题/录题' : '拍照或输入数学题目，开始智能画板'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.ink,
                  fontSize: compactLandscape ? 12 : 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              Icons.edit_note_rounded,
              size: 15,
              color: AppTheme.mutedText(context),
            ),
          ],
        ),
      ),
    );

    final aiActionRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CompactActionBtn(
          icon: Icons.photo_camera_rounded,
          label: '拍照',
          bg: colors.accent,
          fg: colors.onFill(colors.accent),
          outline: colors.outline,
          disabled: _busyAi,
          onTap: _openProblemCaptureSheet,
        ),
        const SizedBox(width: 5),
        _CompactActionBtn(
          icon: Icons.lightbulb_outline_rounded,
          label: '思路',
          bg: const Color(0xFFDBEAFE),
          fg: const Color(0xFF1D4ED8),
          outline: colors.outline,
          disabled: _busyAi,
          onTap: () => _runAiAction(_AiActionKind.ideas),
        ),
        const SizedBox(width: 5),
        _CompactActionBtn(
          icon: Icons.fact_check_outlined,
          label: '诊断',
          bg: const Color(0xFFFEE2E2),
          fg: const Color(0xFFB91C1C),
          outline: colors.outline,
          disabled: _busyAi,
          onTap: () => _runAiAction(_AiActionKind.diagnose),
        ),
        const SizedBox(width: 5),
        _CompactActionBtn(
          icon: Icons.auto_fix_high_rounded,
          label: '解题',
          bg: const Color(0xFFD1FAE5),
          fg: const Color(0xFF047857),
          outline: colors.outline,
          disabled: _busyAi,
          onTap: () => _runAiAction(_AiActionKind.solve),
        ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: colors.paper,
        border: Border(
          bottom: BorderSide(color: colors.outline, width: colors.borderWidth),
        ),
      ),
      child: SafeArea(
        top: true,
        bottom: false,
        left: true,
        right: true,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 8,
            vertical: compactLandscape ? 4 : 6,
          ),
          child: compactLandscape
              // 手机横屏：单行极紧凑顶栏，最大化留给画布的垂直书写高度！
              ? Row(
                  children: [
                    _BoardChip(
                      label: '返回',
                      active: false,
                      compact: true,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(width: 140, child: stemWidget),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            aiActionRow,
                            const SizedBox(width: 6),
                            _BoardChip(
                              label: '竖屏',
                              active: false,
                              compact: true,
                              onTap: _toggleOrientation,
                            ),
                            const SizedBox(width: 4),
                            _BoardChip(
                              label: _immersiveDockHidden ? '显底栏' : '大画布',
                              active: _immersiveDockHidden,
                              compact: true,
                              onTap: () => setState(
                                () => _immersiveDockHidden =
                                    !_immersiveDockHidden,
                              ),
                            ),
                            const SizedBox(width: 4),
                            _BoardChip(
                              label: '图层',
                              active: false,
                              compact: true,
                              onTap: _openBoardSettingsDrawer,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              // 竖屏 / 宽屏：清晰双行顶栏
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _BoardChip(
                          label: '返回',
                          active: false,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: stemWidget),
                        const SizedBox(width: 6),
                        _BoardChip(
                          label: '横屏',
                          active: false,
                          onTap: _toggleOrientation,
                        ),
                        const SizedBox(width: 5),
                        _BoardChip(
                          label: '图层',
                          active: false,
                          onTap: _openBoardSettingsDrawer,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: aiActionRow,
                          ),
                        ),
                        if (_aiStatus != null && _aiStatus!.ready) ...[
                          const SizedBox(width: 6),
                          Text(
                            _aiStatus!.modelName,
                            style: TextStyle(
                              color: AppTheme.mutedText(context),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildBottomDock(
    BuildContext context,
    WelkColors colors, {
    required bool compactLandscape,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colors.paper,
        border: Border(
          top: BorderSide(color: colors.outline, width: colors.borderWidth),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        left: true,
        right: true,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 8,
            vertical: compactLandscape ? 4 : 6,
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
                          _tool == BoardToolMode.pixelEraser ||
                          _tool == BoardToolMode.hand) {
                        _tool = BoardToolMode.pen;
                      }
                    }),
                    child: Container(
                      width: compactLandscape ? 21 : 23,
                      height: compactLandscape ? 21 : 23,
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
                              ? 2.8
                              : 1.4,
                        ),
                      ),
                    ),
                  ),
                _BoardChip(
                  label: _strokeLabels[_widthIdx],
                  active: false,
                  compact: compactLandscape,
                  onTap: () {
                    setState(
                      () => _widthIdx = (_widthIdx + 1) % _strokeWidths.length,
                    );
                    _savePrefs();
                  },
                ),
                const SizedBox(width: 5),
                _BoardChip(
                  label: '钢笔',
                  active: _tool == BoardToolMode.pen,
                  compact: compactLandscape,
                  onTap: () => setState(() {
                    _tool = BoardToolMode.pen;
                    _showShapePicker = false;
                  }),
                ),
                const SizedBox(width: 5),
                _BoardChip(
                  label: '荧光',
                  active: _tool == BoardToolMode.highlighter,
                  compact: compactLandscape,
                  onTap: () => setState(() {
                    _tool = BoardToolMode.highlighter;
                    _showShapePicker = false;
                  }),
                ),
                const SizedBox(width: 5),
                _BoardChip(
                  label: _isShapeTool
                      ? _shapeLabel(_shapeKindForTool(_tool))
                      : '图形',
                  active: _isShapeTool || _showShapePicker,
                  compact: compactLandscape,
                  onTap: () => setState(
                    () => _showShapePicker = !_showShapePicker,
                  ),
                ),
                const SizedBox(width: 5),
                _BoardChip(
                  label: '橡皮',
                  active: _tool == BoardToolMode.strokeEraser,
                  compact: compactLandscape,
                  onTap: () => setState(() {
                    _tool = BoardToolMode.strokeEraser;
                    _showShapePicker = false;
                  }),
                ),
                const SizedBox(width: 5),
                _BoardChip(
                  label: '移动',
                  active: _tool == BoardToolMode.hand,
                  compact: compactLandscape,
                  onTap: () => setState(() {
                    _tool = BoardToolMode.hand;
                    _showShapePicker = false;
                  }),
                ),
                const SizedBox(width: 6),
                _BoardChip(
                  label: '撤销',
                  active: false,
                  compact: compactLandscape,
                  disabled: _undoStack.isEmpty,
                  onTap: _handleUndo,
                ),
                const SizedBox(width: 4),
                _BoardChip(
                  label: '重做',
                  active: false,
                  compact: compactLandscape,
                  disabled: _redoStack.isEmpty,
                  onTap: _handleRedo,
                ),
                const SizedBox(width: 4),
                _BoardChip(
                  label: '清笔迹',
                  active: false,
                  compact: compactLandscape,
                  disabled: !_hasHandwriting,
                  onTap: _clearHandwritingOnly,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final media = MediaQuery.of(context);
    final isLandscapeNow =
        (media.size.width > media.size.height && media.size.height < 560) ||
            (kIsWeb && _isLandscape);
    final plainProblem = _cards.problem != null
        ? MathParser.renderPlainText(_cards.problem!.problemText)
        : '';
    final hasAnyAiBoard = _cards.ideas != null ||
        _cards.diagnosis != null ||
        _cards.solution != null;

    final overlayStyle = colors.isDark
        ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
        : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: colors.paper,
        body: Column(
          children: [
            // 1. 顶部安全区满铺导航与 AI 操作栏
            _buildTopToolbar(
              context,
              colors,
              plainProblem,
              compactLandscape: isLandscapeNow,
            ),

            // 2. 无限矢量画板主舞台（严格 ClipRect 隔离，绝不遮盖顶栏与底栏！）
            Expanded(
              child: ClipRect(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _canvasSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    return Stack(
                      clipBehavior: Clip.hardEdge,
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
                                diagnosisReveal: _diagnosisRevealCtrl.value,
                                solutionReveal: _solutionRevealCtrl.value,
                                draggingCardId: _draggingCardId,
                                eraserCursorWorld: _eraserCursorWorld,
                                eraserCursorRadius:
                                    16.0 / math.max(0.4, _zoom),
                              ),
                            ),
                          ),
                        ),

                        // 空画板简洁引导
                        if (_strokes.isEmpty &&
                            _shapes.isEmpty &&
                            _cards.problem == null &&
                            !hasAnyAiBoard &&
                            _activeStroke == null &&
                            !_busyAi)
                          const IgnorePointer(
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  '拍照或输入数学题 · 点击「思路」逐笔引导 · 写完点击「诊断」批改 · 点击「解题」完整板书',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12.8,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // 几何图形选择浮层
                        if (_showShapePicker)
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 12,
                            child: Center(
                              child: GglComicPanel(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
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
                                        compact: true,
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

                        // 左下角缩放 HUD
                        Positioned(
                          left: 10,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colors.paper.withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: colors.outline.withValues(alpha: 0.65),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () => _stepZoom(-0.2),
                                  child: Icon(
                                    Icons.remove_rounded,
                                    size: 15,
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
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () => _stepZoom(0.2),
                                  child: Icon(
                                    Icons.add_rounded,
                                    size: 15,
                                    color: colors.ink,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 12,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  color: colors.outline.withValues(alpha: 0.3),
                                ),
                                GestureDetector(
                                  onTap: _fitAllContent,
                                  child: Icon(
                                    Icons.fit_screen_rounded,
                                    size: 15,
                                    color: colors.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 右下角 AI 加载 / 逐笔自动绘制控制条 / 重播入口
                        if (_busyAi)
                          Positioned(
                            right: 10,
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF93C5FD),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 13,
                                    height: 13,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    _busyAiLabel,
                                    style: const TextStyle(
                                      color: Color(0xFF1D4ED8),
                                      fontSize: 11.8,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (_anyAiAnimating)
                          Positioned(
                            right: 10,
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: colors.paper.withValues(alpha: 0.96),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF2563EB),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.draw_rounded,
                                    size: 14,
                                    color: Color(0xFF2563EB),
                                  ),
                                  const SizedBox(width: 5),
                                  const Text(
                                    '自动绘制中',
                                    style: TextStyle(
                                      color: Color(0xFF1D4ED8),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  GestureDetector(
                                    onTap: _toggleTraceSpeed,
                                    child: Text(
                                      '${_traceSpeed.toStringAsFixed(0)}x',
                                      style: TextStyle(
                                        color: colors.ink,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: _skipAllTraceAnimations,
                                    child: const Text(
                                      '立即画完',
                                      style: TextStyle(
                                        color: Color(0xFF059669),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (_floatingHint.isNotEmpty)
                          Positioned(
                            right: 10,
                            bottom: 8,
                            child: GglStatusTag(
                              label: _floatingHint,
                              variant: WelkBadgeVariant.info,
                            ),
                          )
                        else if (hasAnyAiBoard)
                          Positioned(
                            right: 10,
                            bottom: 8,
                            child: GestureDetector(
                              onTap: _replayLastTrace,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.paper.withValues(alpha: 0.94),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color:
                                        colors.outline.withValues(alpha: 0.65),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.replay_rounded,
                                      size: 14,
                                      color: colors.ink,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '重播绘制',
                                      style: TextStyle(
                                        color: colors.ink,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // 3. 底部安全区满铺工具 Dock（手机横屏大画布模式下可折叠释放 100% 底部高度）
            if (!(_immersiveDockHidden && isLandscapeNow))
              _buildBottomDock(
                context,
                colors,
                compactLandscape: isLandscapeNow,
              ),
          ],
        ),
      ),
    );
  }
}

class _CompactActionBtn extends StatelessWidget {
  const _CompactActionBtn({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
    required this.outline,
    required this.onTap,
    this.disabled = false,
  });

  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final Color outline;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.48 : 1.0,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: outline, width: 1.4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
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
    this.compact = false,
  });

  final String label;
  final bool active;
  final bool disabled;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    return Opacity(
      opacity: disabled ? 0.42 : 1.0,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 4.5 : 6,
          ),
          decoration: BoxDecoration(
            color: active ? colors.accent : colors.paper,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.outline, width: 1.4),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? colors.onFill(colors.accent) : colors.ink,
              fontSize: compact ? 11.5 : 12,
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
