import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../tasks/presentation/providers/task_provider.dart';
import '../providers/settings_provider.dart';
import '../../../tasks/domain/entities/task.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final authState = ref.watch(authProvider);
    final user = authState.value;

    final taskState = ref.watch(taskListProvider);
    final stats = taskState.stats;

    final settingsAsync = ref.watch(settingsControllerProvider);
    final settingsNotifier = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: Text('Profile', style: textTheme.headlineSmall?.copyWith(color: colorScheme.onSurface)),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.outlineVariant.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, shape: BoxShape.circle),
                                child: Icon(Icons.verified, color: colorScheme.secondary, size: 20),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(user?.fullName ?? 'Guest User', style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: colorScheme.tertiaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.star, color: colorScheme.onTertiaryContainer, size: 12),
                                        const SizedBox(width: 4),
                                        Text('Pro Plan', style: textTheme.bodySmall?.copyWith(color: colorScheme.onTertiaryContainer, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(user?.email ?? 'guest@example.com', style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                              const SizedBox(height: 4),
                              Text('Design Team Workspace', style: textTheme.bodySmall?.copyWith(color: colorScheme.outline)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: colorScheme.onSurface),
                          onPressed: null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Weekly Flow', style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Top 5% Momentum',
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSecondaryContainer, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildMetricCard(context, 'Done', '${stats.tasksCompleted}', '+14%', colorScheme.primary)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMetricCard(context, 'On-Time', '${(stats.onTimePercentage * 100).toInt()}%', null, colorScheme.secondary)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMetricCard(context, 'Streak', '${stats.currentStreak}d', 'Personal best', colorScheme.tertiary)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 120,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily Breakdown', style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildBar(context, 'M', 40),
                        _buildBar(context, 'T', 60),
                        _buildBar(context, 'W', 80, isToday: true),
                        _buildBar(context, 'T', 30),
                        _buildBar(context, 'F', 50),
                        _buildBar(context, 'S', 20),
                        _buildBar(context, 'S', 10),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Preferences', style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface)),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    _buildSettingsRow(
                      context,
                      'Push Notifications',
                      trailing: Switch(
                        value: settingsAsync.value?.pushNotificationsEnabled ?? true,
                        onChanged: (v) => settingsNotifier.updatePushNotificationsEnabled(v),
                        activeColor: colorScheme.primary,
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildSettingsRow(
                      context,
                      'Daily Morning Digest',
                      trailing: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: colorScheme.surface, borderRadius: BorderRadius.circular(16)),
                            child: Text('08:00 AM', style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface)),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: settingsAsync.value?.dailyDigestEnabled ?? false,
                            onChanged: (v) => settingsNotifier.updateDailyDigestEnabled(v),
                            activeColor: colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildSettingsRow(
                      context,
                      'Theme Mode',
                      trailing: DropdownButton<ThemeMode>(
                        value: settingsAsync.value?.themeMode ?? ThemeMode.system,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                          DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                          DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                        ],
                        onChanged: (val) {
                          if (val != null) settingsNotifier.updateThemeMode(val);
                        },
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildSettingsRow(
                      context,
                      'Default Priority',
                      trailing: DropdownButton<TaskPriority>(
                        value: settingsAsync.value?.defaultPriority ?? TaskPriority.medium,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: TaskPriority.low, child: Text('Low')),
                          DropdownMenuItem(value: TaskPriority.medium, child: Text('Medium')),
                          DropdownMenuItem(value: TaskPriority.high, child: Text('High')),
                        ],
                        onChanged: (val) {
                          if (val != null) settingsNotifier.updateDefaultPriority(val);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Account & Data', style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface)),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Backup & Cloud Sync', style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface)),
                              Text('Last synced 5m ago', style: textTheme.bodySmall?.copyWith(color: colorScheme.outline)),
                            ],
                          ),
                          TextButton(
                            onPressed: null,
                            style: TextButton.styleFrom(
                              backgroundColor: colorScheme.surface,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: Text('Sync Now', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildSettingsRow(
                      context,
                      'Export Tasks',
                      trailing: IconButton(
                        icon: Icon(Icons.open_in_new, color: colorScheme.outline, size: 20),
                        onPressed: null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Session', style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => ref.read(authProvider.notifier).logout(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colorScheme.errorContainer),
                    ),
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                  child: Text(
                    'Log Out',
                    style: textTheme.bodyLarge?.copyWith(color: colorScheme.error, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: Column(
                  children: [
                    Text('TaskFlow v2.4.0 • Made with serenity', style: textTheme.bodySmall?.copyWith(color: colorScheme.outline)),
                    const SizedBox(height: 4),
                    Text('Build 4829 • All systems operational', style: textTheme.bodySmall?.copyWith(color: colorScheme.outline)),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, String value, String? subtitle, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: textTheme.headlineSmall?.copyWith(color: colorScheme.onSurface, fontSize: 24)),
              if (subtitle != null) ...[
                const SizedBox(width: 4),
                if (subtitle.contains('%'))
                  Text(subtitle, style: textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.bold)),
              ]
            ],
          ),
          if (subtitle != null && !subtitle.contains('%')) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: textTheme.bodySmall?.copyWith(color: colorScheme.outline, fontSize: 10)),
          ]
        ],
      ),
    );
  }

  Widget _buildBar(BuildContext context, String label, double height, {bool isToday = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 24,
          height: height,
          decoration: BoxDecoration(
            color: isToday ? colorScheme.primary : colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(4),
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
    );
  }

  Widget _buildSettingsRow(BuildContext context, String title, {required Widget trailing}) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface)),
          trailing,
        ],
      ),
    );
  }
}
