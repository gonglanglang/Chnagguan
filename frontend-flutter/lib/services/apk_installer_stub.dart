import 'package:dio/dio.dart';

import 'apk_installer.dart';

bool supportsInAppApkInstall() => false;

Future<bool> fileExists(String path) async => false;

Future<void> deleteIfExists(String path) async {}

Future<ApkDownloadResult> downloadApk({
  required String url,
  required String version,
  required CancelToken cancelToken,
  required void Function(int received, int total) onProgress,
}) async {
  return const ApkDownloadFailure('当前平台不支持应用内直接安装 APK');
}

Future<String?> installApk(String filePath) async {
  return '当前平台不支持自动拉起系统安装器';
}
