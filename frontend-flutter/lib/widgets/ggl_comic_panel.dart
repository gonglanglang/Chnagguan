import 'package:flutter/material.dart';
import 'package:welkui_flutter/welkui_flutter.dart';

import '../app/app_theme.dart';

/// Comic-outlined surface built directly on [WelkTheme] design tokens.
class GglComicPanel extends StatefulWidget {
  const GglComicPanel({
    super.key,
    required this.child,
    this.color,
    this.borderColor,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.shadowOffset,
    this.borderRadius,
    this.onTap,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final Color? color;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Offset? shadowOffset;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final Clip clipBehavior;

  static const BorderRadius defaultComicRadius = BorderRadius.only(
    topLeft: Radius.elliptical(14, 9),
    topRight: Radius.elliptical(8, 15),
    bottomRight: Radius.elliptical(16, 8),
    bottomLeft: Radius.elliptical(9, 13),
  );

  @override
  State<GglComicPanel> createState() => _GglComicPanelState();
}

class _GglComicPanelState extends State<GglComicPanel> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final fill = widget.color ?? colors.paper;
    final outline = widget.borderColor ?? colors.outline;
    final offset = widget.shadowOffset ?? colors.cardShadowOffset;
    final radii = widget.borderRadius ?? GglComicPanel.defaultComicRadius;
    final interactive = widget.onTap != null;
    final effectiveOffset = _pressed && interactive
        ? const Offset(1, 1)
        : offset;

    Widget box = AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      margin: widget.margin,
      transform: Matrix4.translationValues(
        _pressed && interactive ? 2.0 : 0.0,
        _pressed && interactive ? 2.0 : 0.0,
        0,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radii,
        border: Border.all(color: outline, width: colors.borderWidth),
        boxShadow: effectiveOffset == Offset.zero
            ? const []
            : [
                BoxShadow(
                  color: colors.shadow,
                  offset: effectiveOffset,
                  blurRadius: 0,
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: radii,
        clipBehavior: widget.clipBehavior,
        child: Padding(padding: widget.padding, child: widget.child),
      ),
    );

    if (!interactive) return box;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: box,
    );
  }
}

/// Comic progress bar with thick outline and bright fill.
class GglProgressBar extends StatelessWidget {
  const GglProgressBar({
    super.key,
    required this.percent,
    this.height = 12,
    this.fillColor,
  });

  final double percent;
  final double height;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final clamped = percent.clamp(0.0, 1.0);
    final radius = BorderRadius.circular(height / 2);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colors.muted,
        borderRadius: radius,
        border: Border.all(color: colors.outline, width: 1.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fillWidth = constraints.maxWidth * clamped;
          return Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              width: fillWidth,
              height: height,
              decoration: BoxDecoration(
                color: fillColor ?? colors.accent,
                border: clamped > 0.02 && clamped < 0.99
                    ? Border(
                        right: BorderSide(color: colors.outline, width: 1.5),
                      )
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Selectable comic pill used for realm tabs, filters, and grade selectors.
class GglPillChip extends StatelessWidget {
  const GglPillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedColor;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final fill = selected ? (selectedColor ?? colors.accent) : colors.paper;
    final fg = selected ? colors.onFill(fill) : colors.ink;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.elliptical(11, 7),
            topRight: Radius.elliptical(7, 11),
            bottomRight: Radius.elliptical(12, 7),
            bottomLeft: Radius.elliptical(7, 10),
          ),
          border: Border.all(color: colors.outline, width: colors.borderWidth),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colors.shadow,
                    offset: const Offset(2, 2),
                    blurRadius: 0,
                  ),
                ]
              : const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontFamilyFallback: AppTheme.cjkFontFallback,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact straight-angle status tag matching WelkUI palette without aggressive tilt.
class GglStatusTag extends StatelessWidget {
  const GglStatusTag({
    super.key,
    required this.label,
    this.variant = WelkBadgeVariant.defaultStyle,
    this.neutral = false,
  });

  final String label;
  final WelkBadgeVariant variant;
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    final fill = neutral
        ? colors.muted
        : switch (variant) {
            WelkBadgeVariant.defaultStyle => colors.accent,
            WelkBadgeVariant.info => colors.info,
            WelkBadgeVariant.success => colors.success,
            WelkBadgeVariant.warning => colors.warning,
            WelkBadgeVariant.error => colors.error,
          };
    final fg = neutral ? colors.ink : colors.onFill(fill);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(7),
          topRight: Radius.circular(4),
          bottomRight: Radius.circular(8),
          bottomLeft: Radius.circular(5),
        ),
        border: Border.all(color: colors.outline, width: 1.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          height: 1.2,
          fontFamilyFallback: AppTheme.cjkFontFallback,
        ),
      ),
    );
  }
}

class GglSectionLabel extends StatelessWidget {
  const GglSectionLabel({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(4, 16, 4, 10),
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = WelkTheme.of(context).resolveColors(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 5,
            height: 16,
            decoration: BoxDecoration(
              color: colors.accent,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: colors.outline, width: 1.4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: colors.ink,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                fontFamilyFallback: AppTheme.cjkFontFallback,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Stretches a [WelkButton] across available horizontal space cleanly.
class GglBlockButton extends StatelessWidget {
  const GglBlockButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = WelkButtonVariant.primary,
    this.size = WelkButtonSize.medium,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final WelkButtonVariant variant;
  final WelkButtonSize size;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: WelkButton(
        variant: variant,
        size: size,
        onPressed: loading ? null : onPressed,
        child: SizedBox(
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading) ...[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
              ] else if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
