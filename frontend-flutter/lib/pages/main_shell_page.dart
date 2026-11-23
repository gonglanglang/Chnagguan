import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../providers/update_provider.dart';
import '../providers/user_provider.dart';
import 'cultivate/cultivate_tab_page.dart';
import 'home/home_tab_page.dart';
import 'mine/mine_tab_page.dart';
import 'wrong/wrong_tab_page.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _currentIndex = 0;

  final List<ValueNotifier<int>> _tabSignals = List<ValueNotifier<int>>.generate(
    4,
    (_) => ValueNotifier<int>(0),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<UserProvider>();
      if (user.isAuthenticated) {
        unawaited(user.refreshWrongCount());
      }
      unawaited(context.read<UpdateProvider>().checkForUpdate(silent: true));
    });
  }

  @override
  void dispose() {
    for (final notifier in _tabSignals) {
      notifier.dispose();
    }
    super.dispose();
  }

  void _onTabTap(int index) {
    setState(() => _currentIndex = index);
    _tabSignals[index].value++;
  }

  @override
  Widget build(BuildContext context) {
    final wrongCount = context.watch<UserProvider>().wrongCount;
    final colors = WelkTheme.of(context).resolveColors(context);

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
      bottomNavigationBar: WelkBottomNavBar(
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
            icon: Icon(Icons.flag_outlined),
            activeIcon: Icon(Icons.flag_rounded),
            label: '闯关',
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
      ),
    );
  }
}
