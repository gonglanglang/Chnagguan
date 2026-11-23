import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../core/utils/update_utils.dart';
import 'apk_installer.dart';

bool supportsInAppApkInstall() => Platform.isAndroid;

Future<bool> fileExists(String path) async {
  if (path.isEmpty) return false;
  return File(path).exists();
}

Future<void> deleteIfExists(String path) async {
  if (path.isEmpty) return;
  try {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {
    // Ignore cleanup errors
  }
}

Future<ApkDownloadResult> downloadApk({
  required String url,
  required String version,
  required CancelToken cancelToken,
  required void Function(int received, int total) onProgress,
}) async {
  if (!Platform.isAndroid) {
    return const ApkDownloadFailure('仅 Android 设备支持应用内 APK 安装');
  }
  final dir = await getTemporaryDirectory();
  final fileName = UpdateUtils.buildApkFileName(version);
  final targetPath = '${dir.path}${Platform.pathSeparator}$fileName';
  await deleteIfExists(targetPath);

  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 5),
      followRedirects: true,
    ),
  );

  try {
    final response = await dio.download(
      url,
      targetPath,
      cancelToken: cancelToken,
      onReceiveProgress: onProgress,
      deleteOnError: true,
    );

    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      await deleteIfExists(targetPath);
      return ApkDownloadFailure('安装包下载失败（HTTP $status），请点击「重新下载」');
    }

    final contentType =
        (response.headers.value('content-type') ?? '').toLowerCase();
    if (contentType.contains('text/html') ||
        contentType.contains('application/json')) {
      await deleteIfExists(targetPath);
      return const ApkDownloadFailure('安装包文件校验未通过，请点击「重新下载」');
    }

    final file = File(targetPath);
    if (!await file.exists()) {
      return const ApkDownloadFailure('下载文件保存失败，请点击「重新下载」');
    }
    final size = await file.length();
    if (size < UpdateUtils.minValidApkBytes) {
      await deleteIfExists(targetPath);
      return const ApkDownloadFailure('安装包不完整，请点击「重新下载」');
    }

    return ApkDownloadSuccess(filePath: targetPath, totalBytes: size);
  } on DioException catch (e) {
    await deleteIfExists(targetPath);
    if (CancelToken.isCancel(e)) {
      return const ApkDownloadFailure('已取消下载');
    }
    return const ApkDownloadFailure('网络连接中断或超时，请检查网络后点击「重新下载」');
  } catch (_) {
    await deleteIfExists(targetPath);
    return const ApkDownloadFailure('安装包下载失败，请点击「重新下载」');
  }
}

Future<String?> installApk(String filePath) async {
  if (!Platform.isAndroid || filePath.isEmpty) {
    return '当前环境不支持自动拉起安装，请重试';
  }
  try {
    final result = await OpenFilex.open(
      filePath,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      return '安装程序拉起失败（${result.message}），请确认已允许「安装未知来源应用」后点击「立即安装」';
    }
    return null;
  } catch (e) {
    return '安装程序拉起失败（$e），请确认已允许「安装未知来源应用」后点击「立即安装」';
  }
}
