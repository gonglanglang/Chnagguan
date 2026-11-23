import 'package:flutter/material.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import 'ggl_comic_panel.dart';

class GglSkeletonBox extends StatefulWidget {
  const GglSkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
    this.circle = false,
  });

  final double? width;
  final double height;
  final double borderRadius;
  final bool circle;

  @override
  State<GglSkeletonBox> createState() => _GglSkeletonBoxState();
}

class _GglSkeletonBoxState extends State<GglSkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final base = colors.muted;
    final highlight = colors.isDark
        ? const Color(0xFF4C4C54)
        : const Color(0xFFE3DFD3);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final color = Color.lerp(base, highlight, _controller.value) ?? base;
        return Container(
          width: widget.circle ? widget.height : widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: color,
            shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius:
                widget.circle ? null : BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: colors.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
        );
      },
    );
  }
}

class GglCardSkeleton extends StatelessWidget {
  const GglCardSkeleton({super.key, this.lines = 3, this.showMedia = false});

  final int lines;
  final bool showMedia;

  @override
  Widget build(BuildContext context) {
    return GglComicPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showMedia) ...[
            const GglSkeletonBox(width: double.infinity, height: 140),
            const SizedBox(height: 12),
          ],
          const Row(
            children: [
              GglSkeletonBox(width: 90, height: 18),
              Spacer(),
              GglSkeletonBox(width: 58, height: 18),
            ],
          ),
          for (var i = 0; i < lines; i++) ...[
            const SizedBox(height: 10),
            GglSkeletonBox(
              width: i == lines - 1 ? 180 : double.infinity,
              height: i == 0 ? 18 : 13,
            ),
          ],
        ],
      ),
    );
  }
}
