import 'dart:convert';
import 'dart:typed_data';

int _asInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

int? _asNullableInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

bool _asBool(dynamic v, [bool fallback = false]) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().toLowerCase();
  if (s == 'true' || s == '1') return true;
  if (s == 'false' || s == '0') return false;
  return fallback;
}

String _asString(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  return v.toString();
}

String? _asNullableString(dynamic v) {
  if (v == null) return null;
  return v.toString();
}

List<String> _asStringList(dynamic v) {
  if (v is List) {
    return v.map((e) => e?.toString() ?? '').toList();
  }
  return const [];
}

class PageResult<T> {
  const PageResult({
    required this.total,
    required this.pageNum,
    required this.pageSize,
    required this.records,
  });

  final int total;
  final int pageNum;
  final int pageSize;
  final List<T> records;

  factory PageResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemParser,
  ) {
    final rawList = json['records'] as List<dynamic>? ?? const [];
    return PageResult<T>(
      total: _asInt(json['total']),
      pageNum: _asInt(json['pageNum'], 1),
      pageSize: _asInt(json['pageSize'], 10),
      records: rawList
          .whereType<Map<String, dynamic>>()
          .map(itemParser)
          .toList(),
    );
  }
}

class LevelProgress {
  const LevelProgress({
    required this.levelId,
    required this.icon,
    required this.levelName,
    required this.quote,
    required this.minGates,
    this.nextMinGates,
    this.nextIcon,
    this.nextLevelName,
  });

  final int levelId;
  final String icon;
  final String levelName;
  final String quote;
  final int minGates;
  final int? nextMinGates;
  final String? nextIcon;
  final String? nextLevelName;

  factory LevelProgress.fromJson(Map<String, dynamic> json) {
    return LevelProgress(
      levelId: _asInt(json['levelId']),
      icon: _asString(json['icon']),
      levelName: _asString(json['levelName']),
      quote: _asString(json['quote']),
      minGates: _asInt(json['minGates']),
      nextMinGates: _asNullableInt(json['nextMinGates']),
      nextIcon: _asNullableString(json['nextIcon']),
      nextLevelName: _asNullableString(json['nextLevelName']),
    );
  }

  Map<String, dynamic> toJson() => {
        'levelId': levelId,
        'icon': icon,
        'levelName': levelName,
        'quote': quote,
        'minGates': minGates,
        'nextMinGates': nextMinGates,
        'nextIcon': nextIcon,
        'nextLevelName': nextLevelName,
      };
}

class RealmItem {
  const RealmItem({
    required this.realmCode,
    required this.realmName,
    required this.realmOrder,
    required this.gradeCode,
    required this.difficultyLabel,
    required this.description,
    required this.unlockGates,
    required this.examQuestionCount,
    required this.examPassScore,
    required this.chapterCount,
    required this.gateCount,
    required this.passedGateCount,
    required this.unlocked,
    required this.isCurrent,
    required this.isLower,
    required this.isHigher,
    required this.examEligible,
    required this.examRemainingGates,
  });

  final String realmCode;
  final String realmName;
  final int realmOrder;
  final String gradeCode;
  final String difficultyLabel;
  final String description;
  final int unlockGates;
  final int examQuestionCount;
  final int examPassScore;
  final int chapterCount;
  final int gateCount;
  final int passedGateCount;
  final bool unlocked;
  final bool isCurrent;
  final bool isLower;
  final bool isHigher;
  final bool examEligible;
  final int examRemainingGates;

  factory RealmItem.fromJson(Map<String, dynamic> json) {
    return RealmItem(
      realmCode: _asString(json['realmCode'], 'lianqi'),
      realmName: _asString(json['realmName'], '初一'),
      realmOrder: _asInt(json['realmOrder'], 1),
      gradeCode: _asString(json['gradeCode'], 'g7'),
      difficultyLabel: _asString(json['difficultyLabel']),
      description: _asString(json['description']),
      unlockGates: _asInt(json['unlockGates']),
      examQuestionCount: _asInt(json['examQuestionCount'], 5),
      examPassScore: _asInt(json['examPassScore'], 60),
      chapterCount: _asInt(json['chapterCount']),
      gateCount: _asInt(json['gateCount']),
      passedGateCount: _asInt(json['passedGateCount']),
      unlocked: _asBool(json['unlocked'], true),
      isCurrent: _asBool(json['isCurrent']),
      isLower: _asBool(json['isLower']),
      isHigher: _asBool(json['isHigher']),
      examEligible: _asBool(json['examEligible']),
      examRemainingGates: _asInt(json['examRemainingGates']),
    );
  }

  static const List<RealmItem> defaults = <RealmItem>[
    RealmItem(
      realmCode: 'lianqi',
      realmName: '初一',
      realmOrder: 1,
      gradeCode: 'g7',
      difficultyLabel: '难度一 · 基础',
      description: '初一数学基础巩固',
      unlockGates: 0,
      examQuestionCount: 5,
      examPassScore: 60,
      chapterCount: 10,
      gateCount: 40,
      passedGateCount: 0,
      unlocked: true,
      isCurrent: true,
      isLower: false,
      isHigher: false,
      examEligible: false,
      examRemainingGates: 40,
    ),
    RealmItem(
      realmCode: 'zhuji',
      realmName: '初二',
      realmOrder: 2,
      gradeCode: 'g8',
      difficultyLabel: '难度二 · 入门',
      description: '初二数学核心夯实',
      unlockGates: 0,
      examQuestionCount: 5,
      examPassScore: 60,
      chapterCount: 10,
      gateCount: 40,
      passedGateCount: 0,
      unlocked: true,
      isCurrent: false,
      isLower: false,
      isHigher: true,
      examEligible: false,
      examRemainingGates: 40,
    ),
    RealmItem(
      realmCode: 'jiedan',
      realmName: '初三',
      realmOrder: 3,
      gradeCode: 'g9',
      difficultyLabel: '难度三 · 提升',
      description: '初三数学综合进阶',
      unlockGates: 0,
      examQuestionCount: 6,
      examPassScore: 70,
      chapterCount: 9,
      gateCount: 36,
      passedGateCount: 0,
      unlocked: true,
      isCurrent: false,
      isLower: false,
      isHigher: true,
      examEligible: false,
      examRemainingGates: 36,
    ),
    RealmItem(
      realmCode: 'jiaying',
      realmName: '高一',
      realmOrder: 4,
      gradeCode: 'h1',
      difficultyLabel: '难度四 · 强化',
      description: '高一数学思维强化',
      unlockGates: 0,
      examQuestionCount: 6,
      examPassScore: 70,
      chapterCount: 10,
      gateCount: 40,
      passedGateCount: 0,
      unlocked: true,
      isCurrent: false,
      isLower: false,
      isHigher: true,
      examEligible: false,
      examRemainingGates: 40,
    ),
    RealmItem(
      realmCode: 'yuanying',
      realmName: '高二',
      realmOrder: 5,
      gradeCode: 'h2',
      difficultyLabel: '难度五 · 高阶',
      description: '高二数学高阶突破',
      unlockGates: 0,
      examQuestionCount: 8,
      examPassScore: 75,
      chapterCount: 8,
      gateCount: 32,
      passedGateCount: 0,
      unlocked: true,
      isCurrent: false,
      isLower: false,
      isHigher: true,
      examEligible: false,
      examRemainingGates: 32,
    ),
    RealmItem(
      realmCode: 'huashen',
      realmName: '高三',
      realmOrder: 6,
      gradeCode: 'h3',
      difficultyLabel: '难度六 · 冲刺',
      description: '高三综合专题冲刺',
      unlockGates: 0,
      examQuestionCount: 8,
      examPassScore: 80,
      chapterCount: 4,
      gateCount: 16,
      passedGateCount: 0,
      unlocked: true,
      isCurrent: false,
      isLower: false,
      isHigher: true,
      examEligible: false,
      examRemainingGates: 16,
    ),
  ];
}

