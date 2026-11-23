import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../../app/app_theme.dart';
import '../../providers/update_provider.dart';
import '../../widgets/ggl_comic_panel.dart';
import '../../widgets/ggl_feedback.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
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
      final msg = await context
          .read<UpdateProvider>()
          .checkForUpdate(silent: false);
      if (msg != null && mounted) {
        GglFeedback.info(context, msg);
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final version = context.watch<UpdateProvider>().currentVersion;

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: WelkAppBar(
        title: '关于过关啦',
        centerTitle: true,
        layout: WelkAppBarLayout.comicStrip,
        leading: WelkIconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          label: '返回',
          onPressed: () => Navigator.of(context).pop(),
        ),
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
                              color: colors.ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Flutter + WelkUI 修仙数学闯关 · v$version',
                            style: TextStyle(
                              color: AppTheme.mutedText(context),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '按「练气 → 筑基 → 结丹 → 假婴 → 元婴 → 化神」六大境界由浅入深划分题目难度。全境界内容均已开放自由学习；完成当前境界学习要求后可参加随机抽题进阶考核，高境界亦可压制境界重温低境界题目。',
                  style: TextStyle(
                    color: colors.ink.withValues(alpha: 0.84),
                    fontSize: 13.5,
                    height: 1.65,
                  ),
                ),
              ],
            ),
          ),

          const GglSectionLabel(title: '修炼规则'),
          const WelkAccordion(
            title: Text('境界权限与压制重温'),
            initiallyExpanded: true,
            child: Text(
              '全境界 51 章 204 关题库自由开放，不限制跨级学习；高境界同学仍可随时压制境界重温低境界基础题型。',
            ),
          ),
          const SizedBox(height: 10),
          const WelkAccordion(
            title: Text('进阶考核与错题巩固'),
            child: Text(
              '学完本境指定关数即可触发进阶考核，系统从本境题库随机抽题，达标即晋升下一境界；闯关错题自动收入错题本，重做答对即标记掌握并移出。',
            ),
          ),
        ],
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
