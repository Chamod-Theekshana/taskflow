import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/ui.dart';
import '../../domain/entities/task.dart';
import '../providers/task_provider.dart';

Future<void> showTaskFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => const _TaskFilterSheet(),
  );
}

class _TaskFilterSheet extends ConsumerStatefulWidget {
  const _TaskFilterSheet();

  @override
  ConsumerState<_TaskFilterSheet> createState() => _TaskFilterSheetState();
}

class _TaskFilterSheetState extends ConsumerState<_TaskFilterSheet> {
  late TaskSort _sort;
  TaskPriority? _priority;
  String? _category;

  @override
  void initState() {
    super.initState();
    final state = ref.read(taskListProvider);
    _sort = state.sort;
    _priority = state.priorityFilter;
    _category = state.categoryFilter;
  }

  void _apply() {
    ref
        .read(taskListProvider.notifier)
        .setRefinements(sort: _sort, priority: _priority, category: _category);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final used = ref.watch(taskListProvider.select((s) => s.usedCategories));
    final active = _category;
    // A filter whose last task is gone must stay visible, or it could never
    // be switched off.
    final categories = [
      ...used,
      if (active != null &&
          !used.any((c) => c.toLowerCase() == active.toLowerCase()))
        active,
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sort & filter', style: context.text.headlineMedium),
            const SizedBox(height: 20),
            _Group(
              title: 'Sort by',
              children: [
                for (final sort in TaskSort.values)
                  FilterPill(
                    label: sort.label,
                    selected: _sort == sort,
                    onTap: () => setState(() => _sort = sort),
                  ),
              ],
            ),
            _Group(
              title: 'Priority',
              children: [
                FilterPill(
                  label: 'Any',
                  selected: _priority == null,
                  onTap: () => setState(() => _priority = null),
                ),
                for (final p in TaskPriority.values.reversed)
                  FilterPill(
                    label: p.label,
                    selected: _priority == p,
                    onTap: () => setState(() => _priority = p),
                  ),
              ],
            ),
            if (categories.isNotEmpty)
              _Group(
                title: 'Category',
                children: [
                  FilterPill(
                    label: 'Any',
                    selected: _category == null,
                    onTap: () => setState(() => _category = null),
                  ),
                  for (final c in categories)
                    FilterPill(
                      label: c,
                      selected: _category?.toLowerCase() == c.toLowerCase(),
                      onTap: () => setState(() => _category = c),
                    ),
                ],
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: GhostButton(
                    label: 'Reset',
                    height: 52,
                    radius: 12,
                    onPressed: () => setState(() {
                      _sort = TaskSort.dueDate;
                      _priority = null;
                      _category = null;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: PrimaryButton(label: 'Show tasks', onPressed: _apply),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Group({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: context.text.labelSmall?.copyWith(
              color: context.palette.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}
