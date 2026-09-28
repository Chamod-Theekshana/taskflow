import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/routing/route_guard.dart';
import '../../../../core/theme/app_theme.dart';
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

  Future<void> _signIn() async {
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
    final colors = context.colors;
    final text = context.text;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AuthBrand(),
                      const SizedBox(height: 24),
                      Text(
                        'Welcome back',
                        textAlign: TextAlign.center,
                        style: text.displayMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sign in to keep your tasks organized and mindful.',
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      AuthField(
                        label: 'Email address',
                        controller: _email,
                        icon: Icons.mail_outline_rounded,
                        hint: 'alex.morgan@example.com',
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
                      AuthField(
                        label: 'Password',
                        controller: _password,
                        icon: Icons.lock_outline_rounded,
                        hint: '••••••••',
                        obscure: _hidePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _signIn(),
                        validator: (value) => (value ?? '').isEmpty
                            ? 'Enter your password'
                            : null,
                        suffix: IconButton(
                          tooltip: _hidePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () =>
                              setState(() => _hidePassword = !_hidePassword),
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                            color: colors.outline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          RoundCheck(
                            value: _rememberMe,
                            onChanged: (v) => setState(() => _rememberMe = v),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _rememberMe = !_rememberMe),
                            child: Text(
                              'Remember me',
                              style: text.labelMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: 'Sign In',
                        icon: Icons.arrow_forward_rounded,
                        loading: _busy,
                        onPressed: _signIn,
                      ),
                      const SizedBox(height: 32),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            "Don't have an account?",
                            style: text.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go(AppRoutes.signup),
                            child: const Text('Sign up'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const PrivacyNote(
                        text: 'Your tasks stay private on this device',
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
