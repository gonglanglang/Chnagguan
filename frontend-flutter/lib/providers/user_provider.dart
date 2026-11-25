import 'package:flutter/foundation.dart';

import '../core/cache/global_cache.dart';
import '../models/models.dart';
import '../services/guoguanla_api.dart';

class UserProvider extends ChangeNotifier {
  UserProvider({
    required GlobalCache storage,
    required GuoguanlaApi api,
  }) : this._internal(storage, api);

  UserProvider._internal(this._storage, this._api)
      : _accessToken = _storage.accessToken,
        _userInfo = _storage.cachedProfile,
        _guestPassedIds = _storage.guestPassedIds;

  final GlobalCache _storage;
  final GuoguanlaApi _api;

  String _accessToken;
  AppUserProfile? _userInfo;
  List<int> _guestPassedIds;
  HomeSummary? _homeSummary;
  int _wrongCount = 0;
  int _sessionRevision = 0;

  String get accessToken => _accessToken;
  int get sessionRevision => _sessionRevision;
  AppUserProfile? get userInfo => _userInfo;
  List<int> get guestPassedIds => List.unmodifiable(_guestPassedIds);
  HomeSummary? get homeSummary => _homeSummary;
  int get wrongCount => _wrongCount;

  bool get isAuthenticated => _accessToken.isNotEmpty;

  List<RealmItem> get realms =>
      (_homeSummary != null && _homeSummary!.realms.isNotEmpty)
          ? _homeSummary!.realms
          : RealmItem.defaults;

  List<GradeItem> get grades =>
      (_homeSummary != null && _homeSummary!.grades.isNotEmpty)
          ? _homeSummary!.grades
          : GradeItem.fallbacks;

  RealmItem get currentRealm {
    final list = realms;
    for (final r in list) {
      if (r.isCurrent) return r;
    }
    final userRealmCode = _userInfo?.realmCode;
    if (userRealmCode != null && userRealmCode.isNotEmpty) {
      for (final r in list) {
        if (r.realmCode == userRealmCode) return r;
      }
    }
    return list.first;
  }

  String get appNotice => _homeSummary?.appNotice ?? '';
  bool get guestModeEnabled => _homeSummary?.guestModeEnabled ?? true;

  int get passedGateCount {
    if (isAuthenticated && _userInfo != null) {
      return _userInfo!.passedGateCount;
    }
    return _guestPassedIds.length;
  }

  List<int>? get activeGuestIds => isAuthenticated ? null : _guestPassedIds;

  void setWrongCount(int count) {
    final next = count < 0 ? 0 : count;
    if (_wrongCount == next) return;
    _wrongCount = next;
    notifyListeners();
  }

  Future<int> refreshWrongCount() async {
    if (!isAuthenticated) {
      setWrongCount(0);
      return 0;
    }
    try {
      final page = await _api.getWrongPage(pageNum: 1, pageSize: 1);
      setWrongCount(page.total);
    } catch (_) {
      // Silent badge refresh failure
    }
    return _wrongCount;
  }

  Future<void> _setSession(String token, AppUserProfile profile) async {
    _sessionRevision++;
    _accessToken = token;
    _userInfo = profile;
    await _storage.setAccessToken(token);
    await _storage.setCachedProfile(profile);
    notifyListeners();
  }

  Future<void> resetSession() async {
    _sessionRevision++;
    _accessToken = '';
    _userInfo = null;
    _wrongCount = 0;
    await _storage.setAccessToken('');
    await _storage.setCachedProfile(null);
    notifyListeners();
  }

  Future<void> recordGuestPassedGate(int gateId) async {
    if (isAuthenticated) return;
    if (!_guestPassedIds.contains(gateId)) {
      _guestPassedIds = await _storage.saveGuestPassedIds([
        ..._guestPassedIds,
        gateId,
      ]);
      notifyListeners();
    }
  }

  Future<HomeSummary> loadHomeSummary() async {
    final summary = await _api.getHomeSummary(guestPassedIds: activeGuestIds);
    _homeSummary = summary;
    if (summary.profile != null && isAuthenticated) {
      _userInfo = summary.profile;
      await _storage.setCachedProfile(summary.profile);
    }
    notifyListeners();
    return summary;
  }

  Future<AppUserProfile> login({
    required String account,
    required String password,
  }) async {
    final guestIds = List<int>.from(_guestPassedIds);
    final res = await _api.login(
      account: account,
      password: password,
      guestPassedGateIds: guestIds,
    );
    await _setSession(res.token, res.profile);
    if (guestIds.isNotEmpty) {
      await _storage.clearGuestPassedIds();
      _guestPassedIds = <int>[];
    }
    notifyListeners();
    return res.profile;
  }

  Future<AppUserProfile> register({
    required String username,
    required String password,
    required String nickname,
    required String gradeCode,
  }) async {
    final guestIds = List<int>.from(_guestPassedIds);
    final res = await _api.register(
      username: username,
      password: password,
      nickname: nickname,
      gradeCode: gradeCode,
      guestPassedGateIds: guestIds,
    );
    await _setSession(res.token, res.profile);
    if (guestIds.isNotEmpty) {
      await _storage.clearGuestPassedIds();
      _guestPassedIds = <int>[];
    }
    notifyListeners();
    return res.profile;
  }

  Future<AppUserProfile> loadUserInfo() async {
    final rev = _sessionRevision;
    final profile = await _api.getProfile();
    if (rev == _sessionRevision) {
      _userInfo = profile;
      await _storage.setCachedProfile(profile);
      notifyListeners();
    }
    return profile;
  }

  Future<AppUserProfile> updateProfile({
    required String nickname,
    String? avatarUrl,
    String? phone,
    String? email,
  }) async {
    final updated = await _api.updateProfile(
      nickname: nickname,
      avatarUrl: avatarUrl,
      phone: phone,
      email: email,
    );
    _userInfo = updated;
    await _storage.setCachedProfile(updated);
    notifyListeners();
    return updated;
  }

  Future<AppUserProfile> uploadAvatarBytes({
    required Uint8List bytes,
    required String filename,
  }) async {
    final updated = await _api.uploadAvatarBytes(
      bytes: bytes,
      filename: filename,
    );
    _userInfo = updated;
    await _storage.setCachedProfile(updated);
    notifyListeners();
    return updated;
  }

  Future<void> logout() async {
    final rev = _sessionRevision;
    try {
      await _api.logout();
    } catch (_) {
      // Ignore logout network error
    } finally {
      if (rev == _sessionRevision) {
        await resetSession();
      }
    }
  }
}
