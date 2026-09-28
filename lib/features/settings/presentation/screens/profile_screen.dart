import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../tasks/domain/entities/task.dart';
import '../../../tasks/presentation/providers/task_provider.dart';
import '../providers/settings_provider.dart';

const String _appVersion = '1.0.0';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final auth = ref.read(authProvider.notifier);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _EditNameDialog(initialName: current),
    );
    if (!context.mounted) return;
    if (name == null || name.trim().isEmpty || name.trim() == current) return;
    try {
      await auth.updateFullName(name);
      if (context.mounted) _showMessage(context, 'Name updated');
    } catch (e) {
      if (context.mounted) _showMessage(context, describeError(e));
    }
  }

  Future<void> _pickDigestTime(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final settings = ref.read(settingsControllerProvider.notifier);
    final picked = await showTimePicker(
      context: context,
      initialTime:
          parseTimeOfDay(current) ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked == null || !context.mounted) return;
    await settings.updateDailyDigestTime(formatTime24(picked));
  }

  Future<void> _exportTasks(BuildContext context, List<Task> tasks) async {
    if (tasks.isEmpty) {
      _showMessage(context, 'There are no tasks to export yet.');
      return;
    }
    final data = tasks
        .map(
          (t) => {
            'title': t.title,
            'description': t.description,
            'dueDate': t.dueDate.toIso8601String(),
            'dueTime': t.dueTime,
            'allDay': t.isAllDay,
            'priority': t.priority.label,
            'category': t.category,
            'completed': t.isCompleted,
            'completedAt': t.completedAt?.toIso8601String(),
            'subtasks': [
              for (final s in t.subtasks)
                {'title': s.title, 'completed': s.isCompleted},
            ],
          },
        )
        .toList();
    final json = const JsonEncoder.withIndent('  ').convert(data);
    await Clipboard.setData(ClipboardData(text: json));
    if (context.mounted) {
      _showMessage(
        context,
        '${tasks.length} ${tasks.length == 1 ? 'task' : 'tasks'} copied to '
        'the clipboard as JSON.',
      );
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authProvider.notifier);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'Your tasks stay saved on this device for when you sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await auth.logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final user = ref.watch(authProvider).value;

    final taskState = ref.watch(taskListProvider);
    final stats = taskState.stats;

    final settings = ref.watch(settingsControllerProvider).value;
    final settingsNotifier = ref.read(settingsControllerProvider.notifier);
    final digestTime = settings?.dailyDigestTime ?? '08:00';
    final digestTimeOfDay =
        parseTimeOfDay(digestTime) ?? const TimeOfDay(hour: 8, minute: 0);

    final todayIndex = DateTime.now().weekday - 1; // Monday = 0
    final maxDaily = stats.weeklyCompletions.fold<int>(
      0,
      (max, value) => value > max ? value : max,
    );

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: Text(
          'Profile',
          style: textTheme.headlineSmall?.copyWith(color: colorScheme.onSurface),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, dockClearance(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      const UserAvatar(radius: 32),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.verified,
                            color: colorScheme.secondary,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (user?.fullName.isNotEmpty ?? false)
                              ? user!.fullName
                              : 'Guest User',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleLarge?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.tertiaryFixed,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.phone_android,
                                color: colorScheme.onTertiaryFixed,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Local account',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onTertiaryFixed,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit name',
                    icon: Icon(Icons.edit_outlined, color: colorScheme.onSurface),
                    onPressed: user == null
                        ? null
                        : () => _editName(context, ref, user.fullName),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Weekly flow
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Weekly Flow',
                    style: textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${stats.completedThisWeek} done this week',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _MetricCard(
                    title: 'Done',
                    value: '${stats.tasksCompleted}',
                    subtitle: 'of ${stats.totalTasks} tasks',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    title: 'On-Time',
                    value: '${(stats.onTimePercentage * 100).round()}%',
                    subtitle: 'before deadline',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    title: 'Streak',
                    value: '${stats.currentStreak}d',
                    subtitle: stats.currentStreak > 0
                        ? 'Keep it going'
                        : 'Finish one today',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Daily breakdown (fixed height used to overflow: 88px of space
            // for 104px of hard-coded bars and labels)
            Container(
              height: 168,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Breakdown · tasks completed',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < 7; i++)
                          _DayBar(
                            label: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
                            count: stats.weeklyCompletions[i],
                            fraction: maxDaily == 0
                                ? 0
                                : stats.weeklyCompletions[i] / maxDaily,
                            isToday: i == todayIndex,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Preferences
            Text(
              'Preferences',
              style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
            ),
            const SizedBox(height: 16),
            _Section(
              children: [
                _SettingsRow(
                  title: 'Push Notifications',
                  trailing: Switch(
                    value: settings?.pushNotificationsEnabled ?? true,
                    onChanged: settings == null
                        ? null
                        : settingsNotifier.updatePushNotificationsEnabled,
                    activeThumbColor: colorScheme.primary,
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _SettingsRow(
                  title: 'Daily Morning Digest',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ActionChip(
                        label: Text(formatTimeOfDay(digestTimeOfDay)),
                        labelStyle: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                        backgroundColor: colorScheme.surface,
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
                        onPressed: settings == null
                            ? null
                            : () => _pickDigestTime(context, ref, digestTime),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: settings?.dailyDigestEnabled ?? false,
                        onChanged: settings == null
                            ? null
                            : settingsNotifier.updateDailyDigestEnabled,
                        activeThumbColor: colorScheme.primary,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _SettingsRow(
                  title: 'Theme Mode',
                  trailing: DropdownButton<ThemeMode>(
                    value: settings?.themeMode ?? ThemeMode.system,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text('System'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text('Light'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text('Dark'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) settingsNotifier.updateThemeMode(val);
                    },
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _SettingsRow(
                  title: 'Default Priority',
                  trailing: DropdownButton<TaskPriority>(
                    value: settings?.defaultPriority ?? TaskPriority.medium,
                    underline: const SizedBox(),
                    items: [
                      for (final p in TaskPriority.values)
                        DropdownMenuItem(value: p, child: Text(p.label)),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        settingsNotifier.updateDefaultPriority(val);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Account & Data
            Text(
              'Account & Data',
              style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
            ),
            const SizedBox(height: 16),
            _Section(
              children: [
                ListTile(
                  leading: Icon(Icons.shield_outlined, color: colorScheme.secondary),
                  title: Text(
                    'Local storage',
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Your data stays on this device',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  onTap: () => _exportTasks(context, taskState.tasks),
                  leading: Icon(Icons.ios_share, color: colorScheme.primary),
                  title: Text(
                    'Export Tasks',
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Copy all tasks to the clipboard as JSON',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                  trailing: Icon(
                    Icons.content_copy,
                    color: colorScheme.outline,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Session
            Text(
              'Session',
              style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => _confirmLogout(context, ref),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: colorScheme.errorContainer),
                  ),
                  backgroundColor: colorScheme.surfaceContainerLow,
                ),
                child: Text(
                  'Log Out',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                'TaskFlow v$_appVersion • Made with serenity',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  final String initialName;

  const _EditNameDialog({required this.initialName});

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit name'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(labelText: 'Full name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final List<Widget> children;

  const _Section({required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(children: children),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontSize: 24,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.outline,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  final String label;
  final int count;
  final double fraction;
  final bool isToday;

  const _DayBar({
    required this.label,
    required this.count,
    required this.fraction,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Tooltip(
      message: '$count completed',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: fraction.clamp(0.06, 1.0).toDouble(),
                child: Container(
                  width: 24,
                  decoration: BoxDecoration(
                    color: isToday
                        ? colorScheme.primary
                        : (count > 0
                              ? colorScheme.primaryFixedDim
                              : colorScheme.surfaceContainerHigh),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: isToday ? colorScheme.primary : colorScheme.outline,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String title;
  final Widget trailing;

  const _SettingsRow({required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
