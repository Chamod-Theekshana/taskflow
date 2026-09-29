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
import '../../../tasks/presentation/widgets/task_ui.dart';
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
    final name = await promptForText(
      context,
      title: 'Your name',
      hint: 'Full name',
      confirmLabel: 'Save',
      initial: current,
      capitalization: TextCapitalization.words,
    );
    if (name == null || name.trim() == current.trim() || !mounted) return;
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
    final picked = await showChoiceSheet<TaskPriority>(
      context,
      title: 'Default priority',
      subtitle: 'Used for new tasks unless the title says otherwise.',
      options: [
        for (final p in TaskPriority.values.reversed)
          (value: p, label: '${p.label} · ${p.mood}', icon: Icons.flag_outlined),
      ],
      selected: current,
    );
    if (picked == null || !mounted) return;
    await _settings.setDefaultPriority(picked);
  }

  Future<void> _pickTheme(ThemeMode current) async {
    final picked = await showChoiceSheet<ThemeMode>(
      context,
      title: 'Theme',
      options: const [
        (
          value: ThemeMode.dark,
          label: 'Dark',
          icon: Icons.dark_mode_outlined,
        ),
        (
          value: ThemeMode.light,
          label: 'Light',
          icon: Icons.light_mode_outlined,
        ),
        (
          value: ThemeMode.system,
          label: 'Follow device',
          icon: Icons.brightness_auto_outlined,
        ),
      ],
      selected: current,
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
    final confirmed = await confirmAction(
      context,
      title: 'Log out?',
      message:
          'Your tasks stay on this device and will be here when you sign '
          'back in.',
      confirmLabel: 'Log out',
    );
    if (!confirmed || !mounted) return;
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    final settings = ref.watch(settingsProvider);
    final tasks = ref.watch(taskListProvider.select((s) => s.tasks));
    final p = context.palette;
    final text = context.text;

    return Column(
      children: [
        const AppHeader(),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 20, 20, dockClearance(context)),
            children: [
              _ProfileCard(
                name: user?.fullName ?? '',
                email: user?.email ?? '',
                memberSince: user?.memberSince,
                onEdit: () => _editName(user?.fullName ?? ''),
              ),
              const SizedBox(height: 20),
              _WeeklyFlow(
                tasks: tasks,
                goal: settings.dailyGoal,
                onEditGoal: () => _pickGoal(settings.dailyGoal),
              ),
              const SizedBox(height: 20),
              GroupTitle(
                title: 'Preferences',
                trailing: Text(
                  'Automation & UI',
                  style: text.labelSmall?.copyWith(color: p.textSecondary),
                ),
              ),
              _Group(
                children: [
                  _SettingRow(
                    icon: Icons.notifications_active_outlined,
                    title: 'Push Notifications',
                    subtitle: 'Task reminders & daily digest',
                    onTap: () =>
                        _setNotifications(!settings.notificationsEnabled),
                    trailing: AppSwitch(
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
                        title: 'Daily Morning Digest',
                        titleBadge: _TimeChip(
                          time: settings.dailyDigestTime,
                          onTap: () =>
                              _pickDigestTime(settings.dailyDigestTime),
                        ),
                        subtitle: 'Summary of priorities for today',
                        onTap: () => _setDigest(!settings.dailyDigestEnabled),
                        trailing: AppSwitch(
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
                    title: 'Theme Mode',
                    onTap: () => _pickTheme(settings.themeMode),
                    subtitle: switch (settings.themeMode) {
                      ThemeMode.dark => 'Dark obsidian & vibrant orange',
                      ThemeMode.light => 'Light canvas & vibrant orange',
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
                    icon: Icons.flag_outlined,
                    title: 'Default Priority',
                    subtitle: 'Assigned when creating quick tasks',
                    onTap: () => _pickDefaultPriority(settings.defaultPriority),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Pill(
                          label: settings.defaultPriority.label,
                          background: p.accent.withValues(alpha: 0.15),
                          foreground: p.accentSoft,
                          border: p.accent.withValues(alpha: 0.3),
                          dot: priorityAccent(p, settings.defaultPriority),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: p.textMuted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GroupTitle(
                title: 'Account & Data',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.phone_android_rounded,
                      size: 14,
                      color: p.success,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'On this device',
                      style: text.labelSmall?.copyWith(
                        color: p.success,
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
                    title: 'Export Tasks',
                    subtitle:
                        _exportNote ?? 'Copy a full backup to the clipboard',
                    subtitleColor: _exportNote == null ? null : p.success,
                    subtitleIcon: _exportNote == null
                        ? null
                        : Icons.check_circle_outline_rounded,
                    onTap: () => _export(tasks),
                    trailing: Pill(
                      label: 'Copy JSON',
                      background: p.accent.withValues(alpha: 0.15),
                      foreground: p.accent,
                      border: p.accent.withValues(alpha: 0.3),
                      style: text.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                  ),
                  _SettingRow(
                    icon: Icons.upload_file_outlined,
                    title: 'Import Tasks',
                    subtitle: 'Restore from a copied TaskFlow backup',
                    onTap: _import,
                    trailing: Icon(
                      Icons.content_paste_go_rounded,
                      size: 20,
                      color: p.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GroupTitle(title: 'Session', color: p.danger),
              _Group(
                children: [
                  _SettingRow(
                    icon: Icons.logout_rounded,
                    iconColor: p.danger,
                    title: 'Log Out',
                    titleColor: p.danger,
                    subtitle: 'Safely end session on this device',
                    onTap: _logout,
                    trailing: Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: p.danger.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Dot(color: p.accent, size: 6),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'TaskFlow v$kAppVersion • Obsidian Flow',
                      style: text.labelSmall?.copyWith(color: p.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Build $kAppBuild • Your data never leaves this device',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(
                  fontSize: 11,
                  color: p.textFaint,
                ),
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
    final p = context.palette;
    final text = context.text;
    final since = memberSince;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.border),
        boxShadow: p.cardShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    p.accent.withValues(alpha: 0.16),
                    p.accent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: p.raised,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: p.accent.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: const UserAvatar(size: 72, ring: false),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Tooltip(
                        message: 'Signed in',
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: p.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: p.card, width: 2),
                          ),
                          child: const Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  name.isEmpty ? 'Your name' : name,
                  style: text.headlineLarge,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: text.bodySmall?.copyWith(color: p.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Dot(color: p.accent),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        since == null
                            ? 'Offline account'
                            : 'Offline account • Member since '
                                  '${DateFormat('MMM y').format(since)}',
                        style: text.labelSmall?.copyWith(color: p.textMuted),
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
                      horizontal: 18,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: p.raised,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: p.border),
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
    final p = context.palette;
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
        ? 'Nothing done yet'
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

    final footStyle = text.labelSmall?.copyWith(color: p.textSecondary);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: p.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: p.accent.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.insights_rounded, size: 18, color: p.accent),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('Weekly Flow', style: text.headlineSmall)),
              const SizedBox(width: 8),
              Flexible(
                child: Pill(
                  label: status,
                  background: p.accent.withValues(alpha: 0.15),
                  foreground: p.accent,
                  border: p.accent.withValues(alpha: 0.3),
                  style: text.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
                  iconColor: p.accent,
                  value: '${report.completed}',
                  footer: change == null
                      ? Text('this week', style: footStyle)
                      : Row(
                          children: [
                            Icon(
                              report.completed >= previous
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              size: 13,
                              color: p.accent,
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                change,
                                style: footStyle?.copyWith(color: p.accent),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: 'On-Time',
                  icon: Icons.schedule_rounded,
                  iconColor: p.success,
                  value: '$onTime%',
                  footer: Text(
                    pace,
                    style: footStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: 'Streak',
                  icon: Icons.local_fire_department_rounded,
                  iconColor: p.accent,
                  value: '${report.streak}',
                  unit: 'd',
                  footer: Text(
                    streakNote,
                    style: footStyle?.copyWith(
                      color: p.accentSoft,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.cardMuted,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Daily Breakdown',
                        style: text.labelMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Pressable(
                      onTap: onEditGoal,
                      semanticLabel: 'Change daily target',
                      child: Row(
                        children: [
                          Text('Target: $goal tasks/day', style: footStyle),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit_outlined,
                            size: 12,
                            color: p.textSecondary,
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
    final p = context.palette;
    final text = context.text;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.cardMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: text.labelSmall?.copyWith(color: p.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 16, color: iconColor),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: value),
                  if (unit != null)
                    TextSpan(
                      text: unit,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: p.textSecondary,
                      ),
                    ),
                ],
              ),
              style: text.displaySmall?.copyWith(fontSize: 24, height: 1.2),
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
    final top = [...values, goal].reduce((a, b) => a > b ? a : b);

    // Fixed-height chart: keep huge accessibility text from overflowing it.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: SizedBox(
        height: 100,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 7; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Tooltip(
                  message: '${_names[i]}: ${plural(values[i], 'task')}',
                  child: _DayBar(
                    letter: _letters[i],
                    value: values[i],
                    fraction: values[i] / top,
                    metGoal: values[i] >= goal,
                    isToday: i == todayIndex,
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

class _DayBar extends StatelessWidget {
  final String letter;
  final int value;
  final double fraction;
  final bool metGoal;
  final bool isToday;

  const _DayBar({
    required this.letter,
    required this.value,
    required this.fraction,
    required this.metGoal,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = context.text;
    final Color color;
    if (isToday || metGoal) {
      color = p.accent;
    } else if (value > 0) {
      color = p.accent.withValues(alpha: 0.5);
    } else {
      color = p.track;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '$value',
          style: text.labelSmall?.copyWith(
            fontSize: 10,
            color: isToday
                ? p.accent
                : (value > 0 ? p.textSecondary : Colors.transparent),
            fontWeight: isToday ? FontWeight.w700 : null,
          ),
        ),
        const SizedBox(height: 4),
        Flexible(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                height: 6 + 46 * fraction,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  boxShadow: null,
                ),
              ),
              if (isToday)
                const Positioned(
                  top: -3,
                  child: Dot(color: Colors.white, size: 6),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          letter,
          style: text.labelSmall?.copyWith(
            color: isToday ? p.accent : p.textSecondary,
            fontWeight: isToday ? FontWeight.w700 : null,
          ),
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;

  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return Panel(
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
  final Color? iconColor;
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
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.iconColor,
    this.titleColor,
    this.titleBadge,
    this.subtitleColor,
    this.subtitleIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = context.text;
    final subColor = subtitleColor ?? p.textSecondary;
    final badge = titleBadge;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              IconTile(icon: icon, color: iconColor),
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
                            style: text.titleSmall?.copyWith(
                              fontWeight: titleColor == null
                                  ? FontWeight.w500
                                  : FontWeight.w600,
                              color: titleColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          badge,
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        if (subtitleIcon != null) ...[
                          Icon(subtitleIcon, size: 14, color: subColor),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            subtitle,
                            style: text.bodySmall?.copyWith(
                              fontSize: 12,
                              color: subColor,
                            ),
                            maxLines: 1,
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
    final p = context.palette;
    final parsed = parseTimeOfDay(time);
    return Pressable(
      onTap: onTap,
      semanticLabel: 'Change digest time',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: p.track,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: p.border),
        ),
        child: Text(
          parsed == null ? time : formatTimeOfDay(parsed),
          style: context.text.labelSmall?.copyWith(
            fontSize: 10,
            color: p.text.withValues(alpha: 0.8),
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
    final p = context.palette;
    // Narrow phones only get the icons, so the row keeps room for its title.
    final showLabels = MediaQuery.sizeOf(context).width >= 360;

    Widget option(bool isDark, IconData icon, String label) {
      final selected = dark == isDark;
      final fg = selected ? Colors.white : p.textSecondary;
      return Pressable(
        onTap: () => onChanged(isDark),
        semanticLabel: '$label theme',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: showLabels ? 9 : 8,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: selected ? p.accent : null,
            borderRadius: BorderRadius.circular(999),
            boxShadow: null,
          ),
          child: Row(
            children: [
              Icon(icon, size: 15, color: fg),
              if (showLabels) ...[
                const SizedBox(width: 4),
                Text(
                  label,
                  style: context.text.labelSmall?.copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: p.cardMuted,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: p.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            option(false, Icons.light_mode_outlined, 'Light'),
            option(true, Icons.dark_mode_rounded, 'Dark'),
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
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var n = 1; n <= 10; n++)
                  FilterPill(
                    label: '$n',
                    selected: n == current,
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






