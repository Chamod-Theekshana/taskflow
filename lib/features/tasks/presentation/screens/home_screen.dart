import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/momentum_ring.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/task.dart';
import '../providers/task_provider.dart';
import '../widgets/task_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final taskListState = ref.watch(taskListProvider);
    final allTasks = taskListState.tasks;
    final pendingTasks = allTasks.where((t) => !t.isCompleted).toList();
    final highPriorityCount = pendingTasks.where((t) => t.priority == TaskPriority.high).length;

    final displayTasks = taskListState.filteredTasks;
    final todayStr = DateFormat('EEEE, MMM d').format(DateTime.now());

    final user = ref.watch(authProvider).value;
    final userName = user?.fullName ?? 'User';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 100),
          children: [
            // Header Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_getGreeting()}, $userName',
                        style: Theme.of(context).textTheme.displayLarge,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$todayStr • ${pendingTasks.length} tasks pending',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                MomentumRing(progress: taskListState.completionPercentage, size: 64),
              ],
            ),
            const SizedBox(height: 24),

            // Motivational Micro-card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.light_mode, color: Theme.of(context).colorScheme.tertiary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calm Focus State',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$highPriorityCount high-priority items require attention before 5 PM',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      onChanged: (value) => ref.read(taskListProvider.notifier).setSearchQuery(value),
                      decoration: InputDecoration(
                        hintText: 'Search tasks...',
                        hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.outline),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  Icon(Icons.tune, color: Theme.of(context).colorScheme.outline),
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
                  _buildFilterPill(TaskFilter.all, 'All', allTasks.length),
                  const SizedBox(width: 12),
                  _buildFilterPill(TaskFilter.today, 'Today', allTasks.where((t) => t.dueDate.day == DateTime.now().day && t.dueDate.month == DateTime.now().month && t.dueDate.year == DateTime.now().year).length),
                  const SizedBox(width: 12),
                  _buildFilterPill(TaskFilter.upcoming, 'Upcoming', allTasks.where((t) => t.dueDate.isAfter(DateTime.now())).length),
                  const SizedBox(width: 12),
                  _buildFilterPill(TaskFilter.completed, 'Completed', allTasks.where((t) => t.isCompleted).length),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Task List
            ...displayTasks.map((task) => TaskCard(task: task)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(TaskFilter filter, String title, int count) {
    final currentFilter = ref.watch(taskListProvider).filter;
    final isSelected = currentFilter == filter;
    
    return GestureDetector(
      onTap: () {
        ref.read(taskListProvider.notifier).setFilter(filter);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.2) : Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
