import 'dart:async';
import 'dart:math' as math;

import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../app/app_theme.dart';
import '../core/utils/format_utils.dart';

/// 过关啦专业教学视频播放器（基于 Chewie + 自定义手势与放大控制栏）：
/// - 左右滑动快进/快退（带实时时间与进度 HUD）
/// - 双击左侧退 10 秒 / 右侧进 10 秒 / 中间播放暂停
/// - 长按 2.0x 临时倍速快播（松手恢复原倍速）
/// - 上下滑动调节右侧音量 / 左侧画面亮度
/// - 画面放大（1.0x / 1.25x / 1.5x / 2.0x + 放大后拖曳查看板书公式）
/// - 沉浸式横屏全屏、防误触锁屏、0.5x~2.0x 倍速切换、静音与下一节联播
class GglVideoPlayer extends StatefulWidget {
  const GglVideoPlayer({
    super.key,
    required this.videoController,
    required this.title,
    required this.accentColor,
    this.autoPlay = false,
    this.hasNextLesson = false,
    this.onNextLesson,
  });

  final VideoPlayerController videoController;
  final String title;
  final Color accentColor;
  final bool autoPlay;
  final bool hasNextLesson;
  final VoidCallback? onNextLesson;

  @override
  State<GglVideoPlayer> createState() => _GglVideoPlayerState();
}

class _GglVideoPlayerState extends State<GglVideoPlayer> {
  late ChewieController _chewieController;
  late final TransformationController _transformController;
  final ValueNotifier<double> _zoomNotifier = ValueNotifier<double>(1.0);
  final ValueNotifier<double> _brightnessNotifier = ValueNotifier<double>(1.0);

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
    _chewieController = _createChewieController();
  }

  @override
  void didUpdateWidget(covariant GglVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoController != widget.videoController ||
        oldWidget.title != widget.title ||
        oldWidget.hasNextLesson != widget.hasNextLesson) {
      _chewieController.dispose();
      _transformController.value = Matrix4.identity();
      _zoomNotifier.value = 1.0;
      _chewieController = _createChewieController();
    }
  }

  ChewieController _createChewieController() {
    final ratio = widget.videoController.value.aspectRatio;
    return ChewieController(
      videoPlayerController: widget.videoController,
      aspectRatio: ratio > 0 ? ratio : 16 / 9,
      autoPlay: widget.autoPlay,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
      allowPlaybackSpeedChanging: true,
      allowedScreenSleep: false,
      zoomAndPan: true,
      maxScale: 2.5,
      transformationController: _transformController,
      deviceOrientationsOnEnterFullScreen: kIsWeb
          ? DeviceOrientation.values
          : const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ],
      deviceOrientationsAfterFullScreen: kIsWeb
          ? DeviceOrientation.values
          : const [DeviceOrientation.portraitUp],
      playbackSpeeds: const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
      customControls: GglVideoControls(
        title: widget.title,
        accentColor: widget.accentColor,
        transformationController: _transformController,
        zoomNotifier: _zoomNotifier,
        brightnessNotifier: _brightnessNotifier,
        hasNextLesson: widget.hasNextLesson,
        onNextLesson: widget.onNextLesson,
      ),
    );
  }

  @override
  void dispose() {
    _chewieController.dispose();
    _transformController.dispose();
    _zoomNotifier.dispose();
    _brightnessNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Chewie(controller: _chewieController),
    );
  }
}

/// 自定义教学视频播放控制层（同时在嵌入式与全屏态下运行）
class GglVideoControls extends StatefulWidget {
  const GglVideoControls({
    super.key,
    required this.title,
    required this.accentColor,
    required this.transformationController,
    required this.zoomNotifier,
    required this.brightnessNotifier,
    this.hasNextLesson = false,
    this.onNextLesson,
  });

  final String title;
  final Color accentColor;
  final TransformationController transformationController;
  final ValueNotifier<double> zoomNotifier;
  final ValueNotifier<double> brightnessNotifier;
  final bool hasNextLesson;
  final VoidCallback? onNextLesson;

