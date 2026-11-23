import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import 'app/app_config.dart';
import 'core/cache/global_cache.dart';
import 'core/network/api_client.dart';
import 'pages/main_shell_page.dart';
import 'providers/theme_provider.dart';
import 'providers/update_provider.dart';
import 'providers/user_provider.dart';
import 'services/guoguanla_api.dart';
import 'widgets/app_update_dialog.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
  }
  final cache = await GlobalCache.init();
  runApp(GuoguanlaApp(storage: cache));
}

class GuoguanlaApp extends StatefulWidget {
  const GuoguanlaApp({
    super.key,
    required this.storage,
    this.apiBaseUrlOverride,
  });

  final GlobalCache storage;
  final String? apiBaseUrlOverride;

  @override
  State<GuoguanlaApp> createState() => _GuoguanlaAppState();
}

class _GuoguanlaAppState extends State<GuoguanlaApp> {
  late final ApiClient _apiClient;
  late final GuoguanlaApi _api;
  late final ThemeProvider _themeProvider;
  late final UserProvider _userProvider;
  late final UpdateProvider _updateProvider;

  @override
  void initState() {
    super.initState();
    late UserProvider userHolder;
    final initialBaseUrl = widget.apiBaseUrlOverride ??
        widget.storage.customApiBaseUrl ??
        AppConfig.defaultApiBaseUrl;

    _apiClient = ApiClient(
      baseUrl: initialBaseUrl,
      tokenGetter: () => userHolder.accessToken,
      revisionGetter: () => userHolder.sessionRevision,
      onUnauthorized: () {
        userHolder.resetSession();
      },
    );
    _api = GuoguanlaApi(_apiClient);
    _themeProvider = ThemeProvider(widget.storage);
    _userProvider = UserProvider(storage: widget.storage, api: _api);
    userHolder = _userProvider;
    _updateProvider = UpdateProvider(_api);
  }

  @override
  void dispose() {
    _themeProvider.dispose();
    _userProvider.dispose();
    _updateProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<GlobalCache>.value(value: widget.storage),
        Provider<ApiClient>.value(value: _apiClient),
        Provider<GuoguanlaApi>.value(value: _api),
        ChangeNotifierProvider<ThemeProvider>.value(value: _themeProvider),
        ChangeNotifierProvider<UserProvider>.value(value: _userProvider),
        ChangeNotifierProvider<UpdateProvider>.value(value: _updateProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          return WelkTheme(
            data: theme.welkTheme,
            child: MaterialApp(
              navigatorKey: rootNavigatorKey,
              title: AppConfig.appName,
              debugShowCheckedModeBanner: false,
              theme: theme.materialTheme,
              locale: const Locale('zh', 'CN'),
              supportedLocales: const [
                Locale('zh', 'CN'),
                Locale('en', 'US'),
              ],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) {
                return Stack(
                  children: [
                    ?child,
                    const AppUpdateOverlay(),
                  ],
                );
              },
              home: const MainShellPage(),
            ),
          );
        },
      ),
    );
  }
}
