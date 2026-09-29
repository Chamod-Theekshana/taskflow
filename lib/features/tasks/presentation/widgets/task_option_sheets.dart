import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/ui.dart';
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
  return showChoiceSheet<int>(
    context,
    title: 'Remind me',
    options: [
      for (final m in _reminderChoices)
        (
          value: m,
          label: reminderLabel(m),
          icon: m == 0
              ? Icons.notifications_active_outlined
              : Icons.notifications_none_rounded,
        ),
    ],
    selected: current,
  );
}

Future<RepeatRule?> showRepeatSheet(
  BuildContext context,
  RepeatRule current,
  DateTime anchor,
) {
  return showChoiceSheet<RepeatRule>(
    context,
    title: 'Repeat',
    subtitle: 'Finishing a repeating task schedules the next one.',
    options: [
      for (final rule in RepeatRule.values)
        (
          value: rule,
          label: rule.describe(anchor),
          icon: rule == RepeatRule.none
              ? Icons.block_rounded
              : Icons.repeat_rounded,
        ),
    ],
    selected: current,
  );
}

/// Asks for the name of a new tag. Returns null when cancelled.
Future<String?> promptForTag(BuildContext context) {
  return promptForText(
    context,
    title: 'New tag',
    hint: 'e.g. Study, Home, Side project',
    confirmLabel: 'Add',
    maxLength: 24,
    capitalization: TextCapitalization.words,
  );
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
    if (name == null || !context.mounted) return;
    await ref.read(settingsProvider.notifier).addCategory(name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final text = context.text;
    final custom = ref.watch(
      settingsProvider.select((s) => s.customCategories),
    );

    Widget row(String name, {VoidCallback? onDelete}) => Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: p.cardMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          IconTile(
            icon: categoryIcon(name),
            color: categoryTint(p, name),
            size: 34,
            radius: 10,
            iconSize: 18,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: text.bodyLarge)),
          if (onDelete == null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(
                'BUILT IN',
                style: text.labelSmall?.copyWith(
                  color: p.textMuted,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Remove $name',
              icon: Icon(Icons.close_rounded, color: p.textSecondary),
              onPressed: onDelete,
            ),
        ],
      ),
    );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: Text('Tags', style: text.headlineMedium),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                'Removing a tag keeps it on tasks that already use it.',
                style: text.bodySmall?.copyWith(color: p.textSecondary),
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
              child: GhostButton(
                label: 'New tag',
                icon: Icons.add_rounded,
                foreground: p.accentSoft,
                height: 40,
                onPressed: () => _add(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
