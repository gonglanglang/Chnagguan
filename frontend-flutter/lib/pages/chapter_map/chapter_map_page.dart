import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../../app/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../models/models.dart';
import '../../providers/user_provider.dart';
import '../../services/guoguanla_api.dart';
import '../../widgets/ggl_comic_panel.dart';
import '../../widgets/ggl_feedback.dart';
import '../../widgets/ggl_skeleton.dart';
import '../../widgets/ggl_skin_widgets.dart';
import '../login/login_page.dart';
import '../quiz/quiz_page.dart';

class ChapterMapPage extends StatefulWidget {
  const ChapterMapPage({
    super.key,
    required this.chapterId,
    required this.chapterSeq,
    required this.chapterName,
    this.chapterDesc = '',
    this.realmName = '',
  });

  final int chapterId;
  final int chapterSeq;
  final String chapterName;
  final String chapterDesc;
  final String realmName;

  @override
  State<ChapterMapPage> createState() => _ChapterMapPageState();
}

class _ChapterMapPageState extends State<ChapterMapPage> {
  List<GateCard> _gates = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchGates());
  }

  Future<void> _fetchGates() async {
    if (widget.chapterId <= 0) {
      setState(() => _loading = false);
      return;
    }
    if (_gates.isEmpty) setState(() => _loading = true);
    try {
      final api = context.read<GuoguanlaApi>();
      final user = context.read<UserProvider>();
      final result = await api.getGatesByChapter(
        widget.chapterId,
        guestPassedIds: user.activeGuestIds,
      );
      if (mounted) {
        setState(() => _gates = result);
      }
    } catch (e) {
      if (mounted) {
        GglFeedback.error(context, friendlyErrorMessage(e, '加载关卡失败'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _passedCount => _gates.where((g) => g.passed).length;
  int get _totalGatesCount => _gates.isNotEmpty ? _gates.length : 4;
  int get _totalQuestions =>
      _gates.fold<int>(0, (sum, g) => sum + g.questionCount);

  int get _passThresholdPercent {
    GateCard? refGate;
    for (final g in _gates) {
      if (!g.passed && g.questionCount > 0) {
        refGate = g;
        break;
      }
    }
    refGate ??= _gates.isNotEmpty ? _gates.first : null;
    if (refGate == null || refGate.questionCount <= 0) return 60;
    return ((refGate.passCount / refGate.questionCount) * 100).round();
  }

  int get _baseGateOffset => _gates.any((g) => g.gateIndex == 0) ? 1 : 0;

  int _displayGateNum(GateCard gate) => gate.gateIndex + _baseGateOffset;

  GateCard? get _nextPlayableGate {
    for (final g in _gates) {
      if (!g.passed && !g.locked && !g.empty) return g;
    }
    return null;
  }

  GateCard? get _primaryActionGate {
    if (_nextPlayableGate != null) return _nextPlayableGate;
    for (final g in _gates) {
      if (!g.locked && !g.empty) return g;
    }
    return null;
  }

  String get _primaryButtonText {
    final next = _nextPlayableGate;
    if (next != null) return '开始第 ${_displayGateNum(next)} 关';
    if (_primaryActionGate != null &&
        _gates.isNotEmpty &&
        _passedCount == _gates.length) {
      return '重温第 1 关';
    }
    return '暂无可挑战关卡';
  }

  String _gateSubtitle(GateCard gate) {
    if (gate.empty) return '题目整理中 · 敬请期待';
    if (gate.passed) {
      return '${gate.questionCount} 题 · 已通过（答对 ${gate.passCount} 题及格）';
    }
    if (gate.locked) {
      return '${gate.questionCount} 题 · 完成上一关后解锁';
    }
    final pct = gate.questionCount > 0
        ? ((gate.passCount / gate.questionCount) * 100).round()
        : 60;
    return '${gate.questionCount} 题 · 答对 $pct% 即可通关';
  }

  Future<void> _startGate(GateCard gate) async {
    if (gate.empty) {
      GglFeedback.info(context, '该关卡题目整理中，敬请期待');
      return;
    }
    if (gate.locked) {
      GglFeedback.warning(context, '请先通过上一关解锁当前关卡');
      return;
    }
    final user = context.read<UserProvider>();
    if (!user.isAuthenticated && !user.guestModeEnabled) {
      GglFeedback.warning(context, '请先登录后开始闯关');
      await Navigator.of(context).push(
        MaterialPageRoute<bool>(builder: (_) => const LoginPage()),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuizPage(
          mode: QuizMode.gate,
          gateId: gate.id,
          gateSeq: _displayGateNum(gate),
        ),
      ),
    );
    if (mounted) {
      await _fetchGates();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: const GglAppBar(
        title: '闯关地图',
        showBack: true,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchGates,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            if (_loading && _gates.isEmpty) ...[
              const GglCardSkeleton(lines: 4),
              const SizedBox(height: 18),
              const GglCardSkeleton(lines: 5),
            ] else ...[
              // Chapter overview card
              GglComicPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GglStatusTag(
                          label: '第 ${widget.chapterSeq} 章',
                          variant: WelkBadgeVariant.defaultStyle,
                        ),
                        if (widget.realmName.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            widget.realmName,
                            style: TextStyle(
                              color: AppTheme.mutedText(context),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.chapterName,
                      style: TextStyle(
                        color: colors.ink,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (widget.chapterDesc.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.chapterDesc,
                        style: TextStyle(
                          color: AppTheme.mutedText(context),
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const GglDivider(verticalPadding: 0),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _OverviewStat(
                            value: '$_passedCount',
                            unit: '/$_totalGatesCount',
                            label: '已通关',
                          ),
                        ),
                        Expanded(
                          child: _OverviewStat(
                            value: '$_totalQuestions',
                            unit: ' 题',
                            label: '总题数',
                          ),
                        ),
                        Expanded(
                          child: _OverviewStat(
                            value: '$_passThresholdPercent%',
                            unit: '',
                            label: '过关线',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const GglSectionLabel(title: '闯关路线'),

              if (_gates.isEmpty)
                GglComicPanel(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Column(
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 36,
                        color: AppTheme.mutedText(context),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '该章节暂未开放关卡',
                        style: TextStyle(color: AppTheme.mutedText(context)),
                      ),
                    ],
                  ),
                )
              else
                GglComicPanel(
                  child: Column(
                    children: [
                      for (var i = 0; i < _gates.length; i++)
                        _GateTimelineRow(
                          gate: _gates[i],
                          gateNum: _displayGateNum(_gates[i]),
                          subtitle: _gateSubtitle(_gates[i]),
                          isLast: i == _gates.length - 1,
                          onTap: () => _startGate(_gates[i]),
                        ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.emoji_events_rounded,
                    size: 16,
                    color: colors.warningHover,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$_totalGatesCount 关全部通关，可达成完整章节掌握',
                    style: TextStyle(
                      color: AppTheme.mutedText(context),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: colors.paper,
            border: Border(
              top: BorderSide(color: colors.outline, width: colors.borderWidth),
            ),
          ),
          child: GglBlockButton(
            label: _primaryButtonText,
            size: WelkButtonSize.large,
            icon: Icons.play_arrow_rounded,
            onPressed: _primaryActionGate == null
                ? null
                : () => _startGate(_primaryActionGate!),
          ),
        ),
      ),
    );
  }
}

class _OverviewStat extends StatelessWidget {
  const _OverviewStat({
    required this.value,
    required this.unit,
    required this.label,
  });

  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                color: colors.ink,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (unit.isNotEmpty)
              Text(
                unit,
                style: TextStyle(
                  color: AppTheme.mutedText(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: AppTheme.mutedText(context), fontSize: 12.5),
        ),
      ],
    );
  }
}

class _GateTimelineRow extends StatelessWidget {
  const _GateTimelineRow({
    required this.gate,
    required this.gateNum,
    required this.subtitle,
    required this.isLast,
    required this.onTap,
  });

  final GateCard gate;
  final int gateNum;
  final String subtitle;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);

    final Color nodeFill;
    final Color nodeFg;
    if (gate.passed) {
      nodeFill = colors.success;
      nodeFg = colors.onFill(colors.success);
    } else if (!gate.locked && !gate.empty) {
      nodeFill = colors.accent;
      nodeFg = colors.onFill(colors.accent);
    } else {
      nodeFill = colors.muted;
      nodeFg = AppTheme.mutedText(context);
    }

    final (String tagText, WelkBadgeVariant tagVariant) = gate.passed
        ? ('已完成', WelkBadgeVariant.success)
        : gate.empty
            ? ('待整理', WelkBadgeVariant.warning)
            : !gate.locked
                ? ('可挑战', WelkBadgeVariant.defaultStyle)
                : ('未解锁', WelkBadgeVariant.info);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 34,
              child: Column(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: nodeFill,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.outline,
                        width: colors.borderWidth,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadow,
                          offset: const Offset(2, 2),
                        ),
                      ],
                    ),
                    child: gate.passed
                        ? Icon(Icons.check_rounded, size: 17, color: nodeFg)
                        : gate.locked
                            ? Icon(Icons.lock_outline_rounded,
                                size: 15, color: nodeFg)
                            : Text(
                                '$gateNum',
                                style: TextStyle(
                                  color: nodeFg,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2.5,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: gate.passed
                            ? colors.outline
                            : colors.outline.withValues(alpha: 0.25),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 4 : 20, top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '第 $gateNum 关 · ${gate.gateName}',
                            style: TextStyle(
                              color: gate.locked
                                  ? AppTheme.mutedText(context)
                                  : colors.ink,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: AppTheme.mutedText(context),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GglStatusTag(
                      label: tagText,
                      variant: tagVariant,
                      neutral: gate.locked,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
