import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/settings/presentation/providers/settings_provider.dart';
import '../../features/tasks/presentation/providers/task_provider.dart';
import 'notification_service.dart';

/// Keeps scheduled notifications in step with the task list and settings.
/// Watched once from the app root.
final reminderSyncProvider = Provider<void>((ref) {
  Timer? pending;

  void schedule() {
    pending?.cancel();
    // Saving a task touches the list a few times in a row; sync once.
    pending = Timer(const Duration(milliseconds: 400), () {
      if (!ref.mounted) return;
      NotificationService.instance.reschedule(
        tasks: ref.read(taskListProvider).tasks,
        settings: ref.read(settingsProvider),
        signedIn: ref.read(authProvider).value != null,
      );
    });
  }

  ref.listen(taskListProvider.select((s) => s.tasks), (_, _) => schedule());
  ref.listen(settingsProvider, (_, _) => schedule());
  ref.listen(authProvider, (_, _) => schedule());
  ref.onDispose(() => pending?.cancel());
});
