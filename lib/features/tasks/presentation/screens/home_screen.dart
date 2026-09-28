import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/routing/route_guard.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/momentum_ring.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/task.dart';
import '../providers/task_provider.dart';
import '../widgets/task_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(taskListProvider).searchQuery,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(taskListProvider.notifier).setSearchQuery('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final taskListState = ref.watch(taskListProvider);
    final allTasks = taskListState.tasks;
    final pendingTasks = allTasks.where((t) => !t.isCompleted).toList();
    final highPriorityCount = pendingTasks
        .where((t) => t.priority == TaskPriority.high)
        .length;
    final overdueCount = pendingTasks.where((t) => t.isOverdue()).length;

    final displayTasks = taskListState.filteredTasks;
    final todayStr = DateFormat('EEEE, MMM d').format(DateTime.now());

    final user = ref.watch(authProvider).value;
    final firstName = user?.firstName ?? '';
    final greeting = firstName.isEmpty
        ? _getGreeting()
        : '${_getGreeting()}, $firstName';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.read(taskListProvider.notifier).refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: dockClearance(context),
            ),
            children: [
              // Header Section
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(greeting, style: textTheme.displayMedium),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: colorScheme.secondary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '$todayStr • ${pendingTasks.length} '
                                '${pendingTasks.length == 1 ? 'task' : 'tasks'} pending',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  MomentumRing(
                    progress: taskListState.completionPercentage,
                    size: 64,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Motivational Micro-card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryFixed,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.light_mode,
                      color: colorScheme.onTertiaryFixedVariant,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Calm Focus State',
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onTertiaryFixed,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _focusMessage(highPriorityCount, overdueCount),
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onTertiaryFixed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Search Bar
              Container(
                height: 48,
                padding: const EdgeInsets.only(left: 16, right: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: colorScheme.outline),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onChanged: (value) {
                          ref
                              .read(taskListProvider.notifier)
                              .setSearchQuery(value);
                          setState(() {});
                        },
                        decoration: InputDecoration(
                          hintText: 'Search tasks...',
                          hintStyle: textTheme.bodyLarge?.copyWith(
                            color: colorScheme.outline,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear search',
                        icon: Icon(Icons.close, color: colorScheme.outline),
                        onPressed: _clearSearch,
                      )
                    else
                      const SizedBox(width: 12),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Filter Pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(
                  children: [
                    _buildFilterPill(taskListState, TaskFilter.all, 'All'),
                    const SizedBox(width: 12),
                    _buildFilterPill(taskListState, TaskFilter.today, 'Today'),
                    const SizedBox(width: 12),
                    _buildFilterPill(
                      taskListState,
                      TaskFilter.upcoming,
                      'Upcoming',
                    ),
                    const SizedBox(width: 12),
                    _buildFilterPill(
                      taskListState,
                      TaskFilter.completed,
                      'Completed',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Task List
              if (taskListState.isLoading && allTasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (taskListState.errorMessage != null && allTasks.isEmpty)
                _EmptyState(
                  icon: Icons.error_outline,
                  title: 'Could not load your tasks',
                  message: taskListState.errorMessage!,
                  actionLabel: 'Try again',
                  onAction: () =>
                      ref.read(taskListProvider.notifier).refresh(),
                )
              else if (displayTasks.isEmpty)
                allTasks.isEmpty
                    ? _EmptyState(
                        icon: Icons.task_alt,
                        title: 'No tasks yet',
                        message: 'Tap + to add your first task.',
                        actionLabel: 'Add a task',
                        onAction: () => context.push(AppRoutes.addTask),
                      )
                    : const _EmptyState(
                        icon: Icons.filter_alt_off_outlined,
                        title: 'Nothing here',
                        message: 'No tasks match this filter or search.',
                      )
              else
                ...displayTasks.map(
                  (task) => TaskCard(key: ValueKey(task.id), task: task),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _focusMessage(int highPriority, int overdue) {
    if (overdue > 0) {
      return '$overdue overdue ${overdue == 1 ? 'task needs' : 'tasks need'} '
          'your attention.';
    }
    if (highPriority > 0) {
      return '$highPriority high-priority '
          '${highPriority == 1 ? 'item requires' : 'items require'} attention.';
    }
    return 'All clear. Pick one thing and give it your full focus.';
  }

  Widget _buildFilterPill(TaskListState state, TaskFilter filter, String title) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isSelected = state.filter == filter;
    final count = state.countFor(filter);

    return GestureDetector(
      onTap: () => ref.read(taskListProvider.notifier).setFilter(filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: textTheme.labelLarge?.copyWith(
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.onPrimary.withValues(alpha: 0.2)
                    : colorScheme.outlineVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: textTheme.labelSmall?.copyWith(
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(icon, size: 48, color: colorScheme.outline),
          const SizedBox(height: 12),
          Text(title, style: textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