class AppUserProfile {
  const AppUserProfile({
    required this.id,
    required this.username,
    this.phone = '',
    this.email = '',
    required this.nickname,
    required this.avatarUrl,
    required this.gradeCode,
    required this.gradeName,
    required this.realmCode,
    required this.realmName,
    required this.realmOrder,
    required this.difficultyLabel,
    this.nextRealmCode,
    this.nextRealmName,
    required this.realmPassedGates,
    required this.realmTotalGates,
    required this.examUnlockGates,
    required this.examRemainingGates,
    required this.examEligible,
    required this.examQuestionCount,
    required this.examPassScore,
    required this.passedGateCount,
    this.level,
  });

  final int id;
  final String username;
  final String phone;
  final String email;
  final String nickname;
  final String avatarUrl;
  final String gradeCode;
  final String gradeName;
  final String realmCode;
  final String realmName;
  final int realmOrder;
  final String difficultyLabel;
  final String? nextRealmCode;
  final String? nextRealmName;
  final int realmPassedGates;
  final int realmTotalGates;
  final int examUnlockGates;
  final int examRemainingGates;
  final bool examEligible;
  final int examQuestionCount;
  final int examPassScore;
  final int passedGateCount;
  final LevelProgress? level;

  factory AppUserProfile.fromJson(Map<String, dynamic> json) {
    return AppUserProfile(
      id: _asInt(json['id']),
      username: _asString(json['username']),
      phone: _asString(json['phone']),
      email: _asString(json['email']),
      nickname: _asString(json['nickname']),
      avatarUrl: _asString(json['avatarUrl']),
      gradeCode: _asString(json['gradeCode'], 'g7'),
      gradeName: _asString(json['gradeName']),
      realmCode: _asString(json['realmCode'], 'lianqi'),
      realmName: _asString(json['realmName'], '初一'),
      realmOrder: _asInt(json['realmOrder'], 1),
      difficultyLabel: _asString(json['difficultyLabel']),
      nextRealmCode: _asNullableString(json['nextRealmCode']),
      nextRealmName: _asNullableString(json['nextRealmName']),
      realmPassedGates: _asInt(json['realmPassedGates']),
      realmTotalGates: _asInt(json['realmTotalGates']),
      examUnlockGates: _asInt(json['examUnlockGates']),
      examRemainingGates: _asInt(json['examRemainingGates']),
      examEligible: _asBool(json['examEligible']),
      examQuestionCount: _asInt(json['examQuestionCount'], 5),
      examPassScore: _asInt(json['examPassScore'], 60),
      passedGateCount: _asInt(json['passedGateCount']),
      level: json['level'] is Map<String, dynamic>
          ? LevelProgress.fromJson(json['level'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'phone': phone,
        'email': email,
        'nickname': nickname,
        'avatarUrl': avatarUrl,
        'gradeCode': gradeCode,
        'gradeName': gradeName,
        'realmCode': realmCode,
        'realmName': realmName,
        'realmOrder': realmOrder,
        'difficultyLabel': difficultyLabel,
        'nextRealmCode': nextRealmCode,
        'nextRealmName': nextRealmName,
        'realmPassedGates': realmPassedGates,
        'realmTotalGates': realmTotalGates,
        'examUnlockGates': examUnlockGates,
        'examRemainingGates': examRemainingGates,
        'examEligible': examEligible,
        'examQuestionCount': examQuestionCount,
        'examPassScore': examPassScore,
        'passedGateCount': passedGateCount,
        'level': level?.toJson(),
      };
}

class AuthResult {
  const AuthResult({required this.token, required this.profile});

  final String token;
  final AppUserProfile profile;

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      token: _asString(json['token']),
      profile: AppUserProfile.fromJson(
        (json['profile'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }
}

class CaptchaChallenge {
  const CaptchaChallenge({
    required this.captchaKey,
    required this.imageBase64,
    this.expireSeconds = 300,
  });

  final String captchaKey;
  final String imageBase64;
  final int expireSeconds;

  Uint8List? decodeBytes() {
    final raw = imageBase64.trim();
    if (raw.isEmpty) return null;
    try {
      final commaIdx = raw.indexOf(',');
      final payload = commaIdx >= 0 ? raw.substring(commaIdx + 1) : raw;
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }

  factory CaptchaChallenge.fromJson(Map<String, dynamic> json) {
    return CaptchaChallenge(
      captchaKey: _asString(json['captchaKey']),
      imageBase64: _asString(json['imageBase64']),
      expireSeconds: _asInt(json['expireSeconds'], 300),
    );
  }
}

class GradeItem {
  const GradeItem({
    required this.gradeCode,
    required this.gradeName,
    required this.icon,
    required this.chapterCount,
  });

  final String gradeCode;
  final String gradeName;
  final String icon;
  final int chapterCount;

  factory GradeItem.fromJson(Map<String, dynamic> json) {
    return GradeItem(
      gradeCode: _asString(json['gradeCode']),
      gradeName: _asString(json['gradeName']),
      icon: _asString(json['icon']),
      chapterCount: _asInt(json['chapterCount']),
    );
  }

  static const List<GradeItem> fallbacks = <GradeItem>[
    GradeItem(gradeCode: 'g7', gradeName: '初一', icon: '🌱', chapterCount: 10),
    GradeItem(gradeCode: 'g8', gradeName: '初二', icon: '🌿', chapterCount: 10),
    GradeItem(gradeCode: 'g9', gradeName: '初三', icon: '🌳', chapterCount: 9),
    GradeItem(gradeCode: 'h1', gradeName: '高一', icon: '🍃', chapterCount: 10),
    GradeItem(gradeCode: 'h2', gradeName: '高二', icon: '🌲', chapterCount: 8),
    GradeItem(gradeCode: 'h3', gradeName: '高三', icon: '🎯', chapterCount: 4),
  ];
}

class AppDefaultTheme {
  const AppDefaultTheme({
    required this.uiSkin,
    required this.themeHex,
    required this.themeName,
    required this.darkMode,
    required this.version,
  });

  final String uiSkin;
  final String themeHex;
  final String themeName;
  final bool darkMode;
  final String version;

  factory AppDefaultTheme.fromJson(Map<String, dynamic> json) {
    return AppDefaultTheme(
      uiSkin: _asString(json['uiSkin'], 'welkui').toLowerCase(),
      themeHex: _asString(json['themeHex'], '#67C6FF').toUpperCase(),
      themeName: _asString(json['themeName'], '天青漫画'),
      darkMode: _asBool(json['darkMode']),
      version: _asString(json['version'], '1'),
    );
  }

  Map<String, dynamic> toJson() => {
        'uiSkin': uiSkin,
        'themeHex': themeHex,
        'themeName': themeName,
        'darkMode': darkMode,
        'version': version,
      };
}

class HomeBannerItem {
  const HomeBannerItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageKey,
    required this.imageUrl,
    this.sortOrder = 0,
    this.enabled = 1,
    this.hasDetailContent = true,
    this.updatedAt = '',
  });

  final int id;
  final String title;
  final String subtitle;
  final String imageKey;
  final String imageUrl;
  final int sortOrder;
  final int enabled;
  final bool hasDetailContent;
  final String updatedAt;

  factory HomeBannerItem.fromJson(Map<String, dynamic> json) {
    return HomeBannerItem(
      id: _asInt(json['id']),
      title: _asString(json['title']),
      subtitle: _asString(json['subtitle']),
      imageKey: _asString(json['imageKey']),
      imageUrl: _asString(json['imageUrl']),
      sortOrder: _asInt(json['sortOrder']),
      enabled: _asInt(json['enabled'], 1),
      hasDetailContent: _asBool(json['hasDetailContent'], true),
      updatedAt: _asString(json['updatedAt']),
    );
  }
}

class HomeBannerDetail {
  const HomeBannerDetail({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageKey,
    required this.imageUrl,
    required this.contentHtml,
    this.createdAt = '',
    this.updatedAt = '',
  });

  final int id;
  final String title;
  final String subtitle;
  final String imageKey;
  final String imageUrl;
  final String contentHtml;
  final String createdAt;
  final String updatedAt;

  factory HomeBannerDetail.fromJson(Map<String, dynamic> json) {
    return HomeBannerDetail(
      id: _asInt(json['id']),
      title: _asString(json['title']),
      subtitle: _asString(json['subtitle']),
      imageKey: _asString(json['imageKey']),
      imageUrl: _asString(json['imageUrl']),
      contentHtml: _asString(json['contentHtml']),
      createdAt: _asString(json['createdAt']),
      updatedAt: _asString(json['updatedAt']),
    );
  }
}

class HomeSummary {
  const HomeSummary({
    required this.guestModeEnabled,
    required this.appNotice,
    this.profile,
    this.defaultTheme,
    this.banners = const [],
    required this.grades,
    required this.realms,
  });

  final bool guestModeEnabled;
  final String appNotice;
  final AppUserProfile? profile;
  final AppDefaultTheme? defaultTheme;
  final List<HomeBannerItem> banners;
  final List<GradeItem> grades;
  final List<RealmItem> realms;

  factory HomeSummary.fromJson(Map<String, dynamic> json) {
    final gradesRaw = json['grades'] as List<dynamic>? ?? const [];
    final realmsRaw = json['realms'] as List<dynamic>? ?? const [];
    final bannersRaw = json['banners'] as List<dynamic>? ?? const [];
    return HomeSummary(
      guestModeEnabled: _asBool(json['guestModeEnabled'], true),
      appNotice: _asString(json['appNotice']),
      profile: json['profile'] is Map<String, dynamic>
          ? AppUserProfile.fromJson(json['profile'] as Map<String, dynamic>)
          : null,
      defaultTheme: json['defaultTheme'] is Map<String, dynamic>
          ? AppDefaultTheme.fromJson(
              json['defaultTheme'] as Map<String, dynamic>,
            )
          : null,
      banners: bannersRaw
          .whereType<Map<String, dynamic>>()
          .map(HomeBannerItem.fromJson)
          .toList(),
      grades: gradesRaw
          .whereType<Map<String, dynamic>>()
          .map(GradeItem.fromJson)
          .toList(),
      realms: realmsRaw
          .whereType<Map<String, dynamic>>()
          .map(RealmItem.fromJson)
          .toList(),
    );
  }
}

class ChapterCard {
  const ChapterCard({
    required this.id,
    required this.chapterCode,
    required this.gradeCode,
    required this.realmCode,
    required this.realmName,
    required this.realmOrder,
    required this.name,
    required this.description,
    required this.isCustom,
    required this.passedCount,
    required this.totalGates,
    required this.lockedByRealm,
    required this.suppressed,
  });

  final int id;
  final String chapterCode;
  final String gradeCode;
  final String realmCode;
  final String realmName;
  final int realmOrder;
  final String name;
  final String description;
  final int isCustom;
  final int passedCount;
  final int totalGates;
  final bool lockedByRealm;
  final bool suppressed;

  factory ChapterCard.fromJson(Map<String, dynamic> json) {
    return ChapterCard(
      id: _asInt(json['id']),
      chapterCode: _asString(json['chapterCode']),
      gradeCode: _asString(json['gradeCode']),
      realmCode: _asString(json['realmCode']),
      realmName: _asString(json['realmName']),
      realmOrder: _asInt(json['realmOrder'], 1),
      name: _asString(json['name']),
      description: _asString(json['description']),
      isCustom: _asInt(json['isCustom']),
      passedCount: _asInt(json['passedCount']),
      totalGates: _asInt(json['totalGates'], 4),
      lockedByRealm: _asBool(json['lockedByRealm']),
      suppressed: _asBool(json['suppressed']),
    );
  }
}

class GateCard {
  const GateCard({
    required this.id,
    required this.chapterId,
    required this.gateIndex,
    required this.gateName,
    required this.star,
    required this.questionCount,
    required this.passCount,
    required this.passed,
    required this.locked,
    required this.lockedByRealm,
    required this.suppressed,
    required this.empty,
  });

  final int id;
  final int chapterId;
  final int gateIndex;
  final String gateName;
  final int star;
  final int questionCount;
  final int passCount;
  final bool passed;
  final bool locked;
  final bool lockedByRealm;
  final bool suppressed;
  final bool empty;

  factory GateCard.fromJson(Map<String, dynamic> json) {
    return GateCard(
      id: _asInt(json['id']),
      chapterId: _asInt(json['chapterId']),
      gateIndex: _asInt(json['gateIndex']),
      gateName: _asString(json['gateName']),
      star: _asInt(json['star'], 1),
      questionCount: _asInt(json['questionCount']),
      passCount: _asInt(json['passCount']),
      passed: _asBool(json['passed']),
      locked: _asBool(json['locked']),
      lockedByRealm: _asBool(json['lockedByRealm']),
      suppressed: _asBool(json['suppressed']),
      empty: _asBool(json['empty']),
    );
  }
}

class ClientQuestionItem {
  const ClientQuestionItem({
    required this.itemIndex,
    required this.questionFormat,
    required this.stem,
    required this.options,
    this.diagram,
    this.imageUrl,
  });

  final int itemIndex;
  final String questionFormat;
  final String stem;
  final List<String> options;
  final BoardDiagramSpec? diagram;
  final String? imageUrl;

  bool get isEssay => questionFormat == 'ESSAY';
  bool get hasFigure =>
      (diagram != null && diagram!.primitives.isNotEmpty) ||
      (imageUrl != null && imageUrl!.trim().isNotEmpty);

  factory ClientQuestionItem.fromJson(Map<String, dynamic> json) {
    return ClientQuestionItem(
      itemIndex: _asInt(json['itemIndex']),
      questionFormat: _asString(json['questionFormat'], 'SINGLE_CHOICE'),
      stem: _asString(json['stem']),
      options: _asStringList(json['options']),
      diagram: json['diagram'] is Map<String, dynamic>
          ? BoardDiagramSpec.fromJson(json['diagram'] as Map<String, dynamic>)
          : null,
      imageUrl: _asNullableString(json['imageUrl']),
    );
  }
}

class QuizStartResult {
  const QuizStartResult({
    required this.sessionNo,
    required this.mode,
    this.realmCode,
    this.realmName,
    this.realmOrder,
    required this.suppressedMode,
    this.passScore,
    this.chapterId,
    required this.chapterName,
    this.gateId,
    required this.gateName,
    this.star,
    required this.passCount,
    required this.totalCount,
    required this.guestMode,
    required this.items,
  });

  final String sessionNo;
  final String mode;
  final String? realmCode;
  final String? realmName;
  final int? realmOrder;
  final bool suppressedMode;
  final int? passScore;
  final int? chapterId;
  final String chapterName;
  final int? gateId;
  final String gateName;
  final int? star;
  final int passCount;
  final int totalCount;
  final bool guestMode;
  final List<ClientQuestionItem> items;

  factory QuizStartResult.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] as List<dynamic>? ?? const [];
    return QuizStartResult(
      sessionNo: _asString(json['sessionNo']),
      mode: _asString(json['mode'], 'GATE'),
      realmCode: _asNullableString(json['realmCode']),
      realmName: _asNullableString(json['realmName']),
      realmOrder: _asNullableInt(json['realmOrder']),
      suppressedMode: _asBool(json['suppressedMode']),
      passScore: _asNullableInt(json['passScore']),
      chapterId: _asNullableInt(json['chapterId']),
      chapterName: _asString(json['chapterName']),
      gateId: _asNullableInt(json['gateId']),
      gateName: _asString(json['gateName']),
      star: _asNullableInt(json['star']),
      passCount: _asInt(json['passCount']),
      totalCount: _asInt(json['totalCount']),
      guestMode: _asBool(json['guestMode']),
      items: itemsRaw
          .whereType<Map<String, dynamic>>()
          .map(ClientQuestionItem.fromJson)
          .toList(),
    );
  }
}

class CheckItemResult {
  const CheckItemResult({
    required this.itemIndex,
    this.questionFormat,
    required this.correct,
    required this.correctIndex,
    this.referenceAnswer,
    this.answerText,
    this.answerImageUrl,
    this.selfCorrect,
    required this.pendingReview,
    required this.analysis,
  });

  final int itemIndex;
  final String? questionFormat;
  final bool correct;
  final int correctIndex;
  final String? referenceAnswer;
  final String? answerText;
  final String? answerImageUrl;
  final bool? selfCorrect;
  final bool pendingReview;
  final String analysis;

  factory CheckItemResult.fromJson(Map<String, dynamic> json) {
    return CheckItemResult(
      itemIndex: _asInt(json['itemIndex']),
      questionFormat: _asNullableString(json['questionFormat']),
      correct: _asBool(json['correct']),
      correctIndex: _asInt(json['correctIndex'], -1),
      referenceAnswer: _asNullableString(json['referenceAnswer']),
      answerText: _asNullableString(json['answerText']),
      answerImageUrl: _asNullableString(json['answerImageUrl']),
      selfCorrect: json['selfCorrect'] is bool
          ? json['selfCorrect'] as bool
          : null,
      pendingReview: _asBool(json['pendingReview']),
      analysis: _asString(json['analysis']),
    );
  }
}

class UploadAnswerImageResult {
  const UploadAnswerImageResult({
    required this.objectKey,
    required this.previewUrl,
    required this.storageType,
  });

  final String objectKey;
  final String previewUrl;
  final String storageType;

  factory UploadAnswerImageResult.fromJson(Map<String, dynamic> json) {
    return UploadAnswerImageResult(
      objectKey: _asString(json['objectKey']),
      previewUrl: _asString(json['previewUrl']),
      storageType: _asString(json['storageType']),
    );
  }
}

class EssayAnswerRecord {
  const EssayAnswerRecord({
    required this.id,
    required this.sessionNo,
    required this.itemIndex,
    this.realmCode,
    required this.realmName,
    required this.chapterName,
    this.gateId,
    required this.gateName,
    required this.stem,
    this.diagram,
    this.imageUrl,
    required this.referenceAnswer,
    required this.answerText,
    required this.answerImageUrl,
    this.selfCorrect,
    required this.teacherStatus,
    required this.teacherComment,
    this.teacherImageUrl,
    required this.createdAt,
    this.reviewedAt,
  });

  final int id;
  final String sessionNo;
  final int itemIndex;
  final String? realmCode;
  final String realmName;
  final String chapterName;
  final int? gateId;
  final String gateName;
  final String stem;
  final BoardDiagramSpec? diagram;
  final String? imageUrl;
  final String referenceAnswer;
  final String answerText;
  final String answerImageUrl;
  final int? selfCorrect;
  final int teacherStatus;
  final String teacherComment;
  final String? teacherImageUrl;
  final String createdAt;
  final String? reviewedAt;

  factory EssayAnswerRecord.fromJson(Map<String, dynamic> json) {
    return EssayAnswerRecord(
      id: _asInt(json['id']),
      sessionNo: _asString(json['sessionNo']),
      itemIndex: _asInt(json['itemIndex']),
      realmCode: _asNullableString(json['realmCode']),
      realmName: _asString(json['realmName']),
      chapterName: _asString(json['chapterName']),
      gateId: _asNullableInt(json['gateId']),
      gateName: _asString(json['gateName']),
      stem: _asString(json['stem']),
      diagram: json['diagram'] is Map<String, dynamic>
          ? BoardDiagramSpec.fromJson(json['diagram'] as Map<String, dynamic>)
          : null,
      imageUrl: _asNullableString(json['imageUrl']),
      referenceAnswer: _asString(json['referenceAnswer']),
      answerText: _asString(json['answerText']),
      answerImageUrl: _asString(json['answerImageUrl']),
      selfCorrect: _asNullableInt(json['selfCorrect']),
      teacherStatus: _asInt(json['teacherStatus']),
      teacherComment: _asString(json['teacherComment']),
      teacherImageUrl: _asNullableString(json['teacherImageUrl']),
      createdAt: _asString(json['createdAt']),
      reviewedAt: _asNullableString(json['reviewedAt']),
    );
  }
}

class VideoSeriesItem {
  const VideoSeriesItem({
    required this.id,
    required this.title,
    required this.coverImageKey,
    required this.coverImageUrl,
    required this.intro,
    required this.realmCode,
    required this.realmName,
    required this.sortOrder,
    required this.enabled,
    required this.lessonCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String title;
  final String coverImageKey;
  final String coverImageUrl;
  final String intro;
  final String realmCode;
  final String realmName;
  final int sortOrder;
  final int enabled;
  final int lessonCount;
  final String createdAt;
  final String updatedAt;

  factory VideoSeriesItem.fromJson(Map<String, dynamic> json) {
    return VideoSeriesItem(
      id: _asInt(json['id']),
      title: _asString(json['title']),
      coverImageKey: _asString(json['coverImageKey']),
      coverImageUrl: _asString(json['coverImageUrl']),
      intro: _asString(json['intro']),
      realmCode: _asString(json['realmCode']),
      realmName: _asString(json['realmName']),
      sortOrder: _asInt(json['sortOrder']),
      enabled: _asInt(json['enabled'], 1),
      lessonCount: _asInt(json['lessonCount']),
      createdAt: _asString(json['createdAt']),
      updatedAt: _asString(json['updatedAt']),
    );
  }
}

class NoteAttachmentItem {
  const NoteAttachmentItem({
    required this.name,
    required this.objectKey,
    required this.url,
    required this.size,
    required this.contentType,
  });

  final String name;
  final String objectKey;
  final String url;
  final int size;
  final String contentType;

  bool get isImage {
    final ct = contentType.toLowerCase();
    final lower = name.toLowerCase();
    return ct.startsWith('image/') ||
        lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  factory NoteAttachmentItem.fromJson(Map<String, dynamic> json) {
    return NoteAttachmentItem(
      name: _asString(json['name']),
      objectKey: _asString(json['objectKey']),
      url: _asString(json['url']),
      size: _asInt(json['size']),
      contentType: _asString(json['contentType']),
    );
  }
}

class VideoLessonItem {
  const VideoLessonItem({
    required this.id,
    required this.seriesId,
    required this.title,
    this.coverImageKey,
    this.coverImageUrl,
    required this.videoKey,
    required this.videoUrl,
    required this.durationSec,
    required this.classNotes,
    required this.notesAttachments,
    required this.sortOrder,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int seriesId;
  final String title;
  final String? coverImageKey;
  final String? coverImageUrl;
  final String videoKey;
  final String videoUrl;
  final int durationSec;
  final String classNotes;
  final List<NoteAttachmentItem> notesAttachments;
  final int sortOrder;
  final int enabled;
  final String createdAt;
  final String updatedAt;

  bool get hasNotes =>
      classNotes.trim().isNotEmpty || notesAttachments.isNotEmpty;

  factory VideoLessonItem.fromJson(Map<String, dynamic> json) {
    final attRaw = json['notesAttachments'] as List<dynamic>? ?? const [];
    return VideoLessonItem(
      id: _asInt(json['id']),
      seriesId: _asInt(json['seriesId']),
      title: _asString(json['title']),
      coverImageKey: _asNullableString(json['coverImageKey']),
      coverImageUrl: _asNullableString(json['coverImageUrl']),
      videoKey: _asString(json['videoKey']),
      videoUrl: _asString(json['videoUrl']),
      durationSec: _asInt(json['durationSec']),
      classNotes: _asString(json['classNotes']),
      notesAttachments: attRaw
          .whereType<Map<String, dynamic>>()
          .map(NoteAttachmentItem.fromJson)
          .toList(),
      sortOrder: _asInt(json['sortOrder']),
      enabled: _asInt(json['enabled'], 1),
      createdAt: _asString(json['createdAt']),
      updatedAt: _asString(json['updatedAt']),
    );
  }
}

class VideoSeriesDetail {
  const VideoSeriesDetail({required this.series, required this.lessons});

  final VideoSeriesItem series;
  final List<VideoLessonItem> lessons;

  factory VideoSeriesDetail.fromJson(Map<String, dynamic> json) {
    final lessonsRaw = json['lessons'] as List<dynamic>? ?? const [];
    return VideoSeriesDetail(
      series: VideoSeriesItem.fromJson(
        (json['series'] as Map<String, dynamic>?) ?? const {},
      ),
      lessons: lessonsRaw
          .whereType<Map<String, dynamic>>()
          .map(VideoLessonItem.fromJson)
          .toList(),
    );
  }
}

class WrongReviewItem {
  const WrongReviewItem({
    required this.stem,
    this.questionFormat,
    required this.correctAnswer,
    required this.analysis,
    this.diagram,
    this.imageUrl,
  });

  final String stem;
  final String? questionFormat;
  final String correctAnswer;
  final String analysis;
  final BoardDiagramSpec? diagram;
  final String? imageUrl;

  factory WrongReviewItem.fromJson(Map<String, dynamic> json) {
    return WrongReviewItem(
      stem: _asString(json['stem']),
      questionFormat: _asNullableString(json['questionFormat']),
      correctAnswer: _asString(json['correctAnswer']),
      analysis: _asString(json['analysis']),
      diagram: json['diagram'] is Map<String, dynamic>
          ? BoardDiagramSpec.fromJson(json['diagram'] as Map<String, dynamic>)
          : null,
      imageUrl: _asNullableString(json['imageUrl']),
    );
  }
}

class SubmitResult {
  const SubmitResult({
    required this.sessionNo,
    required this.mode,
    required this.totalCount,
    required this.correctCount,
    this.pendingReviewCount,
    this.score,
    this.passScore,
    required this.passCount,
    required this.passed,
    required this.newlyPassed,
    required this.totalPassedGates,
    this.promotedLevel,
    this.promotedRealm,
    required this.wrongItems,
    required this.masteredCount,
    this.nextGateId,
    this.nextGateIndex,
    this.nextGateName,
    this.nextChapterId,
    this.nextChapterName,
    this.nextGateCrossChapter = false,
    this.nextGradeCode,
    this.nextGradeName,
    this.nextGateCrossGrade = false,
  });

  final String sessionNo;
  final String mode;
  final int totalCount;
  final int correctCount;
  final int? pendingReviewCount;
  final int? score;
  final int? passScore;
  final int passCount;
  final bool passed;
  final bool newlyPassed;
  final int totalPassedGates;
  final LevelProgress? promotedLevel;
  final RealmItem? promotedRealm;
  final List<WrongReviewItem> wrongItems;
  final int masteredCount;
  final int? nextGateId;
  final int? nextGateIndex;
  final String? nextGateName;
  final int? nextChapterId;
  final String? nextChapterName;
  final bool nextGateCrossChapter;
  final String? nextGradeCode;
  final String? nextGradeName;
  final bool nextGateCrossGrade;

  bool get hasNextGate => nextGateId != null && nextGateId! > 0;

  SubmitResult copyWithNextGate({
    int? nextGateId,
    int? nextGateIndex,
    String? nextGateName,
    int? nextChapterId,
    String? nextChapterName,
    bool? nextGateCrossChapter,
    String? nextGradeCode,
    String? nextGradeName,
    bool? nextGateCrossGrade,
  }) {
    return SubmitResult(
      sessionNo: sessionNo,
      mode: mode,
      totalCount: totalCount,
      correctCount: correctCount,
      pendingReviewCount: pendingReviewCount,
      score: score,
      passScore: passScore,
      passCount: passCount,
      passed: passed,
      newlyPassed: newlyPassed,
      totalPassedGates: totalPassedGates,
      promotedLevel: promotedLevel,
      promotedRealm: promotedRealm,
      wrongItems: wrongItems,
      masteredCount: masteredCount,
      nextGateId: nextGateId ?? this.nextGateId,
      nextGateIndex: nextGateIndex ?? this.nextGateIndex,
      nextGateName: nextGateName ?? this.nextGateName,
      nextChapterId: nextChapterId ?? this.nextChapterId,
      nextChapterName: nextChapterName ?? this.nextChapterName,
      nextGateCrossChapter: nextGateCrossChapter ?? this.nextGateCrossChapter,
      nextGradeCode: nextGradeCode ?? this.nextGradeCode,
      nextGradeName: nextGradeName ?? this.nextGradeName,
      nextGateCrossGrade: nextGateCrossGrade ?? this.nextGateCrossGrade,
    );
  }

  factory SubmitResult.fromJson(Map<String, dynamic> json) {
    final wrongsRaw = json['wrongItems'] as List<dynamic>? ?? const [];
    return SubmitResult(
      sessionNo: _asString(json['sessionNo']),
      mode: _asString(json['mode'], 'GATE'),
      totalCount: _asInt(json['totalCount']),
      correctCount: _asInt(json['correctCount']),
      pendingReviewCount: _asNullableInt(json['pendingReviewCount']),
      score: _asNullableInt(json['score']),
      passScore: _asNullableInt(json['passScore']),
      passCount: _asInt(json['passCount']),
      passed: _asBool(json['passed']),
      newlyPassed: _asBool(json['newlyPassed']),
      totalPassedGates: _asInt(json['totalPassedGates']),
      promotedLevel: json['promotedLevel'] is Map<String, dynamic>
          ? LevelProgress.fromJson(json['promotedLevel'] as Map<String, dynamic>)
          : null,
      promotedRealm: json['promotedRealm'] is Map<String, dynamic>
          ? RealmItem.fromJson(json['promotedRealm'] as Map<String, dynamic>)
          : null,
      wrongItems: wrongsRaw
          .whereType<Map<String, dynamic>>()
          .map(WrongReviewItem.fromJson)
          .toList(),
      masteredCount: _asInt(json['masteredCount']),
      nextGateId: _asNullableInt(json['nextGateId']),
      nextGateIndex: _asNullableInt(json['nextGateIndex']),
      nextGateName: _asNullableString(json['nextGateName']),
      nextChapterId: _asNullableInt(json['nextChapterId']),
      nextChapterName: _asNullableString(json['nextChapterName']),
      nextGateCrossChapter: _asBool(json['nextGateCrossChapter']),
      nextGradeCode: _asNullableString(json['nextGradeCode']),
      nextGradeName: _asNullableString(json['nextGradeName']),
      nextGateCrossGrade: _asBool(json['nextGateCrossGrade']),
    );
  }
}

class WrongQuestionItem {
  const WrongQuestionItem({
    required this.id,
    required this.gradeCode,
    required this.realmCode,
    required this.realmName,
    this.chapterId,
    required this.chapterName,
    required this.gateName,
    this.questionFormat,
    required this.stem,
    this.diagram,
    this.imageUrl,
    required this.options,
    required this.answerIndex,
    this.referenceAnswer,
    this.lastAnswerImageUrl,
    required this.analysis,
    required this.wrongCount,
    required this.lastWrongAt,
  });

  final int id;
  final String gradeCode;
  final String realmCode;
  final String realmName;
  final int? chapterId;
  final String chapterName;
  final String gateName;
  final String? questionFormat;
  final String stem;
  final BoardDiagramSpec? diagram;
  final String? imageUrl;
  final List<String> options;
  final int answerIndex;
  final String? referenceAnswer;
  final String? lastAnswerImageUrl;
  final String analysis;
  final int wrongCount;
  final String lastWrongAt;

  String formattedCorrectAnswer() {
    if (questionFormat == 'ESSAY') {
      return (referenceAnswer != null && referenceAnswer!.isNotEmpty)
          ? referenceAnswer!
          : '详见解析';
    }
    const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
    final letter =
        answerIndex >= 0 && answerIndex < letters.length
            ? letters[answerIndex]
            : '${answerIndex + 1}';
    final text =
        answerIndex >= 0 && answerIndex < options.length
            ? options[answerIndex]
            : '';
    return text.isNotEmpty ? '$letter. $text' : letter;
  }

  factory WrongQuestionItem.fromJson(Map<String, dynamic> json) {
    return WrongQuestionItem(
      id: _asInt(json['id']),
      gradeCode: _asString(json['gradeCode']),
      realmCode: _asString(json['realmCode']),
      realmName: _asString(json['realmName']),
      chapterId: _asNullableInt(json['chapterId']),
      chapterName: _asString(json['chapterName']),
      gateName: _asString(json['gateName']),
      questionFormat: _asNullableString(json['questionFormat']),
      stem: _asString(json['stem']),
      diagram: json['diagram'] is Map<String, dynamic>
          ? BoardDiagramSpec.fromJson(json['diagram'] as Map<String, dynamic>)
          : null,
      imageUrl: _asNullableString(json['imageUrl']),
      options: _asStringList(json['options']),
      answerIndex: _asInt(json['answerIndex']),
      referenceAnswer: _asNullableString(json['referenceAnswer']),
      lastAnswerImageUrl: _asNullableString(json['lastAnswerImageUrl']),
      analysis: _asString(json['analysis']),
      wrongCount: _asInt(json['wrongCount'], 1),
      lastWrongAt: _asString(json['lastWrongAt']),
    );
  }
}

class AnswerSubmitPayload {
  const AnswerSubmitPayload({
    required this.itemIndex,
    this.selectedIndex,
    this.answerText,
    this.answerImageKey,
    this.selfCorrect,
  });

  final int itemIndex;
  final int? selectedIndex;
  final String? answerText;
  final String? answerImageKey;
  final bool? selfCorrect;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'itemIndex': itemIndex};
    if (selectedIndex != null) map['selectedIndex'] = selectedIndex;
    if (answerText != null) map['answerText'] = answerText;
    if (answerImageKey != null) map['answerImageKey'] = answerImageKey;
    if (selfCorrect != null) map['selfCorrect'] = selfCorrect;
    return map;
  }
}

class AppVersionInfo {
  const AppVersionInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.latestVersionCode,
    required this.hasUpdate,
    required this.forceUpdate,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.githubReleaseUrl,
    required this.githubRepo,
    required this.githubReachable,
    required this.publishedAt,
    required this.source,
    this.downloadChannel = '',
    this.ossCustomDomain = '',
  });

  final String currentVersion;
  final String latestVersion;
  final int latestVersionCode;
  final bool hasUpdate;
  final bool forceUpdate;
  final String releaseNotes;
  final String downloadUrl;
  final String githubReleaseUrl;
  final String githubRepo;
  final bool githubReachable;
  final String publishedAt;
  final String source;
  final String downloadChannel;
  final String ossCustomDomain;

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      currentVersion: _asString(json['currentVersion']),
      latestVersion: _asString(json['latestVersion']),
      latestVersionCode: _asInt(json['latestVersionCode']),
      hasUpdate: _asBool(json['hasUpdate']),
      forceUpdate: _asBool(json['forceUpdate']),
      releaseNotes: _asString(json['releaseNotes']),
      downloadUrl: _asString(json['downloadUrl']),
      githubReleaseUrl: _asString(json['githubReleaseUrl']),
      githubRepo: _asString(json['githubRepo']),
      githubReachable: _asBool(json['githubReachable']),
      publishedAt: _asString(json['publishedAt']),
      source: _asString(json['source']),
      downloadChannel: _asString(json['downloadChannel']),
      ossCustomDomain: _asString(json['ossCustomDomain']),
    );
  }
}

double? _asNullableDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

double _asDouble(dynamic v, [double fallback = 0]) =>
    _asNullableDouble(v) ?? fallback;

class AiBoardStatus {
  const AiBoardStatus({
    required this.enabled,
    required this.configured,
    required this.modelName,
    required this.supportsVision,
    required this.message,
  });

