import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guoguanla_app/app/app_theme.dart';
import 'package:guoguanla_app/core/cache/global_cache.dart';
import 'package:guoguanla_app/core/network/api_client.dart';
import 'package:guoguanla_app/models/models.dart';
import 'package:guoguanla_app/pages/draw_answer/draw_answer_page.dart';
import 'package:guoguanla_app/pages/grade_chapters/grade_chapters_page.dart';
import 'package:guoguanla_app/pages/home/home_tab_page.dart';
import 'package:guoguanla_app/pages/login/login_page.dart';
import 'package:guoguanla_app/pages/profile/profile_page.dart';
import 'package:guoguanla_app/pages/settings/theme_settings_page.dart';
import 'package:guoguanla_app/pages/smart_board/smart_board_page.dart';
import 'package:guoguanla_app/providers/theme_provider.dart';
import 'package:guoguanla_app/providers/update_provider.dart';
import 'package:guoguanla_app/providers/user_provider.dart';
import 'package:guoguanla_app/services/guoguanla_api.dart';
import 'package:guoguanla_app/widgets/ggl_comic_panel.dart';
import 'package:guoguanla_app/widgets/math_text.dart';
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

    // 切换暗黑模式
    await tester.tap(find.byType(WiredSwitch));
    await tester.pumpAndSettle();
    expect(themeProvider.isDarkMode, isTrue);

    // 切换强调色
    await tester.tap(find.text('元气暖黄'));
    await tester.pumpAndSettle();
    expect(themeProvider.accentHex, '#FFDA57');
  });

  testWidgets('LoginPage switches between login and register with grade picker',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = await GlobalCache.init();
    final client = ApiClient(
      baseUrl: 'http://127.0.0.1:9999/api',
      tokenGetter: () => '',
      revisionGetter: () => 0,
    );
    final api = GuoguanlaApi(client);
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

    // Auto-announcement popped once for v1.0.14+114 (notice strip + dialog)
    expect(find.text('修炼公告'), findsOneWidget);
    expect(find.text('测试公告内容 v1.0.14'), findsNWidgets(2));
    expect(cache.lastAnnouncementVersion, '1.0.14+114');

    await tester.tap(find.text('我知道了'));
    await tester.pumpAndSettle();

    // Dialog dismissed (only notice strip remains) and should not pop again on refresh within same version
    expect(find.text('修炼公告'), findsNothing);
    expect(find.text('测试公告内容 v1.0.14'), findsOneWidget);
    refreshSignal.value++;
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('修炼公告'), findsNothing);

    // Home renders AI smart board card, 3-column grade grid and removed old 章节闯关
    expect(find.text('AI 智能手写画板'), findsOneWidget);
    expect(find.text('拍照识题'), findsOneWidget);
    expect(find.text('选择年级'), findsOneWidget);
    expect(find.text('章节闯关'), findsNothing);
    expect(find.text('初一'), findsOneWidget);
    expect(find.text('高三'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('继续修炼'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('继续修炼'), findsOneWidget);

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
}

class _FakeGuoguanlaApi extends GuoguanlaApi {
  String? lastSavedPhone;
  String? lastSavedEmail;

  _FakeGuoguanlaApi()
      : super(
          ApiClient(
            baseUrl: 'http://127.0.0.1:9999/api',
            tokenGetter: () => '',
            revisionGetter: () => 0,
          ),
        );

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
  Future<AiBoardGuidance> generateBoardIdeas({
    String? problemText,
    String? boardImageBase64,
    String? problemImageBase64,
    String? userNotes,
    bool hasHandwriting = false,
  }) async {
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
