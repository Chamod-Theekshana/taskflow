import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/utils/quick_add_parser.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/not_found_screen.dart';
import '../../../../shared/widgets/ui.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../domain/entities/task.dart';
import '../providers/task_provider.dart';
import '../widgets/task_option_sheets.dart';
import '../widgets/task_ui.dart';

const _maxTitle = 120;

enum _Field { date, time, priority, category }

class AddEditTaskScreen extends ConsumerStatefulWidget {
  final int? taskId;
  final DateTime? initialDate;

  const AddEditTaskScreen({super.key, this.taskId, this.initialDate});

  @override
  ConsumerState<AddEditTaskScreen> createState() => _AddEditTaskScreenState();
}

class _AddEditTaskScreenState extends ConsumerState<AddEditTaskScreen> {
  final _title = TextEditingController();
  final _notes = TextEditingController();

  late DateTime _date;
  late TimeOfDay _time;
  TaskPriority _priority = TaskPriority.medium;
  String _category = kBuiltInCategories.first;
  bool _allDay = false;
  bool _reminder = true;
  int _reminderMinutes = 15;
  RepeatRule _repeat = RepeatRule.none;

  Task? _existing;
  bool _loading = false;
  bool _notFound = false;
  bool _saving = false;
  String? _titleError;

  // Quick-add: fields the user set by hand are never overridden, and fields
  // filled in from the title go back to their start value when the word
  // that set them disappears.
  final _manual = <_Field>{};
  final _auto = <_Field>{};
  QuickAdd? _detected;
  late final DateTime _startDate;
  late final TimeOfDay _startTime;
  late final TaskPriority _startPriority;
  final String _startCategory = kBuiltInCategories.first;

  bool get _isEditing => widget.taskId != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final start = widget.initialDate ?? now;
    _date = dateOnly(start);
    _time = _defaultTime(start, now);
    _priority = ref.read(settingsProvider).defaultPriority;
    _startDate = _date;
    _startTime = _time;
    _startPriority = _priority;