  final bool enabled;
  final bool configured;
  final String modelName;
  final bool supportsVision;
  final String message;

  bool get ready => enabled && configured;

  factory AiBoardStatus.fromJson(Map<String, dynamic> json) {
    return AiBoardStatus(
      enabled: _asBool(json['enabled']),
      configured: _asBool(json['configured']),
      modelName: _asString(json['modelName']),
      supportsVision: _asBool(json['supportsVision']),
      message: _asString(json['message']),
    );
  }
}

class DiagramPrimitive {
  const DiagramPrimitive({
    required this.type,
    this.x1,
    this.y1,
    this.x2,
    this.y2,
    this.cx,
    this.cy,
    this.r,
    this.startAngle,
    this.sweepAngle,
    this.vx,
    this.vy,
    this.ax,
    this.ay,
    this.bx,
    this.by,
    this.size,
    this.x,
    this.y,
    this.points = const [],
    this.label,
    this.text,
    this.color = '#1E293B',
    this.fillColor,
    this.dashed = false,
  });

  final String type;
  final double? x1;
  final double? y1;
  final double? x2;
  final double? y2;
  final double? cx;
  final double? cy;
  final double? r;
  final double? startAngle;
  final double? sweepAngle;
  final double? vx;
  final double? vy;
  final double? ax;
  final double? ay;
  final double? bx;
  final double? by;
  final double? size;
  final double? x;
  final double? y;
  final List<List<double>> points;
  final String? label;
  final String? text;
  final String color;
  final String? fillColor;
  final bool dashed;

