import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../../app/app_theme.dart';
import '../../core/cache/global_cache.dart';
import '../../core/utils/format_utils.dart';
import '../../models/models.dart';
import '../../providers/theme_provider.dart';
import '../../providers/update_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/guoguanla_api.dart';
import '../../widgets/ggl_comic_panel.dart';
import '../../widgets/ggl_feedback.dart';
import '../../widgets/ggl_skeleton.dart';
import '../../widgets/ggl_skin_widgets.dart';
import '../about/about_page.dart';
import '../chapter_map/chapter_map_page.dart';
import '../essay_records/essay_records_page.dart';
import '../levels/levels_page.dart';
import '../login/login_page.dart';
import '../profile/profile_page.dart';
import '../quiz/quiz_page.dart';
import '../settings/network_check_page.dart';
import '../settings/theme_settings_page.dart';

class MineTabPage extends StatefulWidget {
  const MineTabPage({super.key, required this.refreshSignal});

  final ValueListenable<int> refreshSignal;

  @override
  State<MineTabPage> createState() => _MineTabPageState();
}

class _MineTabPageState extends State<MineTabPage> {
  List<ChapterCard> _chapterRecords = const [];
  bool _initialLoading = true;
  bool _hasLoadedOnce = false;
  bool _lastAuthState = false;
  bool _loggingOut = false;
  String _cacheUsageText = '0 KB';