  @override
  State<GglVideoControls> createState() => _GglVideoControlsState();
}

enum _HudKind { seek, volume, brightness, doubleTap }

class _GglVideoControlsState extends State<GglVideoControls> {
  static const List<double> _speedOptions = <double>[
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    2.0,
  ];
  static const List<double> _zoomSteps = <double>[1.0, 1.25, 1.5, 2.0];

  bool _controlsVisible = true;
  bool _locked = false;
  bool _isDraggingSlider = false;
  double _sliderDragMs = 0;

  // 手势状态
  bool _isHorizontalSeeking = false;
  Duration _seekStartPos = Duration.zero;
  Duration _seekTargetPos = Duration.zero;
  bool _isLongPressBoosting = false;
  double _speedBeforeBoost = 1.0;

  // 放大后的平移状态
  Offset _panOffset = Offset.zero;
  Size _viewportSize = Size.zero;

  // HUD 提示
  _HudKind? _hudKind;
  String _hudText = '';
  double _hudProgress = 0.0;
  IconData _hudIcon = Icons.fast_forward_rounded;

  Timer? _hideTimer;
  Timer? _hudTimer;
  double _lastVolumeBeforeMute = 1.0;

  ChewieController get _chewie => ChewieController.of(context);
  VideoPlayerController get _video => _chewie.videoPlayerController;

  @override
  void initState() {
    super.initState();
    _scheduleAutoHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _hudTimer?.cancel();
    super.dispose();
  }

