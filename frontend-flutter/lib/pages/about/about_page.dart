import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../../app/app_theme.dart';
import '../../providers/update_provider.dart';
import '../../widgets/ggl_comic_panel.dart';
import '../../widgets/ggl_feedback.dart';
import '../../widgets/ggl_skin_widgets.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  static const String _studioShortName = '云篆科技工作室';
  static const String _organizerName = '深圳市龙华区云篆科技工作室';
  static const String _region = '广东省深圳市龙华区';
  static const String _address =
      '广东省深圳市龙华区龙华街道松和社区东环一路108号油松科技大厦B325';
  static const String _icpNumber = '粤ICP备2026130477号';
  static const String _creditCode = '92440300MAKMC5Q40P';
  static const String _contactEmail = 'gonglanglang2019@163.com';

  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UpdateProvider>().loadLocalVersion();
    });
  }

  Future<void> _handleCheckUpdate() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final msg =
          await context.read<UpdateProvider>().checkForUpdate(silent: false);
      if (msg != null && mounted) {
        GglFeedback.info(context, msg);
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _copyText(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    GglFeedback.success(context, '已复制$label');
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.inkColor(context);
    final muted = AppTheme.mutedText(context);
    final accent = AppTheme.accentColor(context);
    final onAccent = AppTheme.onAccentColor(context);
    final version = context.watch<UpdateProvider>().currentVersion;

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: const GglAppBar(
        title: '关于我们',
        showBack: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          GglComicPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GglComicPanel(
                      padding: EdgeInsets.zero,
                      shadowOffset: const Offset(3, 3),
                      child: Image.asset(
                        'assets/images/app_icon.png',
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '过关啦',
                            style: TextStyle(
                              color: ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '初中高中同步数学闯关 · v$version',
                            style: TextStyle(
                              color: muted,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    GglStatusTag(
                      label: '51 章 204 关',
                      variant: WelkBadgeVariant.defaultStyle,
                    ),
                    GglStatusTag(
                      label: '矢量配图',
                      variant: WelkBadgeVariant.info,
                    ),
                    GglStatusTag(
                      label: 'AI 智能画板',
                      variant: WelkBadgeVariant.success,
                    ),
                    GglStatusTag(
                      label: '同步课堂',
                      variant: WelkBadgeVariant.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '「过关啦」由$_studioShortName倾力打造，围绕人教版初一至高三同步数学知识脉络，编排 51 章 204 道闯关任务与 526 道精绘矢量配图题，融合 AI 智能手写画板、错题本与同步视频课堂，帮助同学夯实基础、稳步进阶。',
                  style: TextStyle(
                    color: ink.withValues(alpha: 0.86),
                    fontSize: 13.5,
                    height: 1.65,
                  ),
                ),
              ],
            ),
          ),
          const GglSectionLabel(title: '开发与运营主体'),
          GglComicPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: AppTheme.insetBoxDecoration(
                        context,
                        color: accent,
                        borderColor: AppTheme.isForui(context) ? accent : null,
                        radius: 10,
                      ),
                      child: Icon(
                        Icons.apartment_rounded,
                        size: 20,
                        color: onAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _studioShortName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '专注中小学数学智能化自测与教研工具研发',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const GglDivider(verticalPadding: 12),
                const _AboutInfoRow(
                  label: '主办单位',
                  value: _organizerName,
                ),
                const GglDivider(verticalPadding: 10),
                const _AboutInfoRow(
                  label: '所在地区',
                  value: _region,
                ),
                const GglDivider(verticalPadding: 10),
                const _AboutInfoRow(
                  label: '办公地址',
                  value: _address,
                ),
                const GglDivider(verticalPadding: 10),
                _AboutInfoRow(
                  label: 'ICP 备案号',
                  value: _icpNumber,
                  actionLabel: '复制',
                  onAction: () => _copyText(_icpNumber, 'ICP 备案号'),
                ),
                const GglDivider(verticalPadding: 10),
                const _AboutInfoRow(
                  label: '信用代码',
                  value: _creditCode,
                ),
                const GglDivider(verticalPadding: 10),
                _AboutInfoRow(
                  label: '联系邮箱',
                  value: _contactEmail,
                  actionLabel: '复制',
                  onAction: () => _copyText(_contactEmail, '联系邮箱'),
                ),
              ],
            ),
          ),
          const GglSectionLabel(title: '学习规则与说明'),
          const GglAccordion(
            title: '自由练习与连续闯关',
            initiallyExpanded: true,
            child: Text(
              '全年级 51 章 204 关题库自由开放，不限制跨年级预习或复习；支持基础关 → 下一关 → 下一章 → 跨年级顺畅衔接，随时回刷巩固薄弱知识点。',
            ),
          ),
          const SizedBox(height: 10),
          const GglAccordion(
            title: '阶段升级测评与错题本',
            child: Text(
              '完成当前学习阶段指定关数即可参加阶段升级测评，系统从本阶段题库随机抽题，达标即晋升下一阶段；闯关错题自动收入错题本，重做答对即标记掌握并移出。',
            ),
          ),
          const SizedBox(height: 10),
          const GglAccordion(
            title: 'AI 智能画板与隐私保护',
            child: Text(
              '支持拍照识题与手写识题，自动矢量重绘几何/函数配图并提供思路引导、步骤诊断与解答核对。我们严格保护学生账号与学习数据安全，所有判题与认证均在服务端完成。',
            ),
          ),
          const SizedBox(height: 20),
          Column(
            children: [
              Text(
                '© 2026 $_organizerName 版权所有',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$_region · $_icpNumber',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: muted.withValues(alpha: 0.85),
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: AppTheme.barDecoration(context, topBorder: true),
          child: GglBlockButton(
            label: _checking ? '正在检查新版本...' : '检查新版本',
            loading: _checking,
            size: WelkButtonSize.large,
            icon: Icons.system_update_rounded,
            onPressed: _handleCheckUpdate,
          ),
        ),
      ),
    );
  }
}

class _AboutInfoRow extends StatelessWidget {
  const _AboutInfoRow({
    required this.label,
    required this.value,
    this.actionLabel,
    this.onAction,
  });

  final String label;
  final String value;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.inkColor(context);
    final muted = AppTheme.mutedText(context);
    final accent = AppTheme.accentColor(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: TextStyle(
              color: muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SelectableText(
            value,
            style: TextStyle(
              color: ink,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: 8),
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                actionLabel!,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: accent,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
