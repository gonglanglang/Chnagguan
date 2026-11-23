class FormatUtils {
  FormatUtils._();

  static String formatDuration(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final mm = (safe ~/ 60).toString().padLeft(2, '0');
    final ss = (safe % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String formatDateTimeShort(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final normalized = iso.replaceAll('T', ' ');
    return normalized.length >= 16 ? normalized.substring(0, 16) : normalized;
  }

  static String shortDifficultyLabel(String label) {
    if (label.isEmpty) return '';
    final idx = label.indexOf('·');
    return idx >= 0 ? label.substring(idx + 1).trim() : label;
  }

  static String padTwo(int num) => num.toString().padLeft(2, '0');

  static String greetingPrefix(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return '早上好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }
}