  void _scheduleAutoHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 3600), () {
      if (!mounted) return;
      if (_isDraggingSlider || _isHorizontalSeeking) return;
      if (_video.value.isPlaying) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) {
      _scheduleAutoHide();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _showTransientHud({
    required _HudKind kind,
    required IconData icon,
    required String text,
    double progress = 0.0,
    Duration duration = const Duration(milliseconds: 900),
  }) {
    _hudTimer?.cancel();
    setState(() {
      _hudKind = kind;
      _hudIcon = icon;
      _hudText = text;
      _hudProgress = progress.clamp(0.0, 1.0);
    });
    _hudTimer = Timer(duration, () {
      if (mounted) {
        setState(() => _hudKind = null);
      }
    });
  }

  Future<void> _togglePlayPause() async {
    final val = _video.value;
    if (val.isPlaying) {
      await _video.pause();
      _hideTimer?.cancel();
      if (mounted) setState(() => _controlsVisible = true);
    } else {
      if (val.duration > Duration.zero &&
          val.position >= val.duration - const Duration(milliseconds: 300)) {
        await _video.seekTo(Duration.zero);
      }
      await _video.play();
      _scheduleAutoHide();
    }
  }

  Future<void> _seekBySeconds(int deltaSec) async {
    final dur = _video.value.duration;
    if (dur <= Duration.zero) return;
    final targetMs = (_video.value.position.inMilliseconds + deltaSec * 1000)
        .clamp(0, dur.inMilliseconds);
    final target = Duration(milliseconds: targetMs);
    await _video.seekTo(target);
    _showTransientHud(
      kind: _HudKind.doubleTap,
      icon: deltaSec >= 0
          ? Icons.forward_10_rounded
          : Icons.replay_10_rounded,
      text: deltaSec >= 0 ? '快进 ${deltaSec}s' : '快退 ${deltaSec.abs()}s',
      progress: targetMs / math.max(1, dur.inMilliseconds),
    );
    if (_controlsVisible) _scheduleAutoHide();
  }

  void _applyZoom(double scale, {Offset? pan}) {
    final clampedScale = scale.clamp(1.0, 2.5);
    widget.zoomNotifier.value = clampedScale;
    if (clampedScale <= 1.01) {
      _panOffset = Offset.zero;
      widget.transformationController.value = Matrix4.identity();
      return;
    }
    final w = _viewportSize.width > 0 ? _viewportSize.width : 360.0;
    final h = _viewportSize.height > 0 ? _viewportSize.height : 210.0;
    final maxDx = (w * (clampedScale - 1.0)) / 2;
    final maxDy = (h * (clampedScale - 1.0)) / 2;
    final nextPan = pan ?? _panOffset;
    _panOffset = Offset(
      nextPan.dx.clamp(-maxDx, maxDx),
      nextPan.dy.clamp(-maxDy, maxDy),
    );
    final tx = (w * (1.0 - clampedScale)) / 2 + _panOffset.dx;
    final ty = (h * (1.0 - clampedScale)) / 2 + _panOffset.dy;
    final matrix = Matrix4.identity()
      ..setEntry(0, 0, clampedScale)
      ..setEntry(1, 1, clampedScale)
      ..setEntry(0, 3, tx)
      ..setEntry(1, 3, ty);
    widget.transformationController.value = matrix;
  }

  void _cycleZoom() {
    final current = widget.zoomNotifier.value;
    var nextIdx = _zoomSteps.indexWhere((s) => s > current + 0.05);
    if (nextIdx < 0) nextIdx = 0;
    final nextScale = _zoomSteps[nextIdx];
    _applyZoom(nextScale, pan: Offset.zero);
    _showTransientHud(
      kind: _HudKind.doubleTap,
      icon: nextScale > 1.01 ? Icons.zoom_in_rounded : Icons.zoom_out_map_rounded,
      text: nextScale > 1.01
          ? '画面放大 ${nextScale.toStringAsFixed(nextScale == 1.5 || nextScale == 2.0 ? 1 : 2)}x（可拖动看公式）'
          : '已还原 1.0x 画面',
      duration: const Duration(milliseconds: 1200),
    );
    _scheduleAutoHide();
  }

  void _resetZoom() {
    _applyZoom(1.0, pan: Offset.zero);
    _showTransientHud(
      kind: _HudKind.doubleTap,
      icon: Icons.zoom_out_map_rounded,
      text: '已还原 1.0x 画面',
    );
  }

  void _toggleMute() {
    final vol = _video.value.volume;
    if (vol > 0) {
      _lastVolumeBeforeMute = vol;
      _video.setVolume(0);
    } else {
      _video.setVolume(_lastVolumeBeforeMute > 0 ? _lastVolumeBeforeMute : 1.0);
    }
    _scheduleAutoHide();
  }

  Future<void> _openSpeedPicker() async {
    _hideTimer?.cancel();
    final currentSpeed = _video.value.playbackSpeed;
    final picked = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: const Color(0xFF18181B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '选择播放倍速',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFamilyFallback: AppTheme.cjkFontFallback,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final sp in _speedOptions)
                      GestureDetector(
                        onTap: () => Navigator.of(sheetCtx).pop(sp),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: (currentSpeed - sp).abs() < 0.01
                                ? widget.accentColor
                                : const Color(0xFF27272A),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${sp}x',
                            style: TextStyle(
                              color: (currentSpeed - sp).abs() < 0.01
                                  ? Colors.black
                                  : Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null && mounted) {
      await _video.setPlaybackSpeed(picked);
      _showTransientHud(
        kind: _HudKind.doubleTap,
        icon: Icons.speed_rounded,
        text: '播放倍速 ${picked}x',
      );
    }
    _scheduleAutoHide();
  }

  void _onDoubleTapDown(TapDownDetails details) {
    if (_locked) return;
    final w = _viewportSize.width;
    if (w <= 0) {
      unawaited(_togglePlayPause());
      return;
    }
    final ratio = details.localPosition.dx / w;
    if (ratio < 0.32) {
      unawaited(_seekBySeconds(-10));
    } else if (ratio > 0.68) {
      unawaited(_seekBySeconds(10));
    } else {
      unawaited(_togglePlayPause());
    }
  }

  void _onLongPressStart(LongPressStartDetails details) {
    if (_locked || !_video.value.isPlaying) return;
    _speedBeforeBoost = _video.value.playbackSpeed;
    _isLongPressBoosting = true;
    unawaited(_video.setPlaybackSpeed(2.0));
    setState(() {});
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (!_isLongPressBoosting) return;
    _isLongPressBoosting = false;
    unawaited(_video.setPlaybackSpeed(_speedBeforeBoost));
    setState(() {});
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (_locked) return;
    if (widget.zoomNotifier.value > 1.01) return;
    final dur = _video.value.duration;
    if (dur <= Duration.zero) return;
    _hideTimer?.cancel();
    _hudTimer?.cancel();
    setState(() {
      _isHorizontalSeeking = true;
      _seekStartPos = _video.value.position;
      _seekTargetPos = _seekStartPos;
      _hudKind = _HudKind.seek;
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_locked) return;
    if (widget.zoomNotifier.value > 1.01) {
      _applyZoom(
        widget.zoomNotifier.value,
        pan: _panOffset + Offset(details.delta.dx, 0),
      );
      return;
    }
    if (!_isHorizontalSeeking) return;
    final dur = _video.value.duration;
    if (dur <= Duration.zero) return;
    final w = math.max(200.0, _viewportSize.width);
    // 滑动一整屏约快进/快退 90 秒（短视频按总时长缩放，操作精准顺手）
    final spanSec = math.min(90.0, math.max(20.0, dur.inSeconds * 0.65));
    final deltaMs = (details.delta.dx / w) * spanSec * 1000.0;
    final nextMs = (_seekTargetPos.inMilliseconds + deltaMs)
        .round()
        .clamp(0, dur.inMilliseconds);
    final nextPos = Duration(milliseconds: nextMs);
    final diffSec = ((nextPos - _seekStartPos).inMilliseconds / 1000).round();
    setState(() {
      _seekTargetPos = nextPos;
      _hudKind = _HudKind.seek;
      _hudIcon = diffSec >= 0
          ? Icons.fast_forward_rounded
          : Icons.fast_rewind_rounded;
      final sign = diffSec >= 0 ? '+' : '';
      _hudText =
          '${FormatUtils.formatDuration(nextPos.inSeconds)} / ${FormatUtils.formatDuration(dur.inSeconds)}  ($sign${diffSec}s)';
      _hudProgress = nextMs / math.max(1, dur.inMilliseconds);
    });
  }

  Future<void> _onHorizontalDragEnd(DragEndDetails details) async {
    if (!_isHorizontalSeeking) return;
    final target = _seekTargetPos;
    setState(() {
      _isHorizontalSeeking = false;
      _hudKind = null;
    });
    await _video.seekTo(target);
    _scheduleAutoHide();
  }

  bool _verticalIsRightSide = true;

  void _onVerticalDragStart(DragStartDetails details) {
    if (_locked) return;
    if (widget.zoomNotifier.value > 1.01) return;
    final w = _viewportSize.width > 0 ? _viewportSize.width : 360.0;
    _verticalIsRightSide = details.localPosition.dx >= w / 2;
    _hudTimer?.cancel();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_locked) return;
    if (widget.zoomNotifier.value > 1.01) {
      _applyZoom(
        widget.zoomNotifier.value,
        pan: _panOffset + Offset(0, details.delta.dy),
      );
      return;
    }
    final h = math.max(160.0, _viewportSize.height);
    final delta = -details.delta.dy / h;
    if (_verticalIsRightSide) {
      final nextVol = (_video.value.volume + delta).clamp(0.0, 1.0);
      unawaited(_video.setVolume(nextVol));
      _showTransientHud(
        kind: _HudKind.volume,
        icon: nextVol <= 0.01
            ? Icons.volume_off_rounded
            : Icons.volume_up_rounded,
        text: '音量 ${(nextVol * 100).round()}%',
        progress: nextVol,
        duration: const Duration(milliseconds: 700),
      );
    } else {
      final nextBright =
          (widget.brightnessNotifier.value + delta).clamp(0.25, 1.0);
      widget.brightnessNotifier.value = nextBright;
      _showTransientHud(
        kind: _HudKind.brightness,
        icon: Icons.brightness_6_rounded,
        text: '亮度 ${(nextBright * 100).round()}%',
        progress: nextBright,
        duration: const Duration(milliseconds: 700),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFullScreen = _chewie.isFullScreen;

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
        return ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: _video,
          builder: (context, value, _) {
            final durMs = math.max(1, value.duration.inMilliseconds);
            final posMs = _isDraggingSlider
                ? _sliderDragMs.round().clamp(0, durMs)
                : (_isHorizontalSeeking
                    ? _seekTargetPos.inMilliseconds.clamp(0, durMs)
                    : value.position.inMilliseconds.clamp(0, durMs));
            final bufferedMs = value.buffered.isNotEmpty
                ? value.buffered.last.end.inMilliseconds.clamp(0, durMs)
                : 0;
            final isEnded = value.duration > Duration.zero &&
                value.position >=
                    value.duration - const Duration(milliseconds: 300) &&
                !value.isPlaying;

            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: _onHorizontalDragStart,
              onHorizontalDragUpdate: _onHorizontalDragUpdate,
              onHorizontalDragEnd: _onHorizontalDragEnd,
              onVerticalDragStart: _onVerticalDragStart,
              onVerticalDragUpdate: _onVerticalDragUpdate,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 左侧上下滑动调节亮度叠加层
                  ValueListenableBuilder<double>(
                    valueListenable: widget.brightnessNotifier,
                    builder: (_, brightness, _) {
                      final dimAlpha = (1.0 - brightness).clamp(0.0, 0.75);
                      if (dimAlpha <= 0.01) return const SizedBox.shrink();
                      return IgnorePointer(
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: dimAlpha),
                        ),
                      );
                    },
                  ),

                  // 底层点按/双击/长按热区（不阻塞顶部控制栏按钮的即时点击）
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggleControls,
                      onDoubleTapDown: _onDoubleTapDown,
                      onDoubleTap: () {},
                      onLongPressStart: _onLongPressStart,
                      onLongPressEnd: _onLongPressEnd,
                    ),
                  ),

                  // 缓冲指示器
                if (value.isBuffering)
                  const IgnorePointer(
                    child: Center(
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.8,
                        ),
                      ),
                    ),
                  ),

                // 长按 2.0x 临时倍速指示条
                if (_isLongPressBoosting)
                  Positioned(
                    top: isFullScreen ? 24 : 10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.fast_forward_rounded,
                              size: 16,
                              color: widget.accentColor,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              '2.0x 倍速快播中（松手恢复）',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontFamilyFallback: AppTheme.cjkFontFallback,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // 中央手势 HUD（快进/快退/音量/亮度/缩放反馈）
                if (_hudKind != null)
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 148),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.76),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_hudIcon, color: Colors.white, size: 26),
                            const SizedBox(height: 6),
                            Text(
                              _hudText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                fontFamilyFallback: AppTheme.cjkFontFallback,
                              ),
                            ),
                            if (_hudKind == _HudKind.seek ||
                                _hudKind == _HudKind.volume ||
                                _hudKind == _HudKind.brightness) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: 136,
                                height: 4,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: _hudProgress,
                                    backgroundColor: Colors.white24,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      widget.accentColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                // 锁屏模式下仅显示解锁按钮
                if (_locked && _controlsVisible)
                  Positioned(
                    left: 16,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _GlassIconButton(
                        icon: Icons.lock_rounded,
                        tooltip: '点击解锁屏幕',
                        onTap: () {
                          setState(() => _locked = false);
                          _scheduleAutoHide();
                        },
                      ),
                    ),
                  ),

                // 放大状态下的快捷还原按钮（即便控制栏隐藏也可一键恢复 1.0x）
                ValueListenableBuilder<double>(
                  valueListenable: widget.zoomNotifier,
                  builder: (_, zoom, _) {
                    if (zoom <= 1.01 || _locked) return const SizedBox.shrink();
                    return Positioned(
                      right: 12,
                      top: _controlsVisible ? (isFullScreen ? 56 : 44) : 10,
                      child: GestureDetector(
                        onTap: _resetZoom,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: widget.accentColor,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '${zoom.toStringAsFixed(zoom == 1.5 || zoom == 2.0 ? 1 : 2)}x · 还原',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // 非锁屏时的顶部 / 中央 / 底部控制层
                if (!_locked)
                  AnimatedOpacity(
                    opacity: _controlsVisible || isEnded ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    child: IgnorePointer(
                      ignoring: !_controlsVisible && !isEnded,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 顶部栏
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: EdgeInsets.fromLTRB(
                                isFullScreen ? 16 : 10,
                                isFullScreen ? 14 : 6,
                                isFullScreen ? 16 : 10,
                                10,
                              ),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Color(0xB8000000), Colors.transparent],
                                ),
                              ),
                              child: SafeArea(
                                bottom: false,
                                top: isFullScreen,
                                child: Row(
                                  children: [
                                    if (isFullScreen) ...[
                                      _GlassIconButton(
                                        icon: Icons.arrow_back_rounded,
                                        tooltip: '退出全屏',
                                        onTap: () => _chewie.exitFullScreen(),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Expanded(
                                      child: Text(
                                        widget.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          fontFamilyFallback:
                                              AppTheme.cjkFontFallback,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    ValueListenableBuilder<double>(
                                      valueListenable: widget.zoomNotifier,
                                      builder: (_, zoom, _) => _ControlPill(
                                        label: zoom > 1.01
                                            ? '放大 ${zoom.toStringAsFixed(zoom == 1.5 || zoom == 2.0 ? 1 : 2)}x'
                                            : '放大',
                                        icon: Icons.zoom_in_rounded,
                                        active: zoom > 1.01,
                                        accent: widget.accentColor,
                                        onTap: _cycleZoom,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    _ControlPill(
                                      label: '${value.playbackSpeed}x',
                                      active: (value.playbackSpeed - 1.0).abs() >
                                          0.01,
                                      accent: widget.accentColor,
                                      onTap: _openSpeedPicker,
                                    ),
                                    if (isFullScreen) ...[
                                      const SizedBox(width: 6),
                                      _GlassIconButton(
                                        icon: Icons.lock_open_rounded,
                                        tooltip: '锁定屏幕防误触',
                                        onTap: () =>
                                            setState(() => _locked = true),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // 中央播放 / 快退10s / 快进10s 控制组
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _GlassIconButton(
                                  icon: Icons.replay_10_rounded,
                                  tooltip: '快退 10 秒',
                                  size: 40,
                                  iconSize: 24,
                                  onTap: () => _seekBySeconds(-10),
                                ),
                                const SizedBox(width: 24),
                                GestureDetector(
                                  onTap: _togglePlayPause,
                                  child: Container(
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: widget.accentColor
                                          .withValues(alpha: 0.92),
                                      shape: BoxShape.circle,
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x55000000),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      isEnded
                                          ? Icons.replay_rounded
                                          : (value.isPlaying
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded),
                                      size: 32,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 24),
                                _GlassIconButton(
                                  icon: Icons.forward_10_rounded,
                                  tooltip: '快进 10 秒',
                                  size: 40,
                                  iconSize: 24,
                                  onTap: () => _seekBySeconds(10),
                                ),
                              ],
                            ),
                          ),

                          // 底部进度条与快捷操作栏
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: EdgeInsets.fromLTRB(
                                isFullScreen ? 16 : 8,
                                10,
                                isFullScreen ? 16 : 8,
                                isFullScreen ? 12 : 4,
                              ),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [Color(0xC8000000), Colors.transparent],
                                ),
                              ),
                              child: SafeArea(
                                top: false,
                                bottom: isFullScreen,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 拖拽进度条（含缓冲轨）
                                    SizedBox(
                                      height: 22,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              child: LinearProgressIndicator(
                                                minHeight: 3,
                                                value: bufferedMs / durMs,
                                                backgroundColor: Colors.white24,
                                                valueColor:
                                                    const AlwaysStoppedAnimation<
                                                        Color>(Colors.white54),
                                              ),
                                            ),
                                          ),
                                          SliderTheme(
                                            data: SliderThemeData(
                                              trackHeight: 3,
                                              thumbShape:
                                                  const RoundSliderThumbShape(
                                                enabledThumbRadius: 6,
                                              ),
                                              overlayShape:
                                                  const RoundSliderOverlayShape(
                                                overlayRadius: 13,
                                              ),
                                              activeTrackColor:
                                                  widget.accentColor,
                                              inactiveTrackColor:
                                                  Colors.transparent,
                                              thumbColor: Colors.white,
                                            ),
                                            child: Slider(
                                              min: 0,
                                              max: durMs.toDouble(),
                                              value: posMs
                                                  .toDouble()
                                                  .clamp(0, durMs.toDouble()),
                                              onChangeStart: (v) {
                                                _hideTimer?.cancel();
                                                setState(() {
                                                  _isDraggingSlider = true;
                                                  _sliderDragMs = v;
                                                });
                                              },
                                              onChanged: (v) {
                                                setState(() => _sliderDragMs = v);
                                              },
                                              onChangeEnd: (v) async {
                                                await _video.seekTo(
                                                  Duration(
                                                    milliseconds: v.round(),
                                                  ),
                                                );
                                                if (mounted) {
                                                  setState(() =>
                                                      _isDraggingSlider = false);
                                                }
                                                _scheduleAutoHide();
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // 底部按钮行
                                    Row(
                                      children: [
                                        _GlassIconButton(
                                          icon: value.isPlaying
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          tooltip:
                                              value.isPlaying ? '暂停' : '播放',
                                          size: 30,
                                          iconSize: 20,
                                          onTap: _togglePlayPause,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${FormatUtils.formatDuration(posMs ~/ 1000)} / ${FormatUtils.formatDuration(value.duration.inSeconds)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11.5,
                                            fontFeatures: [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                        const Spacer(),
                                        if (widget.hasNextLesson &&
                                            widget.onNextLesson != null) ...[
                                          _ControlPill(
                                            label: '下一节',
                                            icon: Icons.skip_next_rounded,
                                            accent: widget.accentColor,
                                            onTap: () {
                                              if (isFullScreen) {
                                                _chewie.exitFullScreen();
                                              }
                                              widget.onNextLesson!();
                                            },
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        _GlassIconButton(
                                          icon: value.volume <= 0.01
                                              ? Icons.volume_off_rounded
                                              : Icons.volume_up_rounded,
                                          tooltip:
                                              value.volume <= 0.01 ? '取消静音' : '静音',
                                          size: 30,
                                          iconSize: 18,
                                          onTap: _toggleMute,
                                        ),
                                        const SizedBox(width: 2),
                                        _GlassIconButton(
                                          icon: isFullScreen
                                              ? Icons.fullscreen_exit_rounded
                                              : Icons.fullscreen_rounded,
                                          tooltip:
                                              isFullScreen ? '退出全屏' : '全屏放大',
                                          size: 30,
                                          iconSize: 21,
                                          onTap: () {
                                            _chewie.toggleFullScreen();
                                            _scheduleAutoHide();
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 34,
    this.iconSize = 20,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.36),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: iconSize),
        ),
      ),
    );
  }
}

class _ControlPill extends StatelessWidget {
  const _ControlPill({
    required this.label,
    required this.accent,
    required this.onTap,
    this.icon,
    this.active = false,
  });

  final String label;
  final Color accent;
  final VoidCallback onTap;
  final IconData? icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? accent.withValues(alpha: 0.9)
              : Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? accent : Colors.white24,
            width: 0.9,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: active ? Colors.black : Colors.white,
              ),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.black : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamilyFallback: AppTheme.cjkFontFallback,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
