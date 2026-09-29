import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Shrinks slightly while pressed (`active:scale-95`).
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

class Dot extends StatelessWidget {
  final Color color;
  final double size;
  final bool glow;

  const Dot({super.key, required this.color, this.size = 8, this.glow = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: null,
      ),
    );
  }
}

/// A dot that gently fades in and out (`animate-pulse`).
class PulsingDot extends StatefulWidget {
  final Color color;
  final double size;
  final bool glow;

  const PulsingDot({
    super.key,
    required this.color,
    this.size = 8,
    this.glow = true,
  });

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(
    begin: 1,
    end: 0.4,
  ).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Dot(color: widget.color, size: widget.size, glow: widget.glow),
    );
  }
}

/// Rounded label used for badges and tags: `px-2.5 py-1 rounded-full`,
/// monospaced text and a hairline border.
class Pill extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final Color? border;
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
    this.border,
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
    final dotColor = dot;
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
        border: border == null ? null : Border.all(color: border!),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            if (dotColor != null) ...[
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: pulseDot
                    ? PulsingDot(color: dotColor, size: 6)
                    : Dot(color: dotColor, size: 6),
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

/// Rounded square holding an icon: `w-10 h-10 rounded-2xl` with a tinted
/// fill and a matching border. Orange unless [color] says otherwise.
class IconTile extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final Color? background;
  final Color? border;
  final double size;
  final double radius;
  final double iconSize;

  const IconTile({
    super.key,
    required this.icon,
    this.color,
    this.background,
    this.border,
    this.size = 40,
    this.radius = 16,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final fg = color ?? context.palette.accent;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? fg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? fg.withValues(alpha: 0.3)),
      ),
      child: Icon(icon, size: iconSize, color: fg),
    );
  }
}

/// Card surface: `bg-[#1a1c22] border border-[#2a2d36] rounded-3xl`.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final bool shadow;
  final Gradient? gradient;

  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.color,
    this.borderColor,
    this.shadow = true,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? p.card) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? p.border),
        boxShadow: shadow ? p.cardShadow : null,
      ),
      child: child,
    );
  }
}

/// Small heading with a leading orange icon ("When", "Priority"...).
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
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: p.accent),
          const SizedBox(width: 8),
          Text(label, style: context.text.titleSmall),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// Heading above a group of settings rows.
class GroupTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Color? color;

  const GroupTitle({super.key, required this.title, this.trailing, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: context.text.titleSmall?.copyWith(
                fontSize: 15,
                color: color,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Orange gradient call-to-action with a soft glow.
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool iconAfter;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;
  final double radius;
  final TextStyle? textStyle;

  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.iconAfter = true,
    this.onPressed,
    this.loading = false,
    this.height = 52,
    this.radius = 12,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = onPressed != null && !loading;
    final iconWidget = icon == null
        ? null
        : Icon(icon, size: 20, color: Colors.white);
    final style = (textStyle ?? context.text.titleMedium)?.copyWith(
      color: Colors.white,
    );

    return Pressable(
      onTap: enabled ? onPressed : null,
      scale: 0.98,
      semanticLabel: label,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: onPressed == null ? 0.5 : 1,
        child: Container(
          height: height,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: p.accentGradient,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),

          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!iconAfter && iconWidget != null) ...[
                      iconWidget,
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        style: style,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (iconAfter && iconWidget != null) ...[
                      const SizedBox(width: 6),
                      iconWidget,
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// Dark outlined button (`bg-[#1a1b21] border border-white/10`).
class GhostButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;
  final double radius;
  final Color? foreground;

  const GhostButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.height = 36,
    this.radius = 10,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = foreground ?? p.text;
    return Pressable(
      onTap: onPressed,
      semanticLabel: label,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: p.border),
        ),
        // Hugs its content, but centres it when given a fixed width.
        child: Center(
          widthFactor: 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: context.text.titleSmall?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Square icon button with a dark fill and hairline border, used in the top
/// bars (`w-10 h-10 rounded-xl`).
class SquareIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;
  final double size;
  final double radius;

  const SquareIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
    this.size = 40,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        semanticLabel: tooltip,
        scale: 0.92,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: p.border),
          ),
          child: Icon(icon, size: 20, color: color ?? p.text),
        ),
      ),
    );
  }
}

