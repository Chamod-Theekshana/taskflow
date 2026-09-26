import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../providers/task_provider.dart';
import '../models/task.dart';

class AddEditTaskScreen extends StatefulWidget {
  final int? taskId;

  const AddEditTaskScreen({super.key, this.taskId});

  @override
  State<AddEditTaskScreen> createState() => _AddEditTaskScreenState();
}

class _AddEditTaskScreenState extends State<AddEditTaskScreen> {
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
            await context.read<TaskProvider>().getTaskById(widget.taskId!);
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

    final provider = context.read<TaskProvider>();
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
    final isEditing = widget.taskId != null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.onSurface),
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
              child: const Icon(Icons.check, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            Text(
              isEditing ? 'Edit Task' : 'Quick Add',
              style: AppTypography.headlineMd.copyWith(color: AppColors.onSurface),
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
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEditing ? 'EDITING TASK' : 'CREATING FOCUS',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.primary,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text('Cancel',
                        style: AppTypography.bodyMd
                            .copyWith(color: AppColors.onSurfaceVariant)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Title & Notes Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.onSurface.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      style: AppTypography.displayLgMobile
                          .copyWith(color: AppColors.onSurface),
                      decoration: InputDecoration(
                        hintText: 'What needs to be done?',
                        hintStyle: AppTypography.displayLgMobile
                            .copyWith(color: AppColors.outline.withOpacity(0.4)),
                        border: InputBorder.none,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.edit_note,
                            color: AppColors.outline, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _notesController,
                            maxLines: 3,
                            minLines: 1,
                            style: AppTypography.bodyMd
                                .copyWith(color: AppColors.onSurface),
                            decoration: InputDecoration(
                              hintText: 'Add notes, context, or links...',
                              hintStyle: AppTypography.bodyMd
                                  .copyWith(color: AppColors.outline),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Divider(color: AppColors.outlineVariant.withOpacity(0.5)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome,
                                color: AppColors.primary, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Auto-detects dates, tags & priority',
                              style: AppTypography.bodySm
                                  .copyWith(color: AppColors.outline),
                            ),
                          ],
                        ),
                        Text(
                          '${_titleController.text.length}/120',
                          style: AppTypography.bodySm
                              .copyWith(color: AppColors.outline),
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
                      const Icon(Icons.calendar_today,
                          color: AppColors.onSurface, size: 18),
                      const SizedBox(width: 8),
                      Text('When',
                          style: AppTypography.labelLg
                              .copyWith(color: AppColors.onSurface)),
                    ],
                  ),
                  Row(
                    children: [
                      Text('All-day',
                          style: AppTypography.bodyMd
                              .copyWith(color: AppColors.onSurfaceVariant)),
                      const SizedBox(width: 4),
                      Switch(
                        value: _isAllDay,
                        onChanged: (val) => setState(() => _isAllDay = val),
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildDateChip('Today', Icons.calendar_today, _dateSelection == 0, () {
                    setState(() {
                      _dateSelection = 0;
                      _selectedDate = DateTime.now();
                    });
                  }),
                  const SizedBox(width: 8),
                  _buildDateChip('Tomorrow', Icons.wb_twilight, _dateSelection == 1, () {
                    setState(() {
                      _dateSelection = 1;
                      _selectedDate = DateTime.now().add(const Duration(days: 1));
                    });
                  }),
                  const SizedBox(width: 8),
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
              const SizedBox(height: 16),

              // Time Row
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
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
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceContainer,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.schedule,
                              color: AppColors.onSurfaceVariant, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Target Time',
                                style: AppTypography.labelMd
                                    .copyWith(color: AppColors.onSurface)),
                            Text('Optimal flow zone',
                                style: AppTypography.bodySm
                                    .copyWith(color: AppColors.outline)),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Text(_selectedTime,
                              style: AppTypography.labelMd
                                  .copyWith(color: AppColors.onSurface)),
                          const Icon(Icons.expand_more,
                              color: AppColors.onSurfaceVariant, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Priority Section
              Row(
                children: [
                  const Icon(Icons.flag_outlined,
                      color: AppColors.onSurface, size: 18),
                  const SizedBox(width: 8),
                  Text('Priority',
                      style: AppTypography.labelLg
                          .copyWith(color: AppColors.onSurface)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _buildPriorityOption(
                          'Low', 'Casual', AppColors.secondaryBright,
                          TaskPriority.low)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _buildPriorityOption(
                          'Medium', 'Normal', AppColors.tertiary,
                          TaskPriority.medium)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _buildPriorityOption(
                          'High', 'Urgent', AppColors.error,
                          TaskPriority.high)),
                ],
              ),
              const SizedBox(height: 24),

              // Category Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.folder_outlined,
                          color: AppColors.onSurface, size: 18),
                      const SizedBox(width: 8),
                      Text('Category',
                          style: AppTypography.labelLg
                              .copyWith(color: AppColors.onSurface)),
                    ],
                  ),
                  Text('Manage tags',
                      style: AppTypography.bodyMd
                          .copyWith(color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryTag('Work', Icons.business_center),
                    const SizedBox(width: 8),
                    _buildCategoryTag('Personal', Icons.person),
                    const SizedBox(width: 8),
                    _buildCategoryTag('Health', Icons.favorite),
                    const SizedBox(width: 8),
                    _buildCategoryTag('Shopping', Icons.shopping_bag),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Reminder & Repeat Card
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.onSurface.withOpacity(0.04),
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
                          color: AppColors.primaryFixed,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.notifications_active,
                            color: AppColors.primary, size: 20),
                      ),
                      title: Text('Remind me',
                          style: AppTypography.bodyLg
                              .copyWith(color: AppColors.onSurface)),
                      subtitle: Text('15 minutes before',
                          style: AppTypography.bodySm
                              .copyWith(color: AppColors.outline)),
                      trailing: Switch(
                        value: _reminder,
                        onChanged: (val) => setState(() => _reminder = val),
                        activeColor: AppColors.primary,
                      ),
                    ),
                    Divider(
                        color: AppColors.outlineVariant.withOpacity(0.5),
                        indent: 16,
                        endIndent: 16),
                    ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.repeat,
                            color: AppColors.onSurfaceVariant, size: 20),
                      ),
                      title: Text('Repeat',
                          style: AppTypography.bodyLg
                              .copyWith(color: AppColors.onSurface)),
                      subtitle: Text('Does not repeat',
                          style: AppTypography.bodySm
                              .copyWith(color: AppColors.outline)),
                      trailing: const Icon(Icons.chevron_right,
                          color: AppColors.outline),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Mindful Focus Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.spa,
                          color: AppColors.secondary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mindful Focus',
                            style: AppTypography.labelMd
                                .copyWith(color: AppColors.onSurface)),
                        Text('One clear intention at a time.',
                            style: AppTypography.bodySm
                                .copyWith(color: AppColors.onSurfaceVariant)),
                      ],
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
                  onPressed: _saveTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    shadowColor: AppColors.primary.withOpacity(0.25),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle, size: 20),
                      const SizedBox(width: 8),
                      Text('Save Task',
                          style: AppTypography.labelLg
                              .copyWith(color: Colors.white)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text('Press Cmd/Ctrl + Enter to fast save',
                    style:
                        AppTypography.labelSm.copyWith(color: AppColors.outline)),
              ),
              const SizedBox(height: 32),
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
              ? AppColors.primary
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          border: isSelected
              ? null
              : Border.all(color: AppColors.outlineVariant),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
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
                    : AppColors.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.labelMd.copyWith(
                color: isSelected ? Colors.white : AppColors.onSurface,
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
                  ? AppColors.tertiaryFixed
                  : AppColors.surfaceContainerLowest)
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected ? color.withOpacity(0.3) : AppColors.outlineVariant),
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
                const SizedBox(width: 4),
                Text(
                  title,
                  style: AppTypography.labelMd.copyWith(
                    color: isSelected ? color : AppColors.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.check, color: color, size: 14),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style:
                  AppTypography.labelSm.copyWith(color: AppColors.outline),
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
              ? AppColors.primaryFixed
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: AppColors.primary.withOpacity(0.3))
              : Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.labelMd.copyWith(
                color: isSelected ? AppColors.primary : AppColors.onSurface,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              const Icon(Icons.check, color: AppColors.primary, size: 14),
            ],
          ],
        ),
      ),
    );
  }
}
