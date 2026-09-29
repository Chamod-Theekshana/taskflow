import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/ui.dart';

final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Monospaced, upper-case field label with an optional note on the right
/// ("REQUIRED", "REVEAL").
class FieldLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const FieldLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: context.text.labelSmall?.copyWith(
                fontSize: 10.5,
                letterSpacing: 1.6,
                color: context.palette.warmMuted,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Small orange note next to a field label.
class FieldNote extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onTap;

  const FieldNote(this.text, {super.key, this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = context.text.labelSmall?.copyWith(
      fontSize: 10,
      letterSpacing: 0.8,
      color: p.accentSoft.withValues(alpha: 0.85),
    );
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: style?.color),
          const SizedBox(width: 4),
        ],
        Text(text.toUpperCase(), style: style),
      ],
    );
    if (onTap == null) return content;
    return Pressable(
      onTap: onTap,
      semanticLabel: text,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: content,
      ),
    );
  }
}

/// Text field of the sign-in and sign-up forms: dark fill, leading icon that
/// lights up orange while focused, orange hairline on focus.
class AuthField extends StatefulWidget {
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;
  final bool mono;

  const AuthField({
    super.key,
    required this.controller,
    required this.icon,
    required this.hint,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
    this.mono = false,
  });

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
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
    final text = context.text;
    final focused = _focus.hasFocus;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color),
    );
    final base = widget.mono
        ? text.bodyMedium?.copyWith(fontFamily: AppFonts.mono)
        : text.bodyMedium;

    return TextFormField(
      controller: widget.controller,
      focusNode: _focus,
      obscureText: widget.obscure,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      autocorrect:
          !widget.obscure && widget.keyboardType != TextInputType.emailAddress,
      enableSuggestions: !widget.obscure,
      textCapitalization: widget.textCapitalization,
      validator: widget.validator,
      onFieldSubmitted: widget.onSubmitted,
      style: base?.copyWith(
        color: p.text,
        letterSpacing: widget.obscure ? 2.0 : null,
      ),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: text.bodyMedium?.copyWith(color: p.textFaint),
        filled: true,
        fillColor: focused ? p.raised : p.card,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        prefixIcon: Icon(
          widget.icon,
          size: 20,
          color: focused ? p.accent : p.warmMuted,
        ),
        suffixIcon: widget.suffix,
        border: border(Colors.transparent),
        enabledBorder: border(Colors.transparent),
        focusedBorder: border(p.accent.withValues(alpha: 0.7)),
        errorBorder: border(p.danger.withValues(alpha: 0.6)),
        focusedErrorBorder: border(p.danger),
        errorStyle: text.bodySmall?.copyWith(color: p.danger, fontSize: 12),
      ),
    );
  }
}

/// Rounded-square checkbox: dark when off, orange with a glow when on.
class AuthCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? semanticLabel;

  const AuthCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      checked: value,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: value ? p.accent : p.card,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: value ? p.accent : p.border),
            boxShadow: null,
          ),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 150),
            scale: value ? 1 : 0,
            child: const Icon(
              Icons.check_rounded,
              size: 15,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Hairline card at the foot of the sign-in form saying where the data
/// lives.
class PrivacyCard extends StatelessWidget {
  final String version;

  const PrivacyCard({super.key, required this.version});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: p.track,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.verified_user_outlined,
              size: 18,
              color: p.accentSoft,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Private by design', style: context.text.labelMedium),
                Text(
                  'Your account and tasks stay on this device',
                  style: context.text.bodySmall?.copyWith(
                    color: p.warm.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: p.accentSoft.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'v$version',
              style: context.text.labelSmall?.copyWith(color: p.accentSoft),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Don't have an account? Sign Up" line under the forms.
class AuthSwitchLink extends StatelessWidget {
  final String question;
  final String action;
  final VoidCallback onTap;

  const AuthSwitchLink({
    super.key,
    required this.question,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          question,
          style: context.text.bodyMedium?.copyWith(color: p.warm),
        ),
        Pressable(
          onTap: onTap,
          semanticLabel: action,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Text(
              action,
              style: context.text.labelLarge?.copyWith(color: p.accentSoft),
            ),
          ),
        ),
      ],
    );
  }
}

/// Orange haze at the top of the sign-in screens.
class AuthTopGlow extends StatelessWidget {
  const AuthTopGlow({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: FractionalTranslation(
          translation: const Offset(0, -0.5),
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  p.accent.withValues(alpha: 0.16),
                  p.accent.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
