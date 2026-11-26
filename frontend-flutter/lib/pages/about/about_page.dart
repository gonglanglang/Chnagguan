import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../../app/app_theme.dart';
import '../../providers/update_provider.dart';
import '../../widgets/ggl_comic_panel.dart';
import '../../widgets/ggl_skin_widgets.dart';
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
    final ink = AppTheme.inkColor(context);
    final version = context.watch<UpdateProvider>().currentVersion;

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: const GglAppBar(
        title: '关于过关啦',
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
                  '按「初一 → 初二 → 初三 → 高一 → 高二 → 高三」六个年级阶段由浅入深编排人教版数学章节与 204 道闯关任务。全年级题库自由开放练习，完成本阶段指定关卡后可参加阶段升级测评，高年级同学也可随时回刷巩固基础题型。',
                  style: TextStyle(
                    color: ink.withValues(alpha: 0.84),
                    fontSize: 13.5,
                    height: 1.65,
                  ),
                ),
              ],
            ),
          ),

          const GglSectionLabel(title: '学习规则'),
          const GglAccordion(
            title: '自由练习与回刷巩固',
            initiallyExpanded: true,
            child: Text(
              '全年级 51 章 204 关题库自由开放，不限制跨年级预习或复习；每章闯关支持连续跳关、跨章及跨年级衔接，随时回刷巩固薄弱知识点。',
            ),
          ),
          const SizedBox(height: 10),
          const GglAccordion(
            title: '阶段升级测评与错题本',
            child: Text(
              '完成当前学习阶段指定关数即可参加阶段升级测评，系统从本阶段题库随机抽题，达标即晋升下一阶段；闯关错题自动收入错题本，重做答对即标记掌握并移出。',
            ),
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
