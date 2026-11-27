import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:skribble/skribble.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../app/app_theme.dart';

/// 皮肤自适应顶部导航栏：
/// - `welkui` 皮肤渲染 [WelkAppBar]；
/// - `skribble` 皮肤渲染 [WiredAppBar]（铺满顶部安全区，搭配手绘底线）；
/// - `forui` 皮肤渲染 [FHeader] / [FHeader.nested]（现代 1px 分割线与简洁排版）。
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
    final isForui = AppTheme.isForui(context);
    final isSkribble = AppTheme.isSkribble(context);
    final backHandler = onBack ?? () => Navigator.of(context).maybePop();

    if (isForui) {
      final fColors = FTheme.of(context).colors;
      final titleWidget = Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: fColors.foreground,
          fontSize: 17.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          fontFamilyFallback: AppTheme.cjkFontFallback,
        ),
      );
      final hasPrefix = leading != null || showBack;
      final prefixes = <Widget>[
        if (leading != null)
          leading!
        else if (showBack)
          FHeaderAction.back(onPress: backHandler),
      ];
      return Container(
        decoration: BoxDecoration(
          color: fColors.card,
          border: Border(bottom: BorderSide(color: fColors.border, width: 1)),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: hasPrefix || centerTitle
                  ? FHeader.nested(
                      titleAlignment:
                          centerTitle ? Alignment.center : Alignment.centerLeft,
                      style: FHeaderStyleDelta.delta(
                        constraints: const BoxConstraints.tightFor(height: 56),
                        padding: EdgeInsetsGeometryDelta.value(EdgeInsets.zero),
                      ),
                      title: titleWidget,
                      prefixes: prefixes,
                      suffixes: actions ?? const <Widget>[],
                    )
                  : FHeader(
                      style: FHeaderStyleDelta.delta(
                        constraints: const BoxConstraints.tightFor(height: 56),
                        padding: EdgeInsetsGeometryDelta.value(EdgeInsets.zero),
                      ),
                      title: titleWidget,
                      suffixes: actions ?? const <Widget>[],
                    ),
            ),
          ),
        ),
      );
    }

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

/// 皮肤自适应图标按钮：WelkUI -> [WelkIconButton]，Skribble -> [WiredIconButton]，Forui -> [FButton.icon]。
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
    if (AppTheme.isForui(context)) {
      return SizedBox(
        width: size,
        height: size,
        child: FButton.icon(
          variant: FButtonVariant.ghost,
          size: FButtonSizeVariant.sm,
          semanticsLabel: label,
          onPress: onPressed,
          child: Icon(icon, size: size * 0.52),
        ),
      );
    }
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

/// 皮肤自适应头像：WelkUI -> [WelkAvatar]，Skribble -> [WiredAvatar]，Forui -> [FAvatar]。
class GglAvatar extends StatelessWidget {
  const GglAvatar({
    super.key,
    required this.alt,
    this.image,
    this.size = WelkAvatarSize.large,
  });

  final String alt;
  final ImageProvider? image;
  final WelkAvatarSize size;

