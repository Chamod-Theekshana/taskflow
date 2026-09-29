import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/progress_ring.dart';
import '../../../shared/widgets/ui.dart';
import '../../tasks/presentation/providers/task_provider.dart';
import '../domain/productivity.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  StatsPeriod _period = StatsPeriod.week;

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskListProvider.select((s) => s.tasks));
    final report = buildReport(tasks, _period, DateTime.now());

    return Column(
      children: [
        const AppHeader(),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 20, 20, dockClearance(context)),
            children: [
              _PeriodPicker(
                value: _period,
                onChanged: (p) => setState(() => _period = p),
              ),
              const SizedBox(height: 16),
              _FlowCard(report: report),
              const SizedBox(height: 16),
              _WeekdayChart(report: report),
              const SizedBox(height: 16),
              _AllocationCard(shares: report.categories),
              const SizedBox(height: 16),
              _FocusWindowCard(
                window: report.focusWindow,
                completed: report.completed,
              ),
              const SizedBox(height: 14),
              _MilestoneCard(
                achievement: report.achievement,
                next: report.nextMilestone,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PeriodPicker extends StatelessWidget {
  final StatsPeriod value;
  final ValueChanged<StatsPeriod> onChanged;

  const _PeriodPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: p.cardMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          for (final period in StatsPeriod.values)
            Expanded(
              child: Pressable(
                onTap: () => onChanged(period),
                semanticLabel: period.label,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: period == value ? p.accent : null,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: period == value ? null : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          period.label,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: period == value
                                ? Colors.white
                                : p.textSecondary,
                          ),
                        ),
                      ),
                      if (period == value) ...[
                        const SizedBox(width: 6),
                        Dot(
                          color: Colors.white.withValues(alpha: 0.9),
                          size: 6,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FlowCard extends StatelessWidget {
  final ProductivityReport report;

  const _FlowCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = context.text;
    final score = report.flowScore;

    final (Color statusBg, Color statusBorder, Color statusFg) = switch (score) {
      >= 60 => (p.successTint, p.successBorder, p.success),
      > 0 => (
        p.accent.withValues(alpha: 0.12),
        p.accent.withValues(alpha: 0.3),
        p.accent,
      ),
      _ => (p.raised, p.border, p.textSecondary),
    };

    return Panel(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LIVE STATE',
                      style: text.labelSmall?.copyWith(
                        color: p.accent,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('Productivity Flow', style: text.headlineMedium),
                  ],
                ),
              ),
              Pill(
                label: report.flowLabel,
                background: statusBg,
                foreground: statusFg,
                border: statusBorder,
                dot: statusFg,
                pulseDot: score > 0,
                style: text.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Tooltip(
            message:
                'How much of what was due got done, and how much of it was '
                'on time.',
            child: ProgressRing(
              progress: score / 100,
              size: 144,
              strokeWidth: 12,
              color: p.accent,
              trackColor: p.track,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '$score'),
                        TextSpan(
                          text: '%',
                          style: TextStyle(
                            fontSize: 20,
                            color: p.accent,
                          ),
                        ),
                      ],
                    ),
                    style: text.displayLarge?.copyWith(height: 1.15),
                  ),
                  Text(
                    'Flow Score',
                    style: text.labelSmall?.copyWith(color: p.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Completed',
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: p.success,
                  value: '${report.completed}',
                  unit: report.completed == 1 ? 'task' : 'tasks',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(
                  label: 'On-Time',
                  icon: Icons.schedule_rounded,
                  iconColor: p.accent,
                  value: '${(report.onTimeRate * 100).round()}',
                  suffix: '%',
                  unit: 'rate',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Day Streak',
                  icon: Icons.local_fire_department_outlined,
                  iconColor: p.accent,
                  value: '${report.streak}',
                  unit: report.streak >= 3
                      ? 'days 🔥'
                      : (report.streak == 1 ? 'day' : 'days'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(
                  label: 'Overdue',
                  icon: Icons.history_rounded,
                  iconColor: p.textSecondary,
                  value: '${report.overdue}',
                  unit: report.overdue == 0 ? 'all clear' : 'to clear',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final String value;
  final String? suffix;
  final String unit;

  const _Metric({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.unit,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = context.text;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.raised,
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
              Icon(icon, size: 18, color: iconColor),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: text.displaySmall?.copyWith(height: 1.1),
                ),
                if (suffix != null)
                  TextSpan(
                    text: suffix,
                    style: text.headlineMedium?.copyWith(color: p.accent),
                  ),
                TextSpan(
                  text: '  $unit',
                  style: text.bodySmall?.copyWith(color: p.textSecondary),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _WeekdayChart extends StatelessWidget {
  final ProductivityReport report;

  const _WeekdayChart({required this.report});

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = context.text;
    final values = report.byWeekday;
    final peak = values.reduce(math.max);
    final peakIndex = peak == 0 ? -1 : values.indexOf(peak);
    final trend = report.trendLabel;
    final up = report.trendIsUp;
    final trendColor = up ? p.accent : p.peach;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Weekly Completion', style: text.headlineMedium),
                    Text(
                      'Tasks wrapped up by weekday',
                      style: text.bodySmall?.copyWith(color: p.textSecondary),
                    ),
                  ],
                ),
              ),
              if (trend != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Pill(
                    label: trend,
                    icon: up
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    iconSize: 16,
                    background: trendColor.withValues(alpha: 0.1),
                    foreground: trendColor,
                    border: trendColor.withValues(alpha: 0.2),
                    style: text.labelMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: Stack(
              children: [
                Positioned.fill(
                  bottom: 26,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < 4; i++)
                        Container(
                          height: 1,
                          color: p.border.withValues(alpha: 0.4),
                        ),
                    ],
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: _Bar(
                          day: _days[i],
                          value: values[i],
                          fraction: peak == 0 ? 0 : values[i] / peak,
                          isPeak: i == peakIndex,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (peak == 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Finish a few tasks and your weekly rhythm will show here.',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: p.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String day;
  final int value;
  final double fraction;
  final bool isPeak;

  const _Bar({
    required this.day,
    required this.value,
    required this.fraction,
    required this.isPeak,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = context.text;
    final barHeight = 20 + 124 * fraction;

    return Semantics(
      label: '$day: ${plural(value, 'task')}',
      excludeSemantics: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isPeak)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: p.accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$value',
                style: text.labelSmall?.copyWith(color: Colors.white),
              ),
            )
          else
            Text(
              '$value',
              style: text.labelSmall?.copyWith(color: p.textSecondary),
            ),
          const SizedBox(height: 8),
          // Flexible: very large text can't push the bar out of the chart.
          Flexible(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 20, end: barHeight),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, height, _) => Container(
                width: 28,
                height: height,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: p.track,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: value == 0
                    ? null
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          color: p.accent.withValues(
                            alpha: isPeak ? 1 : 0.4 + 0.4 * fraction,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: null,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            day,
            style: text.labelSmall?.copyWith(
              color: isPeak ? p.accent : p.textSecondary,
              fontWeight: isPeak ? FontWeight.w700 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _AllocationCard extends StatelessWidget {
  final List<CategoryShare> shares;

  const _AllocationCard({required this.shares});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = context.text;
    final palette = [
      p.accent,
      const Color(0xFFFB923C),
      p.success,
      p.amber,
    ];

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Time Allocation', style: text.headlineMedium),
              ),
              Text(
                switch (shares.length) {
                  0 => 'No tasks yet',
                  1 => '1 Category',
                  final n => '$n Categories',
                },
                style: text.labelSmall?.copyWith(color: p.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 12,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: p.track,
              borderRadius: BorderRadius.circular(999),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: shares.isEmpty
                  ? const SizedBox.expand()
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < shares.length; i++) ...[
                          if (i > 0) const SizedBox(width: 2),
                          Expanded(
                            flex: math.max(1, (shares[i].share * 1000).round()),
                            child: ColoredBox(color: palette[i]),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          if (shares.isEmpty)
            Text(
              'Tasks due in this period will be grouped by category here.',
              style: text.bodySmall?.copyWith(color: p.textMuted),
            ),
          for (var i = 0; i < shares.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == shares.length - 1 ? 0 : 12),
              child: Row(
                children: [
                  Dot(color: palette[i], size: 12),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      shares[i].name,
                      style: text.labelLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    plural(shares[i].count, 'task'),
                    style: text.bodySmall?.copyWith(color: p.textSecondary),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${(shares[i].share * 100).round()}%',
                      textAlign: TextAlign.right,
                      style: text.labelMedium,
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

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final String eyebrow;
  final Color eyebrowColor;
  final String title;
  final String body;

  const _InsightCard({
    required this.icon,
    required this.eyebrow,
    required this.eyebrowColor,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return Panel(
      padding: const EdgeInsets.all(16),
      shadow: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon, size: 44, iconSize: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: text.labelSmall?.copyWith(
                    color: eyebrowColor,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(title, style: text.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: text.bodySmall?.copyWith(
                    color: context.palette.textSecondary,
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

class _FocusWindowCard extends StatelessWidget {
  final FocusWindow? window;
  final int completed;

  const _FocusWindowCard({required this.window, required this.completed});

  @override
  Widget build(BuildContext context) {
    final w = window;
    String hour(int h) => DateFormat('h:mm a').format(DateTime(2000, 1, 1, h));

    return _InsightCard(
      icon: Icons.wb_sunny_outlined,
      eyebrow: 'OPTIMAL WINDOW',
      eyebrowColor: context.palette.textSecondary,
      title: w == null
          ? 'Still learning your rhythm'
          : '${hour(w.startHour)} – ${hour(w.endHour % 24)}',
      body: w == null
          ? 'Finish a few more tasks and your best focus hours will show up '
                'here.'
          : '${w.count} of the $completed tasks you finished were wrapped up '
                'in this window.',
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  final Milestone? achievement;
  final Milestone? next;

  const _MilestoneCard({required this.achievement, required this.next});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement;
    final upcoming = next;

    if (unlocked == null && upcoming == null) return const SizedBox.shrink();

    return _InsightCard(
      icon: unlocked == null
          ? Icons.flag_outlined
          : Icons.workspace_premium_outlined,
      eyebrow: unlocked == null ? 'NEXT MILESTONE' : 'ACHIEVEMENT UNLOCKED',
      eyebrowColor: context.palette.accent,
      title: (unlocked ?? upcoming)!.title,
      body: unlocked != null
          ? upcoming == null
                ? unlocked.description
                : '${unlocked.description} Next up: ${upcoming.title}.'
          : upcoming!.goal,
    );
  }
}
