import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/routing/route_guard.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/ui.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _rememberMe = true;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _leave() => context.go(AppRoutes.splash);

  Future<void> _logIn() async {
    FocusScope.of(context).unfocus();
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authProvider.notifier)
          .login(
            _email.text.trim(),
            _password.text,
            rememberSession: _rememberMe,
          );
      // The router sends a signed-in user to the task list.
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
                            _TopBar(onClose: _leave),
                            const SizedBox(height: 28),
                            Text('Welcome Back', style: text.displayMedium),
                            const SizedBox(height: 6),
                            Text(
                              'Log in to resume your focus streak and manage '
                              'your flow.',
                              style: text.bodyMedium?.copyWith(
                                color: p.warm.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 28),
                            const FieldLabel('Email address'),
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
                            const FieldLabel('Password'),
                            AuthField(
                              controller: _password,
                              icon: Icons.lock_outline_rounded,
                              hint: '••••••••••••',
                              obscure: _hidePassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onSubmitted: (_) => _logIn(),
                              validator: (value) => (value ?? '').isEmpty
                                  ? 'Enter your password'
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
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                  color: p.warmMuted,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                AuthCheckbox(
                                  value: _rememberMe,
                                  semanticLabel: 'Remember me',
                                  onChanged: (v) =>
                                      setState(() => _rememberMe = v),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () => setState(
                                    () => _rememberMe = !_rememberMe,
                                  ),
                                  child: Text(
                                    'Remember me',
                                    style: text.bodySmall?.copyWith(
                                      color: p.warm,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            PrimaryButton(
                              label: 'Log In',
                              icon: Icons.arrow_forward_rounded,
                              loading: _busy,
                              height: 52,
                              textStyle: text.titleLarge,
                              onPressed: _logIn,
                            ),
                            const SizedBox(height: 24),
                            const PrivacyCard(version: kAppVersion),
                            const SizedBox(height: 20),
                            AuthSwitchLink(
                              question: "Don't have an account?",
                              action: 'Sign Up',
                              onTap: () => context.go(AppRoutes.signup),
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

/// Close button, the brand pill and a live dot.
class _TopBar extends StatelessWidget {
  final VoidCallback onClose;

  const _TopBar({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        SquareIconButton(
          icon: Icons.close_rounded,
          tooltip: 'Close',
          onTap: onClose,
        ),
        Expanded(
          child: Center(
            child: Container(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(size: 28, radius: 8, glow: false),
                  const SizedBox(width: 8),
                  Text(
                    'TASKFLOW',
                    style: context.text.labelMedium?.copyWith(
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          width: 40,
          height: 40,
          child: Center(child: PulsingDot(color: p.accent)),
        ),
      ],
    );
  }
}