/// On/off switch from the design: orange with a glow when on, a white knob
/// that can carry a small orange dot.
class AppSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double width;
  final double height;
  final bool showDot;
  final String? semanticLabel;

  const AppSwitch({
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
    final p = context.palette;
    final pad = height >= 28 ? 4.0 : 2.0;
    final knob = height - pad * 2;
    return Semantics(
      toggled: value,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: width,
          height: height,
          padding: EdgeInsets.all(pad),
          decoration: BoxDecoration(
            color: value ? p.accent : p.track,
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(
              color: value
                  ? p.accent
                  : (context.isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : p.border),
            ),

          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: knob - 2,
              height: knob - 2,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: showDot && value ? Dot(color: p.accent, size: 6) : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// "Nothing here" card: glowing icon disc, title and a line of guidance.
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
    final p = context.palette;
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: p.accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: p.accent.withValues(alpha: 0.3)),

            ),
            child: Icon(icon, size: 32, color: p.accent),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: context.text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: p.textSecondary,
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

/// Selectable pill used in filter rows: solid orange with a glow when
/// selected, a dark outlined chip otherwise. Can carry a small counter.
class FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? count;

  /// Tints the counter orange while the pill is not selected (the
  /// "Completed" filter in the design).
  final bool accentCount;

  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.count,
    this.accentCount = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = selected ? Colors.white : p.textSecondary;
    final Color countBg;
    final Color countFg;
    if (selected) {
      countBg = Colors.white.withValues(alpha: 0.2);
      countFg = Colors.white;
    } else if (accentCount) {
      countBg = p.accent.withValues(alpha: 0.2);
      countFg = p.accent;
    } else {
      countBg = p.track;
      countFg = p.textSecondary;
    }

    return Pressable(
      onTap: onTap,
      semanticLabel: count == null ? label : '$label, $count',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? p.accent : p.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? p.accent : p.border),
          boxShadow: null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
            ],
            Text(label, style: context.text.labelMedium?.copyWith(color: fg)),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: countBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  count!,
                  style: context.text.labelSmall?.copyWith(color: countFg),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Search box from the task list design (`h-12 rounded-2xl`, orange focus
/// ring).
class AppSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final Widget? trailing;
  final bool autofocus;

  const AppSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.trailing,
    this.autofocus = false,
  });

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final focused = _focus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 48,
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: focused ? p.accent.withValues(alpha: 0.6) : p.border,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(Icons.search_rounded, size: 20, color: p.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              autofocus: widget.autofocus,
              onChanged: widget.onChanged,
              textInputAction: TextInputAction.search,
              style: context.text.bodyMedium,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: context.text.bodyMedium?.copyWith(
                  color: p.textSecondary.withValues(alpha: 0.6),
                ),
                filled: false,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Clear search',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: p.textSecondary,
                ),
                onPressed: () {
                  widget.controller.clear();
                  widget.onChanged('');
                },
              );
            },
          ),
          ?widget.trailing,
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

/// Bottom sheet listing options with a check next to the current one.
Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<({T value, String label, IconData? icon})> options,
  required T selected,
  String? subtitle,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final p = sheetContext.palette;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                child: Text(title, style: sheetContext.text.headlineMedium),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Text(
                    subtitle,
                    style: sheetContext.text.bodySmall?.copyWith(
                      color: p.textSecondary,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              for (final option in options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _ChoiceRow(
                    label: option.label,
                    icon: option.icon,
                    selected: option.value == selected,
                    onTap: () => Navigator.of(sheetContext).pop(option.value),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _ChoiceRow extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceRow({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? p.accent.withValues(alpha: 0.12) : p.cardMuted,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? p.accent.withValues(alpha: 0.5) : p.border,
          ),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: selected ? p.accent : p.textSecondary),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                label,
                style: context.text.bodyLarge?.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: 20, color: p.accent),
          ],
        ),
      ),
    );
  }
}

/// Confirmation dialog for destructive actions. Returns true when confirmed.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final p = dialogContext.palette;
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: p.textSecondary),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: p.danger),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

/// Single-line text prompt in a dialog. Returns the trimmed text, or null
/// when cancelled.
Future<String?> promptForText(
  BuildContext context, {
  required String title,
  required String hint,
  required String confirmLabel,
  String initial = '',
  int? maxLength,
  TextCapitalization capitalization = TextCapitalization.sentences,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextPromptDialog(
      title: title,
      hint: hint,
      confirmLabel: confirmLabel,
      initial: initial,
      maxLength: maxLength,
      capitalization: capitalization,
    ),
  );
}

class _TextPromptDialog extends StatefulWidget {
  final String title;
  final String hint;
  final String confirmLabel;
  final String initial;
  final int? maxLength;
  final TextCapitalization capitalization;

  const _TextPromptDialog({
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.initial,
    required this.maxLength,
    required this.capitalization,
  });

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: widget.maxLength,
        textCapitalization: widget.capitalization,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        style: context.text.bodyLarge,
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: p.textSecondary),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