    final id = widget.taskId;
    if (id != null) {
      _loading = true;
      _load(id);
    }
  }

  /// Next full hour today, so a new task isn't born overdue; 9 AM on any
  /// other day.
  static TimeOfDay _defaultTime(DateTime day, DateTime now) {
    if (!isSameDate(day, now)) return const TimeOfDay(hour: 9, minute: 0);
    if (now.hour >= 23) return const TimeOfDay(hour: 23, minute: 59);
    return TimeOfDay(hour: now.hour + 1, minute: 0);
  }

  Future<void> _load(int id) async {
    Task? task;
    try {
      task = await ref.read(taskListProvider.notifier).getTaskById(id);
    } catch (_) {
      task = null;
    }
    if (!mounted) return;
    final loaded = task;
    setState(() {
      _loading = false;
      if (loaded == null) {
        _notFound = true;
        return;
      }
      _existing = loaded;
      _title.text = loaded.title;
      _notes.text = loaded.description;
      _date = dateOnly(loaded.dueDate);
      // All-day tasks have no time of their own; offer 9 AM if the user
      // switches all-day off, rather than midnight (already past).
      _time =
          parseTimeOfDay(loaded.dueTime) ??
          (loaded.isAllDay
              ? const TimeOfDay(hour: 9, minute: 0)
              : TimeOfDay(
                  hour: loaded.dueDate.hour,
                  minute: loaded.dueDate.minute,
                ));
      _priority = loaded.priority;
      _category = loaded.category;
      _allDay = loaded.isAllDay;
      _reminder = loaded.reminder;
      _reminderMinutes = loaded.reminderMinutes;
      _repeat = loaded.repeat;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _onTitleChanged(String value) {
    // Quick-add only reads new tasks; editing never rewrites a title.
    if (_isEditing) {
      setState(() => _titleError = null);
      return;
    }
    final result = parseQuickAdd(
      value,
      now: DateTime.now(),
      categories: _allCategories(),
    );
    setState(() {
      _titleError = null;
      _detected = result.hasMatches ? result : null;
      _fromTitle(
        _Field.date,
        result.date != null,
        () => _date = result.date!,
        () => _date = _startDate,
      );
      _fromTitle(_Field.time, result.time != null, () {
        _time = result.time!;
        _allDay = false;
      }, () => _time = _startTime);
      _fromTitle(
        _Field.priority,
        result.priority != null,
        () => _priority = result.priority!,
        () => _priority = _startPriority,
      );
      _fromTitle(
        _Field.category,
        result.category != null,
        () => _category = result.category!,
        () => _category = _startCategory,
      );
    });
  }

  void _fromTitle(
    _Field field,
    bool found,
    VoidCallback apply,
    VoidCallback reset,
  ) {
    if (_manual.contains(field)) return;
    if (found) {
      apply();
      _auto.add(field);
    } else if (_auto.remove(field)) {
      reset();
    }
  }

  /// Records a choice made by hand so quick-add stops touching [field].
  void _setByHand(_Field field, VoidCallback change) {
    setState(() {
      change();
      _manual.add(field);
      _auto.remove(field);
    });
  }

  /// The words are only taken out of the title when everything they meant
  /// was actually applied to the form.
  bool _usedAll(QuickAdd d) =>
      (d.date == null || _auto.contains(_Field.date)) &&
      (d.time == null || _auto.contains(_Field.time)) &&
      (d.priority == null || _auto.contains(_Field.priority)) &&
      (d.category == null || _auto.contains(_Field.category));

  List<String> _allCategories() {
    final custom = ref.read(settingsProvider).customCategories;
    return [...kBuiltInCategories, ...custom];
  }

  Future<void> _pickDate() async {
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      // An overdue task keeps its old date as a valid choice.
      firstDate: _date.isBefore(today) ? _date : today,
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null && mounted) {
      _setByHand(_Field.date, () => _date = dateOnly(picked));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null && mounted) {
      _setByHand(_Field.time, () => _time = picked);
    }
  }

  Future<void> _pickReminder() async {
    final minutes = await showReminderSheet(context, _reminderMinutes);
    if (minutes != null && mounted) {
      setState(() {
        _reminderMinutes = minutes;
        _reminder = true;
      });
    }
  }

  Future<void> _pickRepeat() async {
    final rule = await showRepeatSheet(context, _repeat, _date);
    if (rule != null && mounted) setState(() => _repeat = rule);
  }

  Future<void> _addTag() async {
    final name = await promptForTag(context);
    if (name == null || !mounted) return;
    await ref.read(settingsProvider.notifier).addCategory(name);
    if (!mounted) return;
    // Use the stored spelling when the tag already existed.
    final match = _allCategories().firstWhere(
      (c) => c.toLowerCase() == name.toLowerCase(),
      orElse: () => name,
    );
    _setByHand(_Field.category, () => _category = match);
  }

  Future<void> _save() async {
    if (_saving) return;
    final detected = _detected;
    var title = _title.text.trim();
    if (detected != null && detected.title.isNotEmpty && _usedAll(detected)) {
      title = detected.title;
    }
    if (title.isEmpty) {
      setState(() => _titleError = 'Give the task a title first.');
      return;
    }

    final now = DateTime.now();
    final category = _category.trim();
    final settings = ref.read(settingsProvider);
    final notifier = ref.read(taskListProvider.notifier);

    setState(() => _saving = true);
    try {
      if (category.isNotEmpty &&
          !_allCategories().any(
            (c) => c.toLowerCase() == category.toLowerCase(),
          )) {
        await ref.read(settingsProvider.notifier).addCategory(category);
      }

      final original =
          _existing ??
          Task(title: title, dueDate: now, createdAt: now, updatedAt: now);
      final task = original.copyWith(
        title: title,
        description: _notes.text.trim(),
        dueDate: combineDateAndTime(_date, _allDay ? null : _time),
        dueTime: _allDay ? '' : formatTimeOfDay(_time),
        priority: _priority,
        category: category,
        isAllDay: _allDay,
        reminder: _reminder,
        reminderMinutes: _reminderMinutes,
        repeat: _repeat,
      );

      if (_existing == null) {
        await notifier.addTask(task);
      } else {
        await notifier.updateTask(task);
      }

      if (_reminder && settings.notificationsEnabled) {
        unawaited(NotificationService.instance.requestPermission());
      }
      if (mounted) closeScreen(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(context, describeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_notFound) {
      return const NotFoundScreen(
        title: 'Task not found',
        message: 'This task no longer exists.',
      );
    }

    final p = context.palette;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _save,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _save,
      },
      child: Scaffold(
        backgroundColor: p.canvas,
        body: Column(
          children: [
            BackHeader(
              title: _isEditing ? 'Edit Task' : 'New Task',
              actions: [
                GhostButton(
                  label: 'Cancel',
                  foreground: p.text.withValues(alpha: 0.7),
                  onPressed: () => closeScreen(context),
                ),
                const UserAvatar(size: 34),
              ],
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 32 + bottom),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _ModePill(editing: _isEditing),
                        ),
                        const SizedBox(height: 12),
                        _heroCard(),
                        const SizedBox(height: 22),
                        _whenSection(),
                        const SizedBox(height: 22),
                        _prioritySection(),
                        const SizedBox(height: 22),
                        _categorySection(),
                        const SizedBox(height: 22),
                        _optionsCard(),
                        const SizedBox(height: 20),
                        const _MindfulBanner(),
                        const SizedBox(height: 28),
                        PrimaryButton(
                          label: _isEditing ? 'Save Changes' : 'Save Task',
                          icon: Icons.check_circle_outline_rounded,
                          iconAfter: false,
                          height: 56,
                          radius: 16,
                          loading: _saving,
                          onPressed: _save,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroCard() {
    final p = context.palette;
    final text = context.text;
    final length = _title.text.length;
    final detected = _detected;

    // Only what was actually applied to the form.
    final found = <String>[];
    if (detected != null) {
      if (_auto.contains(_Field.date)) found.add(dayLabel(_date));
      if (_auto.contains(_Field.time)) {
        found.add(shortTime(combineDateAndTime(_date, _time)));
      }
      if (_auto.contains(_Field.category)) found.add('#$_category');
      if (_auto.contains(_Field.priority)) {
        found.add('${_priority.label} priority');
      }
    }
    final divider = Container(height: 1, color: p.divider);

    return Panel(
      color: p.cardMuted,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _title,
            autofocus: !_isEditing,
            maxLength: _maxTitle,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            onChanged: _onTitleChanged,
            style: text.headlineLarge,
            decoration: InputDecoration(
              hintText: 'What needs to be done?',
              hintStyle: text.headlineLarge?.copyWith(
                color: p.text.withValues(alpha: 0.3),
              ),
              filled: false,
              counterText: '',
              isCollapsed: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              errorText: _titleError,
              errorStyle: text.bodySmall?.copyWith(color: p.danger),
            ),
          ),
          const SizedBox(height: 14),
          divider,
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(Icons.notes_rounded, size: 20, color: p.warmMuted),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _notes,
                  minLines: 3,
                  maxLines: 8,
                  textCapitalization: TextCapitalization.sentences,
                  style: text.bodyMedium?.copyWith(height: 1.6),
                  decoration: InputDecoration(
                    hintText: 'Add notes, context, or links...',
                    hintStyle: text.bodyMedium?.copyWith(
                      color: p.text.withValues(alpha: 0.3),
                      height: 1.6,
                    ),
                    filled: false,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          divider,
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 15, color: p.accent),
              const SizedBox(width: 6),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    found.isEmpty
                        ? 'Auto-detects dates, tags & priority'
                        : 'Detected: ${found.join(' · ')}',
                    key: ValueKey(found.join()),
                    style: text.bodySmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: found.isEmpty
                          ? p.text.withValues(alpha: 0.5)
                          : p.accentSoft,
                    ),
                    maxLines: 2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$length/$_maxTitle',
                style: text.labelSmall?.copyWith(
                  color: length > 100
                      ? p.danger
                      : p.text.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _whenSection() {
    final p = context.palette;
    final text = context.text;
    final today = dateOnly(DateTime.now());
    final diff = daysBetween(today, _date);
    final customDate = diff != 0 && diff != 1;
    final due = combineDateAndTime(_date, _time);

    void setDate(DateTime d) => _setByHand(_Field.date, () => _date = d);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          icon: Icons.calendar_today_outlined,
          label: 'When',
          trailing: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _setByHand(_Field.time, () => _allDay = !_allDay),
            child: Row(
              children: [
                Text(
                  'All-day',
                  style: text.bodySmall?.copyWith(
                    fontSize: 12,
                    color: p.warmMuted,
                  ),
                ),
                const SizedBox(width: 10),
                AppSwitch(
                  value: _allDay,
                  width: 36,
                  height: 20,
                  semanticLabel: 'All-day',
                  onChanged: (v) => _setByHand(_Field.time, () => _allDay = v),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              _DateChip(
                icon: Icons.today_outlined,
                label: 'Today',
                selected: diff == 0,
                onTap: () => setDate(today),
              ),
              const SizedBox(width: 8),
              _DateChip(
                icon: Icons.wb_twilight_rounded,
                label: 'Tomorrow',
                selected: diff == 1,
                onTap: () => setDate(addDays(today, 1)),
              ),
              const SizedBox(width: 8),
              _DateChip(
                icon: Icons.calendar_month_outlined,
                label: customDate
                    ? DateFormat(
                        _date.year == today.year ? 'EEE, MMM d' : 'MMM d, y',
                      ).format(_date)
                    : 'Pick Date',
                selected: customDate,
                onTap: _pickDate,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _allDay ? 0.4 : 1,
          child: IgnorePointer(
            ignoring: _allDay,
            child: Panel(
              color: p.cardMuted,
              radius: 16,
              shadow: false,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const IconTile(
                    icon: Icons.schedule_rounded,
                    size: 34,
                    radius: 12,
                    iconSize: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Target Time',
                          style: text.titleSmall?.copyWith(fontSize: 13),
                        ),
                        Text(
                          _allDay
                              ? 'Any time that day'
                              : due.isBefore(DateTime.now())
                              ? 'This time has already passed'
                              : relativeDueLabel(due),
                          style: text.bodySmall?.copyWith(
                            fontSize: 12,
                            color: p.warmMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Pressable(
                    onTap: _pickTime,
                    semanticLabel: 'Change time',
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
                      decoration: BoxDecoration(
                        color: p.raised,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: p.border),
                      ),
                      child: Row(
                        children: [
                          Text(
                            formatTimeOfDay(_time),
                            style: text.titleSmall?.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.expand_more_rounded,
                            size: 18,
                            color: p.text.withValues(alpha: 0.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _prioritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel(icon: Icons.flag_outlined, label: 'Priority'),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final priority in TaskPriority.values) ...[
              if (priority != TaskPriority.low) const SizedBox(width: 10),
              Expanded(
                child: _PriorityOption(
                  priority: priority,
                  selected: _priority == priority,
                  onTap: () => _setByHand(
                    _Field.priority,
                    () => _priority = priority,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _categorySection() {
    final p = context.palette;
    final custom = ref.watch(
      settingsProvider.select((s) => s.customCategories),
    );
    final names = [...kBuiltInCategories, ...custom];
    if (_category.isNotEmpty &&
        !names.any((c) => c.toLowerCase() == _category.toLowerCase())) {
      names.add(_category);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          icon: Icons.label_outline_rounded,
          label: 'Category',
          trailing: Pressable(
            onTap: () => showManageTagsSheet(context),
            semanticLabel: 'Manage tags',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Manage tags',
                style: context.text.bodySmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: p.accentSoft,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (final name in names) ...[
                _CategoryChip(
                  name: name,
                  selected: name.toLowerCase() == _category.toLowerCase(),
                  onTap: () =>
                      _setByHand(_Field.category, () => _category = name),
                ),
                const SizedBox(width: 8),
              ],
              _AddTagChip(onTap: _addTag),
            ],
          ),
        ),
      ],
    );
  }

  Widget _optionsCard() {
    final p = context.palette;
    final notificationsOn = ref.watch(
      settingsProvider.select((s) => s.notificationsEnabled),
    );
    final String reminderText;
    if (!notificationsOn) {
      reminderText = 'Notifications are off in Profile';
    } else if (!_reminder) {
      reminderText = 'No reminder';
    } else if (_allDay) {
      reminderText = 'At 9:00 AM on the day';
    } else {
      reminderText = reminderLabel(_reminderMinutes);
    }

    return Panel(
      color: p.cardMuted,
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          _OptionRow(
            leading: const IconTile(
              icon: Icons.notifications_active_outlined,
              size: 36,
              radius: 12,
            ),
            title: 'Remind me',
            subtitle: reminderText,
            onTap: _allDay ? null : _pickReminder,
            trailing: AppSwitch(
              value: _reminder,
              width: 44,
              height: 24,
              semanticLabel: 'Remind me',
              onChanged: (v) => setState(() => _reminder = v),
            ),
          ),
          const SizedBox(height: 4),
          _OptionRow(
            leading: IconTile(
              icon: Icons.repeat_rounded,
              color: p.textSecondary,
              background: p.raised,
              border: p.border,
              size: 36,
              radius: 12,
            ),
            title: 'Repeat',
            subtitle: _repeat.describe(_date),
            onTap: _pickRepeat,
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: p.text.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// "CREATING FOCUS" / "EDITING TASK" pill.
class _ModePill extends StatelessWidget {
  final bool editing;

  const _ModePill({required this.editing});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: p.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulsingDot(color: p.accent),
          const SizedBox(width: 8),
          Text(
            editing ? 'EDITING TASK' : 'CREATING FOCUS',
            style: context.text.titleSmall?.copyWith(
              fontSize: 11,
              letterSpacing: 0.6,
              color: p.accentSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DateChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? p.accent : p.cardMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? p.accent : p.border),
          boxShadow: null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : p.text.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: context.text.titleSmall?.copyWith(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? Colors.white : p.text.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityOption extends StatelessWidget {
  final TaskPriority priority;
  final bool selected;
  final VoidCallback onTap;

  const _PriorityOption({
    required this.priority,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = context.text;
    final dot = priorityAccent(p, priority);

    return Pressable(
      onTap: onTap,
      semanticLabel: '${priority.label} priority',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? p.accent.withValues(alpha: 0.15) : p.cardMuted,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? p.accent : p.border),
          boxShadow: null,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                priority == TaskPriority.high
                    ? PulsingDot(color: dot)
                    : Dot(color: dot),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    priority.label,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.check_rounded, size: 14, color: p.accentSoft),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              priority.mood,
              style: text.bodySmall?.copyWith(
                fontSize: 10.5,
                color: selected ? p.accentSoft : p.warmMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = selected ? p.accentSoft : p.text.withValues(alpha: 0.8);
    return Pressable(
      onTap: onTap,
      semanticLabel: name,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? p.accent.withValues(alpha: 0.2) : p.cardMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? p.accent.withValues(alpha: 0.5) : p.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(categoryIcon(name), size: 15, color: categoryTint(p, name)),
            const SizedBox(width: 6),
            Text(
              name,
              style: context.text.titleSmall?.copyWith(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: fg,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 4),
              Icon(Icons.check_rounded, size: 13, color: fg),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddTagChip extends StatelessWidget {
  final VoidCallback onTap;

  const _AddTagChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: onTap,
      semanticLabel: 'Add tag',
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: p.raised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 15, color: p.accentSoft),
            const SizedBox(width: 4),
            Text(
              'Add Tag',
              style: context.text.titleSmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: p.accentSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget trailing;

  const _OptionRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.titleSmall),
                    Text(
                      subtitle,
                      style: context.text.bodySmall?.copyWith(
                        fontSize: 12,
                        color: p.warmMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _MindfulBanner extends StatelessWidget {
  const _MindfulBanner();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Panel(
      radius: 16,
      shadow: false,
      padding: const EdgeInsets.all(14),
      borderColor: p.accent.withValues(alpha: 0.2),
      gradient: LinearGradient(
        colors: [p.accent.withValues(alpha: 0.1), p.cardMuted, p.cardMuted],
      ),
      child: Row(
        children: [
          IconTile(
            icon: Icons.local_fire_department_outlined,
            background: p.accent.withValues(alpha: 0.2),
            iconSize: 22,
            radius: 12,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mindful Focus',
                  style: context.text.titleSmall?.copyWith(fontSize: 12),
                ),
                Text(
                  'One clear intention at a time. Flow starts now.',
                  style: context.text.bodySmall?.copyWith(
                    fontSize: 12,
                    color: p.warmMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

