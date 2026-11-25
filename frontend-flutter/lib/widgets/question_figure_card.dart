import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../app/app_theme.dart';
import '../models/models.dart';
import 'image_preview_page.dart';
import 'smart_board/board_diagram_painter.dart';

/// 题目配图渲染卡片：同时支持后端题库矢量几何图 ([BoardDiagramSpec]) 与上传图片 ([imageUrl])。
/// 始终保持纯白干净的试卷底色，确保几何线条、标注与直角符号在浅色/暗黑模式与三种皮肤下均清晰可读；
/// 点击即可全屏双指缩放查看细节。
class QuestionFigureCard extends StatelessWidget {
  const QuestionFigureCard({
    super.key,
    this.diagram,
    this.imageUrl,
    this.compact = false,
  });

  final BoardDiagramSpec? diagram;
  final String? imageUrl;
  final bool compact;

  bool get _hasDiagram => diagram != null && diagram!.primitives.isNotEmpty;
  bool get _hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_hasDiagram && !_hasImage) return const SizedBox.shrink();

    final isForui = AppTheme.isForui(context);
    final colors = WelkTheme.of(context).resolveColors(context);
    final borderColor = isForui
        ? FTheme.of(context).colors.border
        : colors.outline.withValues(alpha: colors.isDark ? 0.55 : 0.75);
    final borderWidth = isForui ? 1.0 : 1.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_hasDiagram)
          GestureDetector(
            onTap: () => _openDiagramZoomDialog(context, diagram!),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor, width: borderWidth),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      8,
                      compact ? 6 : 8,
                      8,
                      compact ? 6 : 10,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: compact ? 145 : 196,
                      child: CustomPaint(
                        painter: _QuestionDiagramCustomPainter(diagram!),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(0xFFCBD5E1),
                          width: 0.8,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.zoom_in_rounded,
                            size: 12,
                            color: Color(0xFF475569),
                          ),
                          SizedBox(width: 2),
                          Text(
                            '放大',
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              fontFamilyFallback: AppTheme.cjkFontFallback,
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
        if (_hasDiagram && _hasImage) const SizedBox(height: 8),
        if (_hasImage)
          GestureDetector(
            onTap: () => ImagePreviewPage.open(
              context,
              imageUrl: imageUrl!.trim(),
              title: '题目配图',
            ),
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight: compact ? 150 : 210,
              ),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor, width: borderWidth),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                imageUrl!.trim(),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      '配图加载失败',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  static Future<void> _openDiagramZoomDialog(
    BuildContext context,
    BoardDiagramSpec spec,
  ) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogCtx) {
        return Dialog.fullscreen(
          backgroundColor: const Color(0xFF0F172A),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          spec.title.isNotEmpty ? spec.title : '题目配图预览',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFamilyFallback: AppTheme.cjkFontFallback,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: AspectRatio(
                          aspectRatio: (spec.width > 20 ? spec.width : 320) /
                              (spec.height > 20 ? spec.height : 210),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: CustomPaint(
                              painter: _QuestionDiagramCustomPainter(spec),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Text(
                    '双指捏合可缩放查看细节',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuestionDiagramCustomPainter extends CustomPainter {
  const _QuestionDiagramCustomPainter(this.spec);

  final BoardDiagramSpec spec;

  @override
  void paint(Canvas canvas, Size size) {
    BoardDiagramPainter.paintDiagram(
      canvas,
      spec,
      Offset.zero & size,
      showFrame: false,
    );
  }

  @override
  bool shouldRepaint(covariant _QuestionDiagramCustomPainter oldDelegate) =>
      oldDelegate.spec != spec;
}
