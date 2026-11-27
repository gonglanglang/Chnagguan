import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:skribble/skribble.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../app/app_theme.dart';
import '../providers/update_provider.dart';
import '../providers/user_provider.dart';
import '../services/guoguanla_api.dart';
import 'cultivate/cultivate_tab_page.dart';
import 'home/home_tab_page.dart';
import 'mine/mine_tab_page.dart';
import 'wrong/wrong_tab_page.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage>
    with WidgetsBindingObserver {
  static const List<String> _tabNames = <String>[
    'home',
    'classroom',
    'wrong',
    'mine',
  ];

  int _currentIndex = 0;
  Timer? _heartbeatTimer;
  bool _appResumed = true;
  bool _lastAuthState = false;
  UserProvider? _userProvider;

  final List<ValueNotifier<int>> _tabSignals = List<ValueNotifier<int>>.generate(
    4,
    (_) => ValueNotifier<int>(0),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<UserProvider>();
      _userProvider = user;
      _lastAuthState = user.isAuthenticated;
      user.addListener(_onUserStateChanged);
      if (user.isAuthenticated) {
        unawaited(user.refreshWrongCount());
        unawaited(_sendOnlineHeartbeat());
      }
      _startHeartbeatLoop();
      unawaited(context.read<UpdateProvider>().checkForUpdate(silent: true));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _userProvider?.removeListener(_onUserStateChanged);
    for (final notifier in _tabSignals) {
      notifier.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    if (_appResumed && mounted) {
      unawaited(_sendOnlineHeartbeat());
    }
  }

  void _onUserStateChanged() {
    if (!mounted) return;
    final nowAuth = _userProvider?.isAuthenticated ?? false;
    if (nowAuth && !_lastAuthState) {
      unawaited(_sendOnlineHeartbeat());
    }
    _lastAuthState = nowAuth;
  }

  void _startHeartbeatLoop() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted && _appResumed) {
        unawaited(_sendOnlineHeartbeat());
      }
    });
  }

  Future<void> _sendOnlineHeartbeat() async {
    if (!mounted) return;
    final user = context.read<UserProvider>();
    if (!user.isAuthenticated) return;
    try {
      final page = _currentIndex >= 0 && _currentIndex < _tabNames.length
          ? _tabNames[_currentIndex]
          : 'home';
      await context.read<GuoguanlaApi>().sendOnlineHeartbeat(page: page);
    } catch (_) {
      // 忽略静默心跳网络异常，不影响主界面交互
    }
  }

  void _onTabTap(int index) {
    setState(() => _currentIndex = index);
    _tabSignals[index].value++;
  }

  @override
  Widget build(BuildContext context) {
    final wrongCount = context.watch<UserProvider>().wrongCount;
    final colors = WelkTheme.of(context).resolveColors(context);
    final isSkribble = AppTheme.isSkribble(context);
    final isForui = AppTheme.isForui(context);

    Widget? wrongBadge;
    if (wrongCount > 0) {
      final label = wrongCount > 99 ? '99+' : '$wrongCount';
      wrongBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: colors.error,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.outline, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: colors.onFill(colors.error),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
      );
    }

    final Widget bottomBar;
    if (isForui) {
      final fColors = FTheme.of(context).colors;
      Widget buildForuiWrongIcon() {
        final baseIcon = Icon(
          _currentIndex == 2
              ? Icons.menu_book_rounded
              : Icons.menu_book_outlined,
        );
        if (wrongCount <= 0) return baseIcon;
        final label = wrongCount > 99 ? '99+' : '$wrongCount';
        return Stack(
          clipBehavior: Clip.none,
          children: [
            baseIcon,
            Positioned(
              right: -12,
              top: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: fColors.destructive,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: fColors.destructiveForeground,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ],
        );
      }

      bottomBar = FBottomNavigationBar(
        index: _currentIndex,
        onChange: _onTabTap,
        safeAreaBottom: true,
        children: [
          FBottomNavigationBarItem(
            icon: Icon(
              _currentIndex == 0 ? Icons.home_rounded : Icons.home_outlined,
            ),
            label: const Text(
              '首页',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          FBottomNavigationBarItem(
            icon: Icon(
              _currentIndex == 1
                  ? Icons.play_circle_rounded
                  : Icons.play_circle_outline_rounded,
            ),
            label: const Text(
              '课堂',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          FBottomNavigationBarItem(
            icon: buildForuiWrongIcon(),
            label: const Text(
              '错题本',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          FBottomNavigationBarItem(
            icon: Icon(
              _currentIndex == 3
                  ? Icons.person_rounded
                  : Icons.person_outline_rounded,
            ),
            label: const Text(
              '我的',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else if (isSkribble) {
      final wired = WiredTheme.of(context);
      bottomBar = Container(
        color: wired.fillColor,
        child: SafeArea(
          top: false,
          child: WiredBottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onTabTap,
            items: [
              const WiredBottomNavItem(
                icon: Icons.home_rounded,
                label: '首页',
              ),
              const WiredBottomNavItem(
                icon: Icons.play_circle_rounded,
                label: '课堂',
              ),
              WiredBottomNavItem(
                icon: Icons.menu_book_rounded,
                label: wrongCount > 0
                    ? '错题(${wrongCount > 99 ? '99+' : wrongCount})'
                    : '错题本',
              ),
              const WiredBottomNavItem(
                icon: Icons.person_rounded,
                label: '我的',
              ),
            ],
          ),
        ),
      );
    } else {
      bottomBar = WelkBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTap,
        layout: WelkBottomNavLayout.comicDock,
        mode: WelkBottomNavMode.defaultMode,
        style: const WelkBottomNavStyle(
          height: 66,
          iconSize: 22,
          labelBehavior: WelkBottomNavLabelBehavior.alwaysShow,
        ),
        items: [
          const WelkBottomNavItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: '首页',
          ),
          const WelkBottomNavItem(
            icon: Icon(Icons.play_circle_outline_rounded),
            activeIcon: Icon(Icons.play_circle_rounded),
            label: '课堂',
          ),
          WelkBottomNavItem(
            icon: const Icon(Icons.menu_book_outlined),
            activeIcon: const Icon(Icons.menu_book_rounded),
            label: '错题本',
            badge: wrongBadge,
          ),
          const WelkBottomNavItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: '我的',
          ),
        ],
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeTabPage(refreshSignal: _tabSignals[0]),
          CultivateTabPage(refreshSignal: _tabSignals[1]),
          WrongTabPage(refreshSignal: _tabSignals[2]),
          MineTabPage(refreshSignal: _tabSignals[3]),
        ],
      ),
      bottomNavigationBar: bottomBar,
    );
  }
}