  @override
  Widget build(BuildContext context) {
    if (AppTheme.isForui(context)) {
      final fColors = FTheme.of(context).colors;
      final diameter = switch (size) {
        WelkAvatarSize.small => 36.0,
        WelkAvatarSize.medium => 48.0,
        WelkAvatarSize.large => 56.0,
      };
      final initial = alt.trim().isNotEmpty ? alt.trim().substring(0, 1) : '学';
      final fallbackWidget = Text(
        initial,
        style: TextStyle(
          color: fColors.primaryForeground,
          fontSize: diameter * 0.36,
          fontWeight: FontWeight.w700,
          fontFamilyFallback: AppTheme.cjkFontFallback,
        ),
      );
      if (image != null) {
        return FAvatar(
          image: image!,
          size: diameter,
          semanticsLabel: alt,
          fallback: fallbackWidget,
        );
      }
      return FAvatar.raw(
        size: diameter,
        style: FAvatarStyleDelta.delta(
          backgroundColor: fColors.primary,
          foregroundColor: fColors.primaryForeground,
        ),
        child: fallbackWidget,
      );
    }

    if (AppTheme.isSkribble(context)) {
      final wired = WiredTheme.of(context);
      final radius = switch (size) {
        WelkAvatarSize.small => 18.0,
        WelkAvatarSize.medium => 24.0,
        WelkAvatarSize.large => 28.0,
      };
      final initial = alt.trim().isNotEmpty ? alt.trim().substring(0, 1) : '学';
      return WiredAvatar(
        radius: radius,
        backgroundImage: image,
        backgroundColor: wired.markerColor.withValues(alpha: 0.45),
        foregroundColor: wired.textColor,
        child: image == null
            ? Text(
                initial,
                style: TextStyle(
                  color: wired.textColor,
                  fontWeight: FontWeight.w800,
                ),
              )
            : null,
      );
    }

    return WelkAvatar(
      alt: alt,
      size: size,
      image: image,
    );
  }
}

