import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:skribble/skribble.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../app/app_theme.dart';
import 'ggl_skin_widgets.dart';

class GglFeedback {
  GglFeedback._();

  static WelkSnackBarController? _activeSnack;

  static void showToast(
    BuildContext context,
    String message, {
    WelkSnackBarVariant variant = WelkSnackBarVariant.info,
    Duration duration = const Duration(milliseconds: 2400),
  }) {
    if (AppTheme.isForui(context, listen: false)) {
      final fColors = FTheme.of(context).colors;
      final (IconData iconData, Color iconColor) = switch (variant) {
        WelkSnackBarVariant.success => (
          Icons.check_circle_rounded,
          const Color(0xFF10B981),
        ),
        WelkSnackBarVariant.warning => (
          Icons.warning_amber_rounded,
          const Color(0xFFF59E0B),
        ),
        WelkSnackBarVariant.error => (
          Icons.error_rounded,
          fColors.destructive,
        ),
        _ => (Icons.info_rounded, fColors.primary),
      };
      if (context.findAncestorStateOfType<FToasterState>() != null) {
        showFToast(
          context: context,
          alignment: FToastAlignment.topCenter,
          duration: duration,
          icon: Icon(iconData, size: 18, color: iconColor),
          title: Text(
            message,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontFamilyFallback: AppTheme.cjkFontFallback,
            ),
          ),
        );
        return;
      }
    }

    if (AppTheme.isSkribble(context, listen: false)) {
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
      final colors = WelkTheme.of(context).resolveColors(context);
      final wired = WiredTheme.of(context);
      final tint = switch (variant) {
        WelkSnackBarVariant.standard => wired.fillColor,
        WelkSnackBarVariant.info => wired.fillColor,
        WelkSnackBarVariant.success => colors.success.withValues(alpha: 0.28),
        WelkSnackBarVariant.warning => colors.warning.withValues(alpha: 0.28),
        WelkSnackBarVariant.error => colors.error.withValues(alpha: 0.28),
      };
      showWiredSnackBar(
        context,
        duration: duration,
        content: WiredThemeScope(
          data: wired.copyWith(fillColor: Color.alphaBlend(tint, wired.fillColor)),
          child: WiredSnackBarContent(
            child: Text(
              message,
              style: TextStyle(
                color: wired.textColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                fontFamilyFallback: AppTheme.cjkFontFallback,
              ),
            ),
          ),
        ),
      );
      return;
    }

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
    if (AppTheme.isForui(context, listen: false)) {
      final result = await showFDialog<bool>(
        context: context,
        builder: (dialogCtx, style, animation) {
          final fColors = FTheme.of(dialogCtx).colors;
          return FDialog(
            animation: animation,
            builder: (ctx, _) => Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: fColors.foreground,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      fontFamilyFallback: AppTheme.cjkFontFallback,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content,
                    style: TextStyle(
                      color: fColors.mutedForeground,
                      fontSize: 14,
                      height: 1.5,
                      fontFamilyFallback: AppTheme.cjkFontFallback,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FButton(
                        variant: FButtonVariant.outline,
                        size: FButtonSizeVariant.sm,
                        mainAxisSize: MainAxisSize.min,
                        onPress: () => Navigator.of(ctx).pop(false),
                        child: Text(noText),
                      ),
                      const SizedBox(width: 10),
                      FButton(
                        variant: variant == WelkDialogVariant.error
                            ? FButtonVariant.destructive
                            : FButtonVariant.primary,
                        size: FButtonSizeVariant.sm,
                        mainAxisSize: MainAxisSize.min,
                        onPress: () => Navigator.of(ctx).pop(true),
                        child: Text(yesText),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
      return result == true;
    }

    if (AppTheme.isSkribble(context, listen: false)) {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) {
          final wired = WiredTheme.of(dialogCtx);
          return WiredDialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: wired.textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    fontFamilyFallback: AppTheme.cjkFontFallback,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  content,
                  style: TextStyle(
                    color: wired.textColor,
                    fontSize: 14,
                    height: 1.5,
                    fontFamilyFallback: AppTheme.cjkFontFallback,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GglButton(
                      label: noText,
                      variant: WelkButtonVariant.secondary,
                      onPressed: () => Navigator.of(dialogCtx).pop(false),
                    ),
                    const SizedBox(width: 10),
                    GglButton(
                      label: yesText,
                      variant: variant == WelkDialogVariant.warning
                          ? WelkButtonVariant.warning
                          : WelkButtonVariant.primary,
                      onPressed: () => Navigator.of(dialogCtx).pop(true),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
      return result == true;
    }

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
    if (AppTheme.isForui(context, listen: false)) {
      await showFDialog<void>(
        context: context,
        builder: (dialogCtx, style, animation) {
          final fColors = FTheme.of(dialogCtx).colors;
          return FDialog(
            animation: animation,
            builder: (ctx, _) => Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: fColors.foreground,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      fontFamilyFallback: AppTheme.cjkFontFallback,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content,
                    style: TextStyle(
                      color: fColors.mutedForeground,
                      fontSize: 14,
                      height: 1.5,
                      fontFamilyFallback: AppTheme.cjkFontFallback,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FButton(
                      variant: FButtonVariant.primary,
                      size: FButtonSizeVariant.sm,
                      mainAxisSize: MainAxisSize.min,
                      onPress: () => Navigator.of(ctx).pop(),
                      child: Text(buttonText),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      return;
    }

    if (AppTheme.isSkribble(context, listen: false)) {
      await showDialog<void>(
        context: context,
        builder: (dialogCtx) {
          final wired = WiredTheme.of(dialogCtx);
          return WiredDialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: wired.textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    fontFamilyFallback: AppTheme.cjkFontFallback,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  content,
                  style: TextStyle(
                    color: wired.textColor,
                    fontSize: 14,
                    height: 1.5,
                    fontFamilyFallback: AppTheme.cjkFontFallback,
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: GglButton(
                    label: buttonText,
                    variant: WelkButtonVariant.primary,
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                  ),
                ),
              ],
            ),
          );
        },
      );
      return;
    }

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
