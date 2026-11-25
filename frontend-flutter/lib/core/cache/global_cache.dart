import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/models.dart';

/// 全局缓存分类（详见 docs/02-开发规范.md 4.4 节）
enum GlobalCacheCategory {
  /// 登录态与身份快照（版本更新 & 清理缓存均强保留）
  auth,

  /// 用户偏好设置（主题、记住账号、接口环境）
  preference,

  /// 学习与课程观看进度（游客通关、课堂上次观看小节）
  learning,

  /// 应用生命周期与版本弹窗状态（已展示公告的版本号、上次安装版本）
  lifecycle,

  /// 可随时安全清理的临时缓存
  temporary,
}

/// 全局缓存条目元数据定义
class GlobalCacheEntryMeta {
  const GlobalCacheEntryMeta({
    required this.storageKey,
    required this.description,
    required this.category,
    this.preserveOnAppUpdate = true,
    this.preserveOnCacheClear = true,
  });

  final String storageKey;
  final String description;
  final GlobalCacheCategory category;

  /// App 覆盖安装升级到新版本时是否保留
  final bool preserveOnAppUpdate;

  /// 用户在「我的 -> 清理缓存」时是否保留
  final bool preserveOnCacheClear;
}

/// 全局缓存注册表：所有需要本地持久化缓存的键必须先在此枚举登记！
enum GlobalCacheKey {
  accessToken(
    GlobalCacheEntryMeta(
      storageKey: 'ggl_access_token',
      description: '学生端 30 天登录凭证 Token',
      category: GlobalCacheCategory.auth,
      preserveOnAppUpdate: true,
      preserveOnCacheClear: true,
    ),
  ),
  userProfile(
    GlobalCacheEntryMeta(
      storageKey: 'ggl_user_profile',
      description: '当前登录学生档案快照',
      category: GlobalCacheCategory.auth,
      preserveOnAppUpdate: true,
      preserveOnCacheClear: true,
    ),
  ),
  rememberedAccount(
    GlobalCacheEntryMeta(
      storageKey: 'ggl_remembered_account',
      description: '登录页记住的用户名',
      category: GlobalCacheCategory.preference,
      preserveOnAppUpdate: true,
      preserveOnCacheClear: true,
    ),
  ),
  guestPassedIds(
    GlobalCacheEntryMeta(
      storageKey: 'ggl_guest_passed_ids',
      description: '游客模式本地已通关关卡 ID 列表',
      category: GlobalCacheCategory.learning,
      preserveOnAppUpdate: true,
      preserveOnCacheClear: true,
    ),
  ),
  darkMode(
    GlobalCacheEntryMeta(
      storageKey: 'ggl_dark_mode',
      description: '暗黑模式开关状态',
      category: GlobalCacheCategory.preference,
      preserveOnAppUpdate: true,
      preserveOnCacheClear: true,
    ),
  ),
  themeHex(
    GlobalCacheEntryMeta(
      storageKey: 'ggl_theme_hex',
      description: '漫画主题强调色 HEX 值',
      category: GlobalCacheCategory.preference,
      preserveOnAppUpdate: true,
      preserveOnCacheClear: true,
    ),
  ),
  themeName(
    GlobalCacheEntryMeta(
      storageKey: 'ggl_theme_name',
      description: '漫画主题强调色名称',
      category: GlobalCacheCategory.preference,
      preserveOnAppUpdate: true,
      preserveOnCacheClear: true,
    ),
  ),
  customApiBaseUrl(
    GlobalCacheEntryMeta(
      storageKey: 'ggl_custom_api_base_url',
      description: '自定义后端接口服务地址',
      category: GlobalCacheCategory.preference,
      preserveOnAppUpdate: true,
      preserveOnCacheClear: true,
    ),
  ),
  lastWatchedVideoLessons(
    GlobalCacheEntryMeta(
      storageKey: 'ggl_video_last_lessons',
      description: '课堂各视频系列上次观看小节 ID 映射 (seriesId -> lessonId)',
      category: GlobalCacheCategory.learning,
      preserveOnAppUpdate: true,
      preserveOnCacheClear: true,
    ),
  ),
  lastAnnouncementVersion(
    GlobalCacheEntryMeta(
      storageKey: 'ggl_last_announcement_version',
      description: '已自动弹出过修炼公告的 App 版本标识 (<version>+<versionCode>)',
      category: GlobalCacheCategory.lifecycle,
      preserveOnAppUpdate: true,
      preserveOnCacheClear: true,
    ),
  ),
  lastInstalledAppVersion(
    GlobalCacheEntryMeta(
      storageKey: 'ggl_last_installed_app_version',
      description: '上次运行记录的 App 版本标识（用于识别升级并保持登录态不丢失）',
      category: GlobalCacheCategory.lifecycle,
      preserveOnAppUpdate: true,
      preserveOnCacheClear: true,
    ),
  ),
  smartBoardPrefs(
    GlobalCacheEntryMeta(
      storageKey: 'ggl_smart_board_prefs',
      description: '智能手写画板个人偏好（默认纸张底纹、笔触粗细与橡皮模式）',
      category: GlobalCacheCategory.preference,
      preserveOnAppUpdate: true,
      preserveOnCacheClear: true,
    ),
  ),
  smartBoardDraft(
    GlobalCacheEntryMeta(
      storageKey: 'ggl_smart_board_draft',
      description: '首页 AI 智能手写画板最近草稿快照（含题目、笔迹、几何图元与 AI 板书，可在清理缓存时释放）',
      category: GlobalCacheCategory.temporary,
      preserveOnAppUpdate: true,
      preserveOnCacheClear: false,
    ),
  );

