import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/ui.dart';
import '../../domain/entities/task.dart';
import '../providers/task_provider.dart';
import '../widgets/task_card.dart';

enum _Quick {
  high('High priority', Icons.flag_outlined),
  today('Due today', Icons.today_outlined),
  overdue('Overdue', Icons.history_rounded),
  repeating('Repeating', Icons.repeat_rounded),
  done('Completed', Icons.done_all_rounded);

  const _Quick(this.label, this.icon);
  final String label;
  final IconData icon;

  bool matches(Task t, DateTime now) => switch (this) {
    _Quick.high => !t.isCompleted && t.priority == TaskPriority.high,
    _Quick.today => isSameDate(t.dueDate, now),
    _Quick.overdue => t.isOverdue(now),
    _Quick.repeating => t.repeat != RepeatRule.none,
    _Quick.done => t.isCompleted,
  };
}

/// Searches every task - open and finished - by title, notes, category and
/// subtasks.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  _Quick? _quick;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tasks = ref.watch(taskListProvider.select((s) => s.tasks));
    final now = DateTime.now();
    final quick = _quick;
    final searching = _query.trim().isNotEmpty || quick != null;

    final results = searching
        ? TaskListState.sortTasks([
            for (final t in tasks)
              if (TaskListState.matchesQuery(t, _query) &&
                  (quick == null || quick.matches(t, now)))
                t,
          ], TaskSort.dueDate)
        : ([...tasks]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)))
              .take(5)
              .toList();

    return Column(
      children: [
        const AppHeader(subtitle: 'Search'),
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, 20, 20, dockClearance(context)),
            children: [
              Text('Find anything', style: context.text.displayMedium),
              const SizedBox(height: 2),
              Text(
                'Titles, notes, categories and subtasks.',
                style: context.text.bodySmall?.copyWith(
                  color: p.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              AppSearchField(
                controller: _controller,
                hint: 'Search your tasks, projects or tags...',
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(
                  children: [
                    for (final item in _Quick.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterPill(
                          label: item.label,
                          icon: item.icon,
                          selected: _quick == item,
                          onTap: () => setState(
                            () => _quick = _quick == item ? null : item,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        searching ? 'Results' : 'Recently updated',
                        style: context.text.headlineSmall,
                      ),
                    ),
                    if (searching)
                      Text(
                        results.length == 1
                            ? '1 match'
                            : '${results.length} matches',
                        style: context.text.labelSmall?.copyWith(
                          color: p.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (results.isEmpty)
                EmptyState(
                  icon: searching
                      ? Icons.search_off_rounded
                      : Icons.inventory_2_outlined,
                  title: searching ? 'No matches' : 'Nothing here yet',
                  message: searching
                      ? 'Try a different word or turn off the filter.'
                      : 'Tasks you create or change will show up here.',
                )
              else
                for (final task in results)
                  Padding(
                    key: ValueKey(task.id),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TaskCard(task: task),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}
