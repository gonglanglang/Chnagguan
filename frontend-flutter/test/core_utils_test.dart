import 'package:flutter_test/flutter_test.dart';
import 'package:guoguanla_app/app/app_theme.dart';
import 'package:guoguanla_app/core/cache/global_cache.dart';
import 'package:guoguanla_app/core/utils/format_utils.dart';
import 'package:guoguanla_app/core/utils/math_parser.dart';
import 'package:guoguanla_app/core/utils/update_utils.dart';
import 'package:guoguanla_app/models/models.dart';
import 'package:guoguanla_app/providers/theme_provider.dart';
import 'package:guoguanla_app/widgets/smart_board/board_handwriting_validator.dart';
import 'package:guoguanla_app/widgets/smart_board/board_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MathParser', () {
    test('parses inline LaTeX fraction, superscript, and Greek symbols', () {
      final tokens = MathParser.parseTokens(
        r'计算 $\frac{a^2 + 1}{2} \times \pi$',
      );
      expect(tokens.any((t) => t.type == MathTokenType.frac), isTrue);
      final frac = tokens.firstWhere((t) => t.type == MathTokenType.frac);
      expect(frac.num, 'a² + 1');
      expect(frac.den, '2');
      expect(
        MathParser.renderPlainText(r'计算 $\frac{a^2 + 1}{2} \times \pi$'),
        '计算 (a² + 1)/2 × π',
      );
    });

    test('parses radicals and cases cleanly', () {
      final plain = MathParser.renderPlainText(
        r'若 $\sqrt[3]{8} = 2$ 且 $x \in \emptyset$',
      );
      expect(plain, contains('³√(8)'));
      expect(plain, contains('∈'));
      expect(plain, contains('∅'));
    });

    test('parses dfrac, tfrac, nested sqrt inside fraction, sets and spacing commands without leaking raw backslashes',
        () {
      const sample = '（1）\$\\dfrac{x^2}{2}+y^2=1\$\n'
          '（2）\$k=\\pm\\dfrac{\\sqrt{10}}{2}\$';
      final tokens = MathParser.parseTokens(sample);
      final fracs = tokens.where((t) => t.type == MathTokenType.frac).toList();
      expect(fracs, hasLength(2));
      expect(fracs[0].num, 'x²');
      expect(fracs[0].den, '2');
      expect(fracs[0].numTokens.any((t) => t.type == MathTokenType.sup), isTrue);
      expect(fracs[1].den, '2');
      expect(fracs[1].numTokens.any((t) => t.type == MathTokenType.sqrt), isTrue);

      final plain = MathParser.renderPlainText(sample);
      expect(plain, isNot(contains(r'\dfrac')));
      expect(plain, isNot(contains(r'\sqrt')));
      expect(plain, contains('x²/2'));
      expect(plain, contains('k=±'));

      final extra = MathParser.renderPlainText(
        r'$\because \{x \mid x \leqslant \tfrac{1}{2}, \; x \in \mathbb{R}\} \therefore \sin x$',
      );
      expect(extra, isNot(contains(r'\')));
      expect(extra, contains('∵'));
      expect(extra, contains('{x'));
      expect(extra, contains('≤'));
      expect(extra, contains('1/2'));
      expect(extra, contains('ℝ'));
      expect(extra, contains('∴'));
      expect(extra, contains('sin'));
    });
  });

  group('UpdateUtils', () {
    test('identifies direct APK endpoints and rejects HTML release pages', () {
      expect(
        UpdateUtils.isDirectApkDownloadUrl(
          'http://47.107.94.90/api/app/version/download',
        ),
        isTrue,
      );
      expect(
        UpdateUtils.isDirectApkDownloadUrl(
          'https://oss.example.com/downloads/guoguanla-v1.0.13.apk?Expires=123',
        ),
        isTrue,
      );
      expect(
        UpdateUtils.isDirectApkDownloadUrl(
          'https://github.com/gonglanglang/Chnagguan/releases/tag/v1.0.13',
        ),
        isFalse,
      );
      expect(
        UpdateUtils.isDirectApkDownloadUrl('https://example.com/index.html'),
        isFalse,
      );
    });

    test('compares semantic versions and formats sizes accurately', () {
      expect(UpdateUtils.compareVersions('v1.0.14', '1.0.13'), 1);
      expect(UpdateUtils.compareVersions('1.0.13', '1.0.13'), 0);
      expect(UpdateUtils.compareVersions('1.0.12', '1.0.13'), -1);
      expect(UpdateUtils.formatUpdateByteSize(512), '1 KB');
      expect(UpdateUtils.formatUpdateByteSize(6 * 1024 * 1024), '6.0 MB');
      expect(UpdateUtils.computeDownloadPercent(50, 100), 50);
      expect(UpdateUtils.computeDownloadPercent(100, 100), 99);
    });

    test('splits multi-line and semicolon release notes', () {
      final notes = UpdateUtils.parseReleaseNotesList(
        '过关啦 v1.0.13 更新：1. 接入 WelkUI 漫画组件库；2. 升级横屏手写画板',
      );
      expect(notes.length, 2);
      expect(notes[0], contains('WelkUI'));
      expect(notes[1], contains('手写画板'));
    });
  });

  group('FormatUtils & Models', () {
    test('formats duration and file size', () {
      expect(FormatUtils.formatDuration(125), '02:05');
      expect(FormatUtils.formatFileSize(1536), '1.5 KB');
      expect(FormatUtils.shortDifficultyLabel('难度一 · 基础'), '基础');
    });

    test('formats wrong question correct answers for choice and essay', () {
      final choice = WrongQuestionItem.fromJson({
        'id': 1,
        'gradeCode': 'g7',
        'realmCode': 'lianqi',
        'realmName': '练气',
        'chapterName': '第1章 有理数',
        'gateName': '基础关',
        'questionFormat': 'SINGLE_CHOICE',
        'stem': '1 + 1 = ?',
        'options': ['1', '2', '3', '4'],
        'answerIndex': 1,
        'analysis': '基础加法',
        'wrongCount': 2,
        'lastWrongAt': '2026-11-23T12:00:00',
      });
      expect(choice.formattedCorrectAnswer(), 'B. 2');

      final essay = WrongQuestionItem.fromJson({
        'id': 2,
        'gradeCode': 'g9',
        'realmCode': 'jiedan',
        'realmName': '结丹',
        'chapterName': '第21章 一元二次方程',
        'gateName': '压轴关',
        'questionFormat': 'ESSAY',
        'stem': '解方程 x^2 - 1 = 0',
        'options': <String>[],
        'answerIndex': -1,
        'referenceAnswer': 'x = ±1',
        'analysis': '因式分解',
        'wrongCount': 1,
        'lastWrongAt': '2026-11-23T12:00:00',
      });
      expect(essay.formattedCorrectAnswer(), 'x = ±1');
    });
  });

  group('GlobalCache', () {
    test('registers all keys uniquely and preserves auth across update/clear',
        () async {
      final storageKeys = GlobalCache.registry.map((e) => e.storageKey).toList();
      expect(storageKeys.toSet().length, storageKeys.length);
      for (final key in storageKeys) {
        expect(key.startsWith('ggl_'), isTrue);
      }

      SharedPreferences.setMockInitialValues(<String, Object>{
        'temp_orphan_key': 'removable',
      });
      final cache = await GlobalCache.init();
      await cache.setAccessToken('jwt-30-days-token');
      await cache.setRememberedAccount('student01');

      // Version upgrade sync must NEVER wipe login token
      final firstSync = await cache.syncInstalledAppVersion('1.0.14+114');
      expect(firstSync, isFalse);
      final upgraded = await cache.syncInstalledAppVersion('1.0.15+115');
      expect(upgraded, isTrue);
      expect(cache.accessToken, 'jwt-30-days-token');

      // Clearing temporary cache preserves auth & preferences
      await cache.clearTemporaryCache();
      expect(cache.accessToken, 'jwt-30-days-token');
      expect(cache.rememberedAccount, 'student01');
      expect(globalCache.accessToken, 'jwt-30-days-token');
    });

    test('caches last watched video lesson per course series', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final cache = await GlobalCache.init();

      expect(cache.getLastVideoLessonId(10), isNull);
      await cache.setLastVideoLessonId(10, 102);
      await cache.setLastVideoLessonId(20, 205);

      expect(cache.getLastVideoLessonId(10), 102);
      expect(cache.getLastVideoLessonId(20), 205);
      expect(cache.getLastVideoLessonId(99), isNull);

      await cache.setLastVideoLessonId(10, 103);
      expect(cache.getLastVideoLessonId(10), 103);
    });

    test('triggers announcement once per app version and re-triggers on update',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final cache = await GlobalCache.init();

      expect(cache.shouldAutoShowAnnouncement('1.0.14+114'), isTrue);
      await cache.markAnnouncementShown('1.0.14+114');
      expect(cache.shouldAutoShowAnnouncement('1.0.14+114'), isFalse);

      // After installing a newer version, announcement triggers once again
      expect(cache.shouldAutoShowAnnouncement('1.0.15+115'), isTrue);
      await cache.markAnnouncementShown('1.0.15+115');
      expect(cache.shouldAutoShowAnnouncement('1.0.15+115'), isFalse);
    });

    test('persists smartBoardPrefs and releases smartBoardDraft on cache clear',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final cache = await GlobalCache.init();

      await cache.setSmartBoardPrefs({'paper': 'grid', 'widthIdx': 2});
      await cache.setSmartBoardDraft({
        'problem': {'title': '测试题', 'problemText': r'解方程 $x^2=4$'},
      });

      expect(cache.smartBoardPrefs['paper'], 'grid');
      expect(cache.smartBoardDraft?['problem'], isNotNull);

      await cache.clearTemporaryCache();
      expect(cache.smartBoardPrefs['paper'], 'grid');
      expect(cache.smartBoardDraft, isNull);
    });

    test('persists smartBoardRecords and preserves them across cache clear',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final cache = await GlobalCache.init();

      final rec = SavedSmartBoardRecord(
        id: 'sb_1001',
        title: SavedSmartBoardRecord.deriveTitle(
          const AiRecognizeResult(
            title: '数学解答题',
            problemText: '（1）\$\\dfrac{x^2}{2}+y^2=1\$',
            subjectTag: '高中数学',
            questionType: '解答题',
            difficulty: '压轴',
          ),
        ),
        createdAtMs: 1700000000000,
        updatedAtMs: 1700000005000,
        strokes: [
          BoardStroke(
            colorValue: 0xFF111827,
            width: 3.4,
            points: const [Offset(10, 20), Offset(60, 25)],
          ),
        ],
        paperStyle: BoardPaperStyle.grid,
        panX: -40,
        panY: -12,
        zoom: 1.25,
        problem: const AiRecognizeResult(
          title: '椭圆综合题',
          problemText: '（1）\$\\dfrac{x^2}{2}+y^2=1\$',
          subjectTag: '高中数学',
          questionType: '解答题',
          difficulty: '压轴',
        ),
        activeResultTabName: 'problem',
        resultCollapsed: false,
        resultPanelPos: const Offset(18, 24),
      );
      expect(rec.title, '（1）x²/2+y²=1');

      await cache.setSmartBoardRecords([rec.toJson()]);
      await cache.clearTemporaryCache();

      expect(cache.smartBoardRecords.length, 1);
      final restored =
          SavedSmartBoardRecord.fromJson(cache.smartBoardRecords.first);
      expect(restored, isNotNull);
      expect(restored!.id, 'sb_1001');
      expect(restored.paperStyle, BoardPaperStyle.grid);
      expect(restored.zoom, 1.25);
      expect(restored.strokes.length, 1);
      expect(restored.problem?.title, '椭圆综合题');
      expect(restored.resultPanelPos, const Offset(18, 24));
    });
  });

  group('BoardHandwritingValidator', () {
    test('rejects empty board, too few strokes, tiny marks, and wild scribbles',
        () {
      // 1. Empty board
      expect(BoardHandwritingValidator.validate(const [], const []).valid,
          isFalse);

      // 2. Too few strokes
      final twoStrokes = [
        BoardStroke(
          colorValue: 0xFF111827,
          width: 3,
          points: const [Offset(10, 10), Offset(40, 10)],
        ),
        BoardStroke(
          colorValue: 0xFF111827,
          width: 3,
          points: const [Offset(50, 10), Offset(80, 10)],
        ),
      ];
      expect(
          BoardHandwritingValidator.validate(twoStrokes, const []).valid,
          isFalse);

      // 3. Tiny cluster
      final tinyStrokes = List.generate(
        5,
        (i) => BoardStroke(
          colorValue: 0xFF111827,
          width: 3,
          points: [Offset(10.0 + i * 2, 10), Offset(14.0 + i * 2, 18)],
        ),
      );
      expect(BoardHandwritingValidator.validate(tinyStrokes, const []).valid,
          isFalse);

      // 4. Wild back-and-forth scribble loop
      final scribblePts = <Offset>[];
      for (var i = 0; i < 60; i++) {
        scribblePts.add(
          Offset(i.isEven ? 20.0 : 220.0, 20.0 + i * 2.5),
        );
      }
      final scribbleStrokes = List.generate(
        4,
        (idx) => BoardStroke(
          colorValue: 0xFF111827,
          width: 3,
          points: scribblePts
              .map((p) => Offset(p.dx + idx * 5, p.dy + idx * 3))
              .toList(),
        ),
      );
      final scribbleRes =
          BoardHandwritingValidator.validate(scribbleStrokes, const []);
      expect(scribbleRes.valid, isFalse);
      expect(scribbleRes.reason, contains('乱涂乱画'));
    });

    test('passes clean handwritten math equation strokes', () {
      // Simulate clean characters for "2x + 3 = 7" (10 character-sized strokes)
      final equationStrokes = <BoardStroke>[
        // '2'
        BoardStroke(
          colorValue: 0xFF111827,
          width: 3,
          points: const [
            Offset(10, 20),
            Offset(28, 16),
            Offset(30, 32),
            Offset(10, 52),
            Offset(34, 52),
          ],
        ),
        // 'x' (2 strokes)
        BoardStroke(
          colorValue: 0xFF111827,
          width: 3,
          points: const [Offset(46, 26), Offset(66, 52)],
        ),
        BoardStroke(
          colorValue: 0xFF111827,
          width: 3,
          points: const [Offset(66, 26), Offset(46, 52)],
        ),
        // '+' (2 strokes)
        BoardStroke(
          colorValue: 0xFF111827,
          width: 3,
          points: const [Offset(84, 38), Offset(106, 38)],
        ),
        BoardStroke(
          colorValue: 0xFF111827,
          width: 3,
          points: const [Offset(95, 26), Offset(95, 50)],
        ),
        // '3'
        BoardStroke(
          colorValue: 0xFF111827,
          width: 3,
          points: const [
            Offset(122, 20),
            Offset(142, 24),
            Offset(128, 36),
            Offset(144, 48),
            Offset(122, 52),
          ],
        ),
        // '=' (2 strokes)
        BoardStroke(
          colorValue: 0xFF111827,
          width: 3,
          points: const [Offset(162, 32), Offset(188, 32)],
        ),
        BoardStroke(
          colorValue: 0xFF111827,
          width: 3,
          points: const [Offset(162, 44), Offset(188, 44)],
        ),
        // '7'
        BoardStroke(
          colorValue: 0xFF111827,
          width: 3,
          points: const [Offset(206, 20), Offset(232, 20), Offset(214, 54)],
        ),
      ];

      final res = BoardHandwritingValidator.validate(equationStrokes, const []);
      expect(res.valid, isTrue);
      expect(res.strokeCount, 9);
    });
  });

  group('SmartBoard Models', () {
    test('serializes strokes/shapes and supports accurate stroke eraser hitTest',
        () {
      final stroke = BoardStroke(
        colorValue: 0xFF2563EB,
        width: 3.4,
        points: const [Offset(10, 10), Offset(110, 10)],
      );
      expect(stroke.hitTest(const Offset(60, 12), 8), isTrue);
      expect(stroke.hitTest(const Offset(60, 50), 8), isFalse);

      final restoredStroke = BoardStroke.fromJson(stroke.toJson());
      expect(restoredStroke, isNotNull);
      expect(restoredStroke!.points.length, 2);
      expect(restoredStroke.colorValue, 0xFF2563EB);

      final shape = BoardShape(
        kind: BoardShapeKind.dashedLine,
        start: const Offset(0, 0),
        end: const Offset(100, 100),
        colorValue: 0xFFDC2626,
        width: 2.5,
      );
      expect(shape.hitTest(const Offset(50, 52), 8), isTrue);
      expect(shape.hitTest(const Offset(10, 90), 8), isFalse);

      final restoredShape = BoardShape.fromJson(shape.toJson());
      expect(restoredShape, isNotNull);
      expect(restoredShape!.kind, BoardShapeKind.dashedLine);
    });
  });

  group('TASK-20261126-001 Theme, Diagrams & Next Gate Models', () {
    test('GlobalCache persists serverDefaultTheme and ThemeProvider enforces it on next launch',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final cache = await GlobalCache.init();
      final provider = ThemeProvider(cache);

      // Simulate server configured Forui dark theme as default
      const serverCfg = AppDefaultTheme(
        uiSkin: 'forui',
        themeHex: '#0EA5E9',
        themeName: '晴空蓝',
        darkMode: true,
        version: '100',
      );
      await provider.applyServerDefaultTheme(serverCfg, isAppLaunch: true);
      expect(provider.isForui, isTrue);
      expect(provider.isDarkMode, isTrue);
      expect(provider.accentHex, '#0EA5E9');
      expect(cache.serverDefaultTheme?.uiSkin, 'forui');
      expect(cache.snapshot()['serverDefaultTheme'], isNotNull);

      // User temporarily switches to Skribble in-session
      await provider.setUiSkin(AppUiSkin.skribble);
      await provider.setDarkMode(false);
      expect(provider.isSkribble, isTrue);

      // Same-version refresh during same session keeps user's temporary pick
      await provider.applyServerDefaultTheme(serverCfg, isAppLaunch: false);
      expect(provider.isSkribble, isTrue);

      // Clearing temporary cache preserves serverDefaultTheme
      await cache.clearTemporaryCache();
      expect(cache.serverDefaultTheme?.uiSkin, 'forui');

      // On NEXT app launch (fresh ThemeProvider), backend default takes precedence
      final relaunched = ThemeProvider(cache);
      expect(relaunched.isForui, isTrue);
      expect(relaunched.isDarkMode, isTrue);
      expect(relaunched.accentHex, '#0EA5E9');

      // Admin updates default theme version -> applies immediately mid-session
      const updatedCfg = AppDefaultTheme(
        uiSkin: 'welkui',
        themeHex: '#FFDA57',
        themeName: '元气暖黄',
        darkMode: false,
        version: '101',
      );
      await provider.applyServerDefaultTheme(updatedCfg, isAppLaunch: false);
      expect(provider.uiSkin, AppUiSkin.welkui);
      expect(provider.accentHex, '#FFDA57');
      expect(provider.isDarkMode, isFalse);

      // Manual switch + resetToDefault restores latest server default
      await provider.setUiSkin(AppUiSkin.forui);
      await provider.resetToDefault();
      expect(provider.uiSkin, AppUiSkin.welkui);
      expect(provider.accentHex, '#FFDA57');
    });

    test('SubmitResult parses nextGate fields and ClientQuestionItem parses arc/rightAngle diagram',
        () {
      final submit = SubmitResult.fromJson({
        'sessionNo': 'QZ123',
        'mode': 'GATE',
        'totalCount': 3,
        'correctCount': 3,
        'passCount': 2,
        'passed': true,
        'newlyPassed': true,
        'totalPassedGates': 4,
        'wrongItems': const [],
        'masteredCount': 0,
        'nextGateId': 9,
        'nextGateIndex': 0,
        'nextGateName': '基础关',
        'nextChapterId': 2,
        'nextChapterName': '第2章 整式的加减',
        'nextGateCrossChapter': true,
      });
      expect(submit.hasNextGate, isTrue);
      expect(submit.nextGateId, 9);
      expect(submit.nextGateIndex, 0);
      expect(submit.nextChapterName, '第2章 整式的加减');
      expect(submit.nextGateCrossChapter, isTrue);

      final item = ClientQuestionItem.fromJson({
        'itemIndex': 0,
        'questionFormat': 'SINGLE_CHOICE',
        'stem': '如图，Rt△ABC 中 ∠C=90°',
        'options': ['3', '4', '5', '6'],
        'diagram': {
          'title': '直角三角形',
          'width': 300,
          'height': 180,
          'primitives': [
            {
              'type': 'rightAngle',
              'vx': 60,
              'vy': 140,
              'ax': 220,
              'ay': 140,
              'bx': 60,
              'by': 40,
              'size': 12,
            },
            {
              'type': 'arc',
              'cx': 220,
              'cy': 140,
              'r': 24,
              'startAngle': 180,
              'sweepAngle': 35,
              'color': '#DC2626',
            },
          ],
        },
        'imageUrl': 'https://example.com/tri.png',
      });
      expect(item.hasFigure, isTrue);
      expect(item.diagram?.primitives.length, 2);
      expect(item.diagram?.primitives[0].type, 'rightangle');
      expect(item.diagram?.primitives[0].vx, 60);
      expect(item.diagram?.primitives[1].type, 'arc');
      expect(item.diagram?.primitives[1].sweepAngle, 35);
      expect(item.imageUrl, 'https://example.com/tri.png');
    });

    test('TASK-20261126-002 parses cross-grade nextGate, OSS channel, speed & normal stage defaults',
        () {
      final submit = SubmitResult.fromJson({
        'sessionNo': 'QZ-G7-LAST',
        'mode': 'GATE',
        'totalCount': 4,
        'correctCount': 4,
        'passCount': 3,
        'passed': true,
        'newlyPassed': true,
        'totalPassedGates': 40,
        'wrongItems': const [],
        'masteredCount': 0,
        'nextGateId': 41,
        'nextGateIndex': 0,
        'nextGateName': '基础关',
        'nextChapterId': 11,
        'nextChapterName': '第11章 三角形',
        'nextGateCrossChapter': true,
        'nextGradeCode': 'g8',
        'nextGradeName': '初二',
        'nextGateCrossGrade': true,
      });
      expect(submit.hasNextGate, isTrue);
      expect(submit.nextGateCrossGrade, isTrue);
      expect(submit.nextGradeCode, 'g8');
      expect(submit.nextGradeName, '初二');

      final fallback = submit.copyWithNextGate(
        nextGateId: 99,
        nextGradeCode: 'g9',
        nextGradeName: '初三',
        nextGateCrossGrade: true,
      );
      expect(fallback.nextGateId, 99);
      expect(fallback.nextGradeName, '初三');

      final longNotes = '更新亮点：${'优化题库配图与交互体验。' * 200}';
      expect(longNotes.length, greaterThan(2000));
      final ver = AppVersionInfo.fromJson({
        'version': '2.3.0',
        'versionCode': 230,
        'downloadUrl': 'https://cdn.example.com/app/guoguanla-2.3.0.apk',
        'downloadChannel': 'OSS_DIRECT',
        'ossCustomDomain': 'https://cdn.example.com',
        'releaseNotes': longNotes,
        'forceUpdate': false,
      });
      expect(ver.downloadChannel, 'OSS_DIRECT');
      expect(ver.ossCustomDomain, 'https://cdn.example.com');
      expect(ver.releaseNotes.length, longNotes.length);
      expect(UpdateUtils.downloadChannelLabel(ver.downloadChannel), 'OSS 直连高速通道');
      expect(UpdateUtils.downloadChannelLabel('SERVER_PROXY'), '应用内安全中转通道');
      expect(UpdateUtils.formatDownloadSpeed(0), '');
      expect(UpdateUtils.formatDownloadSpeed(512 * 1024), '512 KB/s');
      expect(UpdateUtils.formatDownloadSpeed(2.5 * 1024 * 1024), '2.5 MB/s');

      final defaultNames = RealmItem.defaults.map((r) => r.realmName).toList();
      expect(defaultNames, ['初一', '初二', '初三', '高一', '高二', '高三']);
    });
  });
}
