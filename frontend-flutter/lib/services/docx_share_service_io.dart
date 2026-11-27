import 'dart:io';

import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'docx_share_service.dart';

const MethodChannel _fileShareChannel =
    MethodChannel('com.guoguanla.app/file_share');

Future<File> _writeTempDocx(Uint8List bytes, String fileName) async {
  final dir = await getTemporaryDirectory();
  final exportDir = Directory('${dir.path}${Platform.pathSeparator}exports');
  if (!await exportDir.exists()) {
    await exportDir.create(recursive: true);
  }
  final target = File('${exportDir.path}${Platform.pathSeparator}$fileName');
  await target.writeAsBytes(bytes, flush: true);
  return target;
}

Future<DocxActionResult> shareToWeChat({
  required Uint8List bytes,
  required String fileName,
  required String title,
}) async {
  final file = await _writeTempDocx(bytes, fileName);

  if (Platform.isAndroid) {
    try {
      final launched = await _fileShareChannel.invokeMethod<bool>(
        'shareToWeChat',
        <String, dynamic>{
          'filePath': file.path,
          'mimeType': DocxShareService.docxMimeType,
          'title': title,
        },
      );
      if (launched == true) {
        return DocxActionResult(
          success: true,
          message: '已生成 Word 并唤起微信，请选择好友或文件传输助手发送',
          savedPath: file.path,
        );
      }
    } catch (_) {
      // Fall back to system share sheet below
    }
  }

  return shareSystem(bytes: bytes, fileName: fileName, title: title);
}

Future<DocxActionResult> shareSystem({
  required Uint8List bytes,
  required String fileName,
  required String title,
}) async {
  final file = await _writeTempDocx(bytes, fileName);
  try {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            file.path,
            mimeType: DocxShareService.docxMimeType,
            name: fileName,
          ),
        ],
        subject: title,
        text: '$title（A4 错题巩固卷）',
      ),
    );
    return DocxActionResult(
      success: true,
      message: '已调起系统分享，可在面板中选择「微信」发送文档',
      savedPath: file.path,
    );
  } catch (e) {
    return DocxActionResult(
      success: false,
      message: '调起分享失败（$e），文件已保存至 ${file.path}',
      savedPath: file.path,
    );
  }
}

Future<DocxActionResult> openLocally({
  required Uint8List bytes,
  required String fileName,
}) async {
  final file = await _writeTempDocx(bytes, fileName);
  try {
    final result = await OpenFilex.open(
      file.path,
      type: DocxShareService.docxMimeType,
    );
    if (result.type == ResultType.done) {
      return DocxActionResult(
        success: true,
        message: '已打开 Word 文档',
        savedPath: file.path,
      );
    }
    return DocxActionResult(
      success: false,
      message: '未检测到可打开 .docx 的应用（${result.message}），可直接点击分享至微信查看',
      savedPath: file.path,
    );
  } catch (e) {
    return DocxActionResult(
      success: false,
      message: '打开文档失败（$e）',
      savedPath: file.path,
    );
  }
}
