import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import 'docx_share_service.dart';

Future<DocxActionResult> _saveOnWeb(
  Uint8List bytes,
  String fileName,
  String message,
) async {
  try {
    final xFile = XFile.fromData(
      bytes,
      mimeType: DocxShareService.docxMimeType,
      name: fileName,
    );
    await xFile.saveTo(fileName);
    return DocxActionResult(success: true, message: message);
  } catch (e) {
    return DocxActionResult(success: false, message: '浏览器下载 Word 失败：$e');
  }
}

Future<DocxActionResult> shareToWeChat({
  required Uint8List bytes,
  required String fileName,
  required String title,
}) {
  return _saveOnWeb(
    bytes,
    fileName,
    '已下载 Word 错题卷（$fileName），可直接发送至微信或打印（在 App 端支持一键唤起微信分享）',
  );
}

Future<DocxActionResult> shareSystem({
  required Uint8List bytes,
  required String fileName,
  required String title,
}) async {
  try {
    final xFile = XFile.fromData(
      bytes,
      mimeType: DocxShareService.docxMimeType,
      name: fileName,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [xFile],
        subject: title,
        text: '$title（A4 错题巩固卷）',
      ),
    );
    return DocxActionResult(
      success: true,
      message: '已导出 Word 错题卷（$fileName）',
    );
  } catch (_) {
    return _saveOnWeb(bytes, fileName, '已下载 Word 错题卷（$fileName）');
  }
}

Future<DocxActionResult> openLocally({
  required Uint8List bytes,
  required String fileName,
}) {
  return _saveOnWeb(bytes, fileName, '已下载 Word 错题卷（$fileName），请使用 Word 或 WPS 打开');
}
