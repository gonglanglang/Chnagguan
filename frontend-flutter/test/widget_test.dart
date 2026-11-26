import 'dart:typed_data';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:guoguanla_app/app/app_theme.dart';
import 'package:guoguanla_app/core/cache/global_cache.dart';
import 'package:guoguanla_app/core/network/api_client.dart';
import 'package:guoguanla_app/models/models.dart';
import 'package:guoguanla_app/pages/about/about_page.dart';
import 'package:guoguanla_app/pages/draw_answer/draw_answer_page.dart';
import 'package:guoguanla_app/pages/grade_chapters/grade_chapters_page.dart';
import 'package:guoguanla_app/pages/home/home_tab_page.dart';
import 'package:guoguanla_app/pages/login/login_page.dart';
import 'package:guoguanla_app/pages/mine/mine_tab_page.dart';
import 'package:guoguanla_app/pages/profile/profile_page.dart';
import 'package:guoguanla_app/pages/quiz/quiz_page.dart';
import 'package:guoguanla_app/pages/settings/theme_settings_page.dart';
import 'package:guoguanla_app/pages/smart_board/smart_board_page.dart';
import 'package:guoguanla_app/providers/theme_provider.dart';
import 'package:guoguanla_app/providers/update_provider.dart';
import 'package:guoguanla_app/providers/user_provider.dart';
import 'package:guoguanla_app/services/guoguanla_api.dart';
import 'package:guoguanla_app/widgets/ggl_comic_panel.dart';
import 'package:guoguanla_app/widgets/ggl_video_player.dart';
import 'package:guoguanla_app/widgets/math_text.dart';
import 'package:guoguanla_app/widgets/question_figure_card.dart';
import 'package:video_player/video_player.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skribble/skribble.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

