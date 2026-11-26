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
import '../../widgets/math_text.dart';
import '../../widgets/smart_board/board_diagram_painter.dart';
import '../../widgets/smart_board/board_handwriting_validator.dart';
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
  static const int _maxSavedBoards = 25;

  final ImagePicker _picker = ImagePicker();
  GlobalCache? _cache;

  String _boardId = '';
  int _boardCreatedAtMs = 0;
  List<SavedSmartBoardRecord> _savedRecords = <SavedSmartBoardRecord>[];
  bool _recognizedFromHandwriting = false;

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
    _cache = context.read<GlobalCache>();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _boardId = _generateBoardId(nowMs);
    _boardCreatedAtMs = nowMs;

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
    _flushBoardSave(updateUi: false);
    _revealCtrl.dispose();
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
    }
    super.dispose();
  }

  String _generateBoardId([int? nowMs]) =>
      'sb_${nowMs ?? DateTime.now().millisecondsSinceEpoch}';

  String _defaultUntitledTitle([int? timestampMs]) {
    final dt = DateTime.fromMillisecondsSinceEpoch(
      timestampMs ?? _boardCreatedAtMs,
    );
    String two(int n) => n.toString().padLeft(2, '0');
    return '未命名画板 ${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  void _restorePrefsAndDraft() {
    try {
      final cache = _cache;
      if (cache == null) return;
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

      _savedRecords = cache.smartBoardRecords
          .map(SavedSmartBoardRecord.fromJson)
          .whereType<SavedSmartBoardRecord>()
          .toList()
        ..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));

      final draft = cache.smartBoardDraft;
      if (draft != null) {
        final draftWithId = Map<String, dynamic>.from(draft);
        if ((draftWithId['id']?.toString().trim() ?? '').isEmpty) {
          draftWithId['id'] = _boardId;
          draftWithId['createdAtMs'] = _boardCreatedAtMs;
        }
        final restored = SavedSmartBoardRecord.fromJson(draftWithId);
        if (restored != null) {
          _applyRecordState(restored, notify: false);
        }
      }
    } catch (_) {}
  }

  void _applyRecordState(
    SavedSmartBoardRecord record, {
    bool notify = true,
  }) {
    Uint8List? photoBytes;
    if (record.photoB64 != null && record.photoB64!.isNotEmpty) {
      try {
        photoBytes = base64Decode(record.photoB64!);
      } catch (_) {}
    }

    BoardResultTab nextTab = BoardResultTab.problem;
    if (record.activeResultTabName != null) {
      nextTab = BoardResultTab.values.firstWhere(
        (t) => t.name == record.activeResultTabName,
        orElse: () => BoardResultTab.problem,
      );
    }

    void mutate() {
      _boardId = record.id;
      _boardCreatedAtMs = record.createdAtMs;
      _strokes
        ..clear()
        ..addAll(record.strokes.map((s) => s.clone()));
      _shapes
        ..clear()
        ..addAll(record.shapes.map((s) => s.clone()));
      _undoStack.clear();
      _activeStroke = null;
      _activeShape = null;
      _paperStyle = record.paperStyle;
      _panX = record.panX;
      _panY = record.panY;
      _zoom = record.zoom;
      _problem = record.problem;
      _ideas = record.ideas;
      _diagnosis = record.diagnosis;
      _solution = record.solution;
      _croppedPhotoBytes = photoBytes;
      _extractedFigures = const [];
      _purifyFigures = record.purifyFigures;
      _activeResultTab = nextTab;
      _resultCollapsed = record.resultCollapsed;
      _resultPanelPos = record.resultPanelPos ?? const Offset(10, 10);
      _recognizedFromHandwriting = false;
      _showCanvasOpsMenu = false;
      _showShapePicker = false;
    }

    if (notify && mounted) {
      setState(mutate);
    } else {
      mutate();
    }

    if (photoBytes != null &&
        record.problem != null &&
        record.problem!.figureBoxes.isNotEmpty) {
      unawaited(_rebuildExtractedFigures());
    }
  }

  SavedSmartBoardRecord _buildCurrentRecord() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final photoB64 =
        (_croppedPhotoBytes != null && _croppedPhotoBytes!.length <= 420000)
            ? base64Encode(_croppedPhotoBytes!)
            : null;
    return SavedSmartBoardRecord(
      id: _boardId,
      title: SavedSmartBoardRecord.deriveTitle(
        _problem,
        fallback: _defaultUntitledTitle(_boardCreatedAtMs),
      ),
      createdAtMs: _boardCreatedAtMs,
      updatedAtMs: nowMs,
      strokes: _strokes.map((s) => s.clone()).toList(),
      shapes: _shapes.map((s) => s.clone()).toList(),
      paperStyle: _paperStyle,
      panX: _panX,
      panY: _panY,
      zoom: _zoom,
      problem: _problem,
      ideas: _ideas,
      diagnosis: _diagnosis,
      solution: _solution,
      photoB64: photoB64,
      purifyFigures: _purifyFigures,
      activeResultTabName: _activeResultTab.name,
      resultCollapsed: _resultCollapsed,
      resultPanelPos: _resultPanelPos,
    );
  }

  void _flushBoardSave({bool updateUi = true}) {
    final cache = _cache;
    if (cache == null) return;
    try {
      final record = _buildCurrentRecord();
      if (!record.hasMeaningfulContent) {
        unawaited(cache.setSmartBoardDraft(null));
        return;
      }
      final recordJson = record.toJson();
      unawaited(cache.setSmartBoardDraft(recordJson));

      final nextList = List<SavedSmartBoardRecord>.from(_savedRecords)
        ..removeWhere((r) => r.id == record.id)
        ..insert(0, record);
      if (nextList.length > _maxSavedBoards) {
        nextList.removeRange(_maxSavedBoards, nextList.length);
      }
      // 保留前 8 条记录的完整原图缓存，较早记录保留题目/笔迹/AI 全部信息避免本地存储膨胀
      final serialized = <Map<String, dynamic>>[];
      for (var i = 0; i < nextList.length; i++) {
        final map = nextList[i].toJson();
        if (i >= 8) {
          map.remove('photoB64');
        }
        serialized.add(map);
      }
      unawaited(cache.setSmartBoardRecords(serialized));
      if (updateUi && mounted) {
        setState(() => _savedRecords = nextList);
      } else {
        _savedRecords = nextList;
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
      final cache = _cache;
      if (cache == null) return;
      unawaited(
        cache.setSmartBoardPrefs({
          'paper': _paperStyle.name,
          'widthIdx': _widthIdx,
        }),
      );
    } catch (_) {}
  }

  void _scheduleDraftSave({bool immediate = false}) {
    _draftSaveTimer?.cancel();
    if (immediate) {
      _flushBoardSave(updateUi: true);
      return;
    }
    _draftSaveTimer = Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      _flushBoardSave(updateUi: true);
    });
  }

  void _createNewBoard() {
    _draftSaveTimer?.cancel();
    _flushBoardSave(updateUi: true);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final fresh = SavedSmartBoardRecord(
      id: _generateBoardId(nowMs),
      title: _defaultUntitledTitle(nowMs),
      createdAtMs: nowMs,
      updatedAtMs: nowMs,
      paperStyle: _paperStyle,
    );
    _applyRecordState(fresh, notify: true);
    unawaited(_cache?.setSmartBoardDraft(null));
    _showHint('已新建空白画板（原画板已自动保存）');
  }

  void _loadSavedBoard(SavedSmartBoardRecord record) {
    if (record.id == _boardId) {
      _showHint('当前正在编辑此画板');
      return;
    }
    _draftSaveTimer?.cancel();
    _flushBoardSave(updateUi: true);
    _applyRecordState(record, notify: true);
    _scheduleDraftSave(immediate: true);
    _showHint('已恢复画板：${record.title}');
  }

  void _deleteSavedBoard(SavedSmartBoardRecord record) {
    final nextList = List<SavedSmartBoardRecord>.from(_savedRecords)
      ..removeWhere((r) => r.id == record.id);
    setState(() => _savedRecords = nextList);
    unawaited(
      _cache?.setSmartBoardRecords(nextList.map((e) => e.toJson()).toList()),
    );
    if (record.id == _boardId) {
      unawaited(_cache?.setSmartBoardDraft(null));
    }
  }

  String _formatRecordTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<void> _openSavedBoardsSheet() async {
    _draftSaveTimer?.cancel();
    _flushBoardSave(updateUi: true);
    await showGglBottomSheet<void>(
      context: context,
      title: '已保存画板（${_savedRecords.length}）',
      closeLabel: '关闭',
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final colors = WelkTheme.of(ctx).resolveColors(ctx);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '所有画板会自动按题目标题保存完整笔迹、配图与 AI 记录。',
                        style: TextStyle(
                          color: AppTheme.mutedText(ctx),
                          fontSize: 12.2,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GglButton(
                      label: '新建画板',
                      icon: Icons.add_rounded,
                      compact: true,
                      variant: WelkButtonVariant.primary,
                      onPressed: () {
                        Navigator.of(sheetCtx).pop();
                        _createNewBoard();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_savedRecords.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    child: Center(
                      child: Text(
                        '还没有已保存的画板，识题或书写后会自动保存。',
                        style: TextStyle(
                          color: AppTheme.mutedText(ctx),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 380),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _savedRecords.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (itemCtx, index) {
                        final rec = _savedRecords[index];
                        final isCurrent = rec.id == _boardId;
                        return GglComicPanel(
                          color: isCurrent
                              ? AppTheme.mutedSurfaceColor(itemCtx)
                              : AppTheme.surfaceColor(itemCtx),
                          padding: const EdgeInsets.all(10),
                          shadowOffset: const Offset(2, 2),
                          onTap: () {
                            Navigator.of(sheetCtx).pop();
                            _loadSavedBoard(rec);
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      rec.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.ink,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        fontFamilyFallback:
                                            AppTheme.cjkFontFallback,
                                      ),
                                    ),
                                  ),
                                  if (isCurrent) ...[
                                    const SizedBox(width: 6),
                                    const GglStatusTag(
                                      label: '当前',
                                      variant: WelkBadgeVariant.success,
                                    ),
                                  ],
                                  const SizedBox(width: 6),
                                  GglButton(
                                    label: '删除',
                                    compact: true,
                                    variant: WelkButtonVariant.ghost,
                                    onPressed: () {
                                      _deleteSavedBoard(rec);
                                      setSheetState(() {});
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Wrap(
                                spacing: 5,
                                runSpacing: 4,
                                children: [
                                  GglStatusTag(
                                    label: _formatRecordTime(rec.updatedAtMs),
                                    neutral: true,
                                  ),
                                  if (rec.strokes.isNotEmpty)
                                    GglStatusTag(
                                      label: '笔迹 ${rec.strokes.length}',
                                      neutral: true,
                                    ),
                                  if (rec.shapes.isNotEmpty)
                                    GglStatusTag(
                                      label: '图形 ${rec.shapes.length}',
                                      neutral: true,
                                    ),
                                  if (rec.photoB64 != null &&
                                      rec.photoB64!.isNotEmpty)
                                    const GglStatusTag(
                                      label: '含原图',
                                      variant: WelkBadgeVariant.info,
                                    ),
                                  if (rec.ideas != null)
                                    const GglStatusTag(
                                      label: '已思路',
                                      variant: WelkBadgeVariant.info,
                                    ),
                                  if (rec.diagnosis != null)
                                    const GglStatusTag(
                                      label: '已诊断',
                                      variant: WelkBadgeVariant.warning,
                                    ),
                                  if (rec.solution != null)
                                    const GglStatusTag(
                                      label: '已解题',
                                      variant: WelkBadgeVariant.success,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
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
              '支持拍照框选题目、直接识别画板上写出的数学题，或手动输入/编辑题干。',
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
              label: '识别画板手写题目',
              icon: Icons.draw_rounded,
              variant: WelkButtonVariant.info,
              onPressed: () {
                Navigator.of(sheetCtx).pop();
                unawaited(_recognizeFromBoardHandwriting());
              },
            ),
            const SizedBox(height: 8),
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
        _busyAiLabel = '正在识别题目并矢量重绘配图...';
      });

      final result = await api.recognizeMathProblem(
        imageBytes: cropped.bytes,
        filename: 'cropped-problem.png',
        sourceType: 'PHOTO',
      );
      if (!mounted) return;

      // 2. 若 AI 返回可选原图配图框，提取作为「原图对照」备用（主展示优先使用矢量重绘 diagrams）
      var figures = await PhotoFigureExtractor.extractFromPhoto(
        cropped.bytes,
        result.figureBoxes,
      );
      if (!mounted) return;

      // 导入新题前自动清空旧手写笔迹（保留 1 步撤销快照以便误触找回）
      if (_strokes.isNotEmpty || _shapes.isNotEmpty) {
        _pushUndoCheckpoint();
      }
      setState(() {
        _strokes.clear();
        _shapes.clear();
        _activeStroke = null;
        _activeShape = null;
        _zoom = 1.0;
        _panX = 0;
        _panY = 0;
        _problem = result;
        _ideas = null;
        _diagnosis = null;
        _solution = null;
        _extractedFigures = figures;
        _recognizedFromHandwriting = false;
        _activeResultTab = BoardResultTab.problem;
        _resultCollapsed = false;
        _resultPanelPos = const Offset(10, 10);
      });
      if (result.diagrams.isNotEmpty) {
        _startRevealAnimation();
      }
      _scheduleDraftSave(immediate: true);
      _showHint(
        result.diagrams.isNotEmpty
            ? '题目已解析，几何配图已矢量重绘（可一键画到白板）'
            : (figures.isNotEmpty
                ? '题目已解析并自动保存'
                : '题目已解析并自动保存'),
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

  /// 画板手写识题：
  /// 第 1 层（本地 < 5ms 极速预检）：过滤空白、过少笔迹、过小区域与乱涂乱画；
  /// 第 2 层（后端视觉 AI 语义校验）：仅放行完整合理的数学题，拒绝涂鸦/碎片。
  Future<void> _recognizeFromBoardHandwriting() async {
    if (_busyAi) return;
    final check = BoardHandwritingValidator.validate(_strokes, _shapes);
    if (!check.valid) {
      GglFeedback.warning(context, check.reason);
      return;
    }

    setState(() {
      _showCanvasOpsMenu = false;
      _showShapePicker = false;
      _busyAi = true;
      _busyAiLabel = '正在校验并识别画板手写题目...';
    });

    try {
      final pngBytes = await renderSmartBoardToPng(
        strokes: _strokes,
        shapes: _shapes,
        cards: const SmartBoardCardState(),
        includeProblemCard: false,
        includeAiCards: false,
        maxDimension: 1400,
      );
      if (!mounted) return;

      final api = context.read<GuoguanlaApi>();
      final result = await api.recognizeMathProblem(
        imageBytes: pngBytes,
        filename: 'handwritten-problem.png',
        sourceType: 'BOARD_HANDWRITING',
      );
      if (!mounted) return;

      var figures = <ExtractedBoardFigure>[];
      if (result.figureBoxes.isNotEmpty) {
        figures = await PhotoFigureExtractor.extractFromPhoto(
          pngBytes,
          result.figureBoxes,
        );
      }
      if (!mounted) return;

      // 识别成功后自动清除原手写题目笔迹（压入 1 条撤销快照以便需要时撤回），留出干净白板直接作答
      if (_strokes.isNotEmpty || _shapes.isNotEmpty) {
        _pushUndoCheckpoint();
      }
      setState(() {
        _strokes.clear();
        _shapes.clear();
        _activeStroke = null;
        _activeShape = null;
        _zoom = 1.0;
        _panX = 0;
        _panY = 0;
        _problem = result;
        _ideas = null;
        _diagnosis = null;
        _solution = null;
        _croppedPhotoBytes = figures.isNotEmpty ? pngBytes : null;
        _extractedFigures = figures;
        _recognizedFromHandwriting = false;
        _activeResultTab = BoardResultTab.problem;
        _resultCollapsed = false;
        _resultPanelPos = const Offset(10, 10);
      });
      if (result.diagrams.isNotEmpty) {
        _startRevealAnimation();
      }
      _scheduleDraftSave(immediate: true);
      _showHint(
        result.diagrams.isNotEmpty
            ? '手写题目已分析并自动清除笔迹，配图已矢量重绘'
            : '手写题目已分析并自动清除笔迹，直接在白板作答吧',
      );
    } catch (e) {
      if (mounted) {
        GglFeedback.warning(
          context,
          friendlyErrorMessage(e, '未能识别为完整数学题，请工整书写后再试'),
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
    _scheduleDraftSave(immediate: true);
    _showHint('已 1:1 更新原题配图');
  }

  /// 将矢量重绘配图直接绘制到白板画布（转为可擦除/可加辅助线的白板图形与笔画）
  void _stampDiagramToBoard(BoardDiagramSpec spec) {
    if (spec.primitives.isEmpty) return;
    _pushUndoCheckpoint();

    final logicalW = spec.width > 20 ? spec.width : 320.0;
    final logicalH = spec.height > 20 ? spec.height : 210.0;
    final availW = _canvasSize.width > 0 ? _canvasSize.width : 820.0;
    final availH = _canvasSize.height > 0 ? _canvasSize.height : 520.0;

    // 优先放置在白板右侧空闲区，避开左侧题目面板
    final double targetW = math.min(400.0, math.max(240.0, availW * 0.42));
    final double scale = targetW / logicalW;
    final double targetH = logicalH * scale;
    final double screenLeft = availW > 560
        ? math.min(availW - targetW - 24, math.max(330.0, availW * 0.44))
        : (availW - targetW) / 2;
    final double screenTop = math.max(28.0, (availH - targetH) * 0.32);

    Offset toWorld(double x, double y) => _screenToWorld(
          Offset(screenLeft + x * scale, screenTop + y * scale),
        );

    final addedShapes = <BoardShape>[];
    final addedStrokes = <BoardStroke>[];

    for (final p in spec.primitives) {
      final colorVal = BoardDiagramPainter.parseColor(p.color).toARGB32();
      switch (p.type) {
        case 'line':
          if (p.x1 != null && p.y1 != null && p.x2 != null && p.y2 != null) {
            addedShapes.add(BoardShape(
              kind: p.dashed ? BoardShapeKind.dashedLine : BoardShapeKind.line,
              start: toWorld(p.x1!, p.y1!),
              end: toWorld(p.x2!, p.y2!),
              colorValue: colorVal,
              width: 2.6,
            ));
          }
        case 'arrow':
          if (p.x1 != null && p.y1 != null && p.x2 != null && p.y2 != null) {
            addedShapes.add(BoardShape(
              kind: BoardShapeKind.arrow,
              start: toWorld(p.x1!, p.y1!),
              end: toWorld(p.x2!, p.y2!),
              colorValue: colorVal,
              width: 2.4,
            ));
          }
        case 'polygon':
          if (p.points.length >= 3) {
            for (var i = 0; i < p.points.length; i++) {
              final a = p.points[i];
              final b = p.points[(i + 1) % p.points.length];
              addedShapes.add(BoardShape(
                kind: p.dashed
                    ? BoardShapeKind.dashedLine
                    : BoardShapeKind.line,
                start: toWorld(a[0], a[1]),
                end: toWorld(b[0], b[1]),
                colorValue: colorVal,
                width: 2.8,
              ));
            }
          }
        case 'polyline':
          if (p.points.length >= 2) {
            addedStrokes.add(BoardStroke(
              colorValue: colorVal,
              width: 2.6,
              points: [
                for (final pt in p.points) toWorld(pt[0], pt[1]),
              ],
            ));
          }
        case 'circle':
          if (p.cx != null && p.cy != null && p.r != null && p.r! > 0) {
            addedShapes.add(BoardShape(
              kind: BoardShapeKind.oval,
              start: toWorld(p.cx! - p.r!, p.cy! - p.r!),
              end: toWorld(p.cx! + p.r!, p.cy! + p.r!),
              colorValue: colorVal,
              width: 2.6,
            ));
          }
        case 'arc':
          if (p.cx != null && p.cy != null && p.r != null && p.r! > 0) {
            final startRad = (p.startAngle ?? 0) * math.pi / 180.0;
            final sweepRad = (p.sweepAngle ?? 90) * math.pi / 180.0;
            const segs = 16;
            final pts = <Offset>[];
            for (var i = 0; i <= segs; i++) {
              final ang = startRad + sweepRad * (i / segs);
              pts.add(toWorld(
                p.cx! + p.r! * math.cos(ang),
                p.cy! + p.r! * math.sin(ang),
              ));
            }
            addedStrokes.add(BoardStroke(
              colorValue: colorVal,
              width: 2.0,
              points: pts,
            ));
          }
        case 'rightangle':
        case 'right_angle':
          if (p.vx != null &&
              p.vy != null &&
              p.ax != null &&
              p.ay != null &&
              p.bx != null &&
              p.by != null) {
            final v = Offset(p.vx!, p.vy!);
            final va = Offset(p.ax!, p.ay!) - v;
            final vb = Offset(p.bx!, p.by!) - v;
            final la = va.distance;
            final lb = vb.distance;
            if (la > 0.1 && lb > 0.1) {
              final s = p.size ?? 12.0;
              final u = Offset(va.dx / la * s, va.dy / la * s);
              final w = Offset(vb.dx / lb * s, vb.dy / lb * s);
              final p1 = v + u;
              final p2 = v + u + w;
              final p3 = v + w;
              addedStrokes.add(BoardStroke(
                colorValue: colorVal,
                width: 2.0,
                points: [
                  toWorld(p1.dx, p1.dy),
                  toWorld(p2.dx, p2.dy),
                  toWorld(p3.dx, p3.dy),
                ],
              ));
            }
          }
      }
    }

    if (addedShapes.isEmpty && addedStrokes.isEmpty) return;
    setState(() {
      _shapes.addAll(addedShapes);
      _strokes.addAll(addedStrokes);
    });
    _scheduleDraftSave();
    _showHint('已将矢量图形绘制到白板，可直接画辅助线与标注');
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
          final base = _problem ??
              const AiRecognizeResult(
                title: '数学解答题',
                problemText: '',
                subjectTag: '数学',
                questionType: '解答题',
                difficulty: '自选',
              );
          final resolvedTitle = title.isNotEmpty
              ? title
              : SavedSmartBoardRecord.deriveTitle(
                  base.copyWith(title: '', problemText: text),
                  fallback: '数学解答题',
                );
          final updated = base.copyWith(
            title: resolvedTitle,
            problemText: text,
          );
          setState(() {
            _problem = updated;
            _activeResultTab = BoardResultTab.problem;
            _resultCollapsed = false;
          });
          _scheduleDraftSave(immediate: true);
          Navigator.of(sheetCtx).pop();
          _showHint('题目已更新并自动保存');
        },
      ),
    );
  }

  Future<void> _runAiAction(_AiActionKind kind) async {
    if (_busyAi) return;
    final problemText = _problem?.problemText.trim() ?? '';
    final hasDrawing = _hasHandwriting;

    // 强制门禁：使用「思路 / 诊断 / 解题」前必须先通过拍照、手写识题或手动录题识别一道完整数学题
    if (problemText.isEmpty) {
      GglFeedback.warning(
        context,
        '请先通过「拍照」或「手写识题」识别一道完整数学题，再使用思路/诊断/解题',
      );
      return;
    }

    if (kind == _AiActionKind.diagnose && !hasDrawing) {
      GglFeedback.warning(context, '请先在画板上写下你的解题过程，再点击诊断');
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
      _scheduleDraftSave(immediate: true);
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
    final boardTitleText = _problem != null
        ? SavedSmartBoardRecord.deriveTitle(_problem)
        : (plainProblem.isNotEmpty
            ? plainProblem
            : (compactLandscape ? '拍题/手写识题' : '拍照或手写数学题'));

    final stemPill = GestureDetector(
      onTap: _problem == null
          ? _openProblemCaptureSheet
          : _openManualProblemDialog,
      child: Container(
        height: 31,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: AppTheme.insetBoxDecoration(context, radius: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                boardTitleText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.inkColor(context),
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
          label: '手写识题',
          icon: Icons.draw_rounded,
          variant: WelkButtonVariant.primary,
          compact: true,
          onPressed: _busyAi ? null : _recognizeFromBoardHandwriting,
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

    final recordsBtn = GglButton(
      label: _savedRecords.isEmpty ? '记录' : '记录(${_savedRecords.length})',
      icon: Icons.folder_copy_outlined,
      variant: WelkButtonVariant.secondary,
      compact: true,
      onPressed: _busyAi ? null : _openSavedBoardsSheet,
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
      decoration: AppTheme.barDecoration(context, bottomBorder: true),
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
                            recordsBtn,
                            const SizedBox(width: 5),
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
              // 竖屏精简双行顶栏（去掉 LongCat-2.5，替换为「画布操作」与「记录」）
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
                        const SizedBox(width: 5),
                        recordsBtn,
                        const SizedBox(width: 5),
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
                        _scheduleDraftSave();
                      },
                    ),
                ],
              ),
              const GglDivider(verticalPadding: 8),
              Row(
                children: [
                  Expanded(
                    child: GglButton(
                      label: '画板记录',
                      icon: Icons.folder_copy_outlined,
                      compact: true,
                      variant: WelkButtonVariant.secondary,
                      onPressed: () {
                        setState(() => _showCanvasOpsMenu = false);
                        unawaited(_openSavedBoardsSheet());
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: GglButton(
                      label: '新建画板',
                      icon: Icons.note_add_outlined,
                      compact: true,
                      variant: WelkButtonVariant.primary,
                      onPressed: () {
                        setState(() => _showCanvasOpsMenu = false);
                        _createNewBoard();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
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
      decoration: AppTheme.barDecoration(context, topBorder: true),
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
                                    ? AppTheme.accentColor(context)
                                    : AppTheme.borderColor(context),
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
        backgroundColor: AppTheme.surfaceColor(context),
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
                                  '拍照框选题目，或直接在画板写出完整数学题后点「手写识题」\n识别题目后即可使用「思路」「诊断」「解题」，画板自动按题目保存',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12.6,
                                    height: 1.55,
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
                            onPositionChanged: (pos) {
                              setState(() => _resultPanelPos = pos);
                              _scheduleDraftSave();
                            },
                            onTabChanged: (t) {
                              setState(() => _activeResultTab = t);
                              _scheduleDraftSave();
                            },
                            onToggleCollapsed: () {
                              setState(
                                () => _resultCollapsed = !_resultCollapsed,
                              );
                              _scheduleDraftSave();
                            },
                            onEditProblem: _openManualProblemDialog,
                            onRecropFigure: _recropFigureManually,
                            onDrawDiagramToBoard: _stampDiagramToBoard,
                            onCloseActiveTab: () {
                              setState(() => _resultCollapsed = true);
                              _scheduleDraftSave();
                            },
                            showClearHandwritingAction:
                                _recognizedFromHandwriting && _hasHandwriting,
                            onClearHandwritingToSolve: () {
                              _clearHandwritingOnly();
                              setState(() => _recognizedFromHandwriting = false);
                            },
                            problem: _problem,
                            ideas: _ideas,
                            diagnosis: _diagnosis,
                            solution: _solution,
                            extractedFigures: _extractedFigures,
                            hasSourcePhoto: _croppedPhotoBytes != null,
                            purifyFigures: _purifyFigures,
                            onTogglePurifyFigures: () {
                              setState(
                                () => _purifyFigures = !_purifyFigures,
                              );
                              _scheduleDraftSave();
                            },
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
            decoration: AppTheme.insetBoxDecoration(
              context,
              color: accent,
              borderColor: AppTheme.isForui(context) ? accent : null,
              radius: 9,
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
  static const List<(String label, String snippet, int cursorBackOffset)>
      _mathSnippets = [
    ('分式', r'$\dfrac{}{}$', 4),
    ('根号', r'$\sqrt{}$', 2),
    ('平方', r'$^2$', 0),
    ('±', r'$\pm$', 0),
    ('≤', r'$\leqslant$', 0),
    ('≥', r'$\geqslant$', 0),
    ('π', r'$\pi$', 0),
    ('△', r'$\triangle$', 0),
    ('∠', r'$\angle$', 0),
  ];

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

  void _insertSnippet(String snippet, int cursorBackOffset) {
    final text = _stemCtrl.text;
    final sel = _stemCtrl.selection;
    final start = sel.isValid ? sel.start.clamp(0, text.length) : text.length;
    final end = sel.isValid ? sel.end.clamp(0, text.length) : text.length;
    final nextText = text.replaceRange(start, end, snippet);
    final nextOffset =
        (start + snippet.length - cursorBackOffset).clamp(0, nextText.length);
    _stemCtrl.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextOffset),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final previewStem = _stemCtrl.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        GglInput(
          label: '题目标题（选填，留空将自动从题干提取）',
          value: _title,
          placeholder: '例如：椭圆与直线交点综合题',
          onChanged: (v) => setState(() => _title = v),
        ),
        const SizedBox(height: 10),
        GglTextArea(
          controller: _stemCtrl,
          label: '题干内容（支持 LaTeX，如 \$\\dfrac{x^2}{2}+y^2=1\$）',
          hintText: '输入或粘贴数学题干，下方可实时预览公式排版效果...',
          minLines: 3,
          maxLines: 5,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            for (final item in _mathSnippets)
              GglButton(
                label: item.$1,
                compact: true,
                variant: WelkButtonVariant.secondary,
                onPressed: () => _insertSnippet(item.$2, item.$3),
              ),
          ],
        ),
        if (previewStem.isNotEmpty) ...[
          const SizedBox(height: 10),
          GglComicPanel(
            color: AppTheme.mutedSurfaceColor(context),
            padding: const EdgeInsets.all(10),
            shadowOffset: const Offset(1.5, 1.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '实时公式渲染预览',
                  style: TextStyle(
                    color: AppTheme.mutedText(context),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                MathText(
                  previewStem,
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: 14,
                    height: 1.55,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
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
