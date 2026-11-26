import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app/app_config.dart';
import '../core/utils/update_utils.dart';
import '../models/models.dart';
import '../services/apk_installer.dart';
import '../services/guoguanla_api.dart';

class UpdateProvider extends ChangeNotifier {
  UpdateProvider(this._api);

  final GuoguanlaApi _api;

  bool visible = false;
  String currentVersion = AppConfig.fallbackVersion;
  int currentVersionCode = AppConfig.fallbackVersionCode;
  String latestVersion = '';
  int latestVersionCode = 0;
  bool forceUpdate = false;
  String releaseNotes = '';
  List<String> noteList = const [];
  String downloadUrl = '';
  String fallbackUrl = '';
  String downloadChannel = '';
  String ossCustomDomain = '';
  bool downloading = false;
  int progress = 0;
  int downloadedBytes = 0;
  int totalBytes = 0;
  double downloadSpeedBytesPerSec = 0;
  String downloadedFilePath = '';
  String errorMsg = '';

  bool _checking = false;
  int _sessionId = 0;
  CancelToken? _cancelToken;
  int _lastSpeedSampleMs = 0;
  int _lastSpeedSampleBytes = 0;

  Future<({String version, int versionCode})> loadLocalVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final ver = UpdateUtils.normalizeVersion(
        info.version.isNotEmpty ? info.version : AppConfig.fallbackVersion,
      );
      final code = int.tryParse(info.buildNumber) ??
          UpdateUtils.deriveVersionCode(ver);
      currentVersion = ver;
      currentVersionCode = code;
      notifyListeners();
      return (version: ver, versionCode: code);
    } catch (_) {
      return (version: currentVersion, versionCode: currentVersionCode);
    }
  }

  void dismiss() {
    if (forceUpdate || downloading) return;
    visible = false;
    notifyListeners();
  }

  Future<String?> checkForUpdate({bool silent = true}) async {
    if (_checking) return null;
    _checking = true;
    try {
      final local = await loadLocalVersion();
      AppVersionInfo? info;
      try {
        info = await _api.checkLatestVersion(
          currentVersion: local.version,
          versionCode: local.versionCode,
        );
      } catch (_) {
        info = await _api.fetchGithubReleaseFallback(local.version);
      }

      if (info == null) {
        return silent ? null : '暂时无法连接更新服务器';
      }

      if (!info.hasUpdate) {
        return silent ? null : '当前已是最新版本 v${local.version}';
      }

      final resolvedUrl = AppConfig.resolveAbsoluteUrl(
        info.downloadUrl,
        customBaseUrl: _api.client.baseUrl,
      );
      final fallback = info.githubReleaseUrl.isNotEmpty
          ? info.githubReleaseUrl
          : resolvedUrl;

      if (resolvedUrl.isEmpty && fallback.isEmpty) {
        return silent ? null : '当前已是最新版本 v${local.version}';
      }

      final nextVer = info.latestVersion.isNotEmpty
          ? info.latestVersion
          : local.version;

      if (downloading && latestVersion == nextVer) {
        visible = true;
        notifyListeners();
        return null;
      }

      final versionChanged = latestVersion != nextVer;
      latestVersion = nextVer;
      latestVersionCode = info.latestVersionCode;
      forceUpdate = info.forceUpdate;
      releaseNotes = info.releaseNotes;
      noteList = UpdateUtils.parseReleaseNotesList(info.releaseNotes);
      downloadUrl = resolvedUrl;
      fallbackUrl = fallback;
      downloadChannel = info.downloadChannel;
      ossCustomDomain = info.ossCustomDomain;

      if (versionChanged) {
        downloadedFilePath = '';
        _resetProgress();
      } else {
        errorMsg = '';
      }
      visible = true;
      notifyListeners();
      return null;
    } finally {
      _checking = false;
    }
  }

  void _resetProgress() {
    downloading = false;
    progress = 0;
    downloadedBytes = 0;
    totalBytes = 0;
    downloadSpeedBytesPerSec = 0;
    _lastSpeedSampleMs = 0;
    _lastSpeedSampleBytes = 0;
    errorMsg = '';
  }

  void cancelDownload() {
    _sessionId++;
    _cancelToken?.cancel('user_cancelled');
    _cancelToken = null;
    _resetProgress();
    notifyListeners();
  }

  Future<String?> reDownload() async {
    if (downloading) return null;
    final cached = downloadedFilePath;
    downloadedFilePath = '';
    _resetProgress();
    notifyListeners();
    if (cached.isNotEmpty) {
      await ApkInstaller.deleteIfExists(cached);
    }
    return startDownloadOrInstall();
  }

  Future<String?> startDownloadOrInstall() async {
    if (downloading) return null;

    if (downloadedFilePath.isNotEmpty && ApkInstaller.supportsInAppApkInstall) {
      final exists = await ApkInstaller.fileExists(downloadedFilePath);
      if (exists) {
        final installErr = await ApkInstaller.installApk(downloadedFilePath);
        errorMsg = installErr ?? '';
        notifyListeners();
        return null;
      }
      downloadedFilePath = '';
      progress = 0;
    }

    final url = downloadUrl.isNotEmpty ? downloadUrl : fallbackUrl;
    if (url.isEmpty) {
      errorMsg = '未获取到有效安装包下载地址';
      notifyListeners();
      return null;
    }

    if (!ApkInstaller.supportsInAppApkInstall) {
      await Clipboard.setData(ClipboardData(text: url));
      return '已复制新版本下载链接，请在浏览器中打开';
    }

    if (!UpdateUtils.isDirectApkDownloadUrl(url)) {
      errorMsg = '当前更新地址非安装包直链，请检查后台配置';
      notifyListeners();
      return null;
    }

    final sid = ++_sessionId;
    final token = CancelToken();
    _cancelToken = token;
    downloading = true;
    progress = 0;
    downloadedBytes = 0;
    totalBytes = 0;
    downloadSpeedBytesPerSec = 0;
    _lastSpeedSampleMs = DateTime.now().millisecondsSinceEpoch;
    _lastSpeedSampleBytes = 0;
    downloadedFilePath = '';
    errorMsg = '';
    notifyListeners();

    final result = await ApkInstaller.downloadApk(
      url: url,
      version: latestVersion.isNotEmpty ? latestVersion : 'latest',
      cancelToken: token,
      onProgress: (received, total) {
        if (sid != _sessionId) return;
        downloadedBytes = received;
        if (total > 0) {
          totalBytes = total;
          progress = UpdateUtils.computeDownloadPercent(received, total);
        }
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final elapsedMs = nowMs - _lastSpeedSampleMs;
        if (elapsedMs >= 350) {
          final deltaBytes = received - _lastSpeedSampleBytes;
          if (deltaBytes >= 0) {
            downloadSpeedBytesPerSec = deltaBytes * 1000.0 / elapsedMs;
          }
          _lastSpeedSampleMs = nowMs;
          _lastSpeedSampleBytes = received;
        }
        notifyListeners();
      },
    );

    if (sid != _sessionId) return null;
    downloading = false;
    _cancelToken = null;

    if (result is ApkDownloadSuccess) {
      progress = 100;
      downloadedBytes = result.totalBytes;
      totalBytes = result.totalBytes;
      downloadedFilePath = result.filePath;
      notifyListeners();
      final installErr = await ApkInstaller.installApk(result.filePath);
      errorMsg = installErr ?? '';
      notifyListeners();
      return null;
    }

    if (result is ApkDownloadFailure) {
      progress = 0;
      downloadedFilePath = '';
      errorMsg = result.message;
      notifyListeners();
    }
    return null;
  }
}
