import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../providers/task_provider.dart';
import '../widgets/task_card.dart';
import '../widgets/momentum_ring.dart';
import '../models/task.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedFilter = 'All';

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final allTasks = taskProvider.tasks;
    final pendingTasks = allTasks.where((t) => !t.isCompleted).toList();
    final highPriorityCount = pendingTasks.where((t) => t.priority == TaskPriority.high).length;
    
    // Filtering logic
    List<Task> displayTasks = allTasks;
    if (_selectedFilter == 'Today') {
      final now = DateTime.now();
      displayTasks = allTasks.where((t) => t.dueDate.year == now.year && t.dueDate.month == now.month && t.dueDate.day == now.day).toList();
    } else if (_selectedFilter == 'Upcoming') {
      final now = DateTime.now();
      displayTasks = allTasks.where((t) => t.dueDate.isAfter(DateTime(now.year, now.month, now.day, 23, 59, 59))).toList();
    } else if (_selectedFilter == 'Completed') {
      displayTasks = allTasks.where((t) => t.isCompleted).toList();
    }

    final todayStr = DateFormat('EEEE, MMM d').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.surface,
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
                        '${_getGreeting()}, Alex',
                        style: AppTypography.displayLarge,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.secondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$todayStr • ${pendingTasks.length} tasks pending',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const MomentumRing(progress: 0.72, size: 64),
              ],
            ),
            const SizedBox(height: 24),

            // Motivational Micro-card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.tertiaryFixed,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.tertiaryContainer.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.light_mode, color: AppColors.tertiary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calm Focus State',
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$highPriorityCount high-priority items require attention before 5 PM',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.onSurfaceVariant,
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
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppColors.outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search tasks...',
                        hintStyle: AppTypography.bodyLarge.copyWith(color: AppColors.outline),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  const Icon(Icons.tune, color: AppColors.outline),
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
                  _buildFilterPill('All', allTasks.length),
                  const SizedBox(width: 12),
                  _buildFilterPill('Today', allTasks.where((t) => t.dueDate.day == DateTime.now().day).length),
                  const SizedBox(width: 12),
                  _buildFilterPill('Upcoming', allTasks.where((t) => t.dueDate.isAfter(DateTime.now())).length),
                  const SizedBox(width: 12),
                  _buildFilterPill('Completed', allTasks.where((t) => t.isCompleted).length),
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

  Widget _buildFilterPill(String title, int count) {
    final isSelected = _selectedFilter == title;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = title;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: AppTypography.labelLarge.copyWith(
                color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.2) : AppColors.outlineVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: AppTypography.labelSmall.copyWith(
                  color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

