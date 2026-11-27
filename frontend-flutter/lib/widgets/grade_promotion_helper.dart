import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../core/network/api_client.dart';
import '../providers/user_provider.dart';
import 'ggl_feedback.dart';

/// 跨年级晋级确认助手：
/// 当当前年级关卡全部闯完、准备进入下一年级时，弹窗明确提示用户是否晋级下一年级，
/// 用户确认后同步切换当前年级阶段（登录态持久化至后端，游客态持久化至 GlobalCache）。
class GradePromotionHelper {
  GradePromotionHelper._();

  static Future<bool> confirmAndPromoteGrade(
    BuildContext context, {
    required String currentGradeName,
    required String nextGradeCode,
    required String nextGradeName,
  }) async {
    final confirmed = await GglFeedback.confirm(
      context,
      title: '是否晋级到$nextGradeName？',
      content: '恭喜你已完成$currentGradeName的全部闯关挑战！是否正式晋级到「$nextGradeName」并开启新年级关卡？',
      yesText: '晋级$nextGradeName',
      noText: '留在$currentGradeName',
      variant: WelkDialogVariant.success,
    );
    if (!confirmed || !context.mounted) return false;

    try {
      await context.read<UserProvider>().switchGrade(nextGradeCode);
      if (context.mounted) {
        GglFeedback.success(context, '已成功晋级至$nextGradeName，加油开启新征程！');
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        GglFeedback.error(context, friendlyErrorMessage(e, '晋级年级失败，请稍后重试'));
      }
      return false;
    }
  }
}
