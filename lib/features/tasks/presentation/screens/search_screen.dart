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
    final tasks = ref.watch(taskListProvider.select((s) => s.tasks));
    final now = DateTime.now();
    final searching = _query.trim().isNotEmpty || _quick != null;

    final results = searching
        ? TaskListState.sortTasks([
            for (final t in tasks)
              if (TaskListState.matchesQuery(t, _query) &&
                  (_quick == null || _quick!.matches(t, now)))
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
            padding: EdgeInsets.fromLTRB(20, 16, 20, dockClearance(context)),
            children: [
              Text('Find anything', style: context.text.displayMedium),
              const SizedBox(height: 4),
              Text(
                'Titles, notes, categories and subtasks.',
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
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
                    for (final quick in _Quick.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoicePill(
                          label: quick.label,
                          icon: quick.icon,
                          selected: _quick == quick,
                          onTap: () => setState(
                            () => _quick = _quick == quick ? null : quick,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  searching
                      ? plural(results.length, 'result')
                      : 'Recently updated',
                  style: context.text.headlineSmall,
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
