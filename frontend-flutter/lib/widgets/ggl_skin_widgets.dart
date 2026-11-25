import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../app/app_theme.dart';

/// 皮肤自适应顶部导航栏：
/// - `welkui` 皮肤渲染 [WelkAppBar]；
/// - `skribble` 皮肤渲染 [WiredAppBar]（铺满顶部安全区，搭配手绘底线）。
class GglAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GglAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.centerTitle = true,
    this.showBack = false,
    this.onBack,
  });

  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final isSkribble = AppTheme.isSkribble(context);
    final backHandler = onBack ?? () => Navigator.of(context).maybePop();

    if (isSkribble) {
      final wired = WiredTheme.of(context);
      final effectiveLeading = leading ??
          (showBack
              ? Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: WiredIconButton(
                    icon: Icons.arrow_back_rounded,
                    size: 40,
                    iconSize: 20,
                    semanticLabel: '返回',
                    onPressed: backHandler,
                  ),
                )
              : null);
      return Container(
        color: wired.fillColor,
        child: WiredAppBar(
          backgroundColor: wired.fillColor,
          leading: effectiveLeading,
          title: Text(
            title,
            textAlign: centerTitle ? TextAlign.center : TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: wired.textColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              fontFamilyFallback: AppTheme.cjkFontFallback,
            ),
          ),
          actions: actions,
        ),
      );
    }

    final effectiveLeading = leading ??
        (showBack
            ? WelkIconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                label: '返回',
                onPressed: backHandler,
              )
            : null);

    return WelkAppBar(
      title: title,
      centerTitle: centerTitle,
      layout: WelkAppBarLayout.comicStrip,
      leading: effectiveLeading,
      actions: actions ?? const <Widget>[],
    );
  }
}

/// 皮肤自适应图标按钮：WelkUI -> [WelkIconButton]，Skribble -> [WiredIconButton]。
class GglIconButton extends StatelessWidget {
  const GglIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 40,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (AppTheme.isSkribble(context)) {
      return WiredIconButton(
        icon: icon,
        size: size,
        iconSize: size * 0.5,
        semanticLabel: label,
        onPressed: onPressed,
      );
    }
    return WelkIconButton(
      icon: Icon(icon),
      label: label,
      onPressed: onPressed,
    );
  }
}

/// 皮肤自适应按钮：WelkUI -> [WelkButton]，Skribble -> [WiredElevatedButton] / [WiredButton]。
class GglButton extends StatelessWidget {
  const GglButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = WelkButtonVariant.primary,
    this.size = WelkButtonSize.small,
    this.icon,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final WelkButtonVariant variant;
  final WelkButtonSize size;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isSkribble = AppTheme.isSkribble(context);
    final colors = WelkTheme.of(context).resolveColors(context);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: compact ? 14 : 16),
          SizedBox(width: compact ? 3 : 5),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 12 : (size == WelkButtonSize.small ? 13 : 14),
              fontWeight: FontWeight.w700,
              fontFamilyFallback: AppTheme.cjkFontFallback,
            ),
          ),
        ),
      ],
    );

    if (isSkribble) {
      final wired = WiredTheme.of(context);
      final isPrimary = variant == WelkButtonVariant.primary;
      final tint = switch (variant) {
        WelkButtonVariant.primary => wired.markerColor,
        WelkButtonVariant.secondary => wired.fillColor,
        WelkButtonVariant.info => colors.info,
        WelkButtonVariant.success => colors.success,
        WelkButtonVariant.warning => colors.warning,
        WelkButtonVariant.error => colors.error,
        WelkButtonVariant.ghost => wired.fillColor,
      };
      final textColor = (variant == WelkButtonVariant.secondary ||
              variant == WelkButtonVariant.ghost)
          ? wired.textColor
          : colors.onFill(tint);

      if (compact) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Opacity(
            opacity: onPressed == null ? 0.45 : 1.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: RoughBoxDecoration(
                drawConfig: wired.drawConfig,
                shape: RoughBoxShape.roundedRectangle,
                borderRadius: BorderRadius.circular(8),
                borderStyle: RoughDrawingStyle(
                  width: 1.7,
                  color: wired.borderColor,
                ),
                fillStyle: RoughDrawingStyle(color: tint),
                filler: SolidFiller(FillerConfig.build()),
              ),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: textColor),
                child: IconTheme.merge(
                  data: IconThemeData(color: textColor),
                  child: content,
                ),
              ),
            ),
          ),
        );
      }

      final themed = WiredThemeScope(
        data: wired.copyWith(
          fillColor: tint,
          textColor: textColor,
        ),
        child: isPrimary
            ? WiredElevatedButton(
                onPressed: onPressed,
                semanticLabel: label,
                child: content,
              )
            : WiredButton(
                onPressed: onPressed,
                semanticLabel: label,
                child: content,
              ),
      );
      return themed;
    }

    if (compact) {
      final bg = switch (variant) {
        WelkButtonVariant.primary => colors.accent,
        WelkButtonVariant.secondary => colors.paper,
        WelkButtonVariant.info => colors.info,
        WelkButtonVariant.success => colors.success,
        WelkButtonVariant.warning => colors.warning,
        WelkButtonVariant.error => colors.error,
        WelkButtonVariant.ghost => colors.muted,
      };
      final fg = (variant == WelkButtonVariant.secondary ||
              variant == WelkButtonVariant.ghost)
          ? colors.ink
          : colors.onFill(bg);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Opacity(
          opacity: onPressed == null ? 0.45 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.outline, width: 1.5),
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: fg),
              child: IconTheme.merge(
                data: IconThemeData(color: fg),
                child: content,
              ),
            ),
          ),
        ),
      );
    }

    return WelkButton(
      variant: variant,
      size: size,
      onPressed: onPressed,
      child: content,
    );
  }
}

