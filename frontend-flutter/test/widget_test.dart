import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guoguanla_app/app/app_theme.dart';
import 'package:guoguanla_app/core/network/api_client.dart';
import 'package:guoguanla_app/core/storage/app_storage.dart';
import 'package:guoguanla_app/pages/draw_answer/draw_answer_page.dart';
import 'package:guoguanla_app/pages/login/login_page.dart';
import 'package:guoguanla_app/pages/settings/theme_settings_page.dart';
import 'package:guoguanla_app/providers/theme_provider.dart';
import 'package:guoguanla_app/providers/user_provider.dart';
import 'package:guoguanla_app/services/guoguanla_api.dart';
import 'package:guoguanla_app/widgets/ggl_comic_panel.dart';
import 'package:guoguanla_app/widgets/math_text.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  testWidgets('ThemeSettingsPage toggles dark mode and switches comic preset', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = await AppStorage.init();
    final themeProvider = ThemeProvider(storage);

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>.value(
        value: themeProvider,
        child: Consumer<ThemeProvider>(
          builder: (context, theme, _) => WelkTheme(
            data: theme.welkTheme,
            child: MaterialApp(
              theme: theme.materialTheme,
              home: const ThemeSettingsPage(),
            ),
          ),
        ),
      ),
    );

    expect(find.text('主题设置'), findsOneWidget);
    expect(find.text('暗黑漫画模式'), findsOneWidget);
    expect(themeProvider.isDarkMode, isFalse);

    await tester.tap(find.byType(WelkSwitch));
    await tester.pumpAndSettle();
    expect(themeProvider.isDarkMode, isTrue);

    await tester.tap(find.text('元气暖黄'));
    await tester.pumpAndSettle();
    expect(themeProvider.accentHex, '#FFDA57');
  });

  testWidgets('LoginPage switches between login and register with grade picker',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = await AppStorage.init();
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
          Provider<AppStorage>.value(value: storage),
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
}
