import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

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
import '../../widgets/ggl_skin_widgets.dart';
import '../../widgets/smart_board/board_models.dart';
import '../../widgets/smart_board/photo_figure_extractor.dart';
import '../../widgets/smart_board/smart_board_painter.dart';
import '../../widgets/smart_board/smart_board_result_panel.dart';
import 'photo_crop_page.dart';

/// 首页「AI 智能手写画板」：
/// - 横竖屏严格锁定（切横屏不会自动回弹竖屏），顶/底安全区满铺无白边；
/// - 拍照/选图后先进入选区裁剪，再识别题目并从原图 1:1 裁剪提纯还原配图；
/// - 移除荧光笔与模型名展示，精简底栏最大化画布空间，新增「画布操作」菜单（橡皮/移动/撤销/清笔迹）；
/// - 题目/思路/诊断/解题全部采用当前 UI 组件库（WelkUI / Skribble）渲染，风格统一且严格裁剪在画布内；
/// - 解题面板顶部仅呈现纯粹答案，解题思路折叠/排布在下方。
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
    with SingleTickerProviderStateMixin {
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
  bool _showCanvasOpsMenu = false;

  // 题目与 AI 结果（全部使用 UI 库组件渲染，不在 Canvas 上自绘）
  AiRecognizeResult? _problem;
  AiBoardGuidance? _ideas;
  AiBoardGuidance? _diagnosis;
  AiBoardGuidance? _solution;

  Uint8List? _croppedPhotoBytes;
  List<ExtractedBoardFigure> _extractedFigures = const [];
  bool _purifyFigures = true;

  BoardResultTab _activeResultTab = BoardResultTab.problem;
  bool _resultCollapsed = false;
  Offset _resultPanelPos = const Offset(10, 10);

  bool _busyAi = false;
  String _busyAiLabel = '';

  // 逐步呈现动画（用于思路/诊断/解题 UI 卡片与矢量图）
  late final AnimationController _revealCtrl;
  double _traceSpeed = 1.0;

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

  String _floatingHint = '';
  Timer? _hintTimer;
  Timer? _draftSaveTimer;

  @override
  void initState() {
    super.initState();
    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
      value: 1.0,
    )..addListener(() {
        if (mounted) setState(() {});
      });

    // 默认锁定竖屏，仅在用户主动点击「横屏」时严格锁定横屏，避免传感器误触发来回弹跳
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
    }

    _restorePrefsAndDraft();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.autoOpenCapture && mounted) {
        unawaited(_openProblemCaptureSheet());
      }
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _draftSaveTimer?.cancel();
    _revealCtrl.dispose();
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
        if (draft['problem'] is Map<String, dynamic>) {
          _problem = AiRecognizeResult.fromJson(
            draft['problem'] as Map<String, dynamic>,
          );
        }
        if (draft['ideas'] is Map<String, dynamic>) {
          _ideas = AiBoardGuidance.fromJson(
            draft['ideas'] as Map<String, dynamic>,
          );
        }
        if (draft['diagnosis'] is Map<String, dynamic>) {
          _diagnosis = AiBoardGuidance.fromJson(
            draft['diagnosis'] as Map<String, dynamic>,
          );
        }
        if (draft['solution'] is Map<String, dynamic>) {
          _solution = AiBoardGuidance.fromJson(
            draft['solution'] as Map<String, dynamic>,
          );
        }
        final photoB64 = draft['photoB64']?.toString();
        if (photoB64 != null && photoB64.isNotEmpty) {
          try {
            _croppedPhotoBytes = base64Decode(photoB64);
          } catch (_) {}
        }
        if (_croppedPhotoBytes != null &&
            _problem != null &&
            _problem!.figureBoxes.isNotEmpty) {
          unawaited(_rebuildExtractedFigures());
        }
      }
    } catch (_) {}
  }

  Future<void> _rebuildExtractedFigures() async {
    final photo = _croppedPhotoBytes;
    final boxes = _problem?.figureBoxes ?? const [];
    if (photo == null || boxes.isEmpty) return;
    final figs = await PhotoFigureExtractor.extractFromPhoto(photo, boxes);
    if (mounted) {
      setState(() => _extractedFigures = figs);
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
            _problem != null ||
            _ideas != null ||
            _diagnosis != null ||
            _solution != null;
        if (!hasAnything) {
          unawaited(cache.setSmartBoardDraft(null));
          return;
        }
        final map = <String, dynamic>{
          'strokes': _strokes.map((s) => s.toJson()).toList(),
          'shapes': _shapes.map((s) => s.toJson()).toList(),
          if (_problem != null) 'problem': _problem!.toJson(),
          if (_ideas != null) 'ideas': _ideas!.toJson(),
          if (_diagnosis != null) 'diagnosis': _diagnosis!.toJson(),
          if (_solution != null) 'solution': _solution!.toJson(),
        };
        if (_croppedPhotoBytes != null && _croppedPhotoBytes!.length <= 500000) {
          map['photoB64'] = base64Encode(_croppedPhotoBytes!);
        }
        unawaited(cache.setSmartBoardDraft(map));
      } catch (_) {}
    });
  }

  void _showHint(String text) {
    _hintTimer?.cancel();
    setState(() => _floatingHint = text);
    _hintTimer = Timer(const Duration(milliseconds: 1800), () {
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

  bool get _hasHandwriting =>
      _strokes.any((s) => !s.isEraser && s.points.isNotEmpty) ||
      _shapes.isNotEmpty;

  bool get _hasAnyResult =>
      _problem != null ||
      _ideas != null ||
      _diagnosis != null ||
      _solution != null;

  void _pushUndoCheckpoint() {
    _undoStack.add(BoardUndoSnapshot.capture(_strokes, _shapes));
    if (_undoStack.length > _maxHistory) _undoStack.removeAt(0);
  }

  void _handleUndo() {
    if (_undoStack.isEmpty) return;
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
    if (_showShapePicker || _showCanvasOpsMenu) {
      setState(() {
        _showShapePicker = false;
        _showCanvasOpsMenu = false;
      });
    }
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

    setState(() {
      _activeStroke = BoardStroke(
        colorValue: _activeColor.toARGB32(),
        width: _strokeWidths[_widthIdx],
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

    if (_canvasSize.width > 0 &&
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

  void _resetView() {
    setState(() {
      _zoom = 1.0;
      _panX = 0;
      _panY = 0;
    });
  }

  void _startRevealAnimation() {
    final baseMs = (2400 / _traceSpeed).round();
    _revealCtrl.duration = Duration(milliseconds: baseMs);
    _revealCtrl.forward(from: 0.0);
  }

  void _skipRevealAnimation() {
    _hintTimer?.cancel();
    setState(() => _floatingHint = '');
    _revealCtrl.value = 1.0;
  }

  void _toggleTraceSpeed() {
    setState(() => _traceSpeed = _traceSpeed >= 1.9 ? 1.0 : 2.0);
    if (_revealCtrl.isAnimating) {
      final cur = _revealCtrl.value;
      _revealCtrl.duration = Duration(milliseconds: (2400 / _traceSpeed).round());
      _revealCtrl.forward(from: cur);
    }
  }

  // ==================== 横竖屏严格锁定（修复横屏自动回弹竖屏） ====================

  Future<void> _toggleOrientation() async {
    final nextLandscape = !_isLandscape;
    setState(() {
      _isLandscape = nextLandscape;
      _showCanvasOpsMenu = false;
      _showShapePicker = false;
      if (!nextLandscape) _immersiveDockHidden = false;
    });
    if (kIsWeb) {
      _showHint(nextLandscape ? '已切换横屏大画板布局' : '已切换竖屏布局');
      return;
    }
    // 严格锁定所选方向，不再在 1.5 秒后解锁，彻底解决横屏几秒后自动跳回竖屏的问题
    await SystemChrome.setPreferredOrientations(
      nextLandscape
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const [DeviceOrientation.portraitUp],
    );
    _showHint(nextLandscape ? '已锁定横屏大画板' : '已锁定竖屏模式');
  }

  // ==================== 拍照裁剪 + 1:1 图形还原 + AI 三模式 ====================

  Future<void> _openProblemCaptureSheet() async {
    if (_busyAi) return;
    await showGglBottomSheet<void>(
      context: context,
      title: '导入数学题目',
      closeLabel: '取消',
      builder: (sheetCtx) {
        final colors = WelkTheme.of(sheetCtx).resolveColors(sheetCtx);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '拍照或选图后可自由框选题目范围，AI 将解析题干并 1:1 还原题目中的图形。',
              style: TextStyle(
                color: AppTheme.mutedText(sheetCtx),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (!kIsWeb) ...[
                  Expanded(
                    child: _CaptureOptionTile(
                      icon: Icons.photo_camera_rounded,
                      label: '拍照并框选',
                      subtitle: '拍摄题目后截取范围',
                      accent: colors.accent,
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        unawaited(_pickCropAndRecognize(ImageSource.camera));
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: _CaptureOptionTile(
                    icon: Icons.photo_library_rounded,
                    label: kIsWeb ? '上传图片并框选' : '相册选图并框选',
                    subtitle: '框选单道题更精准',
                    accent: colors.success,
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      unawaited(_pickCropAndRecognize(ImageSource.gallery));
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
                Navigator.of(sheetCtx).pop();
                unawaited(_openManualProblemDialog());
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickCropAndRecognize(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 2200,
        maxHeight: 2200,
        imageQuality: 92,
      );
      if (picked == null || !mounted) return;
      final rawBytes = await picked.readAsBytes();
      if (rawBytes.isEmpty || !mounted) return;

      // 1. 进入交互式选区裁剪页，截取目标题目范围
      final cropped = await Navigator.of(context).push<PhotoCropResult>(
        MaterialPageRoute<PhotoCropResult>(
          builder: (_) => PhotoCropPage(
            imageBytes: rawBytes,
            title: '截取题目范围',
            confirmLabel: '确认识别',
          ),
        ),
      );
      if (cropped == null || cropped.bytes.isEmpty || !mounted) return;

      // 若此前锁定了横屏，返回画板后确保方向保持一致
      if (!kIsWeb && _isLandscape) {
        await SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }

      if (!mounted) return;
      final api = context.read<GuoguanlaApi>();
      setState(() {
        _croppedPhotoBytes = cropped.bytes;
        _extractedFigures = const [];
        _busyAi = true;
        _busyAiLabel = '正在识别题目与 1:1 提取配图...';
      });

      final result = await api.recognizeMathProblem(
        imageBytes: cropped.bytes,
        filename: 'cropped-problem.png',
      );
      if (!mounted) return;

      // 2. 若 AI 返回配图归一化框坐标，从原裁剪图直接 1:1 精准切割并提纯
      var figures = await PhotoFigureExtractor.extractFromPhoto(
        cropped.bytes,
        result.figureBoxes,
      );
      if (!mounted) return;

      setState(() {
        _problem = result;
        _ideas = null;
        _diagnosis = null;
        _solution = null;
        _extractedFigures = figures;
        _activeResultTab = BoardResultTab.problem;
        _resultCollapsed = false;
        _resultPanelPos = const Offset(10, 10);
      });
      _scheduleDraftSave();
      _showHint(
        figures.isNotEmpty
            ? '题目已解析，配图已 1:1 还原'
            : (result.hasFigure
                ? '题目已解析，可点「重框配图」精准 1:1 框选图形'
                : '题目已解析'),
      );
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

  /// 允许用户在题目原图上手动精确 1:1 框选配图区域，确保任何复杂几何图都 100% 精准还原。
  Future<void> _recropFigureManually() async {
    final sourceBytes = _croppedPhotoBytes;
    if (sourceBytes == null || sourceBytes.isEmpty) {
      GglFeedback.warning(context, '请先拍照导入题目图片');
      return;
    }
    final existingBox =
        (_problem?.figureBoxes.isNotEmpty ?? false) ? _problem!.figureBoxes.first : null;
    final initialRect = existingBox != null
        ? Rect.fromLTWH(
            existingBox.x,
            existingBox.y,
            existingBox.w,
            existingBox.h,
          )
        : const Rect.fromLTRB(0.12, 0.36, 0.88, 0.92);

    final cropped = await Navigator.of(context).push<PhotoCropResult>(
      MaterialPageRoute<PhotoCropResult>(
        builder: (_) => PhotoCropPage(
          imageBytes: sourceBytes,
          title: '1:1 框选题目配图',
          confirmLabel: '确认还原配图',
          initialRect: initialRect,
        ),
      ),
    );
    if (cropped == null || cropped.bytes.isEmpty || !mounted) return;
    if (!kIsWeb && _isLandscape) {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    final box = BoardFigureBox(
      title: '原题配图 (1:1)',
      x: cropped.normalizedRect.left,
      y: cropped.normalizedRect.top,
      w: cropped.normalizedRect.width,
      h: cropped.normalizedRect.height,
    );
    final extracted = await PhotoFigureExtractor.buildFromCroppedBytes(
      cropped.bytes,
      title: box.title,
      box: box,
    );
    if (extracted == null || !mounted) return;
    setState(() {
      _extractedFigures = [extracted];
      if (_problem != null) {
        _problem = _problem!.copyWith(
          hasFigure: true,
          figureBoxes: [box],
        );
      }
    });
    _scheduleDraftSave();
    _showHint('已 1:1 更新原题配图');
  }

  Future<void> _openManualProblemDialog() async {
    await showGglBottomSheet<void>(
      context: context,
      title: _problem == null ? '输入数学题目' : '编辑题目内容',
      closeLabel: '取消',
      builder: (sheetCtx) => _ManualProblemSheet(
        initialTitle: _problem?.title ?? '',
        initialStem: _problem?.problemText ?? '',
        onSubmit: (title, text) {
          final updated = (_problem ??
                  const AiRecognizeResult(
                    title: '数学解答题',
                    problemText: '',
                    subjectTag: '数学',
                    questionType: '解答题',
                    difficulty: '自选',
                  ))
              .copyWith(
            title: title.isEmpty ? '数学解答题' : title,
            problemText: text,
          );
          setState(() {
            _problem = updated;
            _activeResultTab = BoardResultTab.problem;
            _resultCollapsed = false;
          });
          _scheduleDraftSave();
          Navigator.of(sheetCtx).pop();
          _showHint('题目已更新');
        },
      ),
    );
  }

  Future<void> _runAiAction(_AiActionKind kind) async {
    if (_busyAi) return;
    final problemText = _problem?.problemText.trim() ?? '';
    final hasDrawing = _hasHandwriting;

    if (kind == _AiActionKind.diagnose && !hasDrawing) {
      GglFeedback.warning(context, '请先在画板上写下你的解题过程，再点击诊断');
      return;
    }

    if (problemText.isEmpty && !hasDrawing && _croppedPhotoBytes == null) {
      GglFeedback.warning(context, '请先拍照识别题目、输入题干或在画板上写下题目');
      await _openProblemCaptureSheet();
      return;
    }

    setState(() {
      _showCanvasOpsMenu = false;
      _showShapePicker = false;
      _busyAi = true;
      _busyAiLabel = switch (kind) {
        _AiActionKind.ideas => 'AI 正在生成引导思路...',
        _AiActionKind.diagnose => 'AI 正在诊断手写过程...',
        _AiActionKind.solve => 'AI 正在生成解题答案...',
      };
    });

    try {
      String? boardBase64;
      if (hasDrawing &&
          (kind == _AiActionKind.diagnose || problemText.isEmpty)) {
        final pngBytes = await renderSmartBoardToPng(
          strokes: _strokes,
          shapes: _shapes,
          cards: const SmartBoardCardState(),
          includeProblemCard: false,
          includeAiCards: false,
          maxDimension: 1400,
        );
        boardBase64 = 'data:image/png;base64,${base64Encode(pngBytes)}';
      }

      String? photoBase64;
      if (_croppedPhotoBytes != null &&
          (_problem?.hasFigure == true || problemText.isEmpty)) {
        photoBase64 =
            'data:image/png;base64,${base64Encode(_croppedPhotoBytes!)}';
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

      setState(() {
        switch (kind) {
          case _AiActionKind.ideas:
            _ideas = guidance;
            _activeResultTab = BoardResultTab.ideas;
          case _AiActionKind.diagnose:
            _diagnosis = guidance;
            _activeResultTab = BoardResultTab.diagnosis;
          case _AiActionKind.solve:
            _solution = guidance;
            _activeResultTab = BoardResultTab.solution;
        }
        _resultCollapsed = false;
      });
      _scheduleDraftSave();
      _startRevealAnimation();
      _showHint(
        switch (kind) {
          _AiActionKind.ideas => '思路已生成（仅引导不剧透答案）',
          _AiActionKind.diagnose => '手写诊断已完成',
          _AiActionKind.solve => '答案已生成（思路在下方）',
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

  void _clearHandwritingOnly() {
    if (!_hasHandwriting) return;
    _pushUndoCheckpoint();
    setState(() {
      _strokes.clear();
      _shapes.clear();
      _activeStroke = null;
      _activeShape = null;
      _showCanvasOpsMenu = false;
    });
    _scheduleDraftSave();
    _showHint('已清空手写笔迹');
  }

  Future<void> _confirmClearAll() async {
    final ok = await GglFeedback.confirm(
      context,
      title: '清空整块画板？',
      content: '将清除当前题目、配图、手写笔迹以及全部 AI 内容。',
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
      _problem = null;
      _ideas = null;
      _diagnosis = null;
      _solution = null;
      _croppedPhotoBytes = null;
      _extractedFigures = const [];
      _showCanvasOpsMenu = false;
      _zoom = 1.0;
      _panX = 0;
      _panY = 0;
    });
    _scheduleDraftSave();
    _showHint('画板已全部清空');
  }

  String _shapeLabel(BoardShapeKind kind) => switch (kind) {
        BoardShapeKind.line => '直线',
        BoardShapeKind.dashedLine => '虚线',
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

  // ==================== 顶栏 / 画布操作面板 / 极简底栏 ====================

  Widget _buildTopToolbar(
    BuildContext context,
    WelkColors colors,
    String plainProblem, {
    required bool compactLandscape,
  }) {
    final stemPill = GestureDetector(
      onTap: _problem == null
          ? _openProblemCaptureSheet
          : _openManualProblemDialog,
      child: Container(
        height: 31,
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
                    : (compactLandscape ? '拍题/录题' : '拍照或输入数学题'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              Icons.edit_note_rounded,
              size: 14,
              color: AppTheme.mutedText(context),
            ),
          ],
        ),
      ),
    );

    final aiButtons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GglButton(
          label: '拍照',
          icon: Icons.photo_camera_rounded,
          variant: WelkButtonVariant.primary,
          compact: true,
          onPressed: _busyAi ? null : _openProblemCaptureSheet,
        ),
        const SizedBox(width: 5),
        GglButton(
          label: '思路',
          icon: Icons.lightbulb_outline_rounded,
          variant: WelkButtonVariant.info,
          compact: true,
          onPressed: _busyAi ? null : () => _runAiAction(_AiActionKind.ideas),
        ),
        const SizedBox(width: 5),
        GglButton(
          label: '诊断',
          icon: Icons.fact_check_outlined,
          variant: WelkButtonVariant.warning,
          compact: true,
          onPressed: _busyAi ? null : () => _runAiAction(_AiActionKind.diagnose),
        ),
        const SizedBox(width: 5),
        GglButton(
          label: '解题',
          icon: Icons.check_circle_outline_rounded,
          variant: WelkButtonVariant.success,
          compact: true,
          onPressed: _busyAi ? null : () => _runAiAction(_AiActionKind.solve),
        ),
      ],
    );

    final canvasOpsBtn = GglButton(
      label: '画布操作',
      icon: Icons.tune_rounded,
      variant: _showCanvasOpsMenu
          ? WelkButtonVariant.primary
          : WelkButtonVariant.secondary,
      compact: true,
      onPressed: () => setState(() {
        _showCanvasOpsMenu = !_showCanvasOpsMenu;
        _showShapePicker = false;
      }),
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
            vertical: compactLandscape ? 4 : 5,
          ),
          child: compactLandscape
              // 横屏极紧凑单行顶栏：最大化垂直画布空间
              ? Row(
                  children: [
                    GglButton(
                      label: '返回',
                      variant: WelkButtonVariant.secondary,
                      compact: true,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            aiButtons,
                            const SizedBox(width: 6),
                            canvasOpsBtn,
                            const SizedBox(width: 5),
                            GglButton(
                              label: '竖屏',
                              variant: WelkButtonVariant.secondary,
                              compact: true,
                              onPressed: _toggleOrientation,
                            ),
                            const SizedBox(width: 5),
                            GglButton(
                              label: _immersiveDockHidden ? '显底栏' : '大画布',
                              variant: _immersiveDockHidden
                                  ? WelkButtonVariant.primary
                                  : WelkButtonVariant.secondary,
                              compact: true,
                              onPressed: () => setState(
                                () => _immersiveDockHidden =
                                    !_immersiveDockHidden,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              // 竖屏精简双行顶栏（去掉 LongCat-2.5，替换为「画布操作」）
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        GglButton(
                          label: '返回',
                          variant: WelkButtonVariant.secondary,
                          compact: true,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: stemPill),
                        const SizedBox(width: 6),
                        GglButton(
                          label: '横屏',
                          variant: WelkButtonVariant.secondary,
                          compact: true,
                          onPressed: _toggleOrientation,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: aiButtons,
                          ),
                        ),
                        const SizedBox(width: 6),
                        canvasOpsBtn,
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// 点击「画布操作」后弹出的紧凑面板：直出 橡皮 / 移动 / 撤销 / 清笔迹 + 纸张底纹
  Widget _buildCanvasOpsPopover(BuildContext context, WelkColors colors) {
    return Positioned(
      top: 8,
      right: 10,
      child: SizedBox(
        width: 244,
        child: GglComicPanel(
          padding: const EdgeInsets.all(10),
          shadowOffset: const Offset(2, 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    '画布操作',
                    style: TextStyle(
                      color: colors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _showCanvasOpsMenu = false),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  GglButton(
                    label: '橡皮',
                    icon: Icons.auto_fix_normal_rounded,
                    compact: true,
                    variant: _tool == BoardToolMode.strokeEraser
                        ? WelkButtonVariant.primary
                        : WelkButtonVariant.secondary,
                    onPressed: () => setState(() {
                      _tool = BoardToolMode.strokeEraser;
                      _showCanvasOpsMenu = false;
                    }),
                  ),
                  GglButton(
                    label: '移动',
                    icon: Icons.pan_tool_alt_rounded,
                    compact: true,
                    variant: _tool == BoardToolMode.hand
                        ? WelkButtonVariant.primary
                        : WelkButtonVariant.secondary,
                    onPressed: () => setState(() {
                      _tool = BoardToolMode.hand;
                      _showCanvasOpsMenu = false;
                    }),
                  ),
                  GglButton(
                    label: '撤销',
                    icon: Icons.undo_rounded,
                    compact: true,
                    variant: WelkButtonVariant.secondary,
                    onPressed: _undoStack.isEmpty ? null : _handleUndo,
                  ),
                  GglButton(
                    label: '清笔迹',
                    icon: Icons.layers_clear_rounded,
                    compact: true,
                    variant: WelkButtonVariant.warning,
                    onPressed: _hasHandwriting ? _clearHandwritingOnly : null,
                  ),
                ],
              ),
              const GglDivider(verticalPadding: 8),
              Text(
                '画纸底纹',
                style: TextStyle(
                  color: AppTheme.mutedText(context),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (final entry in const [
                    (BoardPaperStyle.dots, '点阵'),
                    (BoardPaperStyle.grid, '方格'),
                    (BoardPaperStyle.lined, '横线'),
                    (BoardPaperStyle.plain, '纯白'),
                  ])
                    GglButton(
                      label: entry.$2,
                      compact: true,
                      variant: _paperStyle == entry.$1
                          ? WelkButtonVariant.primary
                          : WelkButtonVariant.secondary,
                      onPressed: () {
                        setState(() => _paperStyle = entry.$1);
                        _savePrefs();
                      },
                    ),
                ],
              ),
              const GglDivider(verticalPadding: 8),
              Row(
                children: [
                  Expanded(
                    child: GglButton(
                      label: '重置视野',
                      compact: true,
                      variant: WelkButtonVariant.secondary,
                      onPressed: () {
                        _resetView();
                        setState(() => _showCanvasOpsMenu = false);
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: GglButton(
                      label: '清空全部',
                      compact: true,
                      variant: WelkButtonVariant.error,
                      onPressed: () {
                        setState(() => _showCanvasOpsMenu = false);
                        unawaited(_confirmClearAll());
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 极简底部工具栏：去除荧光笔与重复操作按钮，最大程度留出大画布书写空间
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
            vertical: compactLandscape ? 3 : 5,
          ),
          child: Row(
            children: [
              Expanded(
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
                            width: 20,
                            height: 20,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: (_tool == BoardToolMode.pen ||
                                            _isShapeTool) &&
                                        _activeColor == c
                                    ? colors.accent
                                    : colors.outline,
                                width: (_tool == BoardToolMode.pen ||
                                            _isShapeTool) &&
                                        _activeColor == c
                                    ? 2.6
                                    : 1.3,
                              ),
                            ),
                          ),
                        ),
                      GglButton(
                        label: _strokeLabels[_widthIdx],
                        compact: true,
                        variant: WelkButtonVariant.secondary,
                        onPressed: () {
                          setState(
                            () => _widthIdx =
                                (_widthIdx + 1) % _strokeWidths.length,
                          );
                          _savePrefs();
                        },
                      ),
                      const SizedBox(width: 5),
                      GglButton(
                        label: '钢笔',
                        compact: true,
                        variant: _tool == BoardToolMode.pen
                            ? WelkButtonVariant.primary
                            : WelkButtonVariant.secondary,
                        onPressed: () => setState(() {
                          _tool = BoardToolMode.pen;
                          _showShapePicker = false;
                        }),
                      ),
                      const SizedBox(width: 5),
                      GglButton(
                        label: _isShapeTool
                            ? _shapeLabel(_shapeKindForTool(_tool))
                            : '图形',
                        compact: true,
                        variant: (_isShapeTool || _showShapePicker)
                            ? WelkButtonVariant.primary
                            : WelkButtonVariant.secondary,
                        onPressed: () => setState(() {
                          _showShapePicker = !_showShapePicker;
                          _showCanvasOpsMenu = false;
                        }),
                      ),
                      if (_tool == BoardToolMode.strokeEraser ||
                          _tool == BoardToolMode.hand) ...[
                        const SizedBox(width: 5),
                        GglStatusTag(
                          label: _tool == BoardToolMode.strokeEraser
                              ? '橡皮中'
                              : '移动中',
                          variant: WelkBadgeVariant.warning,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // 紧凑内嵌缩放控制（不占画布内部空间）
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _stepZoom(-0.2),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Icon(Icons.remove_rounded,
                          size: 15, color: colors.ink),
                    ),
                  ),
                  GestureDetector(
                    onTap: _resetView,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Text(
                        '${(_zoom * 100).round()}%',
                        style: TextStyle(
                          color: colors.ink,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _stepZoom(0.2),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Icon(Icons.add_rounded,
                          size: 15, color: colors.ink),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final media = MediaQuery.of(context);
    final isLandscapeNow = _isLandscape ||
        (media.size.width > media.size.height && media.size.height < 560);
    final plainProblem = _problem != null
        ? MathParser.renderPlainText(_problem!.problemText)
        : '';

    final overlayStyle = colors.isDark
        ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
        : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: colors.paper,
        body: Column(
          children: [
            // 1. 顶部安全区满铺操作栏
            _buildTopToolbar(
              context,
              colors,
              plainProblem,
              compactLandscape: isLandscapeNow,
            ),

            // 2. 纯净大画布舞台（严格 ClipRect 隔离，绝不覆盖上下导航）
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
                        // 手写与几何矢量画布（仅渲染纸张、学生笔迹、几何图与橡皮环）
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
                                cards: const SmartBoardCardState(),
                                eraserCursorWorld: _eraserCursorWorld,
                                eraserCursorRadius:
                                    16.0 / math.max(0.4, _zoom),
                              ),
                            ),
                          ),
                        ),

                        // 空画板极简提示
                        if (_strokes.isEmpty &&
                            _shapes.isEmpty &&
                            !_hasAnyResult &&
                            _activeStroke == null &&
                            !_busyAi)
                          const IgnorePointer(
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  '拍照框选数学题 · 点击「思路」引导 · 写完点「诊断」批改 · 点击「解题」直看答案',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12.6,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // 统一 UI 库渲染的题目/思路/诊断/解题面板（自动适配 WelkUI / Skribble）
                        if (_hasAnyResult)
                          SmartBoardResultPanel(
                            canvasSize: _canvasSize,
                            activeTab: _activeResultTab,
                            collapsed: _resultCollapsed,
                            position: _resultPanelPos,
                            onPositionChanged: (pos) =>
                                setState(() => _resultPanelPos = pos),
                            onTabChanged: (t) =>
                                setState(() => _activeResultTab = t),
                            onToggleCollapsed: () => setState(
                              () => _resultCollapsed = !_resultCollapsed,
                            ),
                            onEditProblem: _openManualProblemDialog,
                            onRecropFigure: _recropFigureManually,
                            onCloseActiveTab: () =>
                                setState(() => _resultCollapsed = true),
                            problem: _problem,
                            ideas: _ideas,
                            diagnosis: _diagnosis,
                            solution: _solution,
                            extractedFigures: _extractedFigures,
                            hasSourcePhoto: _croppedPhotoBytes != null,
                            purifyFigures: _purifyFigures,
                            onTogglePurifyFigures: () => setState(
                              () => _purifyFigures = !_purifyFigures,
                            ),
                            revealProgress: _revealCtrl.value,
                            isAnimating: _revealCtrl.isAnimating,
                            traceSpeed: _traceSpeed,
                            onToggleSpeed: _toggleTraceSpeed,
                            onSkipAnimation: _skipRevealAnimation,
                            onReplayAnimation: _startRevealAnimation,
                          ),

                        // 「画布操作」弹出面板
                        if (_showCanvasOpsMenu)
                          _buildCanvasOpsPopover(context, colors),

                        // 几何图形选择条
                        if (_showShapePicker)
                          Positioned(
                            left: 10,
                            right: 10,
                            bottom: 10,
                            child: Center(
                              child: GglComicPanel(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                shadowOffset: const Offset(2, 2),
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final kind in BoardShapeKind.values)
                                      GglButton(
                                        label: _shapeLabel(kind),
                                        compact: true,
                                        variant: _isShapeTool &&
                                                _shapeKindForTool(_tool) == kind
                                            ? WelkButtonVariant.primary
                                            : WelkButtonVariant.secondary,
                                        onPressed: () => setState(() {
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

                        // AI 处理中提示（UI 库面板）
                        if (_busyAi)
                          Positioned(
                            right: 10,
                            bottom: 8,
                            child: GglComicPanel(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              shadowOffset: const Offset(1.5, 1.5),
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
                                    style: TextStyle(
                                      color: colors.ink,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
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
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // 3. 极简底部工具栏（手机横屏大画布模式下可一键折叠）
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
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: colors.outline, width: 1.8),
            ),
            child: Icon(icon, size: 19, color: colors.onFill(accent)),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: colors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
            Text(
              subtitle,
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

class _ManualProblemSheet extends StatefulWidget {
  const _ManualProblemSheet({
    required this.initialTitle,
    required this.initialStem,
    required this.onSubmit,
  });

  final String initialTitle;
  final String initialStem;
  final void Function(String title, String stem) onSubmit;

  @override
  State<_ManualProblemSheet> createState() => _ManualProblemSheetState();
}

class _ManualProblemSheetState extends State<_ManualProblemSheet> {
  late String _title;
  late final TextEditingController _stemCtrl;

  @override
  void initState() {
    super.initState();
    _title = widget.initialTitle;
    _stemCtrl = TextEditingController(text: widget.initialStem);
  }

  @override
  void dispose() {
    _stemCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        GglInput(
          label: '题目标题（选填）',
          value: _title,
          placeholder: '例如：二次函数压轴题',
          onChanged: (v) => setState(() => _title = v),
        ),
        const SizedBox(height: 10),
        Text(
          '题干内容（支持 LaTeX 如 \$x^2-4x+3=0\$）',
          style: TextStyle(
            color: colors.ink,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _stemCtrl,
          minLines: 4,
          maxLines: 7,
          decoration: InputDecoration(
            hintText: '输入或粘贴数学题干...',
            filled: true,
            fillColor: colors.paper,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 14),
        GglBlockButton(
          label: '保存到画板',
          onPressed: () {
            final text = _stemCtrl.text.trim();
            if (text.isEmpty) {
              GglFeedback.warning(context, '请输入数学题目内容');
              return;
            }
            widget.onSubmit(_title.trim(), text);
          },
        ),
      ],
    );
  }
}