/// 皮肤自适应分割线：WelkUI -> [WelkDivider]，Skribble -> [WiredDivider]。
class GglDivider extends StatelessWidget {
  const GglDivider({super.key, this.verticalPadding = 12});

  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    if (AppTheme.isSkribble(context)) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: verticalPadding * 0.5),
        child: const WiredDivider(),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: const WelkDivider(variant: WelkDividerVariant.dashed),
    );
  }
}

/// 皮肤自适应开关：WelkUI -> [WelkSwitch]，Skribble -> [WiredSwitch]。
class GglSwitch extends StatelessWidget {
  const GglSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (AppTheme.isSkribble(context)) {
      final wired = WiredTheme.of(context);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null && label!.isNotEmpty) ...[
            Text(
              label!,
              style: TextStyle(
                color: wired.textColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
          ],
          WiredSwitch(
            value: value,
            activeColor: wired.markerColor,
            semanticLabel: label,
            onChanged: onChanged,
          ),
        ],
      );
    }
    return WelkSwitch(
      value: value,
      label: label ?? '',
      onChanged: onChanged,
    );
  }
}

/// 皮肤自适应输入框：WelkUI -> [WelkInput]，Skribble -> [WiredInput]。
class GglInput extends StatefulWidget {
  const GglInput({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.placeholder,
    this.keyboardType,
    this.obscureText = false,
    this.allowClear = true,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? placeholder;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool allowClear;

  @override
  State<GglInput> createState() => _GglInputState();
}

class _GglInputState extends State<GglInput> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant GglInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _ctrl.text) {
      _ctrl.value = _ctrl.value.copyWith(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppTheme.isSkribble(context)) {
      final wired = WiredTheme.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: wired.textColor,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    fontFamilyFallback: AppTheme.cjkFontFallback,
                  ),
                ),
              ),
              if (widget.allowClear && widget.value.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _ctrl.clear();
                    widget.onChanged('');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '清空',
                      style: TextStyle(
                        color: wired.disabledTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          WiredInput(
            controller: _ctrl,
            hintText: widget.placeholder,
            obscureText: widget.obscureText,
            semanticLabel: widget.label,
            style: TextStyle(
              color: wired.textColor,
              fontSize: 14.5,
              fontFamilyFallback: AppTheme.cjkFontFallback,
            ),
            onChanged: widget.onChanged,
          ),
        ],
      );
    }

    return WelkInput(
      label: widget.label,
      value: widget.value,
      placeholder: widget.placeholder,
      onChanged: widget.onChanged,
      endAction: widget.allowClear && widget.value.isNotEmpty
          ? WelkInputAction(
              icon: const Icon(Icons.close_rounded),
              label: '清空${widget.label}',
              onPressed: () => widget.onChanged(''),
            )
          : null,
    );
  }
}

/// 皮肤自适应底部抽屉弹窗：WelkUI -> [showWelkDrawer]，Skribble -> [showWiredBottomSheet]。
Future<T?> showGglBottomSheet<T>({
  required BuildContext context,
  required String title,
  required Widget Function(BuildContext sheetCtx) builder,
  String closeLabel = '关闭',
}) {
  if (AppTheme.isSkribble(context, listen: false)) {
    return showWiredBottomSheet<T>(
      context: context,
      builder: (sheetCtx) {
        final wired = WiredTheme.of(sheetCtx);
        return Container(
          color: wired.fillColor,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                4,
                16,
                16 + MediaQuery.of(sheetCtx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: wired.textColor,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              fontFamilyFallback: AppTheme.cjkFontFallback,
                            ),
                          ),
                        ),
                        GglButton(
                          label: closeLabel,
                          variant: WelkButtonVariant.secondary,
                          compact: true,
                          onPressed: () => Navigator.of(sheetCtx).pop(),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: WiredDivider(),
                    ),
                    builder(sheetCtx),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  return showWelkDrawer<T>(
    context: context,
    position: WelkDrawerPosition.bottom,
    closeOnTapOutside: true,
    builder: (drawerCtx) => WelkDrawer(
      title: Text(title),
      closeLabel: closeLabel,
      onClose: () => Navigator.of(drawerCtx).pop(),
      child: builder(drawerCtx),
    ),
  );
}
