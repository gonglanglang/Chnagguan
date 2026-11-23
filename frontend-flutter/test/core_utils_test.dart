import 'package:flutter_test/flutter_test.dart';
import 'package:guoguanla_app/core/utils/format_utils.dart';
import 'package:guoguanla_app/core/utils/math_parser.dart';
import 'package:guoguanla_app/core/utils/update_utils.dart';
import 'package:guoguanla_app/models/models.dart';

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
}
