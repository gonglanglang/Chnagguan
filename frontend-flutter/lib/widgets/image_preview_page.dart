import 'package:flutter/material.dart';

import 'ggl_skin_widgets.dart';

class ImagePreviewPage extends StatelessWidget {
  const ImagePreviewPage({
    super.key,
    required this.imageUrl,
    this.title = '图片预览',
  });

  final String imageUrl;
  final String title;

  static Future<void> open(
    BuildContext context, {
    required String imageUrl,
    String title = '图片预览',
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ImagePreviewPage(imageUrl: imageUrl, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121214),
      appBar: GglAppBar(
        title: title,
        showBack: true,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.6,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                child: CircularProgressIndicator(),
              );
            },
            errorBuilder: (context, _, _) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                '图片加载失败，请检查网络连接',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