  const GlobalCacheKey(this.meta);

  final GlobalCacheEntryMeta meta;

  String get storageKey => meta.storageKey;
}

/// 「过关啦」客户端唯一全局缓存对象（Single Source of Truth）。
///
/// 强制开发规范：
/// 1. 严禁在页面、Provider 或 Service 中私自调用 SharedPreferences 读写散落键名；
/// 2. 今后新增任何缓存字段，必须先在 [GlobalCacheKey] 登记元数据，再在本类提供强类型读写方法；
/// 3. 覆盖安装新版本 App 时自动保留全部 `auth` / `preference` / `learning` 数据，确保不重复要求登录。
class GlobalCache {
  GlobalCache._(this._prefs);

  static GlobalCache? _instance;

  /// 全局缓存对象单例引用（应用启动调用 [init] 后即可全局访问，亦支持通过 Provider 注入）
  static GlobalCache get instance {
    final current = _instance;
    if (current == null) {
      throw StateError('GlobalCache 尚未初始化，请先调用 await GlobalCache.init()');
    }
    return current;
  }

  /// 全部已登记缓存键的只读元数据清单
  static List<GlobalCacheKey> get registry => GlobalCacheKey.values;

  static final Set<String> _preservedOnCacheClearKeys = {
    for (final key in GlobalCacheKey.values)
      if (key.meta.preserveOnCacheClear) key.storageKey,
  };

  final SharedPreferences _prefs;

  /// 初始化全局缓存对象并绑定单例
  static Future<GlobalCache> init() async {
    final prefs = await SharedPreferences.getInstance();
    final cache = GlobalCache._(prefs);
    _instance = cache;
    return cache;
  }

  // ==================== 1. 登录态与身份快照 (auth) ====================

  String get accessToken =>
      _prefs.getString(GlobalCacheKey.accessToken.storageKey) ?? '';