/// 皮肤自适应复选框：WelkUI -> [WelkCheckBox]，Skribble -> [WiredCheckbox]，Forui -> [FCheckbox]。
class GglCheckbox extends StatelessWidget {
  const GglCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (AppTheme.isForui(context)) {
      return FCheckbox(
        value: value,
        onChange: onChanged,
        label: label != null && label!.isNotEmpty
            ? Text(
                label!,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  fontFamilyFallback: AppTheme.cjkFontFallback,
                ),
              )
            : null,
      );
    }

    if (AppTheme.isSkribble(context)) {
      final wired = WiredTheme.of(context);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            WiredCheckbox(
              value: value,
              semanticLabel: label,
              onChanged: (v) => onChanged(v ?? false),
            ),
            if (label != null && label!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                label!,
                style: TextStyle(
                  color: wired.textColor,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  fontFamilyFallback: AppTheme.cjkFontFallback,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return WelkCheckBox(
      value: value,
      label: label ?? '',
      onChanged: onChanged,
    );
  }
}

/// 皮肤自适应按钮：
/// - `welkui` 皮肤渲染 [WelkButton] / 扁平漫画紧凑按钮；
/// - `skribble` 皮肤渲染 [WiredElevatedButton] / [WiredButton]；
/// - `forui` 皮肤渲染 [FButton]。
class GglButton extends StatelessWidget {
  const GglButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = WelkButtonVariant.primary,
    this.size = WelkButtonSize.small,
    this.icon,
    this.compact = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final WelkButtonVariant variant;
  final WelkButtonSize size;
  final IconData? icon;
  final bool compact;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final effectiveTap = loading ? null : onPressed;

    if (AppTheme.isForui(context)) {
      final fColors = FTheme.of(context).colors;
      final fVariant = switch (variant) {
        WelkButtonVariant.primary => FButtonVariant.primary,
        WelkButtonVariant.secondary => FButtonVariant.outline,
        WelkButtonVariant.info => FButtonVariant.secondary,
        WelkButtonVariant.success => FButtonVariant.primary,
        WelkButtonVariant.warning => FButtonVariant.secondary,
        WelkButtonVariant.error => FButtonVariant.destructive,
        WelkButtonVariant.ghost => FButtonVariant.ghost,
      };
      final fSize = compact
          ? FButtonSizeVariant.xs
          : switch (size) {
              WelkButtonSize.small => FButtonSizeVariant.sm,
              WelkButtonSize.medium => FButtonSizeVariant.md,
              WelkButtonSize.large => FButtonSizeVariant.lg,
            };
      final pad = compact
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
          : switch (size) {
              WelkButtonSize.small =>
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              WelkButtonSize.medium =>
                const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              WelkButtonSize.large =>
                const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            };
      final minHeight = compact
          ? 30.0
          : switch (size) {
              WelkButtonSize.small => 34.0,
              WelkButtonSize.medium => 40.0,
              WelkButtonSize.large => 46.0,
            };
      final Color? customBg = switch (variant) {
        WelkButtonVariant.success => const Color(0xFF10B981),
        WelkButtonVariant.warning => const Color(0xFFF59E0B),
        _ => null,
      };
      final Color? customFg = switch (variant) {
        WelkButtonVariant.success => Colors.white,
        WelkButtonVariant.warning => const Color(0xFF18181B),
        _ => null,
      };
      final styleDelta = FButtonStyleDelta.delta(
        decoration: customBg != null
            ? FVariantsDelta.delta([
                FVariantOperation.all(
                  DecorationDelta.value(
                    BoxDecoration(
                      color: effectiveTap == null
                          ? customBg.withValues(alpha: 0.45)
                          : customBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ])
            : null,
        contentStyle: FButtonContentStyleDelta.delta(
          constraints: BoxConstraints(minHeight: minHeight),
          padding: EdgeInsetsGeometryDelta.value(pad),
          spacing: compact ? 4 : 6,
          textStyle: FVariantsDelta.delta([
            FVariantOperation.all(
              customFg != null
                  ? TextStyleDelta.delta(color: customFg, height: 1.25)
                  : const TextStyleDelta.delta(height: 1.25),
            ),
          ]),
          iconStyle: customFg != null
              ? FVariantsDelta.delta([
                  FVariantOperation.all(
                    IconThemeDataDelta.delta(color: customFg),
                  ),
                ])
              : null,
        ),
      );
      return FButton(
        variant: fVariant,
        size: fSize,
        style: styleDelta,
        mainAxisSize: MainAxisSize.min,
        onPress: effectiveTap,
        prefix: loading
            ? SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: customFg ?? fColors.primaryForeground,
                ),
              )
            : (icon != null ? Icon(icon, size: compact ? 14 : 16) : null),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: compact ? 12 : (size == WelkButtonSize.small ? 13 : 14),
            fontWeight: FontWeight.w600,
            height: 1.25,
            fontFamilyFallback: AppTheme.cjkFontFallback,
          ),
        ),
      );
    }

    final isSkribble = AppTheme.isSkribble(context);
    final colors = WelkTheme.of(context).resolveColors(context);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          const SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 5),
        ] else if (icon != null) ...[
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
      final isFilledVariant = variant != WelkButtonVariant.secondary &&
          variant != WelkButtonVariant.ghost;
      final tint = switch (variant) {
        WelkButtonVariant.primary => wired.markerColor,
        WelkButtonVariant.secondary => wired.fillColor,
        WelkButtonVariant.info => colors.info,
        WelkButtonVariant.success => colors.success,
        WelkButtonVariant.warning => colors.warning,
        WelkButtonVariant.error => colors.error,
        WelkButtonVariant.ghost => wired.fillColor,
      };
      final textColor = isFilledVariant ? colors.onFill(tint) : wired.textColor;

      if (compact) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: effectiveTap,
          child: Opacity(
            opacity: effectiveTap == null ? 0.45 : 1.0,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (isFilledVariant)
                  Positioned(
                    left: 2,
                    top: 2,
                    right: -2,
                    bottom: -2,
                    child: Container(
                      decoration: RoughBoxDecoration(
                        drawConfig: wired.drawConfig,
                        shape: RoughBoxShape.roundedRectangle,
                        borderRadius: BorderRadius.circular(7),
                        borderStyle: RoughDrawingStyle(
                          width: 0.7,
                          color: wired.borderColor,
                        ),
                        fillStyle: RoughDrawingStyle(color: wired.borderColor),
                        filler: HachureFiller(FillerConfig.build(hachureGap: 2.5)),
                      ),
                    ),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: RoughBoxDecoration(
                    drawConfig: wired.drawConfig,
                    shape: RoughBoxShape.roundedRectangle,
                    borderRadius: BorderRadius.circular(7),
                    borderStyle: RoughDrawingStyle(
                      width: wired.strokeWidth * 0.85,
                      color: wired.borderColor,
                    ),
                    fillStyle: RoughDrawingStyle(color: tint),
                    filler: isFilledVariant
                        ? HachureFiller(FillerConfig.build(hachureGap: 2.6))
                        : SolidFiller(FillerConfig.build()),
                  ),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: textColor),
                    child: IconTheme.merge(
                      data: IconThemeData(color: textColor),
                      child: content,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return WiredThemeScope(
        data: wired.copyWith(
          fillColor: tint,
          textColor: textColor,
        ),
        child: isFilledVariant
            ? WiredElevatedButton(
                onPressed: effectiveTap,
                semanticLabel: label,
                child: content,
              )
            : WiredButton(
                onPressed: effectiveTap,
                semanticLabel: label,
                child: content,
              ),
      );
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
        onTap: effectiveTap,
        child: Opacity(
          opacity: effectiveTap == null ? 0.45 : 1.0,
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
      onPressed: effectiveTap,
      child: content,
    );
  }
}

/// 皮肤自适应分割线：WelkUI -> [WelkDivider]，Skribble -> [WiredDivider]，Forui -> [FDivider]。
class GglDivider extends StatelessWidget {
  const GglDivider({super.key, this.verticalPadding = 12});

  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    if (AppTheme.isForui(context)) {
      return FDivider(
        style: FDividerStyleDelta.delta(
          padding: EdgeInsetsGeometryDelta.value(
            EdgeInsets.symmetric(vertical: verticalPadding),
          ),
        ),
      );
    }
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

/// 皮肤自适应开关：WelkUI -> [WelkSwitch]，Skribble -> [WiredSwitch]，Forui -> [FSwitch]。
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
    if (AppTheme.isForui(context)) {
      final fColors = FTheme.of(context).colors;
      return FSwitch(
        value: value,
        enabled: onChanged != null,
        leadingLabel: true,
        label: label != null && label!.isNotEmpty
            ? Text(
                label!,
                style: TextStyle(
                  color: fColors.foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontFamilyFallback: AppTheme.cjkFontFallback,
                ),
              )
            : null,
        onChange: onChanged,
      );
    }
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

/// 皮肤自适应单行输入框：WelkUI -> [WelkInput]，Skribble -> [WiredInput]，Forui -> [FTextField]。
class GglInput extends StatefulWidget {
  const GglInput({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.placeholder,
    this.keyboardType,
    this.obscureText = false,
    this.onToggleObscure,
    this.allowClear = true,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? placeholder;
  final TextInputType? keyboardType;
  final bool obscureText;
  final VoidCallback? onToggleObscure;
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
    if (AppTheme.isForui(context)) {
      final fColors = FTheme.of(context).colors;
      return FTextField(
        control: FTextFieldControl.managed(
          controller: _ctrl,
          onChange: (v) => widget.onChanged(v.text),
        ),
        label: Text(
          widget.label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontFamilyFallback: AppTheme.cjkFontFallback,
          ),
        ),
        hint: widget.placeholder,
        keyboardType: widget.keyboardType,
        obscureText: widget.obscureText,
        clearable: widget.onToggleObscure == null && widget.allowClear
            ? (v) => v.text.isNotEmpty
            : FTextField.defaultClearable,
        suffixBuilder: widget.onToggleObscure != null
            ? (ctx, style, states) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: widget.onToggleObscure,
                    child: Icon(
                      widget.obscureText
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                      color: fColors.mutedForeground,
                    ),
                  ),
                )
            : null,
      );
    }

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
              if (widget.onToggleObscure != null)
                GestureDetector(
                  onTap: widget.onToggleObscure,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      widget.obscureText
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                      color: wired.disabledTextColor,
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
      type: widget.obscureText ? WelkInputType.password : WelkInputType.text,
      onChanged: widget.onChanged,
      endAction: widget.onToggleObscure != null
          ? WelkInputAction(
              icon: Icon(
                widget.obscureText
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              label: widget.obscureText ? '显示密码' : '隐藏密码',
              onPressed: widget.onToggleObscure!,
            )
          : (widget.allowClear && widget.value.isNotEmpty
              ? WelkInputAction(
                  icon: const Icon(Icons.close_rounded),
                  label: '清空${widget.label}',
                  onPressed: () => widget.onChanged(''),
                )
              : null),
    );
  }
}

/// 皮肤自适应多行文本域：WelkUI -> 粗描边漫画文本域，Skribble -> [WiredTextArea]，Forui -> [FTextField.multiline]。
class GglTextArea extends StatelessWidget {
  const GglTextArea({
    super.key,
    required this.controller,
    this.label,
    this.hintText,
    this.minLines = 4,
    this.maxLines = 7,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? label;
  final String? hintText;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (AppTheme.isForui(context)) {
      return FTextField.multiline(
        control: FTextFieldControl.managed(
          controller: controller,
          onChange: onChanged != null ? (v) => onChanged!(v.text) : null,
        ),
        label: label != null && label!.isNotEmpty
            ? Text(
                label!,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontFamilyFallback: AppTheme.cjkFontFallback,
                ),
              )
            : null,
        hint: hintText,
        minLines: minLines,
        maxLines: maxLines,
      );
    }

    final colors = WelkTheme.of(context).resolveColors(context);
    final isSkribble = AppTheme.isSkribble(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null && label!.isNotEmpty) ...[
          Text(
            label!,
            style: TextStyle(
              color: isSkribble ? WiredTheme.of(context).textColor : colors.ink,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              fontFamilyFallback: AppTheme.cjkFontFallback,
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (isSkribble)
          WiredTextArea(
            controller: controller,
            hintText: hintText,
            minLines: minLines,
            maxLines: maxLines,
            semanticLabel: label,
            style: TextStyle(
              color: WiredTheme.of(context).textColor,
              fontSize: 14,
              height: 1.5,
              fontFamilyFallback: AppTheme.cjkFontFallback,
            ),
            onChanged: onChanged,
          )
        else
          Container(
            decoration: BoxDecoration(
              color: colors.paper,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colors.outline,
                width: colors.borderWidth,
              ),
            ),
            child: TextField(
              controller: controller,
              minLines: minLines,
              maxLines: maxLines,
              onChanged: onChanged,
              style: TextStyle(
                color: colors.ink,
                fontSize: 14,
                height: 1.5,
                fontFamilyFallback: AppTheme.cjkFontFallback,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  color: AppTheme.mutedText(context),
                  fontSize: 13.5,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 皮肤自适应底部抽屉弹窗：
/// WelkUI -> [showWelkDrawer]，Skribble -> [showWiredBottomSheet]，Forui -> [showFSheet]。
Future<T?> showGglBottomSheet<T>({
  required BuildContext context,
  required String title,
  required Widget Function(BuildContext sheetCtx) builder,
  String closeLabel = '关闭',
}) {
  if (AppTheme.isForui(context, listen: false)) {
    return showFSheet<T>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: 0.85,
      builder: (sheetCtx) {
        final fColors = FTheme.of(sheetCtx).colors;
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: fColors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(top: BorderSide(color: fColors.border, width: 1)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                16 + MediaQuery.of(sheetCtx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: fColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: fColors.foreground,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
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
                    const GglDivider(verticalPadding: 10),
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

  if (AppTheme.isSkribble(context, listen: false)) {
    return showWiredBottomSheet<T>(
      context: context,
      builder: (sheetCtx) {
        final wired = WiredTheme.of(sheetCtx);
        final maxSheetHeight = MediaQuery.sizeOf(sheetCtx).height * 0.82;
        return Container(
          color: wired.fillColor,
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxSheetHeight),
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
          ),
        );
      },
    );
  }

  return showWelkDrawer<T>(
    context: context,
    position: WelkDrawerPosition.bottom,
    closeOnTapOutside: true,
    builder: (drawerCtx) {
      final maxBodyHeight = MediaQuery.sizeOf(drawerCtx).height * 0.72;
      return WelkDrawer(
        title: Text(title),
        closeLabel: closeLabel,
        onClose: () => Navigator.of(drawerCtx).pop(),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxBodyHeight),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(drawerCtx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: builder(drawerCtx),
            ),
          ),
        ),
      );
    },
  );
}

/// 皮肤自适应折叠面板：
/// - `forui` -> [FAccordion] + [FAccordionItem]（包裹在现代卡片容器中）；
/// - `skribble` -> 手绘线稿可展开面板；
/// - `welkui` -> [WelkAccordion]。
class GglAccordion extends StatefulWidget {
  const GglAccordion({
    super.key,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<GglAccordion> createState() => _GglAccordionState();
}

class _GglAccordionState extends State<GglAccordion> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    if (AppTheme.isForui(context)) {
      final fColors = FTheme.of(context).colors;
      return Container(
        decoration: BoxDecoration(
          color: fColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: fColors.border, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: FAccordion(
          style: FAccordionStyleDelta.delta(
            titlePadding: EdgeInsetsGeometryDelta.value(
              const EdgeInsets.symmetric(vertical: 13),
            ),
            childPadding: EdgeInsetsGeometryDelta.value(
              const EdgeInsets.only(bottom: 14),
            ),
          ),
          children: [
            FAccordionItem(
              initiallyExpanded: widget.initiallyExpanded,
              dividerBuilder: (_, _) => const SizedBox.shrink(),
              title: Text(
                widget.title,
                style: TextStyle(
                  color: fColors.foreground,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  fontFamilyFallback: AppTheme.cjkFontFallback,
                ),
              ),
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: fColors.mutedForeground,
                  fontSize: 13.5,
                  height: 1.6,
                  fontFamilyFallback: AppTheme.cjkFontFallback,
                ),
                child: widget.child,
              ),
            ),
          ],
        ),
      );
    }

    if (AppTheme.isSkribble(context)) {
      final wired = WiredTheme.of(context);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: RoughBoxDecoration(
            drawConfig: wired.drawConfig,
            shape: RoughBoxShape.roundedRectangle,
            borderRadius: BorderRadius.circular(12),
            borderStyle: RoughDrawingStyle(
              width: wired.strokeWidth,
              color: wired.borderColor,
            ),
            fillStyle: RoughDrawingStyle(color: wired.fillColor),
            filler: SolidFiller(FillerConfig.build()),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: wired.textColor,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        fontFamilyFallback: AppTheme.cjkFontFallback,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: wired.textColor,
                    ),
                  ),
                ],
              ),
              if (_expanded) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: WiredDivider(),
                ),
                DefaultTextStyle.merge(
                  style: TextStyle(
                    color: wired.textColor,
                    fontSize: 13.5,
                    height: 1.6,
                    fontFamilyFallback: AppTheme.cjkFontFallback,
                  ),
                  child: widget.child,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return WelkAccordion(
      initiallyExpanded: widget.initiallyExpanded,
      title: Text(widget.title),
      child: widget.child,
    );
  }
}

/// 标签页选项数据模型，配合 [GglTabs] 使用。
class GglTabOption {
  const GglTabOption({
    required this.value,
    required this.label,
    this.disabled = false,
  });

  final String value;
  final String label;
  final bool disabled;
}

/// 皮肤自适应标签页组件（全部委托给对应 UI 库官方 Tabs 组件）：
/// - `forui` -> [FTabs]（支持横向滚动与受控切换）；
/// - `skribble` -> [WiredTabBar]（横向滚动承载，避免多标签挤压换行）；
/// - `welkui` -> [WelkTabs]（自带漫画描边标签与内容面板，可直接承载 [panelChild]）。
class GglTabs extends StatelessWidget {
  const GglTabs({
    super.key,
    required this.semanticLabel,
    required this.items,
    required this.value,
    required this.onChanged,
    this.panelChild,
    this.scrollable = true,
  });

  final String semanticLabel;
  final List<GglTabOption> items;
  final String value;
  final ValueChanged<String> onChanged;

  /// 可选的标签内容面板。传入时：
  /// - WelkUI 直接放入 [WelkTabItem.content]；
  /// - Forui 放入 [FTabEntry.child]（带 [FCard] 卡片包裹）；
  /// - Skribble 渲染在 [WiredTabBar] 下方的手绘线稿面板内。
  final Widget? panelChild;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final activeIdx = math.max(0, items.indexWhere((e) => e.value == value));
    final activeValue = items[activeIdx].value;

    if (AppTheme.isForui(context)) {
      final fColors = FTheme.of(context).colors;
      final Widget? foruiPanel = panelChild == null
          ? null
          : FCard(
              style: FCardStyleDelta.delta(
                decoration: DecorationDelta.value(
                  BoxDecoration(
                    color: fColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: fColors.border, width: 1),
                    boxShadow: fColors.brightness == Brightness.light
                        ? const [
                            BoxShadow(
                              color: Color(0x0A000000),
                              blurRadius: 6,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : const [],
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: panelChild!,
              ),
            );

      return Semantics(
        label: semanticLabel,
        child: FTabs(
          scrollable: scrollable,
          control: FTabControl.lifted(
            index: activeIdx,
            onChange: (idx) {
              if (idx >= 0 && idx < items.length && !items[idx].disabled) {
                onChanged(items[idx].value);
              }
            },
          ),
          style: FTabsStyleDelta.delta(
            spacing: panelChild == null ? 0 : 12,
          ),
          children: [
            for (final item in items)
              FTabEntry(
                label: Text(
                  item.label,
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(
                    fontFamilyFallback: AppTheme.cjkFontFallback,
                  ),
                ),
                child: foruiPanel ?? const SizedBox.shrink(),
              ),
          ],
        ),
      );
    }

    if (AppTheme.isSkribble(context)) {
      final wired = WiredTheme.of(context);
      final tabLabels = items.map((e) => e.label).toList();
      final tabBar = LayoutBuilder(
        builder: (ctx, constraints) {
          final minWidth = math.max(
            constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0,
            items.length * 68.0,
          );
          final bar = WiredTabBar(
            tabs: tabLabels,
            selectedIndex: activeIdx,
            height: 44,
            semanticLabel: semanticLabel,
            onTap: (idx) {
              if (idx >= 0 && idx < items.length && !items[idx].disabled) {
                onChanged(items[idx].value);
              }
            },
          );
          if (!scrollable) return bar;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: minWidth, child: bar),
          );
        },
      );

      if (panelChild == null) return tabBar;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tabBar,
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: RoughBoxDecoration(
              drawConfig: wired.drawConfig,
              shape: RoughBoxShape.roundedRectangle,
              borderRadius: BorderRadius.circular(12),
              borderStyle: RoughDrawingStyle(
                width: wired.strokeWidth,
                color: wired.borderColor,
              ),
              fillStyle: RoughDrawingStyle(color: wired.fillColor),
              filler: SolidFiller(FillerConfig.build()),
            ),
            child: panelChild!,
          ),
        ],
      );
    }

    return WelkTabs(
      label: semanticLabel,
      value: activeValue,
      variant: WelkTabsVariant.withBg,
      onValueChange: onChanged,
      items: [
        for (final item in items)
          WelkTabItem(
            value: item.value,
            disabled: item.disabled,
            label: Text(
              item.label,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                fontFamilyFallback: AppTheme.cjkFontFallback,
              ),
            ),
            content: panelChild ?? const SizedBox.shrink(),
          ),
      ],
    );
  }
}
