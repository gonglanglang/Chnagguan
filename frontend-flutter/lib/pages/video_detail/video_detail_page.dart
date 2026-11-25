import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../../app/app_theme.dart';
import '../../core/cache/global_cache.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/format_utils.dart';
import '../../models/models.dart';
import '../../providers/user_provider.dart';
import '../../services/guoguanla_api.dart';
import '../../widgets/ggl_comic_panel.dart';
import '../../widgets/ggl_feedback.dart';
import '../../widgets/ggl_skeleton.dart';
import '../../widgets/ggl_skin_widgets.dart';
import '../../widgets/image_preview_page.dart';
import '../../widgets/math_text.dart';
import '../login/login_page.dart';

class VideoDetailPage extends StatefulWidget {
  const VideoDetailPage({
    super.key,
    required this.seriesId,
    this.initialLessonId,
  });

  final int seriesId;
  final int? initialLessonId;

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> {
  final ScrollController _scrollController = ScrollController();

  bool _loading = true;
  VideoSeriesDetail? _detail;
  VideoLessonItem? _activeLesson;
  VideoPlayerController? _playerController;
  bool _playerReady = false;
  bool _playerError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchDetail());
  }

  @override
  void dispose() {
    _disposePlayer();
    _scrollController.dispose();
    super.dispose();
  }

  void _disposePlayer() {
    _playerController?.dispose();
    _playerController = null;
    _playerReady = false;
    _playerError = false;
  }

  Future<void> _fetchDetail() async {
    setState(() => _loading = true);
    try {
      final cache = context.read<GlobalCache>();
      final res = await context
          .read<GuoguanlaApi>()
          .getVideoSeriesDetail(widget.seriesId);
      final targetLessonId = (widget.initialLessonId != null &&
              widget.initialLessonId! > 0)
          ? widget.initialLessonId
          : cache.getLastVideoLessonId(widget.seriesId);
      VideoLessonItem? picked;
      if (targetLessonId != null && targetLessonId > 0) {
        for (final item in res.lessons) {
          if (item.id == targetLessonId) {
            picked = item;
            break;
          }
        }
      }
      picked ??= res.lessons.isNotEmpty ? res.lessons.first : null;
      if (picked != null) {
        unawaited(cache.setLastVideoLessonId(widget.seriesId, picked.id));
      }
      if (!mounted) return;
      setState(() {
        _detail = res;
        _activeLesson = picked;
        _loading = false;
      });
      if (picked != null && context.read<UserProvider>().isAuthenticated) {
        await _initPlayer(picked);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        GglFeedback.error(context, friendlyErrorMessage(e, '加载教学视频失败'));
      }
    }
  }

  Future<void> _initPlayer(VideoLessonItem lesson, {bool autoPlay = false}) async {
    _disposePlayer();
    if (lesson.videoUrl.isEmpty) return;
    setState(() {
      _playerReady = false;
      _playerError = false;
    });
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(lesson.videoUrl),
      );
      _playerController = controller;
      await controller.initialize();
      if (!mounted || _playerController != controller) return;
      setState(() => _playerReady = true);
      if (autoPlay) {
        await controller.play();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _playerError = true);
      }
    }
  }

  Future<void> _selectLesson(VideoLessonItem lesson) async {
    setState(() => _activeLesson = lesson);
    unawaited(
      context
          .read<GlobalCache>()
          .setLastVideoLessonId(widget.seriesId, lesson.id),
    );
    if (_scrollController.hasClients) {
      unawaited(
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        ),
      );
    }
    if (context.read<UserProvider>().isAuthenticated) {
      await _initPlayer(lesson, autoPlay: true);
    }
  }

  Future<void> _requireLoginToWatch() async {
    GglFeedback.warning(context, '请先登录后再观看课程视频');
    final loggedIn = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const LoginPage()),
    );
    if (loggedIn == true && mounted && _activeLesson != null) {
      await _initPlayer(_activeLesson!, autoPlay: true);
    }
  }

  Future<void> _openAttachment(NoteAttachmentItem att) async {
    if (att.url.isEmpty) {
      GglFeedback.error(context, '附件链接已失效，请刷新页面重试');
      return;
    }
    if (att.isImage) {
      await ImagePreviewPage.open(
        context,
        imageUrl: att.url,
        title: att.name,
      );
      return;
    }
    final uri = Uri.tryParse(att.url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    await Clipboard.setData(ClipboardData(text: att.url));
    if (mounted) {
      await GglFeedback.alert(
        context,
        title: '已复制下载链接',
        content: '已复制附件「${att.name}」的下载地址，可在系统浏览器粘贴打开或下载。',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final isAuth = context.watch<UserProvider>().isAuthenticated;
    final detail = _detail;
    final lesson = _activeLesson;

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: GglAppBar(
        title: detail?.series.title ?? '修炼课堂',
        showBack: true,
      ),
      body: Column(
        children: [
          // Top Video Player Stage
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: GglSkeletonBox(width: double.infinity, height: 205),
            )
          else if (lesson != null && lesson.videoUrl.isNotEmpty)
            _buildVideoHeader(context, colors, isAuth, detail, lesson),

          // Scrollable content (Series Info, Class Notes, Lesson List)
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                if (_loading) ...[
                  const GglCardSkeleton(lines: 3),
                  const SizedBox(height: 14),
                  const GglCardSkeleton(lines: 4),
                ] else if (detail != null) ...[
                  // Series summary
                  GglComicPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                detail.series.title,
                                style: TextStyle(
                                  color: colors.ink,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GglStatusTag(
                              label: detail.series.realmName.isNotEmpty
                                  ? detail.series.realmName
                                  : '全境界',
                              variant: WelkBadgeVariant.success,
                            ),
                          ],
                        ),
                        if (detail.series.intro.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            detail.series.intro,
                            style: TextStyle(
                              color: AppTheme.mutedText(context),
                              fontSize: 13.5,
                              height: 1.55,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Class notes & attachments
                  if (lesson != null && lesson.hasNotes) ...[
                    const SizedBox(height: 14),
                    GglComicPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.menu_book_rounded, size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '课堂笔记 · ${lesson.title}',
                                  style: TextStyle(
                                    color: colors.ink,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (lesson.classNotes.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            MathText(lesson.classNotes),
                          ],
                          if (lesson.notesAttachments.isNotEmpty) ...[
                            if (lesson.classNotes.trim().isNotEmpty)
                              const GglDivider(verticalPadding: 12)
                            else
                              const SizedBox(height: 10),
                            Text(
                              '笔记附件（${lesson.notesAttachments.length} 个）',
                              style: TextStyle(
                                color: AppTheme.mutedText(context),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            for (final att in lesson.notesAttachments)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: GglComicPanel(
                                  color: colors.muted,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  shadowOffset: const Offset(2, 2),
                                  onTap: () => _openAttachment(att),
                                  child: Row(
                                    children: [
                                      Icon(
                                        att.isImage
                                            ? Icons.image_rounded
                                            : Icons.description_rounded,
                                        size: 20,
                                        color: colors.ink,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              att.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: colors.ink,
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              FormatUtils.formatFileSize(
                                                  att.size),
                                              style: TextStyle(
                                                color:
                                                    AppTheme.mutedText(context),
                                                fontSize: 11.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      GglStatusTag(
                                        label: att.isImage ? '预览' : '打开',
                                        variant: WelkBadgeVariant.defaultStyle,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // Lesson episodes list
                  const GglSectionLabel(title: '课程选集'),
                  GglComicPanel(
                    child: detail.lessons.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                '该系列暂未上传视频课时',
                                style: TextStyle(
                                  color: AppTheme.mutedText(context),
                                ),
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              for (var i = 0; i < detail.lessons.length; i++)
                                _LessonTile(
                                  index: i,
                                  lesson: detail.lessons[i],
                                  fallbackCover: detail.series.coverImageUrl,
                                  active: lesson?.id == detail.lessons[i].id,
                                  onTap: () => _selectLesson(detail.lessons[i]),
                                ),
                            ],
                          ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoHeader(
    BuildContext context,
    WelkColors colors,
    bool isAuth,
    VideoSeriesDetail? detail,
    VideoLessonItem lesson,
  ) {
    final poster = (lesson.coverImageUrl != null &&
            lesson.coverImageUrl!.isNotEmpty)
        ? lesson.coverImageUrl!
        : (detail?.series.coverImageUrl ?? '');

    if (!isAuth) {
      return GestureDetector(
        onTap: _requireLoginToWatch,
        child: Container(
          width: double.infinity,
          height: 215,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            border: Border(
              bottom: BorderSide(
                color: colors.outline,
                width: colors.borderWidth,
              ),
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (poster.isNotEmpty)
                Image.network(
                  poster,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              Container(
                color: const Color(0x990F172A),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: colors.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.outline, width: 2.5),
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        size: 36,
                        color: colors.onFill(colors.accent),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '点击播放课程视频',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '请先登录后观看',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _playerController;
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(
          bottom: BorderSide(color: colors.outline, width: colors.borderWidth),
        ),
      ),
      child: _playerError
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '视频加载失败',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  GglButton(
                    label: '重试播放',
                    onPressed: () => _initPlayer(lesson, autoPlay: true),
                  ),
                ],
              ),
            )
          : !_playerReady || controller == null
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: AspectRatio(
                        aspectRatio: controller.value.aspectRatio > 0
                            ? controller.value.aspectRatio
                            : 16 / 9,
                        child: VideoPlayer(controller),
                      ),
                    ),
                    ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: controller,
                      builder: (context, value, _) {
                        return Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () {
                              if (value.isPlaying) {
                                controller.pause();
                              } else {
                                controller.play();
                              }
                            },
                            child: Stack(
                              children: [
                                if (!value.isPlaying)
                                  Center(
                                    child: Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: colors.accent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: colors.outline,
                                          width: 2,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.play_arrow_rounded,
                                        size: 34,
                                        color: colors.onFill(colors.accent),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(
                                      10,
                                      6,
                                      10,
                                      6,
                                    ),
                                    color: const Color(0x88000000),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          icon: Icon(
                                            value.isPlaying
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                            color: Colors.white,
                                          ),
                                          onPressed: () {
                                            if (value.isPlaying) {
                                              controller.pause();
                                            } else {
                                              controller.play();
                                            }
                                          },
                                        ),
                                        Text(
                                          FormatUtils.formatDuration(
                                              value.position.inSeconds),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            child: VideoProgressIndicator(
                                              controller,
                                              allowScrubbing: true,
                                              colors: VideoProgressColors(
                                                playedColor: colors.accent,
                                                bufferedColor: Colors.white38,
                                                backgroundColor: Colors.white24,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          FormatUtils.formatDuration(
                                              value.duration.inSeconds),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.index,
    required this.lesson,
    required this.fallbackCover,
    required this.active,
    required this.onTap,
  });

  final int index;
  final VideoLessonItem lesson;
  final String fallbackCover;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final thumb =
        (lesson.coverImageUrl != null && lesson.coverImageUrl!.isNotEmpty)
            ? lesson.coverImageUrl!
            : fallbackCover;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: active
                ? colors.accent.withValues(alpha: colors.isDark ? 0.25 : 0.35)
                : colors.muted,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: colors.outline,
              width: active ? colors.borderWidth : 1.4,
            ),
          ),
          child: Row(
            children: [
              if (thumb.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    thumb,
                    width: 56,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _IndexBox(
                      index: index + 1,
                      active: active,
                    ),
                  ),
                )
              else
                _IndexBox(index: index + 1, active: active),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${index + 1}. ${lesson.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (lesson.durationSec > 0) ...[
                const SizedBox(width: 6),
                Text(
                  FormatUtils.formatDuration(lesson.durationSec),
                  style: TextStyle(
                    color: AppTheme.mutedText(context),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Icon(
                Icons.play_circle_fill_rounded,
                size: 20,
                color: active ? colors.ink : AppTheme.mutedText(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IndexBox extends StatelessWidget {
  const _IndexBox({required this.index, required this.active});

  final int index;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? colors.accent : colors.paper,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: colors.outline, width: 1.5),
      ),
      child: Text(
        '$index',
        style: TextStyle(
          color: active ? colors.onFill(colors.accent) : colors.ink,
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
