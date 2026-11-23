import 'package:dio/dio.dart';

import 'apk_installer_stub.dart'
    if (dart.library.io) 'apk_installer_io.dart' as impl;

abstract class ApkDownloadResult {
  const ApkDownloadResult();
}

class ApkDownloadSuccess extends ApkDownloadResult {
  const ApkDownloadSuccess({
    required this.filePath,
    required this.totalBytes,
  });

  final String filePath;
  final int totalBytes;
}

class ApkDownloadFailure extends ApkDownloadResult {
  const ApkDownloadFailure(this.message);

  final String message;
}

class ApkInstaller {
  ApkInstaller._();

  static bool get supportsInAppApkInstall => impl.supportsInAppApkInstall();

  static Future<bool> fileExists(String path) => impl.fileExists(path);

  static Future<void> deleteIfExists(String path) => impl.deleteIfExists(path);

  static Future<ApkDownloadResult> downloadApk({
    required String url,
    required String version,
    required CancelToken cancelToken,
    required void Function(int received, int total) onProgress,
  }) =>
      impl.downloadApk(
        url: url,
        version: version,
        cancelToken: cancelToken,
        onProgress: onProgress,
      );

  static Future<String?> installApk(String filePath) =>
      impl.installApk(filePath);
}
