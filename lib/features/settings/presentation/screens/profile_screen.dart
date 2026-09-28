import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/ui.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../stats/domain/productivity.dart';
import '../../../tasks/data/task_backup.dart';
import '../../../tasks/domain/entities/task.dart';
import '../../../tasks/presentation/providers/task_provider.dart';
import '../providers/settings_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? _exportNote;

  SettingsController get _settings => ref.read(settingsProvider.notifier);

  Future<void> _editName(String current) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: current),
    );
    if (name == null || name.trim() == current.trim()) return;
    try {
      await ref.read(authProvider.notifier).updateFullName(name);
      if (mounted) showMessage(context, 'Name updated.');
    } catch (e) {
      if (mounted) showMessage(context, describeError(e));
    }
  }

  Future<void> _setNotifications(bool enabled) async {
    if (enabled) {
      final allowed = await NotificationService.instance.requestPermission(
        force: true,
      );
      if (!mounted) return;
      if (!allowed) {
        showMessage(
          context,
          'Notifications are blocked. Allow them for TaskFlow in your '
          'phone settings, then try again.',
        );
        return;
      }
    }
    await _settings.setNotificationsEnabled(enabled);
  }

  Future<void> _setDigest(bool enabled) async {
    if (enabled) {
      final allowed = await NotificationService.instance.requestPermission(
        force: true,
      );
      if (!mounted) return;
      if (!allowed) {
        showMessage(context, 'Allow notifications to get the daily digest.');
        return;
      }
    }
    await _settings.setDailyDigestEnabled(enabled);
  }

  Future<void> _pickDigestTime(String current) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          parseTimeOfDay(current) ?? const TimeOfDay(hour: 8, minute: 0),
      helpText: 'Daily digest time',
    );
    if (picked == null || !mounted) return;
    await _settings.setDailyDigestTime(formatTime24(picked));
  }

  Future<void> _pickDefaultPriority(TaskPriority current) async {
    final picked = await showModalBottomSheet<TaskPriority>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => _PrioritySheet(current: current),
    );
    if (picked == null || !mounted) return;
    await _settings.setDefaultPriority(picked);
  }

  Future<void> _pickTheme(ThemeMode current) async {
    final picked = await showModalBottomSheet<ThemeMode>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => _ThemeSheet(current: current),
    );
    if (picked == null || !mounted) return;
    await _settings.setThemeMode(picked);
  }

  Future<void> _pickGoal(int current) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => _GoalSheet(current: current),
    );
    if (picked == null || !mounted) return;
    await _settings.setDailyGoal(picked);
  }

  Future<void> _export(List<Task> tasks) async {
    if (tasks.isEmpty) {
      showMessage(context, 'There are no tasks to export yet.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: TaskBackup.encode(tasks)));
    if (!mounted) return;
    setState(() => _exportNote = 'Copied ${plural(tasks.length, 'task')}');
    showMessage(
      context,
      'All tasks are on the clipboard. Paste them somewhere safe.',
    );
  }

  Future<void> _import() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (!mounted) return;
    if (text.trim().isEmpty) {
      showMessage(context, 'Copy a TaskFlow backup first, then tap Import.');
      return;
    }
    try {
      final tasks = TaskBackup.decode(text);
      final added = await ref
          .read(taskListProvider.notifier)
          .importTasks(tasks);
      if (!mounted) return;
      showMessage(
        context,
        added == 0
            ? 'Those tasks are already in your list.'
            : 'Imported ${plural(added, 'task')}.',
      );
    } catch (e) {
      if (mounted) showMessage(context, describeError(e));
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'Your tasks stay on this device and will be here when you sign '
          'back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    final settings = ref.watch(settingsProvider);
    final tasks = ref.watch(taskListProvider.select((s) => s.tasks));
    final colors = context.colors;
    final text = context.text;

    return Column(
      children: [
        const AppHeader(),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 16, 20, dockClearance(context)),
            children: [
              _ProfileCard(
                name: user?.fullName ?? '',
                email: user?.email ?? '',
                memberSince: user?.memberSince,
                onEdit: () => _editName(user?.fullName ?? ''),
              ),
              const SizedBox(height: 24),
              _WeeklyFlow(
                tasks: tasks,
                goal: settings.dailyGoal,
                onEditGoal: () => _pickGoal(settings.dailyGoal),
              ),
              const SizedBox(height: 24),
              _SectionTitle(
                title: 'Preferences',
                trailing: Text(
                  'Automation & UI',
                  style: text.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              _Group(
                children: [
                  _SettingRow(
                    icon: Icons.notifications_active_outlined,
                    iconBackground: colors.primaryFixed.withValues(alpha: 0.5),
                    iconColor: colors.primary,
                    title: 'Push Notifications',
                    subtitle: 'Task reminders & daily digest',
                    trailing: SoftToggle(
                      value: settings.notificationsEnabled,
                      showDot: true,
                      semanticLabel: 'Push notifications',
                      onChanged: _setNotifications,
                    ),
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: settings.notificationsEnabled ? 1 : 0.45,
                    child: IgnorePointer(
                      ignoring: !settings.notificationsEnabled,
                      child: _SettingRow(
                        icon: Icons.wb_sunny_outlined,
                        iconBackground: colors.secondaryFixed.withValues(
                          alpha: 0.5,
                        ),
                        iconColor: colors.secondary,
                        title: 'Daily Morning Digest',
                        titleBadge: _TimeChip(
                          time: settings.dailyDigestTime,
                          onTap: () =>
                              _pickDigestTime(settings.dailyDigestTime),
                        ),
                        subtitle: 'Summary of priorities for today',
                        trailing: SoftToggle(
                          value: settings.dailyDigestEnabled,
                          showDot: true,
                          semanticLabel: 'Daily morning digest',
                          onChanged: _setDigest,
                        ),
                      ),
                    ),
                  ),
                  _SettingRow(
                    icon: Icons.palette_outlined,
                    iconBackground: colors.surfaceContainer,
                    iconColor: colors.onSurfaceVariant,
                    title: 'Theme Mode',
                    onTap: () => _pickTheme(settings.themeMode),
                    subtitle: switch (settings.themeMode) {
                      ThemeMode.light => 'Soft daylight tones',
                      ThemeMode.dark => 'Calm night tones',
                      ThemeMode.system => 'Following your device',
                    },
                    trailing: _ThemeSwitch(
                      dark: context.isDark,
                      onChanged: (dark) => _settings.setThemeMode(
                        dark ? ThemeMode.dark : ThemeMode.light,
                      ),
                    ),
                  ),
                  _SettingRow(
                    icon: Icons.outlined_flag_rounded,
                    iconBackground: colors.tertiaryFixed.withValues(alpha: 0.5),
                    iconColor: colors.tertiary,
                    title: 'Default Priority',
                    subtitle: 'Assigned when creating quick tasks',
                    onTap: () => _pickDefaultPriority(settings.defaultPriority),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PriorityPill(priority: settings.defaultPriority),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: colors.outline,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionTitle(
                title: 'Account & Data',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.phone_android_rounded,
                      size: 14,
                      color: colors.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'On this device',
                      style: text.labelSmall?.copyWith(
                        color: colors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _Group(
                children: [
                  _SettingRow(
                    icon: Icons.file_download_outlined,
                    iconBackground: colors.surfaceContainer,
                    iconColor: colors.primary,
                    title: 'Export Tasks',
                    subtitle:
                        _exportNote ?? 'Copy a full backup to the clipboard',
                    subtitleColor: _exportNote == null
                        ? null
                        : colors.secondary,
                    subtitleIcon: _exportNote == null
                        ? null
                        : Icons.check_circle_outline_rounded,
                    onTap: () => _export(tasks),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primaryFixed.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Copy JSON',
                        style: text.labelSmall?.copyWith(color: colors.primary),
                      ),
                    ),
                  ),
                  _SettingRow(
                    icon: Icons.upload_file_outlined,
                    iconBackground: colors.surfaceContainer,
                    iconColor: colors.onSurfaceVariant,
                    title: 'Import Tasks',
                    subtitle: 'Restore from a copied TaskFlow backup',
                    onTap: _import,
                    trailing: Icon(
                      Icons.content_paste_go_rounded,
                      size: 20,
                      color: colors.outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionTitle(title: 'Session', color: colors.error),
              _Group(
                children: [
                  _SettingRow(
                    icon: Icons.logout_rounded,
                    iconBackground: colors.errorContainer,
                    iconColor: colors.error,
                    title: 'Log Out',
                    titleColor: colors.error,
                    subtitle: 'Safely end session on this device',
                    onTap: _logout,
                    trailing: Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: colors.error.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Dot(color: colors.secondary, size: 6),
                  const SizedBox(width: 6),
                  Text(
                    'TaskFlow v$kAppVersion • Made with serenity',
                    style: text.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Build $kAppBuild • Your data never leaves this device',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: colors.outline),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String name;
  final String email;
  final DateTime? memberSince;
  final VoidCallback onEdit;

  const _ProfileCard({
    required this.name,
    required this.email,
    required this.memberSince,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final since = memberSince;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: context.isDark ? null : AppShadows.sm,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -48,
            right: -48,
            child: Container(
              width: 176,
              height: 176,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.primaryFixed.withValues(alpha: 0.45),
                    colors.primaryFixed.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHigh,
                        shape: BoxShape.circle,
                        boxShadow: context.isDark ? null : AppShadows.md,
                      ),
                      child: const UserAvatar(size: 72),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Tooltip(
                        message: 'Signed in',
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: colors.secondary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.surfaceContainerLowest,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.verified_outlined,
                            size: 13,
                            color: colors.onSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  name.isEmpty ? 'Your name' : name,
                  style: text.headlineMedium,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  email,
                  style: text.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Dot(color: colors.secondary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        since == null
                            ? 'Offline account'
                            : 'Offline account • Member since '
                                  '${DateFormat('MMM y').format(since)}',
                        style: text.labelSmall?.copyWith(color: colors.outline),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Pressable(
                  onTap: onEdit,
                  semanticLabel: 'Edit name',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainer,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: context.isDark ? null : AppShadows.sm,
                    ),
                    child: Text('Edit', style: text.labelMedium),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyFlow extends StatelessWidget {
  final List<Task> tasks;
  final int goal;
  final VoidCallback onEditGoal;

  const _WeeklyFlow({
    required this.tasks,
    required this.goal,
    required this.onEditGoal,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final now = DateTime.now();
    final report = buildReport(tasks, StatsPeriod.week, now);
    final daily = completionsThisWeek(tasks, now);
    final todayIndex = now.weekday - 1;

    // Compare with what the goal asks for by today.
    final expected = goal * (todayIndex + 1);
    final String status;
    if (report.completed == 0) {
      status = 'Fresh week';
    } else if (report.completed >= goal * 7) {
      status = 'Weekly goal met';
    } else if (report.completed >= expected) {
      status = 'On track';
    } else {
      status = 'Building momentum';
    }

    final previous = report.previousCompleted ?? 0;
    final String? change = previous == 0
        ? null
        : '${report.completed >= previous ? '+' : ''}'
              '${((report.completed - previous) / previous * 100).round()}%';

    final onTime = (report.onTimeRate * 100).round();
    final pace = report.completed == 0
        ? 'Nothing due yet'
        : onTime >= 80
        ? 'Steady pace'
        : onTime >= 50
        ? 'Finding a rhythm'
        : 'Room to grow';

    final streakNote = report.streak == 0
        ? 'Start today'
        : report.streak >= report.bestStreak
        ? 'Personal best'
        : 'Best: ${report.bestStreak}d';

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colors.primaryFixed,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.insights_rounded,
                  size: 18,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('Weekly Flow', style: text.headlineSmall)),
              Pill(
                label: status,
                background: colors.secondary.withValues(alpha: 0.1),
                foreground: colors.secondary,
                style: text.labelSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Done',
                  icon: Icons.task_alt_rounded,
                  iconColor: colors.primary,
                  value: '${report.completed}',
                  footer: change == null
                      ? Text(
                          'this week',
                          style: text.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        )
                      : Row(
                          children: [
                            Icon(
                              report.completed >= previous
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              size: 13,
                              color: colors.secondary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              change,
                              style: text.labelSmall?.copyWith(
                                color: colors.secondary,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  label: 'On-Time',
                  icon: Icons.schedule_rounded,
                  iconColor: colors.secondary,
                  value: '$onTime%',
                  footer: Text(
                    pace,
                    style: text.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  label: 'Streak',
                  icon: Icons.local_fire_department_rounded,
                  iconColor: colors.tertiaryContainer,
                  value: '${report.streak}',
                  unit: 'd',
                  footer: Text(
                    streakNote,
                    style: text.labelSmall?.copyWith(
                      color: colors.tertiary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Daily Breakdown', style: text.labelMedium),
                    ),
                    Pressable(
                      onTap: onEditGoal,
                      semanticLabel: 'Change daily target',
                      child: Row(
                        children: [
                          Text(
                            'Target: $goal tasks/day',
                            style: text.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.edit_outlined,
                            size: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _DailyBars(values: daily, goal: goal, todayIndex: todayIndex),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final String value;
  final String? unit;
  final Widget footer;

  const _MiniStat({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.footer,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: text.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 16, color: iconColor),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: value),
                  if (unit != null)
                    TextSpan(text: unit, style: text.labelMedium),
                ],
              ),
              style: text.displayMedium,
            ),
          ),
          const SizedBox(height: 2),
          footer,
        ],
      ),
    );
  }
}

class _DailyBars extends StatelessWidget {
  final List<int> values;
  final int goal;
  final int todayIndex;

  const _DailyBars({
    required this.values,
    required this.goal,
    required this.todayIndex,
  });

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _names = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final top = [...values, goal].reduce((a, b) => a > b ? a : b);

    // Fixed-height chart: keep huge accessibility text from overflowing it.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: SizedBox(
        height: 96,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 7; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Tooltip(
                  message: '${_names[i]}: ${plural(values[i], 'task')}',
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (i == todayIndex)
                        Text(
                          '${values[i]}',
                          style: text.labelSmall?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            height: 4 + 44 * (values[i] / top),
                            decoration: BoxDecoration(
                              color: i == todayIndex
                                  ? colors.primaryContainer
                                  : values[i] >= goal
                                  ? colors.primary
                                  : colors.primaryFixed,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                            ),
                          ),
                          if (i == todayIndex)
                            Positioned(
                              top: -4,
                              child: Dot(color: colors.primary, size: 6),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _letters[i],
                        style: text.labelSmall?.copyWith(
                          color: i == todayIndex
                              ? colors.primary
                              : colors.onSurfaceVariant,
                          fontWeight: i == todayIndex ? FontWeight.w700 : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Color? color;

  const _SectionTitle({required this.title, this.trailing, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: context.text.headlineSmall?.copyWith(color: color),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;

  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 4),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final Color? titleColor;
  final Widget? titleBadge;
  final String subtitle;
  final Color? subtitleColor;
  final IconData? subtitleIcon;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingRow({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.titleColor,
    this.titleBadge,
    this.subtitleColor,
    this.subtitleIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final subColor = subtitleColor ?? colors.onSurfaceVariant;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              IconTile(
                icon: icon,
                background: iconBackground,
                color: iconColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: text.headlineSmall?.copyWith(
                              color: titleColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (titleBadge != null) ...[
                          const SizedBox(width: 8),
                          titleBadge!,
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        if (subtitleIcon != null) ...[
                          Icon(subtitleIcon, size: 14, color: subColor),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            subtitle,
                            style: text.bodySmall?.copyWith(color: subColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String time;
  final VoidCallback onTap;

  const _TimeChip({required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final parsed = parseTimeOfDay(time);
    return Pressable(
      onTap: onTap,
      semanticLabel: 'Change digest time',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: context.colors.surfaceContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          parsed == null ? time : formatTimeOfDay(parsed),
          style: context.text.labelSmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _ThemeSwitch extends StatelessWidget {
  final bool dark;
  final ValueChanged<bool> onChanged;

  const _ThemeSwitch({required this.dark, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Widget option(bool isDark, IconData icon, String label) {
      final selected = dark == isDark;
      return Pressable(
        onTap: () => onChanged(isDark),
        semanticLabel: '$label theme',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? colors.surfaceContainerLowest : null,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected && !context.isDark ? AppShadows.sm : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: context.text.labelSmall?.copyWith(
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          option(false, Icons.light_mode_rounded, 'Light'),
          option(true, Icons.dark_mode_outlined, 'Dark'),
        ],
      ),
    );
  }
}

class _PriorityPill extends StatelessWidget {
  final TaskPriority priority;

  const _PriorityPill({required this.priority});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (bg, fg, dot) = switch (priority) {
      TaskPriority.low => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
        colors.secondary,
      ),
      TaskPriority.medium => (
        colors.tertiaryFixed,
        colors.onTertiaryFixed,
        colors.tertiary,
      ),
      TaskPriority.high => (
        colors.errorContainer,
        colors.onErrorContainer,
        colors.error,
      ),
    };
    return Pill(
      label: priority.label,
      background: bg,
      foreground: fg,
      dot: dot,
    );
  }
}

class _PrioritySheet extends StatelessWidget {
  final TaskPriority current;

  const _PrioritySheet({required this.current});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                'Default priority',
                style: context.text.headlineMedium,
              ),
            ),
            for (final p in TaskPriority.values.reversed)
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: _PriorityPill(priority: p),
                title: Text(p.mood),
                trailing: p == current
                    ? Icon(Icons.check_rounded, color: context.colors.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(p),
              ),
          ],
        ),
      ),
    );
  }
}

class _ThemeSheet extends StatelessWidget {
  final ThemeMode current;

  const _ThemeSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    const options = [
      (ThemeMode.light, Icons.light_mode_rounded, 'Light'),
      (ThemeMode.dark, Icons.dark_mode_outlined, 'Dark'),
      (ThemeMode.system, Icons.brightness_auto_outlined, 'Follow device'),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text('Theme', style: context.text.headlineMedium),
            ),
            for (final (mode, icon, label) in options)
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: Icon(icon),
                title: Text(label),
                trailing: mode == current
                    ? Icon(Icons.check_rounded, color: context.colors.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(mode),
              ),
          ],
        ),
      ),
    );
  }
}

class _GoalSheet extends StatelessWidget {
  final int current;

  const _GoalSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily target', style: context.text.headlineMedium),
            const SizedBox(height: 4),
            Text(
              'How many tasks would you like to finish on a good day?',
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var n = 1; n <= 10; n++)
                  ChoicePill(
                    label: '$n',
                    selected: n == current,
                    strong: true,
                    onTap: () => Navigator.of(context).pop(n),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  final String initial;

  const _NameDialog({required this.initial});

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Your name'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(hintText: 'Full name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
