import 'dart:typed_data';

import 'docx_share_service_web.dart'
    if (dart.library.io) 'docx_share_service_io.dart' as impl;

class DocxActionResult {
  const DocxActionResult({
    required this.success,
    required this.message,
    this.savedPath,
  });

  final bool success;
  final String message;
  final String? savedPath;
}

class DocxShareService {
  DocxShareService._();

  static const String docxMimeType =
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

  static String sanitizeFileName(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    final base = cleaned.isEmpty ? '过关啦_数学错题巩固卷' : cleaned;
    return base.toLowerCase().endsWith('.docx') ? base : '$base.docx';
  }

  /// 生成 Word 文件并优先唤起微信分享（未安装或非 Android 自动降级至系统分享 / 浏览器下载）。
  static Future<DocxActionResult> shareToWeChat({
    required Uint8List bytes,
    required String fileName,
    required String title,
  }) =>
      impl.shareToWeChat(
        bytes: bytes,
        fileName: sanitizeFileName(fileName),
        title: title,
      );

  /// 通过系统分享面板分享 Word 文件（支持微信、QQ、钉钉、邮件、AirDrop 等）。
  static Future<DocxActionResult> shareSystem({
    required Uint8List bytes,
    required String fileName,
    required String title,
  }) =>
      impl.shareSystem(
        bytes: bytes,
        fileName: sanitizeFileName(fileName),
        title: title,
      );

  /// 本地打开 Word 文件（Web 端直接触发下载）。
  static Future<DocxActionResult> openLocally({
    required Uint8List bytes,
    required String fileName,
  }) =>
      impl.openLocally(
        bytes: bytes,
        fileName: sanitizeFileName(fileName),
      );
}
