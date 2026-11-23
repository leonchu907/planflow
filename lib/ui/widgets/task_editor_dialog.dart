import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../data/models/enums.dart';
import '../../data/models/task_item.dart';
import '../../providers/plan_provider.dart';

/// 通用任务新建 / 编辑对话框（支持四维选择、日期、优先级、备注、自定义标签、所属学期）
Future<void> showTaskEditorDialog(
  BuildContext context, {
  TaskItem? existingTask,
  PlanDimension initialDimension = PlanDimension.daily,
  DateTime? initialDueDate,
  DateTime? initialWeekStart,
  String? initialMonthKey,
  String? initialSemesterId,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return _TaskEditorDialog(
        existingTask: existingTask,
        initialDimension: existingTask?.dimension ?? initialDimension,
        initialDueDate: initialDueDate,
        initialWeekStart: initialWeekStart,
        initialMonthKey: initialMonthKey,
        initialSemesterId: initialSemesterId,
      );
    },
  );
}

class _TaskEditorDialog extends StatefulWidget {
  const _TaskEditorDialog({
    this.existingTask,
    required this.initialDimension,
    this.initialDueDate,
    this.initialWeekStart,
    this.initialMonthKey,
    this.initialSemesterId,
  });

  final TaskItem? existingTask;
  final PlanDimension initialDimension;
  final DateTime? initialDueDate;
  final DateTime? initialWeekStart;
  final String? initialMonthKey;
  final String? initialSemesterId;

  @override
  State<_TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<_TaskEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  final TextEditingController _customTagController = TextEditingController();

  late PlanDimension _dimension;
  late TaskPriority _priority;
  DateTime? _dueDate;
  String? _selectedSemesterId;
  late Set<String> _selectedTags;
  bool _saving = false;

  bool get _isEditing => widget.existingTask != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingTask;
    final provider = context.read<PlanProvider>();

    _titleController = TextEditingController(text: existing?.title ?? '');
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _dimension = widget.initialDimension;
    _priority = existing?.priority ?? TaskPriority.medium;

    if (existing != null) {
      _dueDate = AppDateUtils.parseIsoDate(existing.dueDate);
      _selectedSemesterId = existing.semesterId;
      _selectedTags = Set<String>.from(existing.tags);
    } else {
      _dueDate = widget.initialDueDate ??
          (_dimension == PlanDimension.daily
              ? provider.selectedDailyDate
              : null);
      _selectedSemesterId =
          widget.initialSemesterId ?? provider.activeSemester?.id;
      _selectedTags = <String>{};
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _customTagController.dispose();
    super.dispose();
  }

