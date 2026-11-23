import 'package:flutter/material.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

class GglFeedback {
  GglFeedback._();

  static WelkSnackBarController? _activeSnack;

  static void showToast(
    BuildContext context,
    String message, {
    WelkSnackBarVariant variant = WelkSnackBarVariant.info,
    Duration duration = const Duration(milliseconds: 2400),
  }) {
    _activeSnack?.close();
    _activeSnack = showWelkSnackBar(
      context: context,
      message: Text(message),
      variant: variant,
      position: WelkSnackBarPosition.top,
      autoHideDuration: duration,
      closeLabel: '关闭提示',
    );
  }

  static void success(BuildContext context, String message) => showToast(
        context,
        message,
        variant: WelkSnackBarVariant.success,
      );

  static void warning(BuildContext context, String message) => showToast(
        context,
        message,
        variant: WelkSnackBarVariant.warning,
      );

  static void error(BuildContext context, String message) => showToast(
        context,
        message,
        variant: WelkSnackBarVariant.error,
        duration: const Duration(milliseconds: 3000),
      );

  static void info(BuildContext context, String message) => showToast(
        context,
        message,
        variant: WelkSnackBarVariant.info,
      );

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String content,
    String yesText = '确定',
    String noText = '取消',
    WelkDialogVariant variant = WelkDialogVariant.warning,
  }) async {
    final result = await showWelkDialog<bool>(
      context: context,
      closeOnTapOutside: true,
      builder: (dialogCtx) => WelkDialog(
        title: Text(title),
        variant: variant,
        type: WelkDialogType.confirmation,
        yesText: yesText,
        noText: noText,
        closeLabel: '关闭',
        onClose: () => Navigator.of(dialogCtx).pop(false),
        onYesPressed: () => Navigator.of(dialogCtx).pop(true),
        onNoPressed: () => Navigator.of(dialogCtx).pop(false),
        child: Text(content),
      ),
    );
    return result == true;
  }

  static Future<void> alert(
    BuildContext context, {
    required String title,
    required String content,
    String buttonText = '知道了',
    WelkDialogVariant variant = WelkDialogVariant.info,
  }) async {
    await showWelkDialog<void>(
      context: context,
      closeOnTapOutside: true,
      builder: (dialogCtx) => WelkDialog(
        title: Text(title),
        variant: variant,
        type: WelkDialogType.standard,
        buttonText: buttonText,
        closeLabel: '关闭',
        onClose: () => Navigator.of(dialogCtx).pop(),
        onPressed: () => Navigator.of(dialogCtx).pop(),
        child: Text(content),
      ),
    );
  }
}
