import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Shrinks slightly while pressed, like the `active:scale-95` buttons in the
/// designs.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final String? semanticLabel;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.96,
    this.semanticLabel,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return Semantics(
      button: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Rounded label used for badges, tags and filters.
class Pill extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;
  final Color? iconColor;
  final double iconSize;
  final Color? dot;
  final bool pulseDot;
  final TextStyle? style;
  final EdgeInsetsGeometry padding;

  const Pill({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
    this.iconColor,
    this.iconSize = 14,
    this.dot,
    this.pulseDot = false,
    this.style,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = (style ?? context.text.labelSmall)?.copyWith(
      color: foreground,
    );
    // Text.rich rather than a Row, so a pill works both as a plain child of
    // a Row (unbounded width) and in tight spots where it has to ellipsize.
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            if (dot != null) ...[
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: pulseDot
                    ? PulsingDot(color: dot!, size: 6)
                    : Dot(color: dot!, size: 6),
              ),
              const WidgetSpan(child: SizedBox(width: 6)),
            ],
            if (icon != null) ...[
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(
                  icon,
                  size: iconSize,
                  color: iconColor ?? foreground,
                ),
              ),
              const WidgetSpan(child: SizedBox(width: 4)),
            ],
            TextSpan(text: label),
          ],
        ),
        style: textStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class Dot extends StatelessWidget {
  final Color color;
  final double size;

  const Dot({super.key, required this.color, this.size = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// A dot that gently fades in and out (`animate-pulse`).
class PulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulsingDot({super.key, required this.color, this.size = 8});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.4).animate(_controller),
      child: Dot(color: widget.color, size: widget.size),
    );
  }
}

/// Rounded square holding an icon, used at the start of rows and cards.
class IconTile extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color color;
  final double size;
  final double radius;
  final double iconSize;

  const IconTile({
    super.key,
    required this.icon,
    required this.background,
    required this.color,
    this.size = 40,
    this.radius = 16,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}

/// White card with the soft design-system shadow.
class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final List<BoxShadow>? shadow;

  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.color,
    this.shadow = AppShadows.sm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? context.colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: context.isDark ? null : shadow,
      ),
      child: child,
    );
  }
}

/// Small heading with a leading icon ("When", "Priority", "Category"...).
class SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;

  const SectionLabel({
    super.key,
    required this.icon,
    required this.label,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.colors.primary),
          const SizedBox(width: 6),
          Text(label, style: context.text.labelLarge),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// Filled indigo button with the soft coloured shadow.
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool iconAfter;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;
  final double radius;
  final Color? color;
  final Color? foreground;

  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.iconAfter = true,
    this.onPressed,
    this.loading = false,
    this.height = 48,
    this.radius = 16,
    this.color,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? context.colors.primary;
    final fg = foreground ?? context.colors.onPrimary;
    final enabled = onPressed != null && !loading;
    final iconWidget = icon == null ? null : Icon(icon, size: 20, color: fg);

    return Pressable(
      onTap: enabled ? onPressed : null,
      scale: 0.98,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: onPressed == null ? 0.6 : 1,
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: context.isDark
                ? null
                : [
                    BoxShadow(
                      color: bg.withValues(alpha: 0.28),
                      blurRadius: 15,
                      spreadRadius: -3,
                      offset: const Offset(0, 10),
                    ),
                  ],
          ),
          child: loading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!iconAfter && iconWidget != null) ...[
                      iconWidget,
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: context.text.labelLarge?.copyWith(color: fg),
                    ),
                    if (iconAfter && iconWidget != null) ...[
                      const SizedBox(width: 8),
                      iconWidget,
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// iOS-style switch from the designs, with an optional dot on the knob.
class SoftToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double width;
  final double height;
  final bool showDot;
  final String? semanticLabel;

  const SoftToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 48,
    this.height = 28,
    this.showDot = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final knob = height - 8;
    return Semantics(
      toggled: value,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: width,
          height: height,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: value ? colors.primary : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: knob,
              height: knob,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: AppShadows.sm,
              ),
              alignment: Alignment.center,
              child: showDot && value
                  ? Dot(color: AppColors.primary, size: 6)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft card for "nothing here" moments.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: colors.onSecondaryContainer),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: context.text.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Selectable pill used in filter rows and option sheets.
class ChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? count;
  final bool strong;

  const ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.count,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Color bg;
    final Color fg;
    if (selected) {
      bg = strong ? colors.primary : colors.primaryFixed;
      fg = strong ? colors.onPrimary : colors.onPrimaryFixed;
    } else {
      bg = colors.surfaceContainerLowest;
      fg = colors.onSurfaceVariant;
    }

    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected || context.isDark ? null : AppShadows.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
            ],
            Text(label, style: context.text.labelMedium?.copyWith(color: fg)),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected && strong
                      ? colors.onPrimary.withValues(alpha: 0.2)
                      : colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  count!,
                  style: context.text.labelSmall?.copyWith(color: fg),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// White rounded search box from the task list design.
class AppSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final Widget? trailing;
  final bool autofocus;
  final FocusNode? focusNode;

  const AppSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.trailing,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: context.isDark ? null : AppShadows.sm,
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(Icons.search_rounded, size: 22, color: colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: context.text.bodyMedium,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: context.text.bodyMedium?.copyWith(
                  color: colors.outline,
                ),
                filled: false,
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Clear search',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              );
            },
          ),
          ?trailing,
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}
