import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/route_guard.dart';

/// Shown for unknown routes and for tasks that no longer exist.
class NotFoundScreen extends StatelessWidget {
  final String title;
  final String message;

  const NotFoundScreen({
    super.key,
    this.title = 'Page not found',
    this.message = 'The page you were looking for does not exist.',
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(backgroundColor: colorScheme.surface, title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 56, color: colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(AppRoutes.home),
                child: const Text('Back to tasks'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
