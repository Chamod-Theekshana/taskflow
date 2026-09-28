import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/routing/route_guard.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/ui.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_widgets.dart';

/// 0-3: long enough (8+), mixed case, has a digit.
int passwordScore(String password) {
  var score = 0;
  if (password.length >= 8) score++;
  if (password.contains(RegExp(r'[A-Z]')) &&
      password.contains(RegExp(r'[a-z]'))) {
    score++;
  }
  if (password.contains(RegExp(r'[0-9]'))) score++;
  return score;
}

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _agreed = false;
  bool _busy = false;

  late final _termsTap = TapGestureRecognizer()
    ..onTap = () => _showPolicy(
      'Terms of Service',
      'TaskFlow is provided as is, for personal use. You are responsible for '
          'the tasks you create and for keeping a backup of anything '
          'important (Profile > Export Tasks). There is no server: your '
          'account only exists on this device.',
    );
  late final _privacyTap = TapGestureRecognizer()
    ..onTap = () => _showPolicy(
      'Privacy Policy',
      'Everything you enter - your name, e-mail, password and tasks - is '
          'stored only on this device. Passwords are salted and hashed. '
          'Nothing is sent to us or to anyone else, and there are no ads or '
          'analytics.',
    );

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  void _showPolicy(String title, String body) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    FocusScope.of(context).unfocus();
    if (_busy || !_formKey.currentState!.validate()) return;
    if (!_agreed) {
      showMessage(context, 'Please accept the Terms of Service first.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(authProvider.notifier)
          .signup(_name.text.trim(), _email.text.trim(), _password.text);
    } catch (e) {
      if (mounted) showMessage(context, describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final linkStyle = text.labelSmall?.copyWith(
      fontSize: 13,
      color: colors.primary,
      fontWeight: FontWeight.w600,
    );

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Pill(
                          label: 'FREE • WORKS OFFLINE',
                          icon: Icons.auto_awesome_rounded,
                          background: colors.primaryFixed,
                          foreground: colors.onPrimaryFixedVariant,
                          style: text.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create your account',
                        textAlign: TextAlign.center,
                        style: text.displayMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Start cultivating calm focus and effortless daily '
                        'progress.',
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      AuthField(
                        label: 'Full Name',
                        controller: _name,
                        icon: Icons.person_outline_rounded,
                        hint: 'Alex Morgan',
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Tell us what to call you'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      AuthField(
                        label: 'Work or Personal Email',
                        controller: _email,
                        icon: Icons.mail_outline_rounded,
                        hint: 'alex@example.com',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) return 'Enter your email';
                          if (!emailPattern.hasMatch(email)) {
                            return 'That email address looks incomplete';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _password,
                        builder: (context, value, _) {
                          final score = passwordScore(value.text);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AuthField(
                                label: 'Password',
                                labelTrailing: _StrengthLabel(
                                  empty: value.text.isEmpty,
                                  score: score,
                                ),
                                controller: _password,
                                icon: Icons.lock_outline_rounded,
                                hint: 'Create a password',
                                obscure: _hidePassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                onSubmitted: (_) => _create(),
                                validator: (v) => passwordScore(v ?? '') < 3
                                    ? 'Use 8+ characters with upper and '
                                          'lower case and a number'
                                    : null,
                                suffix: IconButton(
                                  tooltip: _hidePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () => setState(
                                    () => _hidePassword = !_hidePassword,
                                  ),
                                  icon: Icon(
                                    _hidePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                    color: colors.outline,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _StrengthBars(
                                empty: value.text.isEmpty,
                                score: score,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: RoundCheck(
                              value: _agreed,
                              activeColor: colors.secondary,
                              onChanged: (v) => setState(() => _agreed = v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                style: text.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                                children: [
                                  const TextSpan(text: 'I agree to the '),
                                  TextSpan(
                                    text: 'Terms of Service',
                                    style: linkStyle,
                                    recognizer: _termsTap,
                                  ),
                                  const TextSpan(text: ' and '),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: linkStyle,
                                    recognizer: _privacyTap,
                                  ),
                                  const TextSpan(text: '.'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: 'Create Account',
                        icon: Icons.arrow_forward_rounded,
                        loading: _busy,
                        onPressed: _create,
                      ),
                      const SizedBox(height: 32),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Already have an account?',
                            style: text.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go(AppRoutes.login),
                            style: TextButton.styleFrom(
                              textStyle: text.headlineSmall,
                            ),
                            child: const Text('Sign in'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StrengthLabel extends StatelessWidget {
  final bool empty;
  final int score;

  const _StrengthLabel({required this.empty, required this.score});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (icon, label, color) = empty
        ? (Icons.info_outline_rounded, 'Enter password', colors.outline)
        : switch (score) {
            3 => (Icons.verified_outlined, 'Strong password', colors.secondary),
            2 => (Icons.shield_outlined, 'Medium strength', colors.tertiary),
            _ => (Icons.warning_amber_rounded, 'Too weak', colors.error),
          };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: context.text.labelSmall?.copyWith(color: color)),
      ],
    );
  }
}

class _StrengthBars extends StatelessWidget {
  final bool empty;
  final int score;

  const _StrengthBars({required this.empty, required this.score});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final filled = empty ? 0 : (score <= 1 ? 1 : score);
    final color = switch (filled) {
      3 => colors.secondary,
      2 => colors.tertiaryFixedDim,
      _ => colors.error,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 4,
                decoration: BoxDecoration(
                  color: i < filled ? color : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
