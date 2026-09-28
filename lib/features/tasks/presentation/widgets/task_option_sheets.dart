import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../domain/entities/task.dart';
import 'task_ui.dart';

const _reminderChoices = [0, 5, 10, 15, 30, 60, 1440];

String reminderLabel(int minutes) {
  if (minutes <= 0) return 'When it is due';
  if (minutes == 1440) return '1 day before';
  if (minutes == 60) return '1 hour before';
  return '$minutes minutes before';
}

Future<int?> showReminderSheet(BuildContext context, int current) {
  return _showChoiceSheet<int>(
    context,
    title: 'Remind me',
    options: [
      for (final m in _reminderChoices) (value: m, label: reminderLabel(m)),
    ],
    selected: current,
  );
}

Future<RepeatRule?> showRepeatSheet(
  BuildContext context,
  RepeatRule current,
  DateTime anchor,
) {
  return _showChoiceSheet<RepeatRule>(
    context,
    title: 'Repeat',
    options: [
      for (final rule in RepeatRule.values)
        (value: rule, label: rule.describe(anchor)),
    ],
    selected: current,
  );
}

Future<T?> _showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<({T value, String label})> options,
  required T selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final colors = sheetContext.colors;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(title, style: sheetContext.text.headlineMedium),
              ),
              for (final option in options)
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Text(option.label, style: sheetContext.text.bodyLarge),
                  trailing: option.value == selected
                      ? Icon(Icons.check_rounded, color: colors.primary)
                      : null,
                  selected: option.value == selected,
                  selectedTileColor: colors.primaryFixed.withValues(alpha: 0.5),
                  onTap: () => Navigator.of(sheetContext).pop(option.value),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Asks for the name of a new tag. Returns null when cancelled.
Future<String?> promptForTag(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _NewTagDialog(),
  );
}

class _NewTagDialog extends StatefulWidget {
  const _NewTagDialog();

  @override
  State<_NewTagDialog> createState() => _NewTagDialogState();
}

class _NewTagDialogState extends State<_NewTagDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New tag'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 24,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(
          hintText: 'e.g. Study, Home, Side project',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}

Future<void> showManageTagsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => const _ManageTagsSheet(),
  );
}

class _ManageTagsSheet extends ConsumerWidget {
  const _ManageTagsSheet();

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final name = await promptForTag(context);
    if (name != null) {
      await ref.read(settingsProvider.notifier).addCategory(name);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.text;
    final custom = ref.watch(
      settingsProvider.select((s) => s.customCategories),
    );

    Widget row(String name, {VoidCallback? onDelete}) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: Icon(categoryIcon(name), color: categoryTint(colors, name)),
      title: Text(name, style: text.bodyLarge),
      trailing: onDelete == null
          ? Text(
              'Built in',
              style: text.labelSmall?.copyWith(color: colors.outline),
            )
          : IconButton(
              tooltip: 'Remove $name',
              icon: Icon(Icons.close_rounded, color: colors.onSurfaceVariant),
              onPressed: onDelete,
            ),
    );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Text('Tags', style: text.headlineMedium),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                'Removing a tag keeps it on tasks that already use it.',
                style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
            for (final name in kBuiltInCategories) row(name),
            for (final name in custom)
              row(
                name,
                onDelete: () =>
                    ref.read(settingsProvider.notifier).removeCategory(name),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _add(context, ref),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New tag'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
