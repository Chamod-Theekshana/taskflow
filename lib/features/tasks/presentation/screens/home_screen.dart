import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_guard.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/progress_ring.dart';
import '../../../../shared/widgets/ui.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/task.dart';
import '../providers/task_provider.dart';
import '../widgets/task_card.dart';
import '../widgets/task_filter_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final TextEditingController _search = TextEditingController(
    text: ref.read(taskListProvider).searchQuery,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taskListProvider);
    final notifier = ref.read(taskListProvider.notifier);
    final name = ref.watch(authProvider.select((a) => a.value?.firstName));
    final now = DateTime.now();
    final visible = state.visibleTasks(now);

    return Column(
      children: [
        AppHeader(
          action: _AddButton(),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: notifier.refresh,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                dockClearance(context),
              ),
              children: [
                _Greeting(tasks: state.tasks, name: name, now: now),
                const SizedBox(height: 12),
                _FocusCard(tasks: state.tasks, now: now),
                const SizedBox(height: 32),
                AppSearchField(
                  controller: _search,
                  hint: 'Search your tasks, projects or tags...',
                  onChanged: notifier.setSearchQuery,
                  trailing: _RefineButton(active: state.hasRefinements),
                ),
                const SizedBox(height: 20),
                _FilterRow(state: state, now: now),
                const SizedBox(height: 16),
                ..._list(state, visible, name),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _list(TaskListState state, List<Task> visible, String? name) {
    if (state.isLoading && state.tasks.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (state.errorMessage != null && state.tasks.isEmpty) {
      return [
        EmptyState(
          icon: Icons.cloud_off_rounded,
          title: "Couldn't load your tasks",
          message: state.errorMessage!,
          action: TextButton(
            onPressed: ref.read(taskListProvider.notifier).refresh,
            child: const Text('Try again'),
          ),
        ),
      ];
    }
    if (visible.isEmpty) {
      final searching =
          state.searchQuery.trim().isNotEmpty || state.hasRefinements;
      final who = (name == null || name.isEmpty) ? '' : ', $name';
      return [
        EmptyState(
          icon: searching ? Icons.search_off_rounded : Icons.spa_outlined,
          title: searching ? 'No matches' : 'Breathe easy$who',
          message: searching
              ? 'Nothing fits this search. Try other words or clear the '
                    'filters.'
              : state.tasks.isEmpty
              ? 'No tasks yet. Tap + to add the first thing on your mind.'
              : 'No tasks in this view right now. Take a mindful pause or '
                    'plan ahead.',
        ),
      ];
    }
    return [
      for (final task in visible)
        Padding(
          key: ValueKey(task.id),
          padding: const EdgeInsets.only(bottom: 12),
          child: TaskCard(task: task),
        ),
    ];
  }
}

class _Greeting extends StatelessWidget {
  final List<Task> tasks;
  final String? name;
  final DateTime now;

  const _Greeting({required this.tasks, required this.name, required this.now});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = context.text;
    final pending = tasks.where((t) => !t.isCompleted).length;
    final today = tasks.where((t) => isSameDate(t.dueDate, now)).toList();
    final progress = today.isNotEmpty
        ? today.where((t) => t.isCompleted).length / today.length
        : (tasks.isEmpty
              ? 0.0
              : tasks.where((t) => t.isCompleted).length / tasks.length);
    final greeting = greetingFor(now);
    final who = name;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                who == null || who.isEmpty ? greeting : '$greeting, $who',
                style: text.displayMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Dot(color: p.accent, glow: true),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${DateFormat('EEEE, MMM d').format(now)} • '
                      '${plural(pending, 'task')} pending',
                      style: text.bodySmall?.copyWith(color: p.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Tooltip(
          message: today.isNotEmpty ? "Today's progress" : 'Overall progress',
          child: Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.card,
              shape: BoxShape.circle,
              border: Border.all(color: p.border),
              boxShadow: p.cardShadow,
            ),
            child: ProgressRing(
              progress: progress,
              size: 40,
              strokeWidth: 3.4,
              color: p.accent,
              trackColor: p.track,
              child: Text(
                '${(progress * 100).round()}%',
                style: text.labelSmall?.copyWith(
                  color: p.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One line of guidance based on what's actually on the list.
class _FocusCard extends StatelessWidget {
  final List<Task> tasks;
  final DateTime now;

  const _FocusCard({required this.tasks, required this.now});

  (String, String, IconData) _message() {
    final open = tasks.where((t) => !t.isCompleted).toList();
    final overdue = open.where((t) => t.isOverdue(now)).toList();
    final today = open
        .where((t) => isSameDate(t.dueDate, now) && !t.isOverdue(now))
        .toList();
    final urgent = today.where((t) => t.priority == TaskPriority.high).toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));

    if (tasks.isEmpty) {
      return (
        'A Fresh Start',
        'Add your first task with the + button below.',
        Icons.wb_sunny_outlined,
      );
    }
    if (overdue.isNotEmpty) {
      final n = overdue.length;
      return (
        'Needs Attention',
        '${plural(n, 'task')} ${n == 1 ? 'is' : 'are'} overdue. Clear '
            '${n == 1 ? 'it' : 'them'} first to get back into flow.',
        Icons.history_rounded,
      );
    }
    if (urgent.isNotEmpty) {
      final n = urgent.length;
      final by = urgent.last.isAllDay
          ? 'today'
          : 'before ${shortTime(urgent.last.deadline)}';
      return (
        'Calm Focus State',
        '$n high-priority ${n == 1 ? 'item requires' : 'items require'} '
            'attention $by',
        Icons.wb_sunny_outlined,
      );
    }
    if (today.isNotEmpty) {
      return (
        'Calm Focus State',
        '${plural(today.length, 'task')} planned for today. One at a time.',
        Icons.wb_sunny_outlined,
      );
    }
    if (open.isEmpty) {
      return (
        'All Clear',
        'Everything is done. Enjoy the calm.',
        Icons.spa_outlined,
      );
    }
    return (
      'Calm Focus State',
      'Nothing is due today. A good moment to plan ahead.',
      Icons.wb_sunny_outlined,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (title, body, icon) = _message();
    return Panel(
      padding: const EdgeInsets.all(12),
      radius: 16,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: p.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: p.accent.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: p.accent.withValues(alpha: 0.2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(icon, size: 18, color: p.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: context.text.bodySmall?.copyWith(
                    color: p.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.auto_awesome_outlined,
            size: 20,
            color: p.accent.withValues(alpha: 0.8),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton();

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: 'Add task',
      onTap: () => context.push(AppRoutes.addTask),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: context.palette.accent,
          shape: BoxShape.circle,
          boxShadow: context.palette.glow(),
        ),
        child: const Icon(Icons.add_rounded, size: 22, color: Colors.white),
      ),
    );
  }
}

class _RefineButton extends StatelessWidget {
  final bool active;

  const _RefineButton({required this.active});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return IconButton(
      tooltip: 'Sort and filter',
      visualDensity: VisualDensity.compact,
      onPressed: () => showTaskFilterSheet(context),
      icon: Badge(
        isLabelVisible: active,
        smallSize: 7,
        backgroundColor: p.accent,
        child: Icon(
          Icons.tune_rounded,
          size: 20,
          color: active ? p.accent : p.textSecondary,
        ),
      ),
    );
  }
}

class _FilterRow extends ConsumerWidget {
  final TaskListState state;
  final DateTime now;

  const _FilterRow({required this.state, required this.now});

  static const _labels = {
    TaskFilter.all: 'All',
    TaskFilter.today: 'Today',
    TaskFilter.upcoming: 'Upcoming',
    TaskFilter.completed: 'Completed',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final filter in TaskFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterPill(
                label: _labels[filter]!,
                count: '${state.countFor(filter, now)}',
                accentCount: filter == TaskFilter.completed,
                selected: state.filter == filter,
                onTap: () =>
                    ref.read(taskListProvider.notifier).setFilter(filter),
              ),
            ),
        ],
      ),
    );
  }
}
