import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../../app/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/format_utils.dart';
import '../../models/models.dart';
import '../../providers/user_provider.dart';
import '../../services/guoguanla_api.dart';
import '../../widgets/ggl_comic_panel.dart';
import '../../widgets/ggl_feedback.dart';
import '../../widgets/ggl_skeleton.dart';
import '../../widgets/image_preview_page.dart';
import '../../widgets/math_text.dart';
import '../draw_answer/draw_answer_page.dart';

enum QuizMode { gate, wrongRedo, advanceExam }

class QuizPage extends StatefulWidget {
  const QuizPage({
    super.key,
    required this.mode,
    this.gateId,
    this.gateSeq,
    this.realmCode,
    this.chapterId,
  });

  final QuizMode mode;
  final int? gateId;
  final int? gateSeq;
  final String? realmCode;
  final int? chapterId;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  static const List<String> _letters = ['A', 'B', 'C', 'D', 'E', 'F'];

  bool _loading = true;
  String _loadError = '';
  bool _checking = false;
  bool _submitting = false;

  QuizStartResult? _startData;
  int _currentIdx = 0;
  final Map<int, int> _selectedMap = <int, int>{};
  final Map<int, String> _essayTextMap = <int, String>{};
  final Map<int, String> _essayImageKeyMap = <int, String>{};
  final Map<int, CheckItemResult> _feedbackMap = <int, CheckItemResult>{};
  SubmitResult? _submitResult;

