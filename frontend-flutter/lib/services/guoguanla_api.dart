import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/network/api_client.dart';
import '../core/utils/update_utils.dart';
import '../models/models.dart';

class GuoguanlaApi {
  const GuoguanlaApi(this.client);

  final ApiClient client;

  String? _guestCsv(List<int>? ids) {
    if (ids == null || ids.isEmpty) return null;
    return ids.join(',');
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asMapList(dynamic raw) {
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  // ==================== Auth ====================

  Future<AuthResult> login({
    required String account,
    required String password,
    List<int>? guestPassedGateIds,
  }) {
    return client.request<AuthResult>(
      path: '/app/auth/login',
      method: 'POST',
      skipAuth: true,
      data: {
        'account': account,
        'password': password,
        if (guestPassedGateIds != null && guestPassedGateIds.isNotEmpty)
          'guestPassedGateIds': guestPassedGateIds,
      },
      parser: (raw) => AuthResult.fromJson(_asMap(raw)),
    );
  }

  Future<AuthResult> register({
    required String username,
    required String password,
    required String nickname,
    required String gradeCode,
    List<int>? guestPassedGateIds,
  }) {
    return client.request<AuthResult>(
      path: '/app/auth/register',
      method: 'POST',
      skipAuth: true,
      data: {
        'username': username,
        'password': password,
        'nickname': nickname,
        'gradeCode': gradeCode,
        if (guestPassedGateIds != null && guestPassedGateIds.isNotEmpty)
          'guestPassedGateIds': guestPassedGateIds,
      },
      parser: (raw) => AuthResult.fromJson(_asMap(raw)),
    );
  }

  Future<void> logout() {
    return client.request<void>(
      path: '/app/auth/logout',
      method: 'POST',
      parser: (_) {},
    );
  }

  // ==================== Home / Bank / Realms ====================

  Future<AppDefaultTheme> getDefaultTheme() {
    return client.request<AppDefaultTheme>(
      path: '/app/theme/default',
      method: 'GET',
      skipAuth: true,
      parser: (raw) => AppDefaultTheme.fromJson(_asMap(raw)),
    );
  }

  Future<HomeSummary> getHomeSummary({List<int>? guestPassedIds}) {
    return client.request<HomeSummary>(
      path: '/app/home/summary',
      method: 'GET',
      queryParameters: {'guestPassedIds': _guestCsv(guestPassedIds)},
      parser: (raw) => HomeSummary.fromJson(_asMap(raw)),
    );
  }

  Future<List<RealmItem>> getRealms({List<int>? guestPassedIds}) {
    return client.request<List<RealmItem>>(
      path: '/app/realms',
      method: 'GET',
      queryParameters: {'guestPassedIds': _guestCsv(guestPassedIds)},
      parser: (raw) => _asMapList(raw).map(RealmItem.fromJson).toList(),
    );
  }

  Future<List<ChapterCard>> getChaptersByRealm(
    String realmCode, {
    List<int>? guestPassedIds,
  }) {
    return client.request<List<ChapterCard>>(
      path: '/app/realms/$realmCode/chapters',
      method: 'GET',
      queryParameters: {'guestPassedIds': _guestCsv(guestPassedIds)},
      parser: (raw) => _asMapList(raw).map(ChapterCard.fromJson).toList(),
    );
  }

  Future<List<ChapterCard>> getChaptersByGrade(
    String gradeCode, {
    List<int>? guestPassedIds,
  }) {
    return client.request<List<ChapterCard>>(
      path: '/app/grades/$gradeCode/chapters',
      method: 'GET',
      queryParameters: {'guestPassedIds': _guestCsv(guestPassedIds)},
      parser: (raw) => _asMapList(raw).map(ChapterCard.fromJson).toList(),
    );
  }

  Future<List<GateCard>> getGatesByChapter(
    int chapterId, {
    List<int>? guestPassedIds,
  }) {
    return client.request<List<GateCard>>(
      path: '/app/chapters/$chapterId/gates',
      method: 'GET',
      queryParameters: {'guestPassedIds': _guestCsv(guestPassedIds)},
      parser: (raw) => _asMapList(raw).map(GateCard.fromJson).toList(),
    );
  }

  // ==================== User ====================

  Future<AppUserProfile> getProfile() {
    return client.request<AppUserProfile>(
      path: '/app/user/profile',
      method: 'GET',
      parser: (raw) => AppUserProfile.fromJson(_asMap(raw)),
    );
  }

  Future<AppUserProfile> updateProfile({
    required String nickname,
    String? avatarUrl,
    String? phone,
    String? email,
  }) {
    return client.request<AppUserProfile>(
      path: '/app/user/profile',
      method: 'PUT',
      data: {
        'nickname': nickname,
        'avatarUrl': ?avatarUrl,
        'phone': ?phone,
        'email': ?email,
      },
      parser: (raw) => AppUserProfile.fromJson(_asMap(raw)),
    );
  }

  Future<AppUserProfile> uploadAvatarBytes({
    required Uint8List bytes,
    required String filename,
  }) {
    return client.uploadBytes<AppUserProfile>(
      path: '/app/user/avatar',
      bytes: bytes,
      filename: filename,
      parser: (raw) => AppUserProfile.fromJson(_asMap(raw)),
    );
  }

  Future<List<ChapterCard>> getChapterRecords() {
    return client.request<List<ChapterCard>>(
      path: '/app/user/chapter-records',
      method: 'GET',
      parser: (raw) => _asMapList(raw).map(ChapterCard.fromJson).toList(),
    );
  }

  Future<PageResult<EssayAnswerRecord>> getEssayAnswers({
    int pageNum = 1,
    int pageSize = 10,
  }) {
    return client.request<PageResult<EssayAnswerRecord>>(
      path: '/app/user/essay-answers',
      method: 'GET',
      queryParameters: {'pageNum': pageNum, 'pageSize': pageSize},
      parser: (raw) => PageResult<EssayAnswerRecord>.fromJson(
        _asMap(raw),
        EssayAnswerRecord.fromJson,
      ),
    );
  }

  Future<void> clearEssayAnswers() {
    return client.request<void>(
      path: '/app/user/essay-answers/clear',
      method: 'DELETE',
      parser: (_) {},
    );
  }

  // ==================== Quiz & Realm Exam ====================

  Future<QuizStartResult> startGateQuiz({
    required int gateId,
    List<int>? guestPassedGateIds,
  }) {
    return client.request<QuizStartResult>(
      path: '/app/quiz/start',
      method: 'POST',
      data: {
        'gateId': gateId,
        if (guestPassedGateIds != null && guestPassedGateIds.isNotEmpty)
          'guestPassedGateIds': guestPassedGateIds,
      },
      parser: (raw) => QuizStartResult.fromJson(_asMap(raw)),
    );
  }

  Future<UploadAnswerImageResult> uploadAnswerImageBytes({
    required Uint8List bytes,
    required String sessionNo,
    required int itemIndex,
    String filename = 'essay-answer.png',
  }) {
    return client.uploadBytes<UploadAnswerImageResult>(
      path: '/app/quiz/upload-answer-image',
      bytes: bytes,
      filename: filename,
      extraFields: {
        'sessionNo': sessionNo,
        'itemIndex': itemIndex.toString(),
      },
      parser: (raw) => UploadAnswerImageResult.fromJson(_asMap(raw)),
    );
  }

  Future<CheckItemResult> checkItem({
    required String sessionNo,
    required int itemIndex,
    int? selectedIndex,
    String? answerText,
    String? answerImageKey,
    bool? selfCorrect,
  }) {
    return client.request<CheckItemResult>(
      path: '/app/quiz/check-item',
      method: 'POST',
      data: {
        'sessionNo': sessionNo,
        'itemIndex': itemIndex,
        'selectedIndex': ?selectedIndex,
        'answerText': ?answerText,
        if (answerImageKey != null && answerImageKey.isNotEmpty)
          'answerImageKey': answerImageKey,
        'selfCorrect': ?selfCorrect,
      },
      parser: (raw) => CheckItemResult.fromJson(_asMap(raw)),
    );
  }

  Future<SubmitResult> submitGateQuiz({
    required String sessionNo,
    required List<AnswerSubmitPayload> answers,
    List<int>? guestPassedGateIds,
  }) {
    return client.request<SubmitResult>(
      path: '/app/quiz/submit',
      method: 'POST',
      data: {
        'sessionNo': sessionNo,
        'answers': answers.map((e) => e.toJson()).toList(),
        if (guestPassedGateIds != null && guestPassedGateIds.isNotEmpty)
          'guestPassedGateIds': guestPassedGateIds,
      },
      parser: (raw) => SubmitResult.fromJson(_asMap(raw)),
    );
  }

  Future<QuizStartResult> startRealmExam() {
    return client.request<QuizStartResult>(
      path: '/app/realm/exam/start',
      method: 'POST',
      parser: (raw) => QuizStartResult.fromJson(_asMap(raw)),
    );
  }

  Future<SubmitResult> submitRealmExam({
    required String sessionNo,
    required List<AnswerSubmitPayload> answers,
  }) {
    return client.request<SubmitResult>(
      path: '/app/realm/exam/submit',
      method: 'POST',
      data: {
        'sessionNo': sessionNo,
        'answers': answers.map((e) => e.toJson()).toList(),
      },
      parser: (raw) => SubmitResult.fromJson(_asMap(raw)),
    );
  }

  // ==================== Wrong Questions ====================

  Future<PageResult<WrongQuestionItem>> getWrongPage({
    String? realmCode,
    int? chapterId,
    int pageNum = 1,
    int pageSize = 20,
  }) {
    return client.request<PageResult<WrongQuestionItem>>(
      path: '/app/wrong-questions',
      method: 'GET',
      queryParameters: {
        if (realmCode != null && realmCode.isNotEmpty) 'realmCode': realmCode,
        'chapterId': ?chapterId,
        'pageNum': pageNum,
        'pageSize': pageSize,
      },
      parser: (raw) => PageResult<WrongQuestionItem>.fromJson(
        _asMap(raw),
        WrongQuestionItem.fromJson,
      ),
    );
  }

  Future<QuizStartResult> startWrongRedo({
    String? realmCode,
    int? chapterId,
    int limit = 5,
  }) {
    return client.request<QuizStartResult>(
      path: '/app/wrong-questions/redo/start',
      method: 'POST',
      data: {
        if (realmCode != null && realmCode.isNotEmpty) 'realmCode': realmCode,
        'chapterId': ?chapterId,
        'limit': limit,
      },
      parser: (raw) => QuizStartResult.fromJson(_asMap(raw)),
    );
  }

  Future<SubmitResult> submitWrongRedo({
    required String sessionNo,
    required List<AnswerSubmitPayload> answers,
  }) {
    return client.request<SubmitResult>(
      path: '/app/wrong-questions/redo/submit',
      method: 'POST',
      data: {
        'sessionNo': sessionNo,
        'answers': answers.map((e) => e.toJson()).toList(),
      },
      parser: (raw) => SubmitResult.fromJson(_asMap(raw)),
    );
  }

  Future<void> markWrongMastered(int id) {
    return client.request<void>(
      path: '/app/wrong-questions/$id/master',
      method: 'PUT',
      parser: (_) {},
    );
  }

  Future<void> clearWrongAll() {
    return client.request<void>(
      path: '/app/wrong-questions/clear',
      method: 'DELETE',
      parser: (_) {},
    );
  }

  // ==================== Video Courses ====================

  Future<PageResult<VideoSeriesItem>> getVideoSeriesPage({
    String? realmCode,
    String? keyword,
    int pageNum = 1,
    int pageSize = 12,
  }) {
    return client.request<PageResult<VideoSeriesItem>>(
      path: '/app/videos/series',
      method: 'GET',
      skipAuth: true,
      queryParameters: {
        if (realmCode != null && realmCode.isNotEmpty) 'realmCode': realmCode,
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
        'pageNum': pageNum,
        'pageSize': pageSize,
      },
      parser: (raw) => PageResult<VideoSeriesItem>.fromJson(
        _asMap(raw),
        VideoSeriesItem.fromJson,
      ),
    );
  }

  Future<VideoSeriesDetail> getVideoSeriesDetail(int seriesId) {
    return client.request<VideoSeriesDetail>(
      path: '/app/videos/series/$seriesId',
      method: 'GET',
      skipAuth: true,
      parser: (raw) => VideoSeriesDetail.fromJson(_asMap(raw)),
    );
  }

  // ==================== AI Smart Board ====================

  Future<AiBoardStatus> getAiBoardStatus() {
    return client.request<AiBoardStatus>(
      path: '/app/ai/status',
      method: 'GET',
      timeout: const Duration(seconds: 10),
      parser: (raw) => AiBoardStatus.fromJson(_asMap(raw)),
    );
  }

  Future<AiRecognizeResult> recognizeMathProblem({
    required Uint8List imageBytes,
    required String filename,
    String? extraHint,
    String sourceType = 'PHOTO',
  }) {
    return client.uploadBytes<AiRecognizeResult>(
      path: '/app/ai/recognize-problem/upload',
      bytes: imageBytes,
      filename: filename,
      extraFields: {
        'sourceType': sourceType,
        if (extraHint != null && extraHint.trim().isNotEmpty)
          'extraHint': extraHint.trim(),
      },
      timeout: const Duration(seconds: 90),
      parser: (raw) => AiRecognizeResult.fromJson(_asMap(raw)),
    );
  }

  Future<AiBoardGuidance> generateBoardIdeas({
    String? problemText,
    String? boardImageBase64,
    String? problemImageBase64,
    String? userNotes,
    bool hasHandwriting = false,
  }) {
    return client.request<AiBoardGuidance>(
      path: '/app/ai/board/ideas',
      method: 'POST',
      timeout: const Duration(seconds: 90),
      data: {
        if (problemText != null && problemText.trim().isNotEmpty)
          'problemText': problemText.trim(),
        if (boardImageBase64 != null && boardImageBase64.isNotEmpty)
          'boardImageBase64': boardImageBase64,
        if (problemImageBase64 != null && problemImageBase64.isNotEmpty)
          'problemImageBase64': problemImageBase64,
        if (userNotes != null && userNotes.trim().isNotEmpty)
          'userNotes': userNotes.trim(),
        'hasHandwriting': hasHandwriting,
      },
      parser: (raw) => AiBoardGuidance.fromJson(_asMap(raw)),
    );
  }

  Future<AiBoardGuidance> diagnoseBoardHandwriting({
    String? problemText,
    required String boardImageBase64,
    String? problemImageBase64,
    String? userNotes,
  }) {
    return client.request<AiBoardGuidance>(
      path: '/app/ai/board/diagnose',
      method: 'POST',
      timeout: const Duration(seconds: 120),
      data: {
        if (problemText != null && problemText.trim().isNotEmpty)
          'problemText': problemText.trim(),
        'boardImageBase64': boardImageBase64,
        if (problemImageBase64 != null && problemImageBase64.isNotEmpty)
          'problemImageBase64': problemImageBase64,
        if (userNotes != null && userNotes.trim().isNotEmpty)
          'userNotes': userNotes.trim(),
        'hasHandwriting': true,
      },
      parser: (raw) => AiBoardGuidance.fromJson(_asMap(raw)),
    );
  }

  Future<AiBoardGuidance> solveBoardProblem({
    String? problemText,
    String? boardImageBase64,
    String? problemImageBase64,
    String? userNotes,
  }) {
    return client.request<AiBoardGuidance>(
      path: '/app/ai/board/solve',
      method: 'POST',
      timeout: const Duration(seconds: 120),
      data: {
        if (problemText != null && problemText.trim().isNotEmpty)
          'problemText': problemText.trim(),
        if (boardImageBase64 != null && boardImageBase64.isNotEmpty)
          'boardImageBase64': boardImageBase64,
        if (problemImageBase64 != null && problemImageBase64.isNotEmpty)
          'problemImageBase64': problemImageBase64,
        if (userNotes != null && userNotes.trim().isNotEmpty)
          'userNotes': userNotes.trim(),
        'hasHandwriting': false,
      },
      parser: (raw) => AiBoardGuidance.fromJson(_asMap(raw)),
    );
  }

  Future<AiBoardGuidance> analyzeBoardSolution({
    String? problemText,
    String? boardImageBase64,
    String? problemImageBase64,
    String? userNotes,
    bool hasHandwriting = false,
  }) {
    return solveBoardProblem(
      problemText: problemText,
      boardImageBase64: boardImageBase64,
      problemImageBase64: problemImageBase64,
      userNotes: userNotes,
    );
  }

  // ==================== App Version ====================

  Future<AppVersionInfo> checkLatestVersion({
    required String currentVersion,
    required int versionCode,
  }) {
    return client.request<AppVersionInfo>(
      path: '/app/version/latest',
      method: 'GET',
      skipAuth: true,
      timeout: const Duration(seconds: 8),
      queryParameters: {
        'currentVersion': currentVersion,
        'versionCode': versionCode,
      },
      parser: (raw) => AppVersionInfo.fromJson(_asMap(raw)),
    );
  }

  Future<AppVersionInfo?> fetchGithubReleaseFallback(String localVersion) async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          headers: const {'Accept': 'application/vnd.github+json'},
        ),
      );
      final res = await dio.get<dynamic>(
        'https://api.github.com/repos/gonglanglang/Chnagguan/releases/latest',
      );
      if (res.statusCode == null ||
          res.statusCode! < 200 ||
          res.statusCode! >= 300 ||
          res.data is! Map<String, dynamic>) {
        return null;
      }
      final data = res.data as Map<String, dynamic>;
      final latestVersion = UpdateUtils.normalizeVersion(
        data['tag_name']?.toString(),
      );
      if (latestVersion.isEmpty) return null;
      final assets = data['assets'] as List<dynamic>? ?? const [];
      String downloadUrl = '';
      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final name = (asset['name']?.toString() ?? '').toLowerCase();
          if (name.endsWith('.apk')) {
            downloadUrl = asset['browser_download_url']?.toString() ?? '';
            break;
          }
        }
      }
      final htmlUrl = data['html_url']?.toString() ?? '';
      if (downloadUrl.isEmpty) downloadUrl = htmlUrl;
      final hasUpdate = downloadUrl.isNotEmpty &&
          UpdateUtils.compareVersions(latestVersion, localVersion) > 0;
      return AppVersionInfo(
        currentVersion: localVersion,
        latestVersion: latestVersion,
        latestVersionCode: UpdateUtils.deriveVersionCode(latestVersion),
        hasUpdate: hasUpdate,
        forceUpdate: false,
        releaseNotes: data['body']?.toString() ?? '',
        downloadUrl: downloadUrl,
        githubReleaseUrl: htmlUrl,
        githubRepo: 'gonglanglang/Chnagguan',
        githubReachable: true,
        publishedAt: data['published_at']?.toString() ?? '',
        source: 'GITHUB_DIRECT',
      );
    } catch (_) {
      return null;
    }
  }
}