  void _addCustomTag() {
    final text = _customTagController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _selectedTags.add(text);
      _customTagController.clear();
    });
  }

  Future<void> _pickDueDate() async {
    final initial = _dueDate ?? AppDateUtils.today();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2040, 12, 31),
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null) {
      setState(() => _dueDate = AppDateUtils.dateOnly(picked));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);

    final provider = context.read<PlanProvider>();
    final dueIso = _dueDate != null ? AppDateUtils.toIsoDate(_dueDate!) : null;
    final tagsList = _selectedTags.toList();

    final String? weekStartIso = _dimension == PlanDimension.weekly
        ? AppDateUtils.toIsoDate(
            AppDateUtils.startOfWeek(
              _dueDate ??
                  widget.initialWeekStart ??
                  provider.selectedWeekStart,
            ),
          )
        : widget.existingTask?.weekStartDate;

    final String? monthKey = _dimension == PlanDimension.monthly
        ? (_dueDate != null
            ? AppDateUtils.toMonthKey(_dueDate!)
            : (widget.initialMonthKey ??
                AppDateUtils.toMonthKey(
                  DateTime(
                    provider.selectedMonthYear,
                    provider.selectedMonth,
                    1,
                  ),
                )))
        : widget.existingTask?.monthKey;

    final String? semesterId = _dimension == PlanDimension.semester
        ? (_selectedSemesterId ?? provider.activeSemester?.id)
        : null;

    if (_isEditing) {
      final updated = widget.existingTask!.copyWith(
        title: _titleController.text.trim(),
        notes: _notesController.text.trim(),
        dimension: _dimension,
        priority: _priority,
        dueDate: dueIso,
        weekStartDate: weekStartIso,
        monthKey: monthKey,
        semesterId: semesterId,
        tags: tagsList,
      );
      await provider.updateTask(updated);
    } else {
      await provider.createTask(
        title: _titleController.text.trim(),
        notes: _notesController.text.trim(),
        dimension: _dimension,
        priority: _priority,
        dueDate: dueIso,
        weekStartDate: weekStartIso,
        monthKey: monthKey,
        semesterId: semesterId,
        tags: tagsList,
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlanProvider>();
    final semesters = provider.semesters;
    final availableTags = <String>{
      ...provider.allAvailableTags,
      ..._selectedTags,
    }.toList();
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        _isEditing
                            ? Icons.edit_note_rounded
                            : Icons.add_task_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isEditing ? '编辑任务' : '新建计划任务',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 任务标题
                  TextFormField(
                    controller: _titleController,
                    autofocus: !_isEditing,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '任务标题 *',
                      hintText: '例如：完成高数第四章习题 / 准备期中答辩 PPT',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入任务标题';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // 详细备注
                  TextFormField(
                    controller: _notesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '详细备注',
                      hintText: '补充执行步骤、参考资料或注意事项...',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 时间维度
                  Text(
                    '所属时间维度',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<PlanDimension>(
                    segments: PlanDimension.values
                        .map(
                          (d) => ButtonSegment<PlanDimension>(
                            value: d,
                            label: Text(d.shortLabel),
                          ),
                        )
                        .toList(),
                    selected: <PlanDimension>{_dimension},
                    onSelectionChanged: (selection) {
                      final next = selection.first;
                      setState(() {
                        _dimension = next;
                        if (next == PlanDimension.daily && _dueDate == null) {
                          _dueDate = provider.selectedDailyDate;
                        }
                        if (next == PlanDimension.semester &&
                            _selectedSemesterId == null &&
                            semesters.isNotEmpty) {
                          _selectedSemesterId =
                              provider.activeSemester?.id ?? semesters.first.id;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // 学期选择器（仅当维度为学期计划时展示）
                  if (_dimension == PlanDimension.semester) ...<Widget>[
                    Text('所属学期', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    if (semesters.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer.withAlpha(90),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '尚未创建学期，请先前往「学期计划」页面创建至少一个学期。',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      )
                    else
                      InputDecorator(
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: semesters.any(
                                    (s) => s.id == _selectedSemesterId)
                                ? _selectedSemesterId
                                : semesters.first.id,
                            items: semesters
                                .map(
                                  (s) => DropdownMenuItem<String>(
                                    value: s.id,
                                    child: Text(
                                      '${s.name} (${s.startDate} ~ ${s.endDate})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedSemesterId = val),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],

                  // 优先级
                  Text('优先级', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<TaskPriority>(
                    segments: <ButtonSegment<TaskPriority>>[
                      ButtonSegment<TaskPriority>(
                        value: TaskPriority.high,
                        label: const Text('高优先级'),
                        icon: Icon(
                          Icons.flag_rounded,
                          color: AppTheme.priorityColor(
                            TaskPriority.high,
                            brightness,
                          ),
                        ),
                      ),
                      ButtonSegment<TaskPriority>(
                        value: TaskPriority.medium,
                        label: const Text('中优先级'),
                        icon: Icon(
                          Icons.flag_rounded,
                          color: AppTheme.priorityColor(
                            TaskPriority.medium,
                            brightness,
                          ),
                        ),
                      ),
                      ButtonSegment<TaskPriority>(
                        value: TaskPriority.low,
                        label: const Text('低优先级'),
                        icon: Icon(
                          Icons.flag_rounded,
                          color: AppTheme.priorityColor(
                            TaskPriority.low,
                            brightness,
                          ),
                        ),
                      ),
                    ],
                    selected: <TaskPriority>{_priority},
                    onSelectionChanged: (s) =>
                        setState(() => _priority = s.first),
                  ),
                  const SizedBox(height: 16),

                  // 截止日期
                  Text('截止 / 执行日期', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      ActionChip(
                        avatar: const Icon(Icons.calendar_today_outlined,
                            size: 16),
                        label: Text(
                          _dueDate != null
                              ? AppDateUtils.toIsoDate(_dueDate!)
                              : '选择日期',
                        ),
                        onPressed: _pickDueDate,
                      ),
                      ActionChip(
                        label: const Text('今天'),
                        onPressed: () =>
                            setState(() => _dueDate = AppDateUtils.today()),
                      ),
                      ActionChip(
                        label: const Text('明天'),
                        onPressed: () => setState(
                          () => _dueDate = AppDateUtils.today()
                              .add(const Duration(days: 1)),
                        ),
                      ),
                      if (_dueDate != null &&
                          _dimension != PlanDimension.daily)
                        ActionChip(
                          avatar: const Icon(Icons.clear, size: 16),
                          label: const Text('清除日期'),
                          onPressed: () => setState(() => _dueDate = null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 自定义标签
                  Text('标签', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: availableTags.map((tag) {
                      final selected = _selectedTags.contains(tag);
                      return FilterChip(
                        label: Text(tag),
                        selected: selected,
                        onSelected: (isSelected) {
                          setState(() {
                            if (isSelected) {
                              _selectedTags.add(tag);
                            } else {
                              _selectedTags.remove(tag);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _customTagController,
                          decoration: const InputDecoration(
                            hintText: '输入自定义标签后回车添加...',
                            isDense: true,
                          ),
                          onSubmitted: (_) => _addCustomTag(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: _addCustomTag,
                        child: const Text('添加'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 操作按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('取消'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: (_saving ||
                                (_dimension == PlanDimension.semester &&
                                    semesters.isEmpty))
                            ? null
                            : _submit,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(_isEditing ? '保存修改' : '创建任务'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