  @override
  void initState() {
    super.initState();
    _lastAuthState = context.read<UserProvider>().isAuthenticated;
    widget.refreshSignal.addListener(_onRefreshSignal);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncMineData());
  }

  @override
  void dispose() {
    widget.refreshSignal.removeListener(_onRefreshSignal);
    super.dispose();
  }

  void _onRefreshSignal() {
    if (mounted) unawaited(_syncMineData());
  }

  List<ChapterCard> get _passedChapters =>
      _chapterRecords.where((c) => c.passedCount > 0).toList();

  Future<void> _syncMineData() async {
    final user = context.read<UserProvider>();
    final cache = context.read<GlobalCache>();
    final update = context.read<UpdateProvider>();

    if (!_hasLoadedOnce || _lastAuthState != user.isAuthenticated) {
      if (mounted) setState(() => _initialLoading = true);
    }
    _lastAuthState = user.isAuthenticated;

    final bytes = cache.estimateCacheBytes();
    if (mounted) {
      setState(() => _cacheUsageText = FormatUtils.formatFileSize(bytes));
    }
    unawaited(update.loadLocalVersion());

    if (!user.isAuthenticated) {
      if (mounted) {
        setState(() {
          _chapterRecords = const [];
          _hasLoadedOnce = true;
          _initialLoading = false;
        });
      }
      return;
    }

    final api = context.read<GuoguanlaApi>();
    try {
      await user.loadHomeSummary();
      await user.loadUserInfo();
      final records = await api.getChapterRecords();
      if (mounted) {
        setState(() => _chapterRecords = records);
      }
    } catch (_) {
      // Silent fallback
    } finally {
      if (mounted) {
        setState(() {
          _hasLoadedOnce = true;
          _initialLoading = false;
        });
      }
    }
  }

  Future<bool> _ensureAuth() async {
    final user = context.read<UserProvider>();
    if (user.isAuthenticated) return true;
    GglFeedback.warning(context, '请先登录后继续操作');
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const LoginPage()),
    );
    if (ok == true && mounted) {
      await _syncMineData();
      return true;
    }
    return false;
  }

  Future<void> _openLogin() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const LoginPage()),
    );
    if (ok == true && mounted) {
      await _syncMineData();
    }
  }

  Future<void> _openProfile() async {
    if (!await _ensureAuth() || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ProfilePage()),
    );
    if (mounted) await _syncMineData();
  }

  Future<void> _openEssayRecords() async {
    if (!await _ensureAuth() || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const EssayRecordsPage()),
    );
  }

  Future<void> _handleStartExam() async {
    if (!await _ensureAuth() || !mounted) return;
    final realm = context.read<UserProvider>().currentRealm;
    if (!realm.examEligible) {
      final rem = realm.examRemainingGates > 0 ? realm.examRemainingGates : 1;
      GglFeedback.info(context, '还差 $rem 关解锁${realm.realmName}阶段升级测评');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const QuizPage(mode: QuizMode.advanceExam),
      ),
    );
    if (mounted) await _syncMineData();
  }

  Future<void> _openChapterRecordsDrawer() async {
    final user = context.read<UserProvider>();
    final passed = _passedChapters;

    await showGglBottomSheet<void>(
      context: context,
      title: '章节学习档案',
      closeLabel: '关闭',
      builder: (drawerCtx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
            Text(
              '已留下闯关记录的章节共 ${passed.length} 个，点击可直接进入该章闯关地图。',
              style: TextStyle(
                color: AppTheme.mutedText(drawerCtx),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            if (passed.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Text(
                  user.isAuthenticated
                      ? '还没有通过关卡，回首页开始第一关吧'
                      : '登录后可同步全部章节学习记录',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.mutedText(drawerCtx)),
                ),
              )
            else
              for (var i = 0; i < passed.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GglComicPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shadowOffset: const Offset(2, 2),
                    onTap: () {
                      final ch = passed[i];
                      Navigator.of(drawerCtx).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ChapterMapPage(
                            chapterId: ch.id,
                            chapterSeq: i + 1,
                            chapterName: ch.name,
                            chapterDesc: ch.description,
                            realmName: ch.realmName,
                          ),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                passed[i].name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: WelkTheme.of(drawerCtx)
                                      .resolveColors(drawerCtx)
                                      .ink,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                passed[i].realmName,
                                style: TextStyle(
                                  color: AppTheme.mutedText(drawerCtx),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GglStatusTag(
                          label:
                              '${passed[i].passedCount}/${passed[i].totalGates} 关',
                          variant: passed[i].passedCount >= passed[i].totalGates
                              ? WelkBadgeVariant.success
                              : WelkBadgeVariant.defaultStyle,
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
    );
  }

  Future<void> _handleClearCache() async {
    final ok = await GglFeedback.confirm(
      context,
      title: '清理缓存',
      content: '将清理临时缓存，不影响登录状态与主题设置。',
      yesText: '清理',
      noText: '取消',
    );
    if (!ok || !mounted) return;
    final cache = context.read<GlobalCache>();
    await cache.clearTemporaryCache();
    PaintingBinding.instance.imageCache.clear();
    if (mounted) {
      setState(
        () => _cacheUsageText =
            FormatUtils.formatFileSize(cache.estimateCacheBytes()),
      );
      GglFeedback.success(context, '缓存已清理');
    }
  }

  Future<void> _handleCheckUpdate() async {
    final msg = await context
        .read<UpdateProvider>()
        .checkForUpdate(silent: false);
    if (msg != null && mounted) {
      GglFeedback.info(context, msg);
    }
  }

  Future<void> _handleLogout() async {
    final ok = await GglFeedback.confirm(
      context,
      title: '退出登录',
      content: '确定要退出当前学生账号吗？',
      yesText: '退出登录',
      noText: '取消',
      variant: WelkDialogVariant.error,
    );
    if (!ok || !mounted) return;
    setState(() => _loggingOut = true);
    try {
      await context.read<UserProvider>().logout();
      if (!mounted) return;
      setState(() => _chapterRecords = const []);
      GglFeedback.success(context, '已退出登录');
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final theme = context.watch<ThemeProvider>();
    final update = context.watch<UpdateProvider>();
    final realm = user.currentRealm;
    final realmPct = realm.gateCount > 0
        ? ((realm.passedGateCount / realm.gateCount) * 100).round().clamp(0, 100)
        : 0;
    final avatarUrl = user.userInfo?.avatarUrl ?? '';

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: const GglAppBar(
        title: '我的',
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _syncMineData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            if (_initialLoading) ...[
              const GglCardSkeleton(lines: 3),
              const SizedBox(height: 14),
              const GglCardSkeleton(lines: 2),
              const SizedBox(height: 14),
              const GglCardSkeleton(lines: 5),
            ] else ...[
              // Profile Card
              GglComicPanel(
                child: Column(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: user.isAuthenticated ? _openProfile : _openLogin,
                      child: Row(
                        children: [
                          GglAvatar(
                            alt: user.userInfo?.nickname ?? '头像',
                            size: WelkAvatarSize.large,
                            image: avatarUrl.isNotEmpty
                                ? NetworkImage(avatarUrl)
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.isAuthenticated
                                      ? ((user.userInfo?.nickname.isNotEmpty ??
                                              false)
                                          ? user.userInfo!.nickname
                                          : (user.userInfo?.username ?? '已登录同学'))
                                      : '游客试玩',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppTheme.inkColor(context),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    GglStatusTag(
                                      label: user.isAuthenticated
                                          ? ((user.userInfo?.gradeName
                                                      .isNotEmpty ??
                                                  false)
                                              ? user.userInfo!.gradeName
                                              : '未设年级')
                                          : '本地体验',
                                      variant: WelkBadgeVariant.info,
                                    ),
                                    if (!user.isAuthenticated ||
                                        user.userInfo?.gradeName !=
                                            realm.realmName)
                                      GglStatusTag(
                                        label: '${realm.realmName}阶段',
                                        variant: WelkBadgeVariant.defaultStyle,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                user.isAuthenticated ? '编辑资料' : '点击登录',
                                style: TextStyle(
                                  color: AppTheme.mutedText(context),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: AppTheme.mutedText(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const GglDivider(verticalPadding: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _ProfileStat(
                            value: '${user.passedGateCount}',
                            label: '累计闯关',
                          ),
                        ),
                        Expanded(
                          child: _ProfileStat(
                            value: '${_passedChapters.length}',
                            label: '已学章节',
                          ),
                        ),
                        Expanded(
                          child: _ProfileStat(
                            value: '$realmPct%',
                            label: '阶段进度',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4-Grid Quick Actions
              GglComicPanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _QuickActionItem(
                        icon: Icons.layers_rounded,
                        label: '学习阶段',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const LevelsPage(),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _QuickActionItem(
                        icon: Icons.draw_rounded,
                        label: '解答记录',
                        onTap: _openEssayRecords,
                      ),
                    ),
                    Expanded(
                      child: _QuickActionItem(
                        icon: Icons.school_rounded,
                        label: '升级测评',
                        onTap: _handleStartExam,
                      ),
                    ),
                    Expanded(
                      child: _QuickActionItem(
                        icon: Icons.bar_chart_rounded,
                        label: '章节档案',
                        onTap: _openChapterRecordsDrawer,
                      ),
                    ),
                  ],
                ),
              ),

              const GglSectionLabel(title: '设置与工具'),

              // Settings Menu Card
              GglComicPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SettingTile(
                      icon: Icons.palette_outlined,
                      title: '主题设置',
                      trailing:
                          '${theme.isForui ? 'Forui' : (theme.isSkribble ? 'Skribble' : 'WelkUI')} · ${theme.accentName}',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ThemeSettingsPage(),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: GglDivider(verticalPadding: 0),
                    ),
                    _SettingTile(
                      icon: Icons.cleaning_services_outlined,
                      title: '清理缓存',
                      trailing: _cacheUsageText,
                      onTap: _handleClearCache,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: GglDivider(verticalPadding: 0),
                    ),
                    _SettingTile(
                      icon: Icons.wifi_tethering_rounded,
                      title: '网络检测',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const NetworkCheckPage(),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: GglDivider(verticalPadding: 0),
                    ),
                    _SettingTile(
                      icon: Icons.system_update_outlined,
                      title: '检查新版本',
                      trailing: 'v${update.currentVersion}',
                      onTap: _handleCheckUpdate,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: GglDivider(verticalPadding: 0),
                    ),
                    _SettingTile(
                      icon: Icons.info_outline_rounded,
                      title: '关于我们',
                      trailing: 'v${update.currentVersion}',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AboutPage(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Login / Logout CTA
              if (user.isAuthenticated)
                GglBlockButton(
                  label: _loggingOut ? '正在退出...' : '退出登录',
                  variant: WelkButtonVariant.error,
                  size: WelkButtonSize.large,
                  loading: _loggingOut,
                  onPressed: _handleLogout,
                )
              else
                GglBlockButton(
                  label: '登录 / 注册',
                  variant: WelkButtonVariant.primary,
                  size: WelkButtonSize.large,
                  onPressed: _openLogin,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.inkColor(context);
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: ink,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: AppTheme.mutedText(context), fontSize: 12),
        ),
      ],
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final ink = AppTheme.inkColor(context);
    final accent = AppTheme.accentColor(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: AppTheme.insetBoxDecoration(
              context,
              color: accent.withValues(
                alpha: AppTheme.isForui(context)
                    ? (colors.isDark ? 0.22 : 0.14)
                    : (colors.isDark ? 0.25 : 0.45),
              ),
              radius: 11,
            ),
            child: Icon(icon, size: 21, color: ink),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.inkColor(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: ink),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (trailing != null && trailing!.isNotEmpty) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 165),
                child: Text(
                  trailing!,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: AppTheme.mutedText(context),
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppTheme.mutedText(context),
            ),
          ],
        ),
      ),
    );
  }
}