void main() {
  testWidgets('WelkTheme + MathText + GglComicPanel render cleanly', (
    WidgetTester tester,
  ) async {
    final welk = AppTheme.buildWelkTheme(
      isDark: false,
      accent: AppTheme.presets.first.color,
    );

    await tester.pumpWidget(
      WelkTheme(
        data: welk,
        child: MaterialApp(
          theme: AppTheme.buildMaterialTheme(isDark: false, welk: welk),
          home: const Scaffold(
            body: GglComicPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MathText(r'求解方程 $\frac{x^2}{2} = 8$'),
                  SizedBox(height: 12),
                  GglProgressBar(percent: 0.5),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(GglComicPanel), findsOneWidget);
    expect(find.byType(GglProgressBar), findsOneWidget);
    expect(find.textContaining('求解方程'), findsOneWidget);
  });

  testWidgets('MathText renders dfrac with nested superscript and radical cleanly',
      (WidgetTester tester) async {
    final welk = AppTheme.buildWelkTheme(
      isDark: false,
      accent: AppTheme.presets.first.color,
    );
    const sample = '（1）\$\\dfrac{x^2}{2}+y^2=1\$\n'
        '（2）\$k=\\pm\\dfrac{\\sqrt{10}}{2}\$';

    await tester.pumpWidget(
      WelkTheme(
        data: welk,
        child: MaterialApp(
          theme: AppTheme.buildMaterialTheme(isDark: false, welk: welk),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: MathText(sample),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining(r'\dfrac'), findsNothing);
    expect(find.textContaining(r'\sqrt'), findsNothing);
    expect(find.textContaining('（1）'), findsOneWidget);
    expect(find.textContaining('（2）'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('2'), findsNWidgets(4));
  });

  testWidgets(
      'ThemeSettingsPage switches UI skin to Skribble immediately, toggles dark mode and preset',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = await GlobalCache.init();
    final themeProvider = ThemeProvider(storage);

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>.value(
        value: themeProvider,
        child: Consumer<ThemeProvider>(
          builder: (context, theme, _) => WelkTheme(
            data: theme.welkTheme,
            child: WiredThemeScope(
              data: theme.skribbleTheme,
              child: MaterialApp(
                theme: theme.materialTheme,
                localizationsDelegates: FLocalizations.localizationsDelegates,
                builder: (ctx, child) => FTheme(
                  data: theme.foruiTheme,
                  child: FToaster(child: child!),
                ),
                home: const ThemeSettingsPage(),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('主题与皮肤设置'), findsOneWidget);
    expect(find.text('WelkUI 漫画风'), findsOneWidget);
    expect(find.text('Skribble 手绘风'), findsOneWidget);
    expect(find.text('Forui 现代极简'), findsOneWidget);
    expect(find.byType(WelkAppBar), findsOneWidget);
    expect(find.byType(WiredAppBar), findsNothing);
    expect(themeProvider.isDarkMode, isFalse);
    expect(themeProvider.isSkribble, isFalse);

    // 点击切换为 Skribble 手绘皮肤，应立即重渲染 Skribble 原生组件
    await tester.tap(find.text('Skribble 手绘风'));
    await tester.pumpAndSettle();
    expect(themeProvider.isSkribble, isTrue);
    expect(storage.uiSkin, 'skribble');
    expect(find.byType(WiredAppBar), findsOneWidget);
    expect(find.byType(WiredSwitch), findsOneWidget);
    expect(find.byType(WiredProgress), findsWidgets);

    // 点击切换为 Forui 现代极简皮肤，应立即重渲染 Forui 原生组件
    await tester.tap(find.text('Forui 现代极简'));
    await tester.pumpAndSettle();
    expect(themeProvider.isForui, isTrue);
    expect(storage.uiSkin, 'forui');
    expect(find.byWidgetPredicate((w) => w is FHeader), findsOneWidget);
    expect(find.byType(FCard), findsWidgets);
    expect(find.byType(FSwitch), findsOneWidget);

    // 切换暗黑模式
    await tester.tap(find.byType(FSwitch));
    await tester.pumpAndSettle();
    expect(themeProvider.isDarkMode, isTrue);

    // 向下滚动验证 Forui 进度条与强调色切换
    await tester.scrollUntilVisible(
      find.text('Forui (shadcn/ui) 组件实时预览'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(FDeterminateProgress), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('元气暖黄'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('元气暖黄'));
    await tester.pumpAndSettle();
    expect(themeProvider.accentHex, '#FFDA57');
  });

  testWidgets(
      'QuizPage renders QuestionFigureCard diagram and advances directly to next gate on pass',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final cache = await GlobalCache.init();
    final api = _FakeGuoguanlaApi();
    final userProvider = UserProvider(storage: cache, api: api);
    final themeProvider = ThemeProvider(cache);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<GlobalCache>.value(value: cache),
          Provider<GuoguanlaApi>.value(value: api),
          ChangeNotifierProvider<UserProvider>.value(value: userProvider),
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ],
        child: Consumer<ThemeProvider>(
          builder: (context, theme, _) => WelkTheme(
            data: theme.welkTheme,
            child: MaterialApp(
              theme: theme.materialTheme,
              localizationsDelegates: FLocalizations.localizationsDelegates,
              builder: (ctx, child) => FTheme(
                data: theme.foruiTheme,
                child: FToaster(child: child!),
              ),
              home: const QuizPage(
                mode: QuizMode.gate,
                gateId: 101,
                gateSeq: 1,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Gate 1 displays geometry diagram card
    expect(find.textContaining('第 1 关'), findsOneWidget);
    expect(find.byType(QuestionFigureCard), findsOneWidget);

    // Tap figure card to verify zoom dialog opens cleanly
    await tester.tap(find.byType(QuestionFigureCard));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();

    // Select option A -> check -> submit
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('提交答案'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成交卷'));
    await tester.pumpAndSettle();

    // Settlement displays direct Next Gate button
    expect(find.text('闯关成功！'), findsOneWidget);
    expect(find.text('进入下一关 · 第 2 关'), findsOneWidget);

    // Tap Next Gate -> immediately starts Gate 102 without popping back
    await tester.tap(find.text('进入下一关 · 第 2 关'));
    await tester.pumpAndSettle();
    expect(api.startedGateIds, [101, 102]);
    expect(find.textContaining('第 2 关'), findsOneWidget);
    expect(find.textContaining('第二关题目'), findsOneWidget);
  });

  testWidgets(
      'GglVideoControls renders zoom, speed, skip, fullscreen and horizontal swipe seek controls',
      (WidgetTester tester) async {
    final prevPlatform = VideoPlayerPlatform.instance;
    final fakePlatform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakePlatform;
    addTearDown(() => VideoPlayerPlatform.instance = prevPlatform);

    final videoCtrl = VideoPlayerController.networkUrl(
      Uri.parse('https://example.com/demo.mp4'),
    );
    await videoCtrl.initialize();
    videoCtrl.value = const VideoPlayerValue(
      duration: Duration(minutes: 5),
      position: Duration(seconds: 30),
      size: Size(1280, 720),
      isInitialized: true,
    );
    final transformCtrl = TransformationController();
    final zoomNotifier = ValueNotifier<double>(1.0);
    final brightnessNotifier = ValueNotifier<double>(1.0);
    final chewieCtrl = ChewieController(
      videoPlayerController: videoCtrl,
      autoPlay: false,
      looping: false,
      transformationController: transformCtrl,
    );
    addTearDown(() {
      chewieCtrl.dispose();
      videoCtrl.dispose();
      transformCtrl.dispose();
      zoomNotifier.dispose();
      brightnessNotifier.dispose();
    });

    var nextTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 230,
            child: ChewieControllerProvider(
              controller: chewieCtrl,
              child: GglVideoControls(
                title: '第 1 节：勾股定理精讲',
                accentColor: const Color(0xFF67C6FF),
                transformationController: transformCtrl,
                zoomNotifier: zoomNotifier,
                brightnessNotifier: brightnessNotifier,
                hasNextLesson: true,
                onNextLesson: () => nextTapped = true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('第 1 节：勾股定理精讲'), findsOneWidget);
    expect(find.text('放大'), findsOneWidget);
    expect(find.text('1.0x'), findsOneWidget);
    expect(find.text('下一节'), findsOneWidget);
    expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);
    expect(find.byIcon(Icons.forward_10_rounded), findsOneWidget);
    expect(find.byIcon(Icons.replay_10_rounded), findsOneWidget);

    // 点击「放大」按钮，画面缩放升级至 1.25x 并出现还原按钮
    await tester.tap(find.text('放大'));
    await tester.pump();
    expect(zoomNotifier.value, closeTo(1.25, 0.01));
    expect(find.text('1.25x · 还原'), findsOneWidget);

    // 还原 1.0x 后验证右滑快进手势调用 seekTo
    await tester.tap(find.text('1.25x · 还原'));
    await tester.pump();
    expect(zoomNotifier.value, closeTo(1.0, 0.01));

    await tester.drag(find.byType(GglVideoControls), const Offset(120, 0));
    await tester.pump();
    expect(fakePlatform.lastSeekPosition, isNotNull);
    expect(fakePlatform.lastSeekPosition!.inSeconds, greaterThan(30));

    await tester.tap(find.text('下一节'));
    await tester.pump();
    expect(nextTapped, isTrue);

    // 释放所有挂起的瞬时 HUD 定时器
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('LoginPage switches between login and register with grade picker',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = await GlobalCache.init();
    final api = _FakeGuoguanlaApi();
    final userProvider = UserProvider(storage: storage, api: api);
    final welk = AppTheme.buildWelkTheme(
      isDark: false,
      accent: AppTheme.presets.first.color,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<GlobalCache>.value(value: storage),
          Provider<GuoguanlaApi>.value(value: api),
          ChangeNotifierProvider<UserProvider>.value(value: userProvider),
        ],
        child: WelkTheme(
          data: welk,
          child: MaterialApp(
            theme: AppTheme.buildMaterialTheme(isDark: false, welk: welk),
            home: const LoginPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('欢迎来到过关啦'), findsOneWidget);
    expect(find.text('立即登录'), findsOneWidget);

    await tester.tap(find.text('注册'));
    await tester.pumpAndSettle();

    expect(find.text('所在年级'), findsOneWidget);
    expect(find.text('初一'), findsOneWidget);
    expect(find.text('高三'), findsOneWidget);
    expect(find.textContaining('图形验证码'), findsOneWidget);
    expect(api.captchaCallCount, 1);
  });

  testWidgets('DrawAnswerPage renders comic toolbar and infinite canvas', (
    WidgetTester tester,
  ) async {
    final welk = AppTheme.buildWelkTheme(
      isDark: false,
      accent: AppTheme.presets.first.color,
    );

    await tester.pumpWidget(
      WelkTheme(
        data: welk,
        child: MaterialApp(
          theme: AppTheme.buildMaterialTheme(isDark: false, welk: welk),
          home: const DrawAnswerPage(
            sessionNo: 'TEST-SESSION',
            itemIndex: 0,
            stem: r'解方程 $x^2 - 4 = 0$',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('返回'), findsOneWidget);
    expect(find.text('完成保存'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets(
      'HomeTabPage renders 3-col grade grid without 章节闯关 and auto-pops announcement once',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    PackageInfo.setMockInitialValues(
      appName: '过关啦',
      packageName: 'com.guoguanla.app',
      version: '1.0.14',
      buildNumber: '114',
      buildSignature: '',
    );
    final cache = await GlobalCache.init();
    final api = _FakeGuoguanlaApi();
    final userProvider = UserProvider(storage: cache, api: api);
    final updateProvider = UpdateProvider(api);
    final refreshSignal = ValueNotifier<int>(0);
    addTearDown(refreshSignal.dispose);
    final welk = AppTheme.buildWelkTheme(
      isDark: false,
      accent: AppTheme.presets.first.color,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<GlobalCache>.value(value: cache),
          Provider<GuoguanlaApi>.value(value: api),
          ChangeNotifierProvider<UserProvider>.value(value: userProvider),
          ChangeNotifierProvider<UpdateProvider>.value(value: updateProvider),
        ],
        child: WelkTheme(
          data: welk,
          child: MaterialApp(
            theme: AppTheme.buildMaterialTheme(isDark: false, welk: welk),
            home: HomeTabPage(refreshSignal: refreshSignal),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    // Auto-announcement popped once for v1.0.14+114 (notice strip tag + dialog title)
    expect(find.text('学习公告'), findsNWidgets(2));
    expect(find.text('我知道了'), findsOneWidget);
    expect(find.text('测试公告内容 v1.0.14'), findsNWidgets(2));
    expect(cache.lastAnnouncementVersion, '1.0.14+114');

    await tester.tap(find.text('我知道了'));
    await tester.pumpAndSettle();

    // Dialog dismissed (only notice strip remains) and should not pop again on refresh within same version
    expect(find.text('我知道了'), findsNothing);
    expect(find.text('学习公告'), findsOneWidget);
    expect(find.text('测试公告内容 v1.0.14'), findsOneWidget);
    refreshSignal.value++;
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('我知道了'), findsNothing);

    // Home renders AI smart board card, 3-column grade grid and removed old 章节闯关 & 学习体系
    expect(find.text('AI 智能手写画板'), findsOneWidget);
    expect(find.text('拍照识题'), findsOneWidget);
    expect(find.text('选择年级'), findsOneWidget);
    expect(find.text('章节闯关'), findsNothing);
    expect(find.text('学习体系'), findsNothing);
    expect(find.text('初一'), findsWidgets);
    expect(find.text('高三'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('继续学习'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('继续学习'), findsOneWidget);

    final grid = tester.widget<GridView>(find.byType(GridView).first);
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 3);
  });

  testWidgets('GradeChaptersPage renders chapters in a 2-column grid', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final cache = await GlobalCache.init();
    final api = _FakeGuoguanlaApi();
    final userProvider = UserProvider(storage: cache, api: api);
    final welk = AppTheme.buildWelkTheme(
      isDark: false,
      accent: AppTheme.presets.first.color,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<GlobalCache>.value(value: cache),
          Provider<GuoguanlaApi>.value(value: api),
          ChangeNotifierProvider<UserProvider>.value(value: userProvider),
        ],
        child: WelkTheme(
          data: welk,
          child: MaterialApp(
            theme: AppTheme.buildMaterialTheme(isDark: false, welk: welk),
            home: GradeChaptersPage(grade: GradeItem.fallbacks.first),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('初一 · 章节闯关'), findsOneWidget);
    expect(find.text('第1章 有理数'), findsOneWidget);
    expect(find.text('第2章 整式的加减'), findsOneWidget);

    final grid = tester.widget<GridView>(find.byType(GridView).first);
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
  });

  testWidgets(
      'SmartBoardPage hides highlighter/model name, opens 画布操作 menu, renders AI cards with UI library & pure answer top',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final cache = await GlobalCache.init();
    final api = _FakeGuoguanlaApi();
    final themeProvider = ThemeProvider(cache);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<GlobalCache>.value(value: cache),
          Provider<GuoguanlaApi>.value(value: api),
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ],
        child: Consumer<ThemeProvider>(
          builder: (context, theme, _) => WelkTheme(
            data: theme.welkTheme,
            child: WiredThemeScope(
              data: theme.skribbleTheme,
              child: MaterialApp(
                theme: theme.materialTheme,
                home: const SmartBoardPage(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('拍照'), findsOneWidget);
    expect(find.text('思路'), findsOneWidget);
    expect(find.text('诊断'), findsOneWidget);
    expect(find.text('解题'), findsOneWidget);
    expect(find.text('画布操作'), findsOneWidget);
    // 已去除荧光与 LongCat-2.5 模型展示
    expect(find.text('荧光'), findsNothing);
    expect(find.text('LongCat-2.5'), findsNothing);

    // 点击「画布操作」展示橡皮、移动、撤销、清笔迹
    await tester.tap(find.text('画布操作'));
    await tester.pumpAndSettle();
    expect(find.text('橡皮'), findsOneWidget);
    expect(find.text('移动'), findsOneWidget);
    expect(find.text('撤销'), findsOneWidget);
    expect(find.text('清笔迹'), findsOneWidget);

    // 关闭菜单并手动录入数学题
    await tester.tap(find.text('画布操作').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('拍照'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('手动输入 / 编辑题干'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).last,
      r'解方程 $x^2 - 5x + 6 = 0$',
    );
    await tester.tap(find.text('保存到画板'));
    await tester.pumpAndSettle();

    // 触发 AI 思路（UI 库面板展示，不泄露答案）
    await tester.tap(find.text('思路'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('立即显示'), findsOneWidget);
    await tester.tap(find.text('立即显示'));
    await tester.pumpAndSettle();
    expect(find.text('引导思路（不含答案）'), findsOneWidget);
    expect(find.text('重播'), findsOneWidget);

    // 触发 AI 解题（顶部纯粹答案，下方解题思路）
    await tester.tap(find.text('解题').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('立即显示'));
    await tester.pumpAndSettle();
    expect(find.text('答案'), findsOneWidget);
    expect(find.text('解题思路'), findsOneWidget);
    // 验证纯答案位置严格位于「解题思路」上方
    final answerTop = tester.getTopLeft(find.text('答案')).dy;
    final ideaTop = tester.getTopLeft(find.text('解题思路')).dy;
    expect(answerTop, lessThan(ideaTop));
  });

  testWidgets(
      'SmartBoardPage renders compact single-row toolbar in phone landscape with large canvas',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final cache = await GlobalCache.init();
    final api = _FakeGuoguanlaApi();
    final themeProvider = ThemeProvider(cache);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<GlobalCache>.value(value: cache),
          Provider<GuoguanlaApi>.value(value: api),
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ],
        child: Consumer<ThemeProvider>(
          builder: (context, theme, _) => WelkTheme(
            data: theme.welkTheme,
            child: WiredThemeScope(
              data: theme.skribbleTheme,
              child: MaterialApp(
                theme: theme.materialTheme,
                home: const SmartBoardPage(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('竖屏'), findsOneWidget);
    expect(find.text('大画布'), findsOneWidget);
    expect(find.text('画布操作'), findsOneWidget);
    expect(find.text('拍照'), findsOneWidget);
    expect(find.text('思路'), findsOneWidget);
    expect(find.text('诊断'), findsOneWidget);
    expect(find.text('解题'), findsOneWidget);

    // Toggle immersive big-canvas mode hides bottom dock cleanly
    await tester.tap(find.text('大画布'));
    await tester.pumpAndSettle();
    expect(find.text('显底栏'), findsOneWidget);
    expect(find.text('钢笔'), findsNothing);
  });

  testWidgets(
      'ProfilePage removes 修仙境界 and supports binding phone & email without verification',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final cache = await GlobalCache.init();
    final api = _FakeGuoguanlaApi();
    final userProvider = UserProvider(storage: cache, api: api);
    final themeProvider = ThemeProvider(cache);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<GlobalCache>.value(value: cache),
          Provider<GuoguanlaApi>.value(value: api),
          ChangeNotifierProvider<UserProvider>.value(value: userProvider),
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ],
        child: Consumer<ThemeProvider>(
          builder: (context, theme, _) => WelkTheme(
            data: theme.welkTheme,
            child: WiredThemeScope(
              data: theme.skribbleTheme,
              child: MaterialApp(
                theme: theme.materialTheme,
                home: const ProfilePage(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('当前修仙境界'), findsNothing);
    expect(find.text('绑定手机号'), findsOneWidget);
    expect(find.text('绑定邮箱'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), '13812345678');
    await tester.enterText(find.byType(TextField).at(2), 'math@example.com');
    await tester.tap(find.text('保存资料'));
    await tester.pumpAndSettle();

    expect(api.lastSavedPhone, '13812345678');
    expect(api.lastSavedEmail, 'math@example.com');
  });

  testWidgets(
      'SmartBoardPage enforces problem-first gate, upgrades problem editor with live preview, and auto-saves/restores records by problem title',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final cache = await GlobalCache.init();
    final api = _FakeGuoguanlaApi();
    final themeProvider = ThemeProvider(cache);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<GlobalCache>.value(value: cache),
          Provider<GuoguanlaApi>.value(value: api),
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ],
        child: Consumer<ThemeProvider>(
          builder: (context, theme, _) => WelkTheme(
            data: theme.welkTheme,
            child: WiredThemeScope(
              data: theme.skribbleTheme,
              child: MaterialApp(
                theme: theme.materialTheme,
                home: const SmartBoardPage(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. 未识题前，点击「思路」「解题」必须被拦截，不得发起 AI 调用
    await tester.tap(find.text('思路'));
    await tester.pumpAndSettle();
    expect(api.ideasCallCount, 0);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.text('解题'));
    await tester.pumpAndSettle();
    expect(api.solveCallCount, 0);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // 2. 空画板点击「手写识题」应被本地极速预检拦截
    expect(find.text('手写识题'), findsOneWidget);
    await tester.tap(find.text('手写识题'));
    await tester.pumpAndSettle();
    expect(api.recognizeCallCount, 0);

    // 等待顶部提示条自动收起，避免遮挡顶栏按钮
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // 3. 打开编辑题目抽屉，验证快捷公式插入按钮与实时公式预览
    await tester.tap(find.text('拍照'));
    await tester.pumpAndSettle();
    expect(find.text('识别画板手写题目'), findsOneWidget);
    await tester.tap(find.text('手动输入 / 编辑题干'));
    await tester.pumpAndSettle();

    expect(find.text('分式'), findsOneWidget);
    expect(find.text('根号'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).first,
      '椭圆标准方程',
    );
    await tester.enterText(
      find.byType(TextField).last,
      '（1）\$\\dfrac{x^2}{2}+y^2=1\$',
    );
    await tester.pumpAndSettle();
    expect(find.text('实时公式渲染预览'), findsOneWidget);
    await tester.ensureVisible(find.text('保存到画板'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存到画板'));
    await tester.pumpAndSettle();

    // 4. 识别/录入题目后可正常触发 AI 思路，且画板以题目标题自动保存
    await tester.tap(find.text('思路'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(api.ideasCallCount, 1);
    await tester.tap(find.text('立即显示'));
    await tester.pumpAndSettle();

    expect(cache.smartBoardRecords.length, 1);
    expect(cache.smartBoardRecords.first['title'], '椭圆标准方程');
    expect(find.text('记录(1)'), findsOneWidget);

    // 5. 打开「记录(1)」新建画板后再恢复「椭圆标准方程」
    await tester.tap(find.text('记录(1)'));
    await tester.pumpAndSettle();
    expect(find.text('已保存画板（1）'), findsOneWidget);
    expect(find.text('已思路'), findsOneWidget);

    await tester.tap(find.text('新建画板'));
    await tester.pumpAndSettle();
    expect(find.text('引导思路（不含答案）'), findsNothing);

    await tester.tap(find.text('记录(1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('椭圆标准方程').last);
    await tester.pumpAndSettle();
    expect(find.text('引导思路（不含答案）'), findsOneWidget);
  });

  testWidgets(
      'Switching UI skin to Skribble switches buttons and inputs to Wired widgets on LoginPage & HomeTabPage',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'ggl_ui_skin': 'skribble',
    });
    final cache = await GlobalCache.init();
    final api = _FakeGuoguanlaApi();
    final userProvider = UserProvider(storage: cache, api: api);
    final themeProvider = ThemeProvider(cache);
    expect(themeProvider.isSkribble, isTrue);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<GlobalCache>.value(value: cache),
          Provider<GuoguanlaApi>.value(value: api),
          ChangeNotifierProvider<UserProvider>.value(value: userProvider),
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ],
        child: Consumer<ThemeProvider>(
          builder: (context, theme, _) => WelkTheme(
            data: theme.welkTheme,
            child: WiredThemeScope(
              data: theme.skribbleTheme,
              child: MaterialApp(
                theme: theme.materialTheme,
                home: const LoginPage(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WiredAppBar), findsOneWidget);
    expect(find.byType(WiredInput), findsNWidgets(2));
    expect(find.byType(WiredCheckbox), findsOneWidget);
    expect(find.byType(WiredElevatedButton), findsOneWidget);
    expect(find.byType(WelkButton), findsNothing);
    expect(find.byType(WelkInput), findsNothing);
    expect(find.byType(WelkCheckBox), findsNothing);
  });

  testWidgets(
      'Forui skin replaces WelkAccordion on AboutPage, shows Forui on MineTabPage, and supports cross-grade CTA on QuizPage',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'ggl_ui_skin': 'forui',
    });
    PackageInfo.setMockInitialValues(
      appName: '过关啦',
      packageName: 'com.guoguanla.app',
      version: '2.3.0',
      buildNumber: '230',
      buildSignature: '',
    );
    final cache = await GlobalCache.init();
    final api = _FakeGuoguanlaApi();
    final userProvider = UserProvider(storage: cache, api: api);
    final themeProvider = ThemeProvider(cache);
    final updateProvider = UpdateProvider(api);
    final refreshSignal = ValueNotifier<int>(0);
    addTearDown(refreshSignal.dispose);
    expect(themeProvider.isForui, isTrue);

    Widget wrapForui(Widget home) => MultiProvider(
          providers: [
            Provider<GlobalCache>.value(value: cache),
            Provider<GuoguanlaApi>.value(value: api),
            ChangeNotifierProvider<UserProvider>.value(value: userProvider),
            ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
            ChangeNotifierProvider<UpdateProvider>.value(value: updateProvider),
          ],
          child: Consumer<ThemeProvider>(
            builder: (context, theme, _) => WelkTheme(
              data: theme.welkTheme,
              child: WiredThemeScope(
                data: theme.skribbleTheme,
                child: FTheme(
                  data: theme.foruiTheme,
                  child: MaterialApp(
                    theme: theme.materialTheme,
                    home: home,
                  ),
                ),
              ),
            ),
          ),
        );

    // 1. AboutPage renders studio/ICP info + FAccordion (no WelkAccordion, no cultivation copy, no private ID/phone)
    await tester.pumpWidget(wrapForui(const AboutPage()));
    await tester.pumpAndSettle();
    expect(find.text('开发与运营主体'), findsOneWidget);
    expect(find.text('深圳市龙华区云篆科技工作室'), findsOneWidget);
    expect(find.text('广东省深圳市龙华区'), findsOneWidget);
    expect(find.text('粤ICP备2026130477号'), findsOneWidget);
    expect(find.text('92440300MAKMC5Q40P'), findsOneWidget);
    expect(find.text('gonglanglang2019@163.com'), findsOneWidget);
    expect(find.textContaining(RegExp(r'\b\d{17}[\dXx]\b')), findsNothing);
    expect(find.textContaining(RegExp(r'\b1[3-9]\d{9}\b')), findsNothing);

    await tester.scrollUntilVisible(
      find.text('AI 智能画板与隐私保护'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.byType(FAccordion), findsNWidgets(3));
    expect(find.byType(WelkAccordion), findsNothing);
    expect(find.text('学习规则与说明'), findsOneWidget);
    expect(find.textContaining('修仙'), findsNothing);

    // 2. MineTabPage shows "Forui · ..." instead of mislabeling WelkUI
    await tester.pumpWidget(wrapForui(MineTabPage(refreshSignal: refreshSignal)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Forui · '), findsOneWidget);
    expect(find.text('学习阶段'), findsOneWidget);
    expect(find.text('境界体系'), findsNothing);

    // 3. QuizPage shows cross-grade CTA when finishing final gate of 初一
    await tester.pumpWidget(
      wrapForui(
        const QuizPage(mode: QuizMode.gate, gateId: 901, gateSeq: 4),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('提交答案'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成交卷'));
    await tester.pumpAndSettle();
    expect(find.text('进入初二 · 第 1 关'), findsOneWidget);
    expect(find.textContaining('即将开启初二'), findsOneWidget);
  });

  testWidgets(
      'TASK-20261126-003 LoginPage register loads/refreshes graphic captcha and submits captchaKey + captchaCode',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final cache = await GlobalCache.init();
    final api = _FakeGuoguanlaApi();
    final userProvider = UserProvider(storage: cache, api: api);
    final welk = AppTheme.buildWelkTheme(
      isDark: false,
      accent: AppTheme.presets.first.color,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<GlobalCache>.value(value: cache),
          Provider<GuoguanlaApi>.value(value: api),
          ChangeNotifierProvider<UserProvider>.value(value: userProvider),
        ],
        child: WelkTheme(
          data: welk,
          child: MaterialApp(
            theme: AppTheme.buildMaterialTheme(isDark: false, welk: welk),
            home: const LoginPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('注册'));
    await tester.pumpAndSettle();
    expect(api.captchaCallCount, 1);
    final captchaImage =
        find.byWidgetPredicate((w) => w is Image && w.image is MemoryImage);
    expect(captchaImage, findsOneWidget);

    // 点击图形验证码图片应刷新验证码
    await tester.ensureVisible(captchaImage);
    await tester.pumpAndSettle();
    await tester.tap(captchaImage);
    await tester.pumpAndSettle();
    expect(api.captchaCallCount, 2);

    // 填写注册信息（用户名、昵称、密码、图形验证码）并选择所在年级
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(4));
    await tester.enterText(fields.at(0), 'newstu01');
    await tester.enterText(fields.at(1), '云篆同学');
    await tester.enterText(fields.at(2), 'abc123456');
    await tester.enterText(fields.at(3), 'ab7k');
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('初一'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('初一'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('注册并开始学习'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('注册并开始学习'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(api.registerCallCount, 1);
    expect(api.lastCaptchaKey, 'cap_test_2');
    expect(api.lastCaptchaCode, 'ab7k');
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets(
      'TASK-20261126-003 SmartBoardPage auto-clears handwriting after recognize, renders vector diagram redraw and stamps to canvas',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final cache = await GlobalCache.init();
    final api = _FakeGuoguanlaApi();
    final themeProvider = ThemeProvider(cache);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<GlobalCache>.value(value: cache),
          Provider<GuoguanlaApi>.value(value: api),
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ],
        child: Consumer<ThemeProvider>(
          builder: (context, theme, _) => WelkTheme(
            data: theme.welkTheme,
            child: WiredThemeScope(
              data: theme.skribbleTheme,
              child: MaterialApp(
                theme: theme.materialTheme,
                home: const SmartBoardPage(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 在画板中央绘制清晰多笔画手写题干（满足 BoardHandwritingValidator）
    Future<void> drawStroke(Offset start, Offset end) async {
      final g = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 16));
      await g.moveTo(Offset.lerp(start, end, 0.5)!);
      await tester.pump(const Duration(milliseconds: 16));
      await g.moveTo(end);
      await tester.pump(const Duration(milliseconds: 16));
      await g.up();
      await tester.pump(const Duration(milliseconds: 16));
    }

    await drawStroke(const Offset(220, 220), const Offset(280, 220));
    await drawStroke(const Offset(250, 195), const Offset(250, 255));
    await drawStroke(const Offset(310, 200), const Offset(350, 255));
    await drawStroke(const Offset(350, 200), const Offset(310, 255));
    await drawStroke(const Offset(380, 220), const Offset(430, 220));
    await drawStroke(const Offset(380, 238), const Offset(430, 238));
    await tester.pumpAndSettle();

    // 点击「手写识题」：应调用识题接口、自动清掉原手写笔迹，并展示矢量重绘配图与「画到白板」按钮
    await tester.tap(find.text('手写识题'));
    await tester.pump();
    // 等待异步离屏 PNG 编码与识题响应完成
    for (var i = 0; i < 15 && api.recognizeCallCount == 0; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(api.recognizeCallCount, 1);
    expect(find.text('题目配图（矢量重绘）'), findsOneWidget);
    expect(find.text('画到白板'), findsOneWidget);

    // 识题后手写笔迹已被自动清空：此时再次点击「手写识题」应被空画板预检拦截，不会重复调用接口
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('手写识题'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(api.recognizeCallCount, 1);

    // 点击「画到白板」将矢量重绘几何图绘制到白板画布
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('画到白板'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('已将矢量图形绘制到白板'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}

class _FakeGuoguanlaApi extends GuoguanlaApi {
  static const String _tinyPngBase64 =
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

  String? lastSavedPhone;
  String? lastSavedEmail;
  String? lastCaptchaKey;
  String? lastCaptchaCode;
  int captchaCallCount = 0;
  int registerCallCount = 0;
  int recognizeCallCount = 0;
  int ideasCallCount = 0;
  int solveCallCount = 0;

  _FakeGuoguanlaApi()
      : super(
          ApiClient(
            baseUrl: 'http://127.0.0.1:9999/api',
            tokenGetter: () => '',
            revisionGetter: () => 0,
          ),
        );

  @override
  Future<CaptchaChallenge> getRegisterCaptcha() async {
    captchaCallCount++;
    return CaptchaChallenge(
      captchaKey: 'cap_test_$captchaCallCount',
      imageBase64: _tinyPngBase64,
      expireSeconds: 300,
    );
  }

  @override
  Future<AuthResult> register({
    required String username,
    required String password,
    required String nickname,
    required String gradeCode,
    required String captchaKey,
    required String captchaCode,
    List<int>? guestPassedGateIds,
  }) async {
    registerCallCount++;
    lastCaptchaKey = captchaKey;
    lastCaptchaCode = captchaCode;
    return AuthResult(
      token: 'fake_reg_token',
      profile: AppUserProfile(
        id: 2,
        username: username,
        phone: '',
        email: '',
        nickname: nickname,
        avatarUrl: '',
        gradeCode: gradeCode,
        gradeName: '初一',
        realmCode: 'lianqi',
        realmName: '初一',
        realmOrder: 1,
        difficultyLabel: '基础入门',
        realmPassedGates: 0,
        realmTotalGates: 40,
        examUnlockGates: 40,
        examRemainingGates: 40,
        examEligible: false,
        examQuestionCount: 5,
        examPassScore: 60,
        passedGateCount: 0,
      ),
    );
  }

  @override
  Future<AppUserProfile> getProfile() async {
    return const AppUserProfile(
      id: 1,
      username: 'stu_demo',
      phone: '',
      email: '',
      nickname: '小测同学',
      avatarUrl: '',
      gradeCode: 'g8',
      gradeName: '初二',
      realmCode: 'zhuji',
      realmName: '筑基',
      realmOrder: 2,
      difficultyLabel: '难度二',
      realmPassedGates: 3,
      realmTotalGates: 40,
      examUnlockGates: 40,
      examRemainingGates: 37,
      examEligible: false,
      examQuestionCount: 5,
      examPassScore: 60,
      passedGateCount: 3,
    );
  }

  @override
  Future<AppUserProfile> updateProfile({
    required String nickname,
    String? avatarUrl,
    String? phone,
    String? email,
  }) async {
    lastSavedPhone = phone;
    lastSavedEmail = email;
    return AppUserProfile(
      id: 1,
      username: 'stu_demo',
      phone: phone ?? '',
      email: email ?? '',
      nickname: nickname,
      avatarUrl: avatarUrl ?? '',
      gradeCode: 'g8',
      gradeName: '初二',
      realmCode: 'zhuji',
      realmName: '筑基',
      realmOrder: 2,
      difficultyLabel: '难度二',
      realmPassedGates: 3,
      realmTotalGates: 40,
      examUnlockGates: 40,
      examRemainingGates: 37,
      examEligible: false,
      examQuestionCount: 5,
      examPassScore: 60,
      passedGateCount: 3,
    );
  }

  @override
  Future<HomeSummary> getHomeSummary({List<int>? guestPassedIds}) async {
    return const HomeSummary(
      guestModeEnabled: true,
      appNotice: '测试公告内容 v1.0.14',
      grades: GradeItem.fallbacks,
      realms: RealmItem.defaults,
    );
  }

  final List<int> startedGateIds = <int>[];

  @override
  Future<QuizStartResult> startGateQuiz({
    required int gateId,
    List<int>? guestPassedGateIds,
  }) async {
    startedGateIds.add(gateId);
    if (gateId == 901) {
      return const QuizStartResult(
        sessionNo: 'QZ-GATE-G7-LAST',
        mode: 'GATE',
        realmCode: 'lianqi',
        realmName: '初一',
        suppressedMode: false,
        chapterId: 10,
        chapterName: '第10章 数据的收集、整理与描述',
        gateId: 901,
        gateName: '综合压轴',
        star: 4,
        passCount: 1,
        totalCount: 1,
        guestMode: true,
        items: [
          ClientQuestionItem(
            itemIndex: 0,
            questionFormat: 'SINGLE_CHOICE',
            stem: '初一最后一关测试题：3 + 2 = ?',
            options: ['5', '6', '7', '8'],
          ),
        ],
      );
    }
    if (gateId == 102) {
      return const QuizStartResult(
        sessionNo: 'QZ-GATE-102',
        mode: 'GATE',
        suppressedMode: false,
        chapterId: 11,
        chapterName: '第11章 三角形',
        gateId: 102,
        gateName: '进阶关',
        star: 2,
        passCount: 1,
        totalCount: 1,
        guestMode: true,
        items: [
          ClientQuestionItem(
            itemIndex: 0,
            questionFormat: 'SINGLE_CHOICE',
            stem: '第二关题目：等腰三角形顶角为 80°，底角为多少？',
            options: ['50°', '40°', '80°', '60°'],
          ),
        ],
      );
    }
    return const QuizStartResult(
      sessionNo: 'QZ-GATE-101',
      mode: 'GATE',
      suppressedMode: false,
      chapterId: 11,
      chapterName: '第11章 三角形',
      gateId: 101,
      gateName: '基础关',
      star: 1,
      passCount: 1,
      totalCount: 1,
      guestMode: true,
      items: [
        ClientQuestionItem(
          itemIndex: 0,
          questionFormat: 'SINGLE_CHOICE',
          stem: '如图，在 Rt△ABC 中，∠C=90°，AC=3，BC=4，则 AB=',
          options: ['5', '6', '7', '25'],
          diagram: BoardDiagramSpec(
            title: '直角三角形 Rt△ABC',
            width: 300,
            height: 190,
            primitives: [
              DiagramPrimitive(
                type: 'polygon',
                points: [
                  [60, 150],
                  [230, 150],
                  [60, 40],
                ],
                fillColor: '#38BDF8',
              ),
              DiagramPrimitive(
                type: 'rightangle',
                vx: 60,
                vy: 150,
                ax: 230,
                ay: 150,
                bx: 60,
                by: 40,
                size: 14,
              ),
              DiagramPrimitive(
                type: 'arc',
                cx: 230,
                cy: 150,
                r: 22,
                startAngle: 180,
                sweepAngle: 33,
                color: '#DC2626',
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Future<CheckItemResult> checkItem({
    required String sessionNo,
    required int itemIndex,
    int? selectedIndex,
    String? answerText,
    String? answerImageKey,
    bool? selfCorrect,
  }) async {
    return CheckItemResult(
      itemIndex: itemIndex,
      questionFormat: 'SINGLE_CHOICE',
      correct: selectedIndex == 0,
      correctIndex: 0,
      pendingReview: false,
      analysis: '由勾股定理可得 AB = 5',
    );
  }

  @override
  Future<SubmitResult> submitGateQuiz({
    required String sessionNo,
    required List<AnswerSubmitPayload> answers,
    List<int>? guestPassedGateIds,
  }) async {
    if (sessionNo == 'QZ-GATE-G7-LAST') {
      return const SubmitResult(
        sessionNo: 'QZ-GATE-G7-LAST',
        mode: 'GATE',
        totalCount: 1,
        correctCount: 1,
        passCount: 1,
        passed: true,
        newlyPassed: true,
        totalPassedGates: 40,
        wrongItems: [],
        masteredCount: 0,
        nextGateId: 102,
        nextGateIndex: 0,
        nextGateName: '基础关',
        nextChapterId: 11,
        nextChapterName: '第11章 三角形',
        nextGateCrossChapter: true,
        nextGradeCode: 'g8',
        nextGradeName: '初二',
        nextGateCrossGrade: true,
      );
    }
    return SubmitResult(
      sessionNo: sessionNo,
      mode: 'GATE',
      totalCount: 1,
      correctCount: 1,
      passCount: 1,
      passed: true,
      newlyPassed: true,
      totalPassedGates: 1,
      wrongItems: const [],
      masteredCount: 0,
      nextGateId: sessionNo == 'QZ-GATE-101' ? 102 : null,
      nextGateIndex: sessionNo == 'QZ-GATE-101' ? 1 : null,
      nextGateName: sessionNo == 'QZ-GATE-101' ? '进阶关' : null,
      nextChapterId: 11,
      nextChapterName: '第11章 三角形',
      nextGateCrossChapter: false,
    );
  }

  @override
  Future<List<ChapterCard>> getChaptersByRealm(
    String realmCode, {
    List<int>? guestPassedIds,
  }) async {
    return _demoChapters;
  }

  @override
  Future<List<ChapterCard>> getChaptersByGrade(
    String gradeCode, {
    List<int>? guestPassedIds,
  }) async {
    return _demoChapters;
  }

  @override
  Future<AiBoardStatus> getAiBoardStatus() async {
    return const AiBoardStatus(
      enabled: true,
      configured: true,
      modelName: 'LongCat-2.5',
      supportsVision: true,
      message: 'AI 智能画板已就绪',
    );
  }

  @override
  Future<AiRecognizeResult> recognizeMathProblem({
    required Uint8List imageBytes,
    required String filename,
    String? extraHint,
    String sourceType = 'PHOTO',
  }) async {
    recognizeCallCount++;
    return const AiRecognizeResult(
      title: '三角形中线长度求解',
      problemText: '如图，△ABC 中，AD 为 BC 的中线，已知 AB、AC 及 ∠A，求中线 AD 长。',
      subjectTag: '初中几何',
      questionType: '解答题',
      difficulty: '中等',
      diagrams: [
        BoardDiagramSpec(
          title: '△ABC 与中线 AD',
          width: 320,
          height: 210,
          primitives: [
            DiagramPrimitive(
              type: 'polygon',
              points: [
                [112, 34],
                [56, 174],
                [262, 174],
              ],
              color: '#1E293B',
            ),
            DiagramPrimitive(
              type: 'line',
              x1: 112,
              y1: 34,
              x2: 159,
              y2: 174,
              color: '#2563EB',
            ),
            DiagramPrimitive(type: 'point', x: 112, y: 34, label: 'A'),
            DiagramPrimitive(type: 'point', x: 56, y: 174, label: 'B'),
            DiagramPrimitive(type: 'point', x: 262, y: 174, label: 'C'),
            DiagramPrimitive(type: 'point', x: 159, y: 174, label: 'D'),
          ],
        ),
      ],
    );
  }

  @override
  Future<AiBoardGuidance> generateBoardIdeas({
    String? problemText,
    String? boardImageBase64,
    String? problemImageBase64,
    String? userNotes,
    bool hasHandwriting = false,
  }) async {
    ideasCallCount++;
    return const AiBoardGuidance(
      mode: 'IDEAS',
      headline: '十字相乘法破题',
      summary: '寻找两数乘积为 6 且和为 -5。',
      knowledgePoints: ['因式分解'],
      steps: [
        AiBoardStep(
          stepNo: 1,
          title: '拆分常数项',
          content: '将 6 拆分为 (-2) × (-3)',
          formula: r'$(x-2)(x-3)=0$',
        ),
      ],
      finalAnswer: '',
    );
  }

  @override
  Future<AiBoardGuidance> solveBoardProblem({
    String? problemText,
    String? boardImageBase64,
    String? problemImageBase64,
    String? userNotes,
  }) async {
    solveCallCount++;
    return const AiBoardGuidance(
      mode: 'SOLVE',
      headline: '规范分步求解',
      summary: '因式分解法一步到位。',
      knowledgePoints: ['一元二次方程'],
      steps: [
        AiBoardStep(
          stepNo: 1,
          title: '因式分解',
          content: '左端分解为两个一次因式之积',
          formula: r'$(x-2)(x-3)=0$',
        ),
        AiBoardStep(
          stepNo: 2,
          title: '求解两根',
          content: r'得 $x-2=0$ 或 $x-3=0$',
          formula: r'$x_1=2,\; x_2=3$',
        ),
      ],
      finalAnswer: r'$x_1=2,\; x_2=3$',
      diagrams: [
        BoardDiagramSpec(
          title: '抛物线零点草图',
          primitives: [
            DiagramPrimitive(type: 'arrow', x1: 20, y1: 170, x2: 300, y2: 170),
            DiagramPrimitive(
              type: 'polyline',
              points: [
                [60, 80],
                [160, 190],
                [260, 80],
              ],
              color: '#2563EB',
            ),
          ],
        ),
      ],
    );
  }

  static const List<ChapterCard> _demoChapters = <ChapterCard>[
    ChapterCard(
      id: 1,
      chapterCode: 'c1',
      gradeCode: 'g7',
      realmCode: 'lianqi',
      realmName: '练气',
      realmOrder: 1,
      name: '第1章 有理数',
      description: '正负数与数轴',
      isCustom: 0,
      passedCount: 2,
      totalGates: 4,
      lockedByRealm: false,
      suppressed: false,
    ),
    ChapterCard(
      id: 2,
      chapterCode: 'c2',
      gradeCode: 'g7',
      realmCode: 'lianqi',
      realmName: '练气',
      realmOrder: 1,
      name: '第2章 整式的加减',
      description: '单项式与多项式',
      isCustom: 0,
      passedCount: 0,
      totalGates: 4,
      lockedByRealm: false,
      suppressed: false,
    ),
  ];
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  Duration? lastSeekPosition;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async => 1;

  @override
  Future<void> dispose(int playerId) async {}

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    lastSeekPosition = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async =>
      lastSeekPosition ?? const Duration(seconds: 30);

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => Stream<VideoEvent>.value(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(minutes: 5),
          size: const Size(1280, 720),
        ),
      );

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.shrink();
}