  factory DiagramPrimitive.fromJson(Map<String, dynamic> json) {
    final rawPts = json['points'] as List<dynamic>? ?? const [];
    final pts = <List<double>>[];
    for (final item in rawPts) {
      if (item is List && item.length >= 2) {
        final px = _asNullableDouble(item[0]);
        final py = _asNullableDouble(item[1]);
        if (px != null && py != null) {
          pts.add(<double>[px, py]);
        }
      }
    }
    return DiagramPrimitive(
      type: _asString(json['type']).toLowerCase(),
      x1: _asNullableDouble(json['x1']),
      y1: _asNullableDouble(json['y1']),
      x2: _asNullableDouble(json['x2']),
      y2: _asNullableDouble(json['y2']),
      cx: _asNullableDouble(json['cx']),
      cy: _asNullableDouble(json['cy']),
      r: _asNullableDouble(json['r']),
      startAngle: _asNullableDouble(json['startAngle']),
      sweepAngle: _asNullableDouble(json['sweepAngle']),
      vx: _asNullableDouble(json['vx']),
      vy: _asNullableDouble(json['vy']),
      ax: _asNullableDouble(json['ax']),
      ay: _asNullableDouble(json['ay']),
      bx: _asNullableDouble(json['bx']),
      by: _asNullableDouble(json['by']),
      size: _asNullableDouble(json['size']),
      x: _asNullableDouble(json['x']),
      y: _asNullableDouble(json['y']),
      points: pts,
      label: _asNullableString(json['label']),
      text: _asNullableString(json['text']),
      color: _asString(json['color'], '#1E293B'),
      fillColor: _asNullableString(json['fillColor']) ??
          _asNullableString(json['fill']),
      dashed: _asBool(json['dashed']),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        if (x1 != null) 'x1': x1,
        if (y1 != null) 'y1': y1,
        if (x2 != null) 'x2': x2,
        if (y2 != null) 'y2': y2,
        if (cx != null) 'cx': cx,
        if (cy != null) 'cy': cy,
        if (r != null) 'r': r,
        if (startAngle != null) 'startAngle': startAngle,
        if (sweepAngle != null) 'sweepAngle': sweepAngle,
        if (vx != null) 'vx': vx,
        if (vy != null) 'vy': vy,
        if (ax != null) 'ax': ax,
        if (ay != null) 'ay': ay,
        if (bx != null) 'bx': bx,
        if (by != null) 'by': by,
        if (size != null) 'size': size,
        if (x != null) 'x': x,
        if (y != null) 'y': y,
        if (points.isNotEmpty) 'points': points,
        if (label != null) 'label': label,
        if (text != null) 'text': text,
        'color': color,
        if (fillColor != null) 'fillColor': fillColor,
        'dashed': dashed,
      };
}

class BoardDiagramSpec {
  const BoardDiagramSpec({
    required this.title,
    this.width = 320,
    this.height = 220,
    required this.primitives,
  });

