import 'package:flutter_test/flutter_test.dart';
import 'package:guoguanla_app/core/cache/global_cache.dart';
import 'package:guoguanla_app/core/utils/format_utils.dart';
import 'package:guoguanla_app/core/utils/math_parser.dart';
import 'package:guoguanla_app/core/utils/update_utils.dart';
import 'package:guoguanla_app/models/models.dart';
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
}
