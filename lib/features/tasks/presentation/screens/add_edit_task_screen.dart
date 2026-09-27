import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import '../providers/task_provider.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task.dart';

class AddEditTaskScreen extends ConsumerStatefulWidget {
  final int? taskId;

  const AddEditTaskScreen({super.key, this.taskId});

  @override
  ConsumerState<AddEditTaskScreen> createState() => _AddEditTaskScreenState();
}

class _AddEditTaskScreenState extends ConsumerState<AddEditTaskScreen> {
  ColorScheme get colorScheme => Theme.of(context).colorScheme;
  TextTheme get textTheme => Theme.of(context).textTheme;

  late TextEditingController _titleController;
  late TextEditingController _notesController;
  DateTime _selectedDate = DateTime.now();
  String _selectedTime = '02:00 PM';
  TaskPriority _priority = TaskPriority.medium;
  String _category = 'Work';
  bool _isAllDay = false;
  bool _reminder = true;
  int _dateSelection = 0; // 0=Today, 1=Tomorrow, 2=Pick
  Task? _existingTask;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _notesController = TextEditingController();

    if (widget.taskId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final task =
            await ref.read(taskListProvider.notifier).getTaskById(widget.taskId!);
        if (task != null && mounted) {
          setState(() {
            _existingTask = task;
            _titleController.text = task.title;
            _notesController.text = task.description;
            _selectedDate = task.dueDate;
            _selectedTime = task.dueTime;
            _priority = task.priority;
            _category = task.category;
            _isAllDay = task.isAllDay;
            _reminder = task.reminder;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveTask() async {
    if (_titleController.text.trim().isEmpty) return;

    final provider = ref.read(taskListProvider.notifier);
    final now = DateTime.now();

    if (widget.taskId == null) {
      final task = Task(
        title: _titleController.text.trim(),
        description: _notesController.text.trim(),
        dueDate: _selectedDate,
        dueTime: _selectedTime,
        priority: _priority,
        category: _category,
        isAllDay: _isAllDay,
        reminder: _reminder,
        reminderMinutes: _reminder ? 15 : 0,
        createdAt: now,
        updatedAt: now,
      );
      await provider.addTask(task);
    } else {
      final updated = _existingTask!.copyWith(
        title: _titleController.text.trim(),
        description: _notesController.text.trim(),
        dueDate: _selectedDate,
        dueTime: _selectedTime,
        priority: _priority,
        category: _category,
        isAllDay: _isAllDay,
        reminder: _reminder,
        reminderMinutes: _reminder ? 15 : 0,
        updatedAt: now,
      );
      await provider.updateTask(updated);
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isEditing = widget.taskId != null;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: colorScheme.onSurface),
          onPressed: () => context.pop(),
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
              child: Icon(Icons.check, color: Colors.white, size: 18),
            ),
            SizedBox(width: 8),
            Text(
              isEditing ? 'Edit Task' : 'Quick Add',
              style: textTheme.headlineMedium?.copyWith(color: colorScheme.onSurface),
            ),
          ],
        ),
        centerTitle: true,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                      SizedBox(width: 8),
                      Text(
                        isEditing ? 'EDITING TASK' : 'CREATING FOCUS',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text('Cancel',
                        style: textTheme.bodyMedium
                            ?.copyWith(color: colorScheme.onSurfaceVariant)),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Title & Notes Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.onSurface.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      style: textTheme.displayMedium
                          ?.copyWith(color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'What needs to be done?',
                        hintStyle: textTheme.displayMedium
                            ?.copyWith(color: colorScheme.outline.withOpacity(0.4)),
                        border: InputBorder.none,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.edit_note,
                            color: colorScheme.outline, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _notesController,
                            maxLines: 3,
                            minLines: 1,
                            style: textTheme.bodyMedium
                                ?.copyWith(color: colorScheme.onSurface),
                            decoration: InputDecoration(
                              hintText: 'Add notes, context, or links...',
                              hintStyle: textTheme.bodyMedium
                                  ?.copyWith(color: colorScheme.outline),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Divider(color: colorScheme.outlineVariant.withOpacity(0.5)),
                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome,
                                color: colorScheme.primary, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Auto-detects dates, tags & priority',
                              style: textTheme.bodySmall
                                  ?.copyWith(color: colorScheme.outline),
                            ),
                          ],
                        ),
                        Text(
                          '${_titleController.text.length}/120',
                          style: textTheme.bodySmall
                              ?.copyWith(color: colorScheme.outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // When Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          color: colorScheme.onSurface, size: 18),
                      SizedBox(width: 8),
                      Text('When',
                          style: textTheme.labelLarge
                              ?.copyWith(color: colorScheme.onSurface)),
                    ],
                  ),
                  Row(
                    children: [
                      Text('All-day',
                          style: textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant)),
                      SizedBox(width: 4),
                      Switch(
                        value: _isAllDay,
                        onChanged: (val) => setState(() => _isAllDay = val),
                        activeColor: colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  _buildDateChip('Today', Icons.calendar_today, _dateSelection == 0, () {
                    setState(() {
                      _dateSelection = 0;
                      _selectedDate = DateTime.now();
                    });
                  }),
                  SizedBox(width: 8),
                  _buildDateChip('Tomorrow', Icons.wb_twilight, _dateSelection == 1, () {
                    setState(() {
                      _dateSelection = 1;
                      _selectedDate = DateTime.now().add(const Duration(days: 1));
                    });
                  }),
                  SizedBox(width: 8),
                  _buildDateChip('Pick Date', Icons.calendar_month, _dateSelection == 2,
                      () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() {
                        _dateSelection = 2;
                        _selectedDate = picked;
                      });
                    }
                  }),
                ],
              ),
              SizedBox(height: 16),

              // Time Row
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.schedule,
                              color: colorScheme.onSurfaceVariant, size: 18),
                        ),
                        SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Target Time',
                                style: textTheme.labelMedium
                                    ?.copyWith(color: colorScheme.onSurface)),
                            Text('Optimal flow zone',
                                style: textTheme.bodySmall
                                    ?.copyWith(color: colorScheme.outline)),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Text(_selectedTime,
                              style: textTheme.labelMedium
                                  ?.copyWith(color: colorScheme.onSurface)),
                          Icon(Icons.expand_more,
                              color: colorScheme.onSurfaceVariant, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // Priority Section
              Row(
                children: [
                  Icon(Icons.flag_outlined,
                      color: colorScheme.onSurface, size: 18),
                  SizedBox(width: 8),
                  Text('Priority',
                      style: textTheme.labelLarge
                          ?.copyWith(color: colorScheme.onSurface)),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _buildPriorityOption(
                          'Low', 'Casual', colorScheme.secondaryContainer,
                          TaskPriority.low)),
                  SizedBox(width: 8),
                  Expanded(
                      child: _buildPriorityOption(
                          'Medium', 'Normal', colorScheme.tertiary,
                          TaskPriority.medium)),
                  SizedBox(width: 8),
                  Expanded(
                      child: _buildPriorityOption(
                          'High', 'Urgent', colorScheme.error,
                          TaskPriority.high)),
                ],
              ),
              SizedBox(height: 24),

              // Category Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.folder_outlined,
                          color: colorScheme.onSurface, size: 18),
                      SizedBox(width: 8),
                      Text('Category',
                          style: textTheme.labelLarge
                              ?.copyWith(color: colorScheme.onSurface)),
                    ],
                  ),
                  Text('Manage tags',
                      style: textTheme.bodyMedium
                          ?.copyWith(color: colorScheme.primary)),
                ],
              ),
              SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryTag('Work', Icons.business_center),
                    SizedBox(width: 8),
                    _buildCategoryTag('Personal', Icons.person),
                    SizedBox(width: 8),
                    _buildCategoryTag('Health', Icons.favorite),
                    SizedBox(width: 8),
                    _buildCategoryTag('Shopping', Icons.shopping_bag),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // Reminder & Repeat Card
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.onSurface.withOpacity(0.04),
                      blurRadius: 6,
                    ),
                  ],
                ),
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
                        child: Icon(Icons.notifications_active,
                            color: colorScheme.primary, size: 20),
                      ),
                      title: Text('Remind me',
                          style: textTheme.bodyLarge
                              ?.copyWith(color: colorScheme.onSurface)),
                      subtitle: Text('15 minutes before',
                          style: textTheme.bodySmall
                              ?.copyWith(color: colorScheme.outline)),
                      trailing: Switch(
                        value: _reminder,
                        onChanged: (val) => setState(() => _reminder = val),
                        activeColor: colorScheme.primary,
                      ),
                    ),
                    Divider(
                        color: colorScheme.outlineVariant.withOpacity(0.5),
                        indent: 16,
                        endIndent: 16),
                    ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.repeat,
                            color: colorScheme.onSurfaceVariant, size: 20),
                      ),
                      title: Text('Repeat',
                          style: textTheme.bodyLarge
                              ?.copyWith(color: colorScheme.onSurface)),
                      subtitle: Text('Does not repeat',
                          style: textTheme.bodySmall
                              ?.copyWith(color: colorScheme.outline)),
                      trailing: Icon(Icons.chevron_right,
                          color: colorScheme.outline),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // Mindful Focus Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh.withOpacity(0.4),
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
                      child: Icon(Icons.spa,
                          color: colorScheme.secondary, size: 22),
                    ),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mindful Focus',
                            style: textTheme.labelMedium
                                ?.copyWith(color: colorScheme.onSurface)),
                        Text('One clear intention at a time.',
                            style: textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    shadowColor: colorScheme.primary.withOpacity(0.25),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 20),
                      SizedBox(width: 8),
                      Text('Save Task',
                          style: textTheme.labelLarge
                              ?.copyWith(color: Colors.white)),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 8),
              Center(
                child: Text('Press Cmd/Ctrl + Enter to fast save',
                    style:
                        textTheme.labelSmall?.copyWith(color: colorScheme.outline)),
              ),
              SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateChip(
      String label, IconData icon, bool isSelected, VoidCallback onTap) {
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
                      color: colorScheme.primary.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : colorScheme.onSurfaceVariant),
            SizedBox(width: 6),
            Text(
              label,
              style: textTheme.labelMedium?.copyWith(
                color: isSelected ? Colors.white : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityOption(
      String title, String subtitle, Color color, TaskPriority value) {
    final isSelected = _priority == value;
    return GestureDetector(
      onTap: () => setState(() => _priority = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (value == TaskPriority.medium
                  ? colorScheme.tertiaryFixed
                  : colorScheme.surfaceContainerLowest)
              : colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected ? color.withOpacity(0.3) : colorScheme.outlineVariant),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: color.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
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
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                SizedBox(width: 4),
                Text(
                  title,
                  style: textTheme.labelMedium?.copyWith(
                    color: isSelected ? color : colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isSelected) ...[
                  SizedBox(width: 4),
                  Icon(Icons.check, color: color, size: 14),
                ],
              ],
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style:
                  textTheme.labelSmall?.copyWith(color: colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTag(String label, IconData icon) {
    final isSelected = _category == label;
    return GestureDetector(
      onTap: () => setState(() => _category = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryFixed
              : colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: colorScheme.primary.withOpacity(0.3))
              : Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant),
            SizedBox(width: 6),
            Text(
              label,
              style: textTheme.labelMedium?.copyWith(
                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
            if (isSelected) ...[
              SizedBox(width: 4),
              Icon(Icons.check, color: colorScheme.primary, size: 14),
            ],
          ],
        ),
      ),
    );
  }
}
