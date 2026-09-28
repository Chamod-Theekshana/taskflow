import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_logo.dart';

final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Labelled text field used on the sign-in and sign-up forms.
class AuthField extends StatelessWidget {
  final String label;
  final Widget? labelTrailing;
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;

  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    required this.hint,
    this.labelTrailing,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: text.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              ?labelTrailing,
            ],
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          autocorrect: !obscure && keyboardType != TextInputType.emailAddress,
          enableSuggestions: !obscure,
          textCapitalization: textCapitalization,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          style: text.bodyMedium,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: text.bodyMedium?.copyWith(
              color: colors.outline.withValues(alpha: 0.7),
            ),
            filled: true,
            fillColor: colors.surfaceContainerLowest,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            prefixIcon: Icon(icon, size: 20),
            prefixIconColor: WidgetStateColor.resolveWith(
              (states) => states.contains(WidgetState.focused)
                  ? colors.primary
                  : colors.outline,
            ),
            suffixIcon: suffix,
            border: border(colors.outlineVariant.withValues(alpha: 0.45), 1.5),
            enabledBorder: border(
              colors.outlineVariant.withValues(alpha: 0.45),
              1.5,
            ),
            focusedBorder: border(colors.primary, 1.5),
            errorBorder: border(colors.error.withValues(alpha: 0.6), 1.5),
            focusedErrorBorder: border(colors.error, 1.5),
          ),
        ),
      ],
    );
  }
}

/// Small rounded checkbox from the auth designs.
class RoundCheck extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;

  const RoundCheck({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final active = activeColor ?? colors.primary;
    return Semantics(
      checked: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: value ? active : colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(8),
            border: value
                ? null
                : Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
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

/// Logo tile + wordmark shown above the sign-in form.
class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.colors.surfaceContainer,
            borderRadius: BorderRadius.circular(24),
            boxShadow: context.isDark ? null : AppShadows.sm,
          ),
          child: const AppLogo(size: 44, radius: 14),
        ),
        const SizedBox(height: 8),
        Wordmark(
          style: context.text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// "Your data stays on this device" note under the auth forms.
class PrivacyNote extends StatelessWidget {
  final String text;

  const PrivacyNote({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.verified_user_outlined, size: 16, color: colors.secondary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: context.text.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
