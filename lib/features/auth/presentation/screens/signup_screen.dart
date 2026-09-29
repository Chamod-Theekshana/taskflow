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

/// The rules a new password has to meet: 8+ characters, upper and lower
/// case, and a number.
bool passwordMeetsRules(String password) =>
    password.length >= 8 &&
    password.contains(RegExp(r'[A-Z]')) &&
    password.contains(RegExp(r'[a-z]')) &&
    password.contains(RegExp(r'[0-9]'));

/// 0-4: long enough (8+), mixed case, has a digit, and either a symbol or
/// 12+ characters.
int passwordScore(String password) {
  var score = 0;
  if (password.length >= 8) score++;
  if (password.contains(RegExp(r'[A-Z]')) &&
      password.contains(RegExp(r'[a-z]'))) {
    score++;
  }
  if (password.contains(RegExp(r'[0-9]'))) score++;
  if (password.length >= 12 || password.contains(RegExp(r'[^A-Za-z0-9]'))) {
    score++;
  }
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

  void _leave() => context.go(AppRoutes.splash);

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
      // The router sends the new account to the task list.
    } catch (e) {
      if (mounted) showMessage(context, describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = context.text;
    final linkStyle = TextStyle(
      color: p.text,
      decoration: TextDecoration.underline,
      decorationColor: p.text.withValues(alpha: 0.6),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: p.canvas,
        body: Stack(
          children: [
            const Positioned.fill(child: AuthTopGlow()),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: SquareIconButton(
                                icon: Icons.arrow_back_rounded,
                                tooltip: 'Back',
                                radius: 20,
                                onTap: _leave,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                PulsingDot(color: p.accent),
                                const SizedBox(width: 8),
                                Text(
                                  'FREE • WORKS OFFLINE',
                                  style: text.labelSmall?.copyWith(
                                    color: p.accentSoft,
                                    letterSpacing: 1.6,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create Your Account',
                              style: text.displayMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Plan, focus and finish what matters. '
                              'Everything stays on this device.',
                              style: text.bodyMedium?.copyWith(
                                color: p.warmMuted,
                              ),
                            ),
                            const SizedBox(height: 28),
                            const FieldLabel(
                              'Full name',
                              trailing: FieldNote('Required'),
                            ),
                            AuthField(
                              controller: _name,
                              icon: Icons.person_outline_rounded,
                              hint: 'Alex Morgan',
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              autofillHints: const [AutofillHints.name],
                              validator: (value) =>
                                  (value ?? '').trim().isEmpty
                                  ? 'Tell us what to call you'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            const FieldLabel(
                              'Email address',
                              trailing: FieldNote('Required'),
                            ),
                            AuthField(
                              controller: _email,
                              icon: Icons.mail_outline_rounded,
                              hint: 'alex@designflow.io',
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
                            FieldLabel(
                              'Password',
                              trailing: FieldNote(
                                _hidePassword ? 'Reveal' : 'Hide',
                                icon: _hidePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                onTap: () => setState(
                                  () => _hidePassword = !_hidePassword,
                                ),
                              ),
                            ),
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _password,
                              builder: (context, value, _) {
                                final score = passwordScore(value.text);
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    AuthField(
                                      controller: _password,
                                      icon: Icons.lock_outline_rounded,
                                      hint: 'Create a strong password',
                                      obscure: _hidePassword,
                                      mono: true,
                                      textInputAction: TextInputAction.done,
                                      autofillHints: const [
                                        AutofillHints.newPassword,
                                      ],
                                      onSubmitted: (_) => _create(),
                                      validator: (v) =>
                                          passwordMeetsRules(v ?? '')
                                          ? null
                                          : 'Use 8+ characters with upper '
                                                'and lower case and a number',
                                      suffix: value.text.isEmpty
                                          ? null
                                          : Center(
                                              widthFactor: 1,
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 14,
                                                ),
                                                child: Dot(
                                                  color: _strengthColor(
                                                    p,
                                                    score,
                                                  ),
                                                  glow: true,
                                                ),
                                              ),
                                            ),
                                    ),
                                    const SizedBox(height: 10),
                                    _StrengthMeter(
                                      empty: value.text.isEmpty,
                                      score: score,
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 18),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _agreed = !_agreed),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 1),
                                    child: AuthCheckbox(
                                      value: _agreed,
                                      semanticLabel: 'Accept the terms',
                                      onChanged: (v) =>
                                          setState(() => _agreed = v),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text.rich(
                                      TextSpan(
                                        style: text.bodySmall?.copyWith(
                                          color: p.warmMuted,
                                        ),
                                        children: [
                                          const TextSpan(
                                            text: 'I agree to the ',
                                          ),
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
                            ),
                            const SizedBox(height: 24),
                            PrimaryButton(
                              label: 'Get Started Free',
                              icon: Icons.arrow_forward_rounded,
                              loading: _busy,
                              height: 54,
                              textStyle: text.titleLarge,
                              onPressed: _create,
                            ),
                            const SizedBox(height: 24),
                            AuthSwitchLink(
                              question: 'Already registered?',
                              action: 'Log In',
                              onTap: () => context.go(AppRoutes.login),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _strengthColor(AppPalette p, int score) => switch (score) {
  4 => p.success,
  3 => p.accent,
  2 => p.amber,
  _ => p.danger,
};

String _strengthLabel(int score) => switch (score) {
  4 => 'Strong',
  3 => 'Good',
  2 => 'Fair',
  _ => 'Weak',
};

/// "Password strength" line with four segments, orange rising to green.
class _StrengthMeter extends StatelessWidget {
  final bool empty;
  final int score;

  const _StrengthMeter({required this.empty, required this.score});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = context.text;
    final filled = empty ? 0 : score.clamp(1, 4);
    final segments = [
      p.accent,
      p.accent,
      const Color(0xFFEC6A06),
      p.success,
    ];
    final color = _strengthColor(p, score);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Password strength',
                  style: text.labelSmall?.copyWith(color: p.warmMuted),
                ),
              ),
              if (empty)
                Text(
                  '8+ chars, Aa, 0-9',
                  style: text.labelSmall?.copyWith(color: p.textFaint),
                )
              else ...[
                Dot(color: color, size: 6),
                const SizedBox(width: 4),
                Text(
                  '${_strengthLabel(score)} ($score/4)',
                  style: text.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 6,
                    decoration: BoxDecoration(
                      color: i < filled ? segments[i] : p.track,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: i < filled
                          ? [
                              BoxShadow(
                                color: segments[i].withValues(alpha: 0.45),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