  final String title;
  final double width;
  final double height;
  final List<DiagramPrimitive> primitives;

  factory BoardDiagramSpec.fromJson(Map<String, dynamic> json) {
    final primsRaw = json['primitives'] as List<dynamic>? ?? const [];
    return BoardDiagramSpec(
      title: _asString(json['title'], '示意图'),
      width: _asDouble(json['width'], 320),
      height: _asDouble(json['height'], 220),
      primitives: primsRaw
          .whereType<Map<String, dynamic>>()
          .map(DiagramPrimitive.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'width': width,
        'height': height,
        'primitives': primitives.map((e) => e.toJson()).toList(),
      };
}

class BoardFigureBox {
  const BoardFigureBox({
    this.title = '原题配图',
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  final String title;
  final double x;
  final double y;
  final double w;
  final double h;

  factory BoardFigureBox.fromJson(Map<String, dynamic> json) {
    return BoardFigureBox(
      title: _asString(json['title'], '原题配图'),
      x: _asDouble(json['x']).clamp(0.0, 0.96),
      y: _asDouble(json['y']).clamp(0.0, 0.96),
      w: _asDouble(json['w'], 0.5).clamp(0.04, 1.0),
      h: _asDouble(json['h'], 0.4).clamp(0.04, 1.0),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
      };
}

class AiRecognizeResult {
  const AiRecognizeResult({
    required this.title,
    required this.problemText,
    required this.subjectTag,
    required this.questionType,
    required this.difficulty,
    this.knownConditions = const [],
    this.targets = const [],
    this.hasFigure = false,
    this.figureNote = '',
    this.figureBoxes = const [],
    this.diagrams = const [],
    this.modelUsed = '',
    this.latencyMs = 0,
  });

  final String title;
  final String problemText;
  final String subjectTag;
  final String questionType;
  final String difficulty;
  final List<String> knownConditions;
  final List<String> targets;
  final bool hasFigure;
  final String figureNote;
  final List<BoardFigureBox> figureBoxes;
  final List<BoardDiagramSpec> diagrams;
  final String modelUsed;
  final int latencyMs;

  AiRecognizeResult copyWith({
    String? title,
    String? problemText,
    String? subjectTag,
    String? questionType,
    String? difficulty,
    List<String>? knownConditions,
    List<String>? targets,
    bool? hasFigure,
    String? figureNote,
    List<BoardFigureBox>? figureBoxes,
    List<BoardDiagramSpec>? diagrams,
  }) {
    return AiRecognizeResult(
      title: title ?? this.title,
      problemText: problemText ?? this.problemText,
      subjectTag: subjectTag ?? this.subjectTag,
      questionType: questionType ?? this.questionType,
      difficulty: difficulty ?? this.difficulty,
      knownConditions: knownConditions ?? this.knownConditions,
      targets: targets ?? this.targets,
      hasFigure: hasFigure ?? this.hasFigure,
      figureNote: figureNote ?? this.figureNote,
      figureBoxes: figureBoxes ?? this.figureBoxes,
      diagrams: diagrams ?? this.diagrams,
      modelUsed: modelUsed,
      latencyMs: latencyMs,
    );
  }

  factory AiRecognizeResult.fromJson(Map<String, dynamic> json) {
    final diagRaw = json['diagrams'] as List<dynamic>? ?? const [];
    final boxRaw = json['figureBoxes'] as List<dynamic>? ?? const [];
    return AiRecognizeResult(
      title: _asString(json['title'], '数学解答题'),
      problemText: _asString(json['problemText']),
      subjectTag: _asString(json['subjectTag'], '数学'),
      questionType: _asString(json['questionType'], '解答题'),
      difficulty: _asString(json['difficulty'], '中档'),
      knownConditions: _asStringList(json['knownConditions']),
      targets: _asStringList(json['targets']),
      hasFigure: _asBool(json['hasFigure']) || boxRaw.isNotEmpty,
      figureNote: _asString(json['figureNote']),
      figureBoxes: boxRaw
          .whereType<Map<String, dynamic>>()
          .map(BoardFigureBox.fromJson)
          .toList(),
      diagrams: diagRaw
          .whereType<Map<String, dynamic>>()
          .map(BoardDiagramSpec.fromJson)
          .toList(),
      modelUsed: _asString(json['modelUsed']),
      latencyMs: _asInt(json['latencyMs']),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'problemText': problemText,
        'subjectTag': subjectTag,
        'questionType': questionType,
        'difficulty': difficulty,
        'knownConditions': knownConditions,
        'targets': targets,
        'hasFigure': hasFigure,
        'figureNote': figureNote,
        'figureBoxes': figureBoxes.map((e) => e.toJson()).toList(),
        'diagrams': diagrams.map((e) => e.toJson()).toList(),
        'modelUsed': modelUsed,
        'latencyMs': latencyMs,
      };
}

class AiStudentDiagnosis {
  const AiStudentDiagnosis({
    required this.status,
    required this.comment,
    this.mistakePoint = '',
    this.suggestion = '',
  });

  final String status;
  final String comment;
  final String mistakePoint;
  final String suggestion;

  factory AiStudentDiagnosis.fromJson(Map<String, dynamic> json) {
    return AiStudentDiagnosis(
      status: _asString(json['status'], 'NONE').toUpperCase(),
      comment: _asString(json['comment']),
      mistakePoint: _asString(json['mistakePoint']),
      suggestion: _asString(json['suggestion']),
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'comment': comment,
        'mistakePoint': mistakePoint,
        'suggestion': suggestion,
      };
}

class AiBoardStep {
  const AiBoardStep({
    required this.stepNo,
    required this.title,
    required this.content,
    this.formula = '',
    this.highlight = '',
  });

  final int stepNo;
  final String title;
  final String content;
  final String formula;
  final String highlight;

  factory AiBoardStep.fromJson(Map<String, dynamic> json) {
    return AiBoardStep(
      stepNo: _asInt(json['stepNo'], 1),
      title: _asString(json['title']),
      content: _asString(json['content']),
      formula: _asString(json['formula']),
      highlight: _asString(json['highlight']),
    );
  }

  Map<String, dynamic> toJson() => {
        'stepNo': stepNo,
        'title': title,
        'content': content,
        'formula': formula,
        'highlight': highlight,
      };
}

class AiBoardGuidance {
  const AiBoardGuidance({
    required this.mode,
    required this.headline,
    this.summary = '',
    this.knowledgePoints = const [],
    this.studentDiagnosis,
    this.steps = const [],
    this.finalAnswer = '',
    this.pitfalls = const [],
    this.diagrams = const [],
    this.modelUsed = '',
    this.latencyMs = 0,
  });

  final String mode;
  final String headline;
  final String summary;
  final List<String> knowledgePoints;
  final AiStudentDiagnosis? studentDiagnosis;
  final List<AiBoardStep> steps;
  final String finalAnswer;
  final List<String> pitfalls;
  final List<BoardDiagramSpec> diagrams;
  final String modelUsed;
  final int latencyMs;

  bool get isIdeas => mode.toUpperCase() == 'IDEAS';
  bool get isDiagnose => mode.toUpperCase() == 'DIAGNOSE';
  bool get isSolve => !isIdeas && !isDiagnose;

  factory AiBoardGuidance.fromJson(Map<String, dynamic> json) {
    final stepsRaw = json['steps'] as List<dynamic>? ?? const [];
    final diagRaw = json['diagrams'] as List<dynamic>? ?? const [];
    final stuDiagRaw = json['studentDiagnosis'];
    return AiBoardGuidance(
      mode: _asString(json['mode'], 'IDEAS').toUpperCase(),
      headline: _asString(json['headline'], 'AI 板书指导'),
      summary: _asString(json['summary']),
      knowledgePoints: _asStringList(json['knowledgePoints']),
      studentDiagnosis: stuDiagRaw is Map<String, dynamic>
          ? AiStudentDiagnosis.fromJson(stuDiagRaw)
          : null,
      steps: stepsRaw
          .whereType<Map<String, dynamic>>()
          .map(AiBoardStep.fromJson)
          .toList(),
      finalAnswer: _asString(json['finalAnswer']),
      pitfalls: _asStringList(json['pitfalls']),
      diagrams: diagRaw
          .whereType<Map<String, dynamic>>()
          .map(BoardDiagramSpec.fromJson)
          .toList(),
      modelUsed: _asString(json['modelUsed']),
      latencyMs: _asInt(json['latencyMs']),
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'headline': headline,
        'summary': summary,
        'knowledgePoints': knowledgePoints,
        if (studentDiagnosis != null)
          'studentDiagnosis': studentDiagnosis!.toJson(),
        'steps': steps.map((e) => e.toJson()).toList(),
        'finalAnswer': finalAnswer,
        'pitfalls': pitfalls,
        'diagrams': diagrams.map((e) => e.toJson()).toList(),
        'modelUsed': modelUsed,
        'latencyMs': latencyMs,
      };
}
