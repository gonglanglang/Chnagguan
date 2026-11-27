import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_theme.dart';
import '../core/network/api_client.dart';
import '../models/models.dart';
import '../pages/banner/banner_detail_page.dart';
import 'ggl_comic_panel.dart';

/// 首页顶部师资力量轮播图组件：
/// 支持自动轮播、手动滑动、点击跳转至富文本详情页。
class HomeBannerCarousel extends StatefulWidget {
  const HomeBannerCarousel({
    super.key,
    required this.banners,
    this.autoPlayInterval = const Duration(seconds: 5),
  });

  final List<HomeBannerItem> banners;
  final Duration autoPlayInterval;

  @override
  State<HomeBannerCarousel> createState() => _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends State<HomeBannerCarousel> {
  late final PageController _pageController;
  Timer? _autoTimer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _restartAutoPlay();
  }

  @override
  void didUpdateWidget(covariant HomeBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) {
      if (_currentIndex >= widget.banners.length) {
        _currentIndex = 0;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      }
      _restartAutoPlay();
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _restartAutoPlay() {
    _autoTimer?.cancel();
    if (widget.banners.length <= 1) return;
    _autoTimer = Timer.periodic(widget.autoPlayInterval, (_) {
      if (!mounted || !_pageController.hasClients || widget.banners.length <= 1) {
        return;
      }
      final next = (_currentIndex + 1) % widget.banners.length;
      unawaited(
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  String _resolveImageUrl(BuildContext context, String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('data:')) {
      return trimmed;
    }
    try {
      final origin = context.read<ApiClient>().baseOrigin;
      if (origin.isEmpty) return trimmed;
      return trimmed.startsWith('/') ? '$origin$trimmed' : '$origin/$trimmed';
    } catch (_) {
      return trimmed;
    }
  }

  void _openBanner(HomeBannerItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BannerDetailPage(
          bannerId: item.id,
          initialBanner: item,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();
    final accent = AppTheme.accentColor(context);
    final muted = AppTheme.mutedText(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GglComicPanel(
          padding: EdgeInsets.zero,
          child: AspectRatio(
            aspectRatio: 16 / 6.2,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: widget.banners.length,
                  onPageChanged: (index) {
                    if (mounted) setState(() => _currentIndex = index);
                  },
                  itemBuilder: (ctx, idx) {
                    final item = widget.banners[idx];
                    final imgUrl = _resolveImageUrl(ctx, item.imageUrl);
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _openBanner(item),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (imgUrl.isNotEmpty)
                            Image.network(
                              imgUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (c, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  color: AppTheme.mutedSurfaceColor(c),
                                  alignment: Alignment.center,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                );
                              },
                              errorBuilder: (c, _, _) => _BannerFallbackArt(
                                title: item.title,
                                subtitle: item.subtitle,
                                accent: accent,
                              ),
                            )
                          else
                            _BannerFallbackArt(
                              title: item.title,
                              subtitle: item.subtitle,
                              accent: accent,
                            ),
                          // Bottom readability scrim
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0.35, 1.0],
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.72),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 12,
                            top: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.52),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.28),
                                  width: 1,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified_rounded,
                                    size: 12,
                                    color: Colors.amberAccent,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '师资力量',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 10,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w900,
                                          height: 1.2,
                                          fontFamilyFallback:
                                              AppTheme.cjkFontFallback,
                                        ),
                                      ),
                                      if (item.subtitle.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          item.subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.88),
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '详情',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.banners.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: i == _currentIndex ? 18 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i == _currentIndex
                        ? accent
                        : muted.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BannerFallbackArt extends StatelessWidget {
  const _BannerFallbackArt({
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.9),
            const Color(0xFF1E3A8A),
          ],
        ),
      ),
      padding: const EdgeInsets.all(16),
      alignment: Alignment.topRight,
      child: Icon(
        Icons.auto_stories_rounded,
        size: 54,
        color: Colors.white.withValues(alpha: 0.2),
      ),
    );
  }
}
