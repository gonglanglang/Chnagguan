import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../../app/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/format_utils.dart';
import '../../models/models.dart';
import '../../services/guoguanla_api.dart';
import '../../widgets/ggl_comic_panel.dart';
import '../../widgets/ggl_feedback.dart';
import '../../widgets/ggl_skeleton.dart';
import '../../widgets/ggl_skin_widgets.dart';
import '../../widgets/image_preview_page.dart';

/// 首页师资力量轮播图富文本详情页（原生 Flutter 渲染，全面兼容 Android / iOS / Web）。
class BannerDetailPage extends StatefulWidget {
  const BannerDetailPage({
    super.key,
    required this.bannerId,
    this.initialBanner,
  });

  final int bannerId;
  final HomeBannerItem? initialBanner;

  @override
  State<BannerDetailPage> createState() => _BannerDetailPageState();
}

class _BannerDetailPageState extends State<BannerDetailPage> {
  bool _loading = true;
  String _error = '';
  HomeBannerDetail? _detail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetail());
  }

  String _resolveUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('data:')) {
      return trimmed;
    }
    final origin = context.read<ApiClient>().baseOrigin;
    if (origin.isEmpty) return trimmed;
    return trimmed.startsWith('/') ? '$origin$trimmed' : '$origin/$trimmed';
  }

  String _normalizeHtmlMediaUrls(String html) {
    final origin = context.read<ApiClient>().baseOrigin;
    if (origin.isEmpty || html.isEmpty) return html;
    return html.replaceAllMapped(
      RegExp(r'''(src|href)=(["'])(/api/[^"']+)\2''', caseSensitive: false),
      (m) => '${m.group(1)}=${m.group(2)}$origin${m.group(3)}${m.group(2)}',
    );
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final res = await context.read<GuoguanlaApi>().getHomeBannerDetail(
            widget.bannerId,
          );
      if (!mounted) return;
      setState(() => _detail = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyErrorMessage(e, '加载详情失败，请稍后重试'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _handleTapUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https' && uri.scheme != 'mailto')) {
      return false;
    }
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        GglFeedback.warning(context, '无法打开该链接');
      }
      return launched;
    } catch (_) {
      if (mounted) GglFeedback.warning(context, '无法打开该链接');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.inkColor(context);
    final muted = AppTheme.mutedText(context);
    final accent = AppTheme.accentColor(context);
    final surface = AppTheme.surfaceColor(context);
    final title = (_detail?.title.isNotEmpty ?? false)
        ? _detail!.title
        : (widget.initialBanner?.title.isNotEmpty ?? false)
            ? widget.initialBanner!.title
            : '师资详情';
    final subtitle = (_detail?.subtitle.isNotEmpty ?? false)
        ? _detail!.subtitle
        : (widget.initialBanner?.subtitle ?? '');
    final rawCover = (_detail?.imageUrl.isNotEmpty ?? false)
        ? _detail!.imageUrl
        : (widget.initialBanner?.imageUrl ?? '');
    final coverUrl = _resolveUrl(rawCover);
    final updatedAt = _detail?.updatedAt ?? widget.initialBanner?.updatedAt ?? '';
    final normalizedHtml = _normalizeHtmlMediaUrls(_detail?.contentHtml ?? '');

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: GglAppBar(
        title: title,
        showBack: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadDetail,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            if (coverUrl.isNotEmpty) ...[
              GglComicPanel(
                padding: EdgeInsets.zero,
                onTap: () => ImagePreviewPage.open(
                  context,
                  imageUrl: coverUrl,
                  title: title,
                ),
                child: AspectRatio(
                  aspectRatio: 12 / 5,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: AppTheme.mutedSurfaceColor(ctx),
                            alignment: Alignment.center,
                            child: const CircularProgressIndicator(strokeWidth: 2),
                          );
                        },
                        errorBuilder: (ctx, _, _) => Container(
                          color: AppTheme.mutedSurfaceColor(ctx),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 36,
                            color: muted,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.zoom_in_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                              SizedBox(width: 3),
                              Text(
                                '查看大图',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Header Meta Card
            GglComicPanel(
              color: surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const GglStatusTag(
                        label: '师资风采',
                        variant: WelkBadgeVariant.info,
                      ),
                      if (updatedAt.isNotEmpty)
                        Text(
                          '更新于 ${FormatUtils.formatDateTimeShort(updatedAt)}',
                          style: TextStyle(
                            color: muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: TextStyle(
                      color: ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1.35,
                      fontFamilyFallback: AppTheme.cjkFontFallback,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: muted,
                        fontSize: 13.5,
                        height: 1.5,
                        fontFamilyFallback: AppTheme.cjkFontFallback,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Rich Content Body
            if (_loading && _detail == null)
              const GglCardSkeleton(lines: 6)
            else if (_error.isNotEmpty && _detail == null)
              GglComicPanel(
                padding: const EdgeInsets.symmetric(
                  vertical: 32,
                  horizontal: 20,
                ),
                child: Column(
                  children: [
                    Icon(Icons.error_outline_rounded, size: 40, color: muted),
                    const SizedBox(height: 10),
                    Text(
                      _error,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    GglButton(
                      label: '重新加载',
                      onPressed: () => unawaited(_loadDetail()),
                    ),
                  ],
                ),
              )
            else
              GglComicPanel(
                color: surface,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: normalizedHtml.trim().isEmpty
                    ? Text(
                        '暂未编辑详细介绍内容。',
                        style: TextStyle(color: muted, fontSize: 14),
                      )
                    : HtmlWidget(
                        normalizedHtml,
                        textStyle: TextStyle(
                          color: ink,
                          fontSize: 15,
                          height: 1.75,
                          fontFamilyFallback: AppTheme.cjkFontFallback,
                        ),
                        onTapUrl: _handleTapUrl,
                        customStylesBuilder: (element) {
                          final tag = element.localName?.toLowerCase();
                          if (tag == 'h1') {
                            return {
                              'font-size': '20px',
                              'font-weight': '800',
                              'margin': '14px 0 8px 0',
                            };
                          }
                          if (tag == 'h2') {
                            return {
                              'font-size': '18px',
                              'font-weight': '800',
                              'margin': '14px 0 8px 0',
                            };
                          }
                          if (tag == 'h3') {
                            return {
                              'font-size': '16px',
                              'font-weight': '700',
                              'margin': '12px 0 6px 0',
                            };
                          }
                          if (tag == 'p') {
                            return {'margin': '8px 0'};
                          }
                          if (tag == 'blockquote') {
                            final hex = AppTheme.toHex(accent);
                            return {
                              'border-left': '4px solid $hex',
                              'padding': '8px 12px',
                              'margin': '10px 0',
                              'background-color':
                                  WelkTheme.of(context).resolveDarkMode(context)
                                      ? '#26262B'
                                      : '#F5F7FA',
                            };
                          }
                          if (tag == 'a') {
                            return {
                              'color': AppTheme.toHex(accent),
                              'text-decoration': 'underline',
                            };
                          }
                          return null;
                        },
                        customWidgetBuilder: (element) {
                          if (element.localName?.toLowerCase() == 'img') {
                            final rawSrc = element.attributes['src'] ?? '';
                            final imgSrc = _resolveUrl(rawSrc);
                            if (imgSrc.isEmpty) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: GestureDetector(
                                onTap: () => ImagePreviewPage.open(
                                  context,
                                  imageUrl: imgSrc,
                                  title: element.attributes['alt'] ?? title,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    imgSrc,
                                    width: double.infinity,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (ctx, child, progress) {
                                      if (progress == null) return child;
                                      return Container(
                                        height: 160,
                                        color: AppTheme.mutedSurfaceColor(ctx),
                                        alignment: Alignment.center,
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      );
                                    },
                                    errorBuilder: (ctx, _, _) => Container(
                                      height: 120,
                                      color: AppTheme.mutedSurfaceColor(ctx),
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.broken_image_outlined,
                                            size: 20,
                                            color: muted,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '图片加载失败',
                                            style: TextStyle(
                                              color: muted,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          return null;
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
