class UpdateUtils {
  UpdateUtils._();

  static const int minValidApkBytes = 100 * 1024;

  static String normalizeVersion(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '1.0.0';
    final trimmed = raw.trim();
    if (trimmed.startsWith('v') || trimmed.startsWith('V')) {
      return trimmed.substring(1).trim();
    }
    return trimmed;
  }

  static int deriveVersionCode(String version) {
    final core = normalizeVersion(version).split('-').first;
    final parts = core.split('.');
    int partAt(int idx) {
      if (idx >= parts.length) return 0;
      final digits = parts[idx].replaceAll(RegExp(r'\D'), '');
      return int.tryParse(digits) ?? 0;
    }

    return partAt(0) * 100 + partAt(1) * 10 + partAt(2);
  }

  static int compareVersions(String v1, String v2) {
    final a = normalizeVersion(v1).split('-').first.split('.');
    final b = normalizeVersion(v2).split('-').first.split('.');
    final len = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < len; i++) {
      final na = i < a.length
          ? int.tryParse(a[i].replaceAll(RegExp(r'\D'), '')) ?? 0
          : 0;
      final nb = i < b.length
          ? int.tryParse(b[i].replaceAll(RegExp(r'\D'), '')) ?? 0
          : 0;
      if (na != nb) return na > nb ? 1 : -1;
    }
    return 0;
  }

  /// Recognizes `.apk`, `/api/app/version/download`, and `/downloads/` as direct in-app APK downloads.
  static bool isDirectApkDownloadUrl(String? rawUrl) {
    final trimmed = (rawUrl ?? '').trim();
    if (trimmed.isEmpty) return false;
    final pathOnly = trimmed.split(RegExp(r'[?#]')).first.toLowerCase();
    if (pathOnly.isEmpty) return false;
    if (pathOnly.endsWith('.html') ||
        pathOnly.endsWith('.htm') ||
        pathOnly.contains('/releases/tag/') ||
        pathOnly.endsWith('/releases/latest')) {
      return false;
    }
    return pathOnly.endsWith('.apk') ||
        pathOnly.contains('/api/app/version/download') ||
        pathOnly.contains('/downloads/');
  }

  static String formatUpdateByteSize(int bytes) {
    if (bytes <= 0) return '0 MB';
    if (bytes < 1024 * 1024) {
      final kb = (bytes / 1024).round();
      return '${kb < 1 ? 1 : kb} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static int computeDownloadPercent(int downloadedBytes, int totalBytes) {
    if (totalBytes <= 0) return 0;
    final safeDownloaded = downloadedBytes < 0 ? 0 : downloadedBytes;
    final pct = ((safeDownloaded * 100) / totalBytes).round();
    return pct.clamp(0, 99);
  }

  static String buildApkFileName(String version) {
    final safe =
        normalizeVersion(version).replaceAll(RegExp(r'[^0-9A-Za-z._-]'), '_');
    return 'guoguanla-v${safe.isEmpty ? 'latest' : safe}.apk';
  }

  static List<String> parseReleaseNotesList(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) {
      return const ['优化页面布局与作答体验', '修复已知问题，建议立即更新'];
    }
    final byLines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.replaceFirst(RegExp(r'^[-*•]\s*'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (byLines.length > 1) return byLines;

    final normalized = text.replaceFirst(
      RegExp(r'^(过关啦\s*v?[\d.]+\s*更新[:：]\s*)', caseSensitive: false),
      '',
    );
    final parts = normalized
        .split(RegExp(r'[；;]+|(?=\d+[.、]\s*)'))
        .map((s) => s.replaceFirst(RegExp(r'^\d+[.、]\s*'), '').trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.isNotEmpty ? parts : <String>[text];
  }
}