  int _elapsedSec = 0;
  Timer? _timer;
  final TextEditingController _essayController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initQuiz());
  }

  @override
  void dispose() {
    _stopTimer();
    _essayController.dispose();
    super.dispose();
  }

  ClientQuestionItem? get _currentItem {
    final items = _startData?.items;
    if (items == null || _currentIdx < 0 || _currentIdx >= items.length) {
      return null;
    }
    return items[_currentIdx];
  }

  int? get _currentSelected {
    final item = _currentItem;
    if (item == null) return null;
    return _selectedMap[item.itemIndex];
  }

  CheckItemResult? get _currentFeedback {
    final item = _currentItem;
    if (item == null) return null;
    return _feedbackMap[item.itemIndex];
  }

  double get _progressRatio {
    final total = _startData?.totalCount ?? 1;
    if (total <= 0) return 0;
    return ((_currentIdx + 1) / total).clamp(0.0, 1.0);
  }

  String get _navbarTitle {
    if (widget.mode == QuizMode.advanceExam) return '境界进阶考核';
    if (widget.mode == QuizMode.wrongRedo) return '错题重做';
    final name = (_startData?.gateName.isNotEmpty ?? false)
        ? _startData!.gateName
        : '关卡挑战';
    return widget.gateSeq != null ? '第 ${widget.gateSeq} 关 · $name' : name;
  }

  void _startTimer() {
    _stopTimer();
    _elapsedSec = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsedSec++);
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _syncEssayController() {
    final item = _currentItem;
    final nextText = item != null ? (_essayTextMap[item.itemIndex] ?? '') : '';
    if (_essayController.text != nextText) {
      _essayController.text = nextText;
    }
  }

  Future<void> _initQuiz() async {
    setState(() {
      _loading = true;
      _loadError = '';
      _submitResult = null;
      _currentIdx = 0;
      _selectedMap.clear();
      _essayTextMap.clear();
      _essayImageKeyMap.clear();
      _feedbackMap.clear();
    });

    try {
      final api = context.read<GuoguanlaApi>();
      final user = context.read<UserProvider>();
      QuizStartResult res;
      if (widget.mode == QuizMode.advanceExam) {
        res = await api.startRealmExam();
      } else if (widget.mode == QuizMode.wrongRedo) {
        res = await api.startWrongRedo(
          realmCode: widget.realmCode,
          chapterId: widget.chapterId,
          limit: 5,
        );
      } else if (widget.gateId != null) {
        res = await api.startGateQuiz(
          gateId: widget.gateId!,
          guestPassedGateIds: user.activeGuestIds,
        );
      } else {
        throw const ApiException('缺少关卡参数');
      }

      if (mounted) {
        setState(() => _startData = res);
        _syncEssayController();
        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _loadError = friendlyErrorMessage(e, '出题失败，请稍后重试'),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleConfirmChoice() async {
    final start = _startData;
    final item = _currentItem;
    final selected = _currentSelected;
    if (start == null ||
        item == null ||
        selected == null ||
        _currentFeedback != null ||
        _checking) {
      return;
    }

    setState(() => _checking = true);
    try {
      final res = await context.read<GuoguanlaApi>().checkItem(
            sessionNo: start.sessionNo,
            itemIndex: item.itemIndex,
            selectedIndex: selected,
          );
      if (mounted) {
        setState(() => _feedbackMap[item.itemIndex] = res);
      }
    } catch (e) {
      if (mounted) {
        GglFeedback.error(context, friendlyErrorMessage(e, '判题失败'));
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _handleCheckEssayText() async {
    final start = _startData;
    final item = _currentItem;
    if (start == null || item == null || _checking) return;
    final text = (_essayTextMap[item.itemIndex] ?? '').trim();
    if (text.isEmpty) {
      GglFeedback.warning(context, '请先输入解题思路或打开画板手写');
      return;
    }

    setState(() => _checking = true);
    try {
      final res = await context.read<GuoguanlaApi>().checkItem(
            sessionNo: start.sessionNo,
            itemIndex: item.itemIndex,
            answerText: text,
            answerImageKey: _essayImageKeyMap[item.itemIndex],
          );
      if (mounted) {
        setState(() => _feedbackMap[item.itemIndex] = res);
      }
    } catch (e) {
      if (mounted) {
        GglFeedback.error(context, friendlyErrorMessage(e, '提交解答失败'));
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _openLandscapeDraw() async {
    final start = _startData;
    final item = _currentItem;
    if (start == null || item == null) return;

    final result = await Navigator.of(context).push<DrawAnswerResult>(
      MaterialPageRoute<DrawAnswerResult>(
        builder: (_) => DrawAnswerPage(
          sessionNo: start.sessionNo,
          itemIndex: item.itemIndex,
          stem: item.stem,
          initialAnswerText: (_essayTextMap[item.itemIndex] ?? '').trim(),
        ),
      ),
    );

    if (result != null && mounted && result.sessionNo == start.sessionNo) {
      setState(() {
        if (result.answerText.isNotEmpty) {
          _essayTextMap[result.itemIndex] = result.answerText;
        }
        if (result.answerImageKey.isNotEmpty) {
          _essayImageKeyMap[result.itemIndex] = result.answerImageKey;
        }
        _feedbackMap[result.itemIndex] = result.feedback;
      });
      _syncEssayController();
      GglFeedback.success(context, '作答已上传云端，等待老师批改');
    }
  }

  void _nextQuestion() {
    final items = _startData?.items;
    if (items == null) return;
    if (_currentIdx < items.length - 1) {
      setState(() => _currentIdx++);
      _syncEssayController();
    }
  }

  Future<void> _handleSubmit() async {
    final start = _startData;
    if (start == null || _submitting) return;

    final answers = start.items.map((item) {
      if (item.isEssay) {
        final fb = _feedbackMap[item.itemIndex];
        return AnswerSubmitPayload(
          itemIndex: item.itemIndex,
          answerText: _essayTextMap[item.itemIndex] ?? fb?.answerText ?? '',
          answerImageKey: _essayImageKeyMap[item.itemIndex] ?? '',
          selfCorrect: fb?.selfCorrect,
        );
      }
      return AnswerSubmitPayload(
        itemIndex: item.itemIndex,
        selectedIndex: _selectedMap[item.itemIndex] ?? -1,
      );
    }).toList();

    setState(() => _submitting = true);
    try {
      final api = context.read<GuoguanlaApi>();
      final user = context.read<UserProvider>();
      SubmitResult res;
      if (widget.mode == QuizMode.advanceExam) {
        res = await api.submitRealmExam(
          sessionNo: start.sessionNo,
          answers: answers,
        );
      } else if (widget.mode == QuizMode.wrongRedo) {
        res = await api.submitWrongRedo(
          sessionNo: start.sessionNo,
          answers: answers,
        );
      } else {
        res = await api.submitGateQuiz(
          sessionNo: start.sessionNo,
          answers: answers,
        );
      }

      _stopTimer();
      if (mounted) {
        setState(() => _submitResult = res);
      }

      if (res.passed &&
          res.newlyPassed &&
          widget.mode == QuizMode.gate &&
          !user.isAuthenticated &&
          start.gateId != null) {
        await user.recordGuestPassedGate(start.gateId!);
      }
      if (user.isAuthenticated) {
        unawaited(user.loadHomeSummary());
        unawaited(user.refreshWrongCount());
      }
    } catch (e) {
      if (mounted) {
        GglFeedback.error(context, friendlyErrorMessage(e, '交卷失败'));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleExit() async {
    final hasProgress = _selectedMap.isNotEmpty ||
        _feedbackMap.isNotEmpty ||
        _essayTextMap.values.any((v) => v.trim().isNotEmpty);
    if (_submitResult != null || !hasProgress) {
      Navigator.of(context).pop();
      return;
    }
    final ok = await GglFeedback.confirm(
      context,
      title: '退出答题',
      content: '当前尚未交卷，确定放弃本次作答并退出吗？',
      yesText: '确认退出',
      noText: '继续答题',
      variant: WelkDialogVariant.error,
    );
    if (ok && mounted) {
      Navigator.of(context).pop();
    }
  }

  String _feedbackTitle(CheckItemResult fb) {
    if (fb.pendingReview) return '已提交等待老师批改';
    return fb.correct ? '回答正确！' : '回答错误';
  }

  String _feedbackFoot(CheckItemResult fb) {
    if (fb.pendingReview) return '解答过程已提交云端，老师批改后将同步结果';
    if (widget.mode == QuizMode.wrongRedo) {
      return fb.correct ? '重做答对，交卷后自动移出错题本' : '本题将继续保留在错题本中';
    }
    return fb.correct ? '思路清晰，继续下一题吧！' : '本题已自动收入错题本';
  }

  String _resultHeadline(SubmitResult res) {
    if (widget.mode == QuizMode.advanceExam) {
      return res.passed ? '考核通过，成功晋升！' : '暂未达标，再接再厉';
    }
    if (widget.mode == QuizMode.wrongRedo) {
      final mastered = res.masteredCount > 0 ? res.masteredCount : res.correctCount;
      return '本次重做掌握 $mastered 题';
    }
    return res.passed ? '闯关成功！' : '差一点点，继续加油';
  }

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_handleExit());
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.pageBackground(context),
        appBar: WelkAppBar(
          title: _navbarTitle,
          centerTitle: true,
        layout: WelkAppBarLayout.comicStrip,
          leading: WelkIconButton(
            icon: const Icon(Icons.close_rounded),
            label: '退出答题',
            onPressed: _handleExit,
          ),
        ),
        body: Column(
          children: [
            if (_startData != null && _submitResult == null)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  color: colors.paper,
                  border: Border(
                    bottom: BorderSide(
                      color: colors.outline,
                      width: colors.borderWidth,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              '第 ',
                              style: TextStyle(
                                color: AppTheme.mutedText(context),
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${_currentIdx + 1}',
                              style: TextStyle(
                                color: colors.ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              ' / ${_startData!.totalCount} 题',
                              style: TextStyle(
                                color: AppTheme.mutedText(context),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 16,
                              color: AppTheme.mutedText(context),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              FormatUtils.formatDuration(_elapsedSec),
                              style: TextStyle(
                                color: colors.ink,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GglProgressBar(percent: _progressRatio, height: 10),
                  ],
                ),
              ),
            Expanded(
              child: _buildBody(context, colors),
            ),
          ],
        ),
        bottomNavigationBar: _buildFooter(context, colors),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WelkColors colors) {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          GglCardSkeleton(lines: 3),
          SizedBox(height: 14),
          GglCardSkeleton(lines: 1),
          SizedBox(height: 10),
          GglCardSkeleton(lines: 1),
          SizedBox(height: 10),
          GglCardSkeleton(lines: 1),
        ],
      );
    }

    if (_loadError.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GglComicPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 44,
                  color: colors.errorHover,
                ),
                const SizedBox(height: 12),
                Text(
                  _loadError,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                WelkButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('返回上一页'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_submitResult != null) {
      return _buildResultView(context, colors, _submitResult!);
    }

    final item = _currentItem;
    final start = _startData;
    if (item == null || start == null) return const SizedBox.shrink();

    final fb = _currentFeedback;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        // Question stem card
        GglComicPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  GglStatusTag(
                    label: item.isEssay ? '解答题' : '单选题',
                    variant: WelkBadgeVariant.defaultStyle,
                  ),
                  GglStatusTag(
                    label: start.chapterName.isNotEmpty
                        ? start.chapterName
                        : (start.realmName ?? '综合训练'),
                    variant: WelkBadgeVariant.info,
                  ),
                  if (start.suppressedMode)
                    const GglStatusTag(
                      label: '高境压制',
                      variant: WelkBadgeVariant.warning,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              MathText(
                item.stem,
                style: TextStyle(
                  color: colors.ink,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w600,
                  height: 1.65,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Single-choice options OR Essay section
        if (!item.isEssay)
          Column(
            children: [
              for (var idx = 0; idx < item.options.length; idx++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildOptionCard(colors, idx, item.options[idx], fb),
                ),
            ],
          )
        else
          _buildEssayCard(context, colors, item, fb),

        // Check feedback & analysis
        if (fb != null) ...[
          const SizedBox(height: 14),
          _buildFeedbackCard(context, colors, item, fb),
        ],
      ],
    );
  }

  Widget _buildOptionCard(
    WelkColors colors,
    int idx,
    String optionText,
    CheckItemResult? fb,
  ) {
    final isSelected = _currentSelected == idx;
    Color cardFill = colors.paper;
    Color letterFill = colors.muted;
    Widget? trailingIcon;

    if (fb == null) {
      if (isSelected) {
        cardFill = colors.accent.withValues(alpha: colors.isDark ? 0.25 : 0.35);
        letterFill = colors.accent;
      }
    } else {
      if (idx == fb.correctIndex) {
        cardFill = colors.success.withValues(alpha: colors.isDark ? 0.28 : 0.42);
        letterFill = colors.success;
        trailingIcon = Icon(
          Icons.check_circle_rounded,
          color: colors.ink,
          size: 22,
        );
      } else if (isSelected && !fb.correct) {
        cardFill = colors.error.withValues(alpha: colors.isDark ? 0.28 : 0.42);
        letterFill = colors.error;
        trailingIcon = Icon(
          Icons.cancel_rounded,
          color: colors.ink,
          size: 22,
        );
      }
    }

    final letter = idx < _letters.length ? _letters[idx] : '${idx + 1}';

    return GglComicPanel(
      color: cardFill,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      shadowOffset: isSelected || (fb != null && idx == fb.correctIndex)
          ? const Offset(3, 3)
          : const Offset(2, 2),
      onTap: fb != null || _checking
          ? null
          : () {
              final item = _currentItem;
              if (item != null) {
                setState(() => _selectedMap[item.itemIndex] = idx);
              }
            },
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: letterFill,
              shape: BoxShape.circle,
              border: Border.all(color: colors.outline, width: 1.8),
            ),
            child: Text(
              letter,
              style: TextStyle(
                color: colors.onFill(letterFill),
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: MathText(
              optionText,
              style: TextStyle(
                color: colors.ink,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: 8),
            trailingIcon,
          ],
        ],
      ),
    );
  }

  Widget _buildEssayCard(
    BuildContext context,
    WelkColors colors,
    ClientQuestionItem item,
    CheckItemResult? fb,
  ) {
    final imgUrl = fb?.answerImageUrl;
    return GglComicPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.draw_rounded, size: 20),
              const SizedBox(width: 8),
              Text(
                '手写画板作答',
                style: TextStyle(
                  color: colors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '支持横屏无限画板手写演算并直传云端等待老师批改',
            style: TextStyle(color: AppTheme.mutedText(context), fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          if (imgUrl != null && imgUrl.isNotEmpty) ...[
            GestureDetector(
              onTap: () => ImagePreviewPage.open(
                context,
                imageUrl: imgUrl,
                title: '我的手写作答',
              ),
              child: Container(
                width: double.infinity,
                height: 170,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.outline, width: 1.8),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(imgUrl, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 10),
          ],
          GglBlockButton(
            label: (imgUrl != null && imgUrl.isNotEmpty)
                ? '重新打开手写画板'
                : '前往横屏手写画板',
            icon: Icons.brush_rounded,
            variant: WelkButtonVariant.info,
            onPressed: _openLandscapeDraw,
          ),
          if (fb == null) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _essayController,
              maxLines: 4,
              maxLength: 500,
              onChanged: (v) => _essayTextMap[item.itemIndex] = v,
              decoration: InputDecoration(
                hintText: '也可以在此补充文字解题步骤...',
                filled: true,
                fillColor: colors.muted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: colors.outline, width: colors.borderWidth),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: colors.outline, width: colors.borderWidth),
                ),
              ),
            ),
            const SizedBox(height: 10),
            GglBlockButton(
              label: _checking ? '正在提交...' : '提交文字解答并查看参考解析',
              variant: WelkButtonVariant.secondary,
              loading: _checking,
              onPressed: _handleCheckEssayText,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(
    BuildContext context,
    WelkColors colors,
    ClientQuestionItem item,
    CheckItemResult fb,
  ) {
    final accentColor = fb.pendingReview
        ? colors.info
        : fb.correct
            ? colors.success
            : colors.error;

    return GglComicPanel(
      color: accentColor.withValues(alpha: colors.isDark ? 0.16 : 0.24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                fb.pendingReview
                    ? Icons.hourglass_top_rounded
                    : fb.correct
                        ? Icons.check_circle_rounded
                        : Icons.error_rounded,
                color: colors.ink,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _feedbackTitle(fb),
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!item.isEssay && fb.correctIndex >= 0)
                GglStatusTag(
                  label:
                      '正确答案 ${fb.correctIndex < _letters.length ? _letters[fb.correctIndex] : fb.correctIndex + 1}',
                  variant: fb.correct
                      ? WelkBadgeVariant.success
                      : WelkBadgeVariant.error,
                ),
            ],
          ),
          if (fb.referenceAnswer != null &&
              fb.referenceAnswer!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '参考答案：',
              style: TextStyle(
                color: colors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            MathText(fb.referenceAnswer!),
          ],
          if (fb.analysis.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.paper,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.outline, width: 1.5),
              ),
              child: MathText(
                fb.analysis,
                style: TextStyle(color: colors.ink, fontSize: 14),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            _feedbackFoot(fb),
            style: TextStyle(
              color: AppTheme.mutedText(context),
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView(
    BuildContext context,
    WelkColors colors,
    SubmitResult res,
  ) {
    final badgeColor = res.passed ? colors.success : colors.error;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        GglComicPanel(
          child: Column(
            children: [
              Container(
                width: 68,
                height: 68,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.outline,
                    width: colors.borderWidth,
                  ),
                  boxShadow: [
                    BoxShadow(color: colors.shadow, offset: const Offset(3, 3)),
                  ],
                ),
                child: Icon(
                  res.passed ? Icons.emoji_events_rounded : Icons.bolt_rounded,
                  size: 36,
                  color: colors.onFill(badgeColor),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _resultHeadline(res),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '本轮共 ${res.totalCount} 题，答对 ${res.correctCount} 题'
                '${res.score != null ? ' · 得分 ${res.score}' : ''}',
                style: TextStyle(
                  color: AppTheme.mutedText(context),
                  fontSize: 13.5,
                ),
              ),
              if ((res.pendingReviewCount ?? 0) > 0) ...[
                const SizedBox(height: 8),
                GglStatusTag(
                  label: '另有 ${res.pendingReviewCount} 道解答题待老师批改',
                  variant: WelkBadgeVariant.info,
                ),
              ],
              const SizedBox(height: 16),
              const WelkDivider(variant: WelkDividerVariant.dashed),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      value: '${res.correctCount}',
                      label: '答对题数',
                    ),
                  ),
                  Expanded(
                    child: _MetricTile(
                      value: FormatUtils.formatDuration(_elapsedSec),
                      label: '本次用时',
                    ),
                  ),
                  Expanded(
                    child: _MetricTile(
                      value: '${res.totalPassedGates}',
                      label: '累计过关',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (res.promotedRealm != null) ...[
          const SizedBox(height: 14),
          GglComicPanel(
            color: colors.accent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GglStatusTag(
                  label: '境界晋升',
                  variant: WelkBadgeVariant.success,
                ),
                const SizedBox(height: 10),
                Text(
                  '恭喜晋升至 ${res.promotedRealm!.realmName}！',
                  style: TextStyle(
                    color: colors.onFill(colors.accent),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (res.promotedRealm!.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    res.promotedRealm!.description,
                    style: TextStyle(
                      color: colors.onFill(colors.accent),
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (res.wrongItems.isNotEmpty) ...[
          const GglSectionLabel(title: '错题速览（已自动收录错题本）'),
          GglComicPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < res.wrongItems.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: WelkDivider(variant: WelkDividerVariant.dashed),
                    ),
                  MathText(
                    res.wrongItems[i].stem,
                    style: TextStyle(
                      color: colors.ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const GglStatusTag(
                        label: '正解',
                        variant: WelkBadgeVariant.success,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: MathText(
                          res.wrongItems[i].correctAnswer,
                          style: TextStyle(
                            color: colors.ink,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget? _buildFooter(BuildContext context, WelkColors colors) {
    if (_loadError.isNotEmpty) return null;

    Widget child;
    if (_loading) {
      child = const GglSkeletonBox(width: double.infinity, height: 48);
    } else if (_submitResult != null) {
      child = Row(
        children: [
          Expanded(
            child: GglBlockButton(
              label: '再做一次',
              variant: WelkButtonVariant.secondary,
              size: WelkButtonSize.medium,
              onPressed: _initQuiz,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GglBlockButton(
              label: '返回',
              variant: WelkButtonVariant.primary,
              size: WelkButtonSize.medium,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      );
    } else if (_startData != null && _currentItem != null) {
      final item = _currentItem!;
      final fb = _currentFeedback;
      if (fb == null && !item.isEssay) {
        child = GglBlockButton(
          label: _checking ? '正在判题...' : '提交答案',
          size: WelkButtonSize.large,
          loading: _checking,
          onPressed: _currentSelected == null ? null : _handleConfirmChoice,
        );
      } else if (fb == null && item.isEssay) {
        child = GglBlockButton(
          label: '打开手写画板作答',
          icon: Icons.brush_rounded,
          size: WelkButtonSize.large,
          onPressed: _openLandscapeDraw,
        );
      } else if (_currentIdx < _startData!.items.length - 1) {
        child = GglBlockButton(
          label: '下一题',
          icon: Icons.arrow_forward_rounded,
          size: WelkButtonSize.large,
          onPressed: _nextQuestion,
        );
      } else {
        child = GglBlockButton(
          label: _submitting ? '正在交卷...' : '完成交卷',
          icon: Icons.done_all_rounded,
          variant: WelkButtonVariant.success,
          size: WelkButtonSize.large,
          loading: _submitting,
          onPressed: _handleSubmit,
        );
      }
    } else {
      return null;
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: colors.paper,
          border: Border(
            top: BorderSide(color: colors.outline, width: colors.borderWidth),
          ),
        ),
        child: child,
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: colors.ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: AppTheme.mutedText(context), fontSize: 12),
        ),
      ],
    );
  }
}
