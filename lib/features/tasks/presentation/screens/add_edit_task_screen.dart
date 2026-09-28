import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/routing/route_guard.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../shared/widgets/not_found_screen.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../domain/entities/task.dart';
import '../providers/task_provider.dart';
import '../widgets/task_ui.dart';

const int _kTitleMaxLength = 120;

class AddEditTaskScreen extends ConsumerStatefulWidget {
  final int? taskId;

  const AddEditTaskScreen({super.key, this.taskId});

  @override
  ConsumerState<AddEditTaskScreen> createState() => _AddEditTaskScreenState();
}

class _AddEditTaskScreenState extends ConsumerState<AddEditTaskScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;

  DateTime _selectedDate = dateOnly(DateTime.now());
  // Next full hour, so a task created late in the day is not born overdue
  // (the old fixed 02:00 PM default was).
  TimeOfDay _selectedTime = _defaultTime();
  TaskPriority _priority = TaskPriority.medium;
  String _category = kTaskCategories.first.name;
  bool _isAllDay = false;
  bool _reminder = true;
  Task? _existingTask;

  bool _loadingTask = false;
  bool _taskNotFound = false;
  bool _saving = false;
  String? _titleError;

  bool get _isEditing => widget.taskId != null;

  static TimeOfDay _defaultTime() {
    final now = DateTime.now();
    if (now.hour >= 23) return const TimeOfDay(hour: 23, minute: 59);
    return TimeOfDay(hour: now.hour + 1, minute: 0);
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _notesController = TextEditingController();

    if (_isEditing) {
      _loadingTask = true;
      _loadExistingTask(widget.taskId!);
    } else {
      // Honour the "Default Priority" preference from the profile screen
      // (it was saved but never used).
      final settings = ref.read(settingsControllerProvider).value;
      if (settings != null) _priority = settings.defaultPriority;
    }
  }

  Future<void> _loadExistingTask(int id) async {
    Task? task;
    try {
      task = await ref.read(taskListProvider.notifier).getTaskById(id);
    } catch (_) {
      task = null;
    }
    if (!mounted) return;
    final Task? loaded = task;
    setState(() {
      _loadingTask = false;
      if (loaded == null) {
        _taskNotFound = true;
        return;
      }
      final task = loaded;
      _existingTask = task;
      _titleController.text = task.title;
      _notesController.text = task.description;
      _selectedDate = dateOnly(task.dueDate);
      _selectedTime =
          parseTimeOfDay(task.dueTime) ??
          TimeOfDay(hour: task.dueDate.hour, minute: task.dueDate.minute);
      _priority = task.priority;
      if (task.category.isNotEmpty) _category = task.category;
      _isAllDay = task.isAllDay;
      _reminder = task.reminder;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  /// 0 = Today, 1 = Tomorrow, 2 = another (picked) date.
  int get _dateSelection {
    final diff = daysBetween(DateTime.now(), _selectedDate);
    if (diff == 0) return 0;
    if (diff == 1) return 1;
    return 2;
  }

  Future<void> _pickDate() async {
    final today = dateOnly(DateTime.now());
    // Editing an overdue task used to crash here: its date was before
    // `firstDate: DateTime.now()`.
    final firstDate = _selectedDate.isBefore(today) ? _selectedDate : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstDate,
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = dateOnly(picked));
    }
  }

  Future<void> _pickTime() async {
    if (_isAllDay) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && mounted) {
      setState(() => _selectedTime = picked);
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is not available yet.')),
    );
  }

  Future<void> _saveTask() async {
    if (_saving) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Please enter a title');
      return;
    }

    final provider = ref.read(taskListProvider.notifier);
    final now = DateTime.now();
    final dueDate = combineDateAndTime(
      _selectedDate,
      _isAllDay ? null : _selectedTime,
    );
    final dueTime = _isAllDay ? '' : formatTimeOfDay(_selectedTime);

    setState(() => _saving = true);
    try {
      final existing = _existingTask;
      if (existing == null) {
        await provider.addTask(
          Task(
            title: title,
            description: _notesController.text.trim(),
            dueDate: dueDate,
            dueTime: dueTime,
            priority: _priority,
            category: _category,
            isAllDay: _isAllDay,
            reminder: _reminder,
            reminderMinutes: _reminder ? 15 : 0,
            createdAt: now,
            updatedAt: now,
          ),
        );
      } else {
        await provider.updateTask(
          existing.copyWith(
            title: title,
            description: _notesController.text.trim(),
            dueDate: dueDate,
            dueTime: dueTime,
            priority: _priority,
            category: _category,
            isAllDay: _isAllDay,
            reminder: _reminder,
            reminderMinutes: _reminder ? 15 : 0,
          ),
        );
      }
      if (mounted) _close();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    if (_isEditing && _taskNotFound) {
      return const NotFoundScreen(
        title: 'Task not found',
        message: 'This task no longer exists.',
      );
    }

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter, control: true):
            _saveTask,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _saveTask,
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Back',
            icon: Icon(Icons.arrow_back_ios_new, color: colorScheme.onSurface),
            onPressed: _close,
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF818CF8), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                _isEditing ? 'Edit Task' : 'Quick Add',
                style: textTheme.headlineMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          centerTitle: true,
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: UserAvatar(),
            ),
          ],
        ),
        body: _loadingTask
            ? const Center(child: CircularProgressIndicator())
            : _buildForm(colorScheme, textTheme),
      ),
    );
  }

  Widget _buildForm(ColorScheme colorScheme, TextTheme textTheme) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Context Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isEditing ? 'EDITING TASK' : 'CREATING FOCUS',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _close,
                  child: Text(
                    'Cancel',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Title & Notes Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    autofocus: !_isEditing,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(_kTitleMaxLength),
                    ],
                    onChanged: (_) => setState(() => _titleError = null),
                    style: textTheme.displayMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'What needs to be done?',
                      hintStyle: textTheme.displayMedium?.copyWith(
                        color: colorScheme.outline.withValues(alpha: 0.5),
                      ),
                      border: InputBorder.none,
                      errorText: _titleError,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.edit_note, color: colorScheme.outline, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _notesController,
                          maxLines: 3,
                          minLines: 1,
                          textCapitalization: TextCapitalization.sentences,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Add notes, context, or links...',
                            hintStyle: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.outline,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Divider(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: colorScheme.primary, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'One clear action per task works best',
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
                      ),
                      Text(
                        '${_titleController.text.length}/$_kTitleMaxLength',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // When Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: colorScheme.onSurface,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'When',
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'All-day',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Switch(
                      value: _isAllDay,
                      onChanged: (val) => setState(() => _isAllDay = val),
                      activeThumbColor: colorScheme.primary,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildDateChip(
                  colorScheme,
                  textTheme,
                  'Today',
                  Icons.calendar_today,
                  _dateSelection == 0,
                  () => setState(
                    () => _selectedDate = dateOnly(DateTime.now()),
                  ),
                ),
                _buildDateChip(
                  colorScheme,
                  textTheme,
                  'Tomorrow',
                  Icons.wb_twilight,
                  _dateSelection == 1,
                  () {
                    final now = DateTime.now();
                    setState(
                      () => _selectedDate = DateTime(
                        now.year,
                        now.month,
                        now.day + 1,
                      ),
                    );
                  },
                ),
                _buildDateChip(
                  colorScheme,
                  textTheme,
                  _dateSelection == 2
                      ? DateFormat('EEE, MMM d').format(_selectedDate)
                      : 'Pick Date',
                  Icons.calendar_month,
                  _dateSelection == 2,
                  _pickDate,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Time Row
            Opacity(
              opacity: _isAllDay ? 0.5 : 1,
              // Material (not a decorated Container) so the ripple is visible.
              child: Material(
                color: colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _isAllDay ? null : _pickTime,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.schedule,
                            color: colorScheme.onSurfaceVariant,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Target Time',
                                style: textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                _isAllDay
                                    ? 'Turn off All-day to set a time'
                                    : 'Tap to change',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _isAllDay
                                    ? 'All day'
                                    : formatTimeOfDay(_selectedTime),
                                style: textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              Icon(
                                Icons.expand_more,
                                color: colorScheme.onSurfaceVariant,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Priority Section
            Row(
              children: [
                Icon(Icons.flag_outlined, color: colorScheme.onSurface, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Priority',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildPriorityOption(
                    colorScheme,
                    textTheme,
                    'Casual',
                    TaskPriority.low,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPriorityOption(
                    colorScheme,
                    textTheme,
                    'Normal',
                    TaskPriority.medium,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPriorityOption(
                    colorScheme,
                    textTheme,
                    'Urgent',
                    TaskPriority.high,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Category Section
            Row(
              children: [
                Icon(Icons.folder_outlined, color: colorScheme.onSurface, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Category',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in kTaskCategories)
                  _buildCategoryTag(
                    colorScheme,
                    textTheme,
                    category.name,
                    category.icon,
                  ),
                // Keep a custom category from older data selectable.
                if (!kTaskCategories.any((c) => c.name == _category))
                  _buildCategoryTag(
                    colorScheme,
                    textTheme,
                    _category,
                    categoryIcon(_category),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Reminder & Repeat Card
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.04),
                    blurRadius: 6,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryFixed,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.notifications_active,
                          color: colorScheme.onPrimaryFixedVariant,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'Remind me',
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        '15 minutes before',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                      trailing: Switch(
                        value: _reminder,
                        onChanged: (val) => setState(() => _reminder = val),
                        activeThumbColor: colorScheme.primary,
                      ),
                    ),
                    Divider(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                      indent: 16,
                      endIndent: 16,
                    ),
                    ListTile(
                      onTap: () => _showComingSoon('Repeating tasks'),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.repeat,
                          color: colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'Repeat',
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        'Does not repeat',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Mindful Focus Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.spa,
                      color: colorScheme.onSecondaryContainer,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mindful Focus',
                          style: textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'One clear intention at a time.',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  shadowColor: colorScheme.primary.withValues(alpha: 0.25),
                ),
                child: _saving
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _isEditing ? 'Save Changes' : 'Save Task',
                            style: textTheme.labelLarge?.copyWith(
                              color: colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Press Cmd/Ctrl + Enter to fast save',
                style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDateChip(
    ColorScheme colorScheme,
    TextTheme textTheme,
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          border: isSelected
              ? null
              : Border.all(color: colorScheme.outlineVariant),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: textTheme.labelMedium?.copyWith(
                color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityOption(
    ColorScheme colorScheme,
    TextTheme textTheme,
    String subtitle,
    TaskPriority value,
  ) {
    final isSelected = _priority == value;
    final accent = priorityAccent(colorScheme, value);
    return GestureDetector(
      onTap: () => setState(() => _priority = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? priorityBackground(colorScheme, value)
              : colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? accent.withValues(alpha: 0.5)
                : colorScheme.outlineVariant,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    value.label,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium?.copyWith(
                      color: isSelected
                          ? priorityForeground(colorScheme, value)
                          : colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.check,
                    color: priorityForeground(colorScheme, value),
                    size: 14,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTag(
    ColorScheme colorScheme,
    TextTheme textTheme,
    String label,
    IconData icon,
  ) {
    final isSelected = _category == label;
    final selectedForeground = colorScheme.onPrimaryFixedVariant;
    return GestureDetector(
      onTap: () => setState(() => _category = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryFixed
              : colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.3)
                : colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? selectedForeground
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: textTheme.labelMedium?.copyWith(
                color: isSelected ? selectedForeground : colorScheme.onSurface,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(Icons.check, color: selectedForeground, size: 14),
            ],
          ],
        ),
      ),
    );
  }
}
