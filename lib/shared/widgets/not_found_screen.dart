import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/route_guard.dart';
import '../../core/theme/app_theme.dart';
import 'ui.dart';

/// Unknown links and tasks that no longer exist.
class NotFoundScreen extends StatelessWidget {
  final String title;
  final String message;

  const NotFoundScreen({
    super.key,
    this.title = 'Page not found',
    this.message = "The page you were looking for doesn't exist.",
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: EmptyState(
              icon: Icons.explore_off_rounded,
              title: title,
              message: message,
              action: SizedBox(
                width: 220,
                child: PrimaryButton(
                  label: 'Back to tasks',
                  icon: Icons.arrow_forward_rounded,
                  height: 48,
                  onPressed: () => context.go(AppRoutes.home),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