  Future<void> setAccessToken(String token) async {
    final key = GlobalCacheKey.accessToken.storageKey;
    if (token.isEmpty) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, token);
    }
  }

  AppUserProfile? get cachedProfile {
    final raw = _prefs.getString(GlobalCacheKey.userProfile.storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AppUserProfile.fromJson(decoded);
      }
    } catch (_) {
      // 忽略损坏的旧缓存
    }
    return null;
  }

  Future<void> setCachedProfile(AppUserProfile? profile) async {
    final key = GlobalCacheKey.userProfile.storageKey;
    if (profile == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, jsonEncode(profile.toJson()));
    }
  }

  // ==================== 2. 用户偏好设置 (preference) ====================

  String get rememberedAccount =>
      _prefs.getString(GlobalCacheKey.rememberedAccount.storageKey) ?? '';

  Future<void> setRememberedAccount(String account) async {
    final key = GlobalCacheKey.rememberedAccount.storageKey;
    if (account.trim().isEmpty) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, account.trim());
    }
  }

  bool get isDarkMode =>
      _prefs.getBool(GlobalCacheKey.darkMode.storageKey) ?? false;

  Future<void> setDarkMode(bool value) =>
      _prefs.setBool(GlobalCacheKey.darkMode.storageKey, value);

  String get themeHex =>
      _prefs.getString(GlobalCacheKey.themeHex.storageKey) ?? '#67C6FF';

  String get themeName =>
      _prefs.getString(GlobalCacheKey.themeName.storageKey) ?? '天青漫画';

  Future<void> setThemeColor({
    required String hex,
    required String name,
  }) async {
    await _prefs.setString(GlobalCacheKey.themeHex.storageKey, hex);
    await _prefs.setString(GlobalCacheKey.themeName.storageKey, name);
  }

  String? get customApiBaseUrl {
    final v = _prefs.getString(GlobalCacheKey.customApiBaseUrl.storageKey);
    return (v != null && v.trim().isNotEmpty) ? v.trim() : null;
  }

  Future<void> setCustomApiBaseUrl(String? url) async {
    final key = GlobalCacheKey.customApiBaseUrl.storageKey;
    if (url == null || url.trim().isEmpty) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, url.trim());
    }
  }

  // ==================== 3. 学习进度与课堂记录 (learning) ====================

  List<int> get guestPassedIds {
    final raw = _prefs.getStringList(GlobalCacheKey.guestPassedIds.storageKey);
    if (raw == null) return <int>[];
    return raw.map(int.tryParse).whereType<int>().toSet().toList()..sort();
  }

  Future<List<int>> saveGuestPassedIds(List<int> ids) async {
    final unique = ids.toSet().toList()..sort();
    await _prefs.setStringList(
      GlobalCacheKey.guestPassedIds.storageKey,
      unique.map((e) => e.toString()).toList(),
    );
    return unique;
  }

  Future<void> clearGuestPassedIds() =>
      _prefs.remove(GlobalCacheKey.guestPassedIds.storageKey);

  /// 获取全部视频系列上次观看小节映射 (`seriesId -> lessonId`)
  Map<int, int> get lastWatchedVideoLessons {
    final raw =
        _prefs.getString(GlobalCacheKey.lastWatchedVideoLessons.storageKey);
    if (raw == null || raw.isEmpty) return <int, int>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final result = <int, int>{};
        decoded.forEach((k, v) {
          final seriesId = int.tryParse(k.toString());
          final lessonId = v is int ? v : int.tryParse(v.toString());
          if (seriesId != null &&
              seriesId > 0 &&
              lessonId != null &&
              lessonId > 0) {
            result[seriesId] = lessonId;
          }
        });
        return result;
      }
    } catch (_) {
      // 忽略格式异常缓存
    }
    return <int, int>{};
  }

  /// 读取指定课程系列上次观看的小节 ID（无缓存时返回 null，由视频详情页默认选中第 1 小节）
  int? getLastVideoLessonId(int seriesId) {
    if (seriesId <= 0) return null;
    return lastWatchedVideoLessons[seriesId];
  }

  /// 记录指定课程系列当前观看的小节 ID
  Future<void> setLastVideoLessonId(int seriesId, int lessonId) async {
    if (seriesId <= 0 || lessonId <= 0) return;
    final current = lastWatchedVideoLessons;
    if (current[seriesId] == lessonId) return;
    current[seriesId] = lessonId;
    final encoded = jsonEncode({
      for (final entry in current.entries) entry.key.toString(): entry.value,
    });
    await _prefs.setString(
      GlobalCacheKey.lastWatchedVideoLessons.storageKey,
      encoded,
    );
  }

  // ==================== 4. 版本生命周期与公告弹窗 (lifecycle) ====================

  String get lastAnnouncementVersion =>
      _prefs.getString(GlobalCacheKey.lastAnnouncementVersion.storageKey) ?? '';

  /// 判断当前 App 版本是否需要自动弹出一次修炼公告。
  /// 当本地无记录，或 App 已升级至新版本（`<version>+<versionCode>` 变化）时返回 true。
  bool shouldAutoShowAnnouncement(String appVersionKey) {
    final normalized = appVersionKey.trim();
    if (normalized.isEmpty) return false;
    return lastAnnouncementVersion != normalized;
  }

  /// 标记当前 App 版本的修炼公告已自动弹出过一次
  Future<void> markAnnouncementShown(String appVersionKey) async {
    final normalized = appVersionKey.trim();
    if (normalized.isEmpty) return;
    await _prefs.setString(
      GlobalCacheKey.lastAnnouncementVersion.storageKey,
      normalized,
    );
  }

  String get lastInstalledAppVersion =>
      _prefs.getString(GlobalCacheKey.lastInstalledAppVersion.storageKey) ?? '';

  /// 同步当前运行的 App 版本号；版本升级时严格保留登录态与偏好缓存，不清除 Token。
  /// 若检测到版本变化，返回 true。
  Future<bool> syncInstalledAppVersion(String appVersionKey) async {
    final normalized = appVersionKey.trim();
    if (normalized.isEmpty) return false;
    final previous = lastInstalledAppVersion;
    if (previous == normalized) return false;
    await _prefs.setString(
      GlobalCacheKey.lastInstalledAppVersion.storageKey,
      normalized,
    );
    return previous.isNotEmpty;
  }

  // ==================== 5. 智能手写画板偏好与草稿 (preference / temporary) ====================

  Map<String, dynamic> get smartBoardPrefs {
    final raw = _prefs.getString(GlobalCacheKey.smartBoardPrefs.storageKey);
    if (raw == null || raw.isEmpty) return const <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // 忽略损坏的偏好缓存
    }
    return const <String, dynamic>{};
  }

  Future<void> setSmartBoardPrefs(Map<String, dynamic> prefs) async {
    await _prefs.setString(
      GlobalCacheKey.smartBoardPrefs.storageKey,
      jsonEncode(prefs),
    );
  }

  Map<String, dynamic>? get smartBoardDraft {
    final raw = _prefs.getString(GlobalCacheKey.smartBoardDraft.storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // 忽略损坏草稿
    }
    return null;
  }

  Future<void> setSmartBoardDraft(Map<String, dynamic>? draft) async {
    final key = GlobalCacheKey.smartBoardDraft.storageKey;
    if (draft == null || draft.isEmpty) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, jsonEncode(draft));
    }
  }

  // ==================== 6. 缓存统计、快照与安全清理 ====================

  /// 导出全局缓存对象当前状态摘要（已对 Token 脱敏，便于调试排查）
  Map<String, Object?> snapshot() {
    return <String, Object?>{
      'hasAccessToken': accessToken.isNotEmpty,
      'hasCachedProfile': cachedProfile != null,
      'rememberedAccount': rememberedAccount,
      'guestPassedCount': guestPassedIds.length,
      'isDarkMode': isDarkMode,
      'themeHex': themeHex,
      'themeName': themeName,
      'customApiBaseUrl': customApiBaseUrl,
      'lastWatchedVideoLessons': lastWatchedVideoLessons,
      'lastAnnouncementVersion': lastAnnouncementVersion,
      'lastInstalledAppVersion': lastInstalledAppVersion,
      'hasSmartBoardDraft': smartBoardDraft != null,
      'smartBoardPrefs': smartBoardPrefs,
    };
  }

  int estimateCacheBytes() {
    var total = 0;
    for (final key in _prefs.getKeys()) {
      final value = _prefs.get(key);
      total += key.length * 2;
      if (value is String) {
        total += value.length * 2;
      } else if (value is List<String>) {
        for (final item in value) {
          total += item.length * 2;
        }
      } else {
        total += 8;
      }
    }
    return total;
  }

  /// 清理非保留临时缓存（严格保护登录凭证、用户偏好、学习进度与版本公告记录）
  Future<void> clearTemporaryCache() async {
    for (final key in _prefs.getKeys().toList()) {
      if (!_preservedOnCacheClearKeys.contains(key)) {
        await _prefs.remove(key);
      }
    }
  }
}

/// 便捷全局缓存对象访问器（等价于 [GlobalCache.instance]）
GlobalCache get globalCache => GlobalCache.instance;
