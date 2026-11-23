import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../data/models/enums.dart';
import '../../data/models/task_item.dart';
import '../../providers/plan_provider.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/task_card.dart';
import '../widgets/task_editor_dialog.dart';

/// 周计划页面（本周核心目标、周一至周日任务分布概览、直接分配与拆解到日计划）
class WeeklyPage extends StatelessWidget {
  const WeeklyPage({super.key});

  Future<void> _showAssignDayDialog(
    BuildContext context,
    PlanProvider provider,
    TaskItem weeklyTask,
    List<DateTime> weekDays,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('直接分配到本周具体某天'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  '将「${weeklyTask.title}」分配到某一天后，该任务将自动同步显示在对应日期的日计划中。',
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < weekDays.length; i++)
                  Builder(
                    builder: (_) {
                      final day = weekDays[i];
                      final iso = AppDateUtils.toIsoDate(day);
                      final isAssigned = weeklyTask.dueDate == iso;
                      return ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        leading: Icon(
                          isAssigned
                              ? Icons.check_circle_rounded
                              : Icons.calendar_today_outlined,
                          color: isAssigned
                              ? Theme.of(dialogContext).colorScheme.primary
                              : null,
                        ),
                        title: Text(
                          '${AppDateUtils.weekdayShortLabels[i]} · ${day.month}月${day.day}日',
                        ),
                        trailing: isAssigned
                            ? const Text('当前已分配')
                            : const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          await provider.assignWeeklyTaskToDate(
                            weeklyTask.id,
                            day,
                          );
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                      );
                    },
                  ),
                if (weeklyTask.dueDate != null) ...<Widget>[
                  const Divider(),
                  TextButton.icon(
                    onPressed: () async {
                      await provider.unassignWeeklyTaskDate(weeklyTask.id);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                    icon: const Icon(Icons.link_off_rounded),
                    label: const Text('取消具体日期分配（仅保留在周目标）'),
                  ),
                ],
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showBreakdownDialog(
    BuildContext context,
    PlanProvider provider,
    TaskItem weeklyTask,
    List<DateTime> weekDays,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _BreakdownWeeklyDialog(
        provider: provider,
        weeklyTask: weeklyTask,
        weekDays: weekDays,
      ),
    );
  }

  Future<void> _deleteWithUndo(
    BuildContext context,
    PlanProvider provider,
    TaskItem task,
  ) async {
    final removed = await provider.deleteTask(task.id);
    if (!context.mounted || removed == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已删除「${removed.title}」'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () => provider.restoreDeletedTask(removed),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlanProvider>();
    final weekStart = provider.selectedWeekStart;
    final weekDays = AppDateUtils.daysOfWeek(weekStart);
    final weeklyGoals = provider.weeklyGoalsForWeek(weekStart);
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppConstants.desktopBreakpoint;

    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildWeekNavigator(context, provider, weekStart),
            const SizedBox(height: 14),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // 左侧：本周核心目标池
                  SizedBox(
                    width: 400,
                    child: _buildWeeklyGoalsPanel(
                      context,
                      provider,
                      weeklyGoals,
                      weekDays,
                      weekStart,
                    ),
                  ),
                  const SizedBox(width: 18),
                  // 右侧：周一至周日任务分布概览
                  Expanded(
                    child: _buildSevenDaysBoard(
                      context,
                      provider,
                      weekDays,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 移动端单列滚动布局
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
      children: <Widget>[
        _buildWeekNavigator(context, provider, weekStart),
        const SizedBox(height: 12),
        _buildWeeklyGoalsHeader(context, weeklyGoals.length, weekStart),
        const SizedBox(height: 8),
        if (weeklyGoals.isEmpty)
          EmptyStateView(
            icon: Icons.flag_outlined,
            title: '本周尚未设定核心目标',
            subtitle: '添加周目标后可一键分配或拆解到本周周一至周日',
            actionLabel: '新建周目标',
            onAction: () => showTaskEditorDialog(
              context,
              initialDimension: PlanDimension.weekly,
              initialWeekStart: weekStart,
            ),
          )
        else
          for (final goal in weeklyGoals)
            _buildWeeklyGoalCard(context, provider, goal, weekDays),
        const SizedBox(height: 16),
        Text(
          '周一至周日任务分布',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < weekDays.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildWeekdayCard(context, provider, weekDays[i], i),
          ),
      ],
    );
  }

  Widget _buildWeekNavigator(
    BuildContext context,
    PlanProvider provider,
    DateTime weekStart,
  ) {
    final theme = Theme.of(context);
    final currentWeekMonday = AppDateUtils.startOfWeek(AppDateUtils.today());
    final isCurrentWeek = AppDateUtils.isSameDay(weekStart, currentWeekMonday);

    return Row(
      children: <Widget>[
        IconButton.filledTonal(
          tooltip: '上一周',
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => provider.shiftWeek(-1),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                AppDateUtils.formatWeekRange(weekStart),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                isCurrentWeek ? '本周计划概览' : '${weekStart.year}年周计划',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (!isCurrentWeek) ...<Widget>[
          TextButton(
            onPressed: () => provider.setSelectedWeekAnchor(AppDateUtils.today()),
            child: const Text('回到本周'),
          ),
          const SizedBox(width: 4),
        ],
        IconButton.filledTonal(
          tooltip: '下一周',
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () => provider.shiftWeek(1),
        ),
      ],
    );
  }

  Widget _buildWeeklyGoalsHeader(
    BuildContext context,
    int count,
    DateTime weekStart,
  ) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            '本周核心目标 ($count)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: () => showTaskEditorDialog(
            context,
            initialDimension: PlanDimension.weekly,
            initialWeekStart: weekStart,
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('周目标'),
        ),
      ],
    );
  }

  Widget _buildWeeklyGoalsPanel(
    BuildContext context,
    PlanProvider provider,
    List<TaskItem> weeklyGoals,
    List<DateTime> weekDays,
    DateTime weekStart,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(140)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildWeeklyGoalsHeader(context, weeklyGoals.length, weekStart),
          const SizedBox(height: 10),
          Expanded(
            child: weeklyGoals.isEmpty
                ? EmptyStateView(
                    icon: Icons.flag_outlined,
                    title: '暂无本周核心目标',
                    subtitle: '支持将周目标直接分配或拆解到具体某一天',
                    actionLabel: '新建周目标',
                    onAction: () => showTaskEditorDialog(
                      context,
                      initialDimension: PlanDimension.weekly,
                      initialWeekStart: weekStart,
                    ),
                  )
                : ListView.builder(
                    itemCount: weeklyGoals.length,
                    itemBuilder: (context, index) => _buildWeeklyGoalCard(
                      context,
                      provider,
                      weeklyGoals[index],
                      weekDays,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyGoalCard(
    BuildContext context,
    PlanProvider provider,
    TaskItem goal,
    List<DateTime> weekDays,
  ) {
    final subtasks = provider.subtasksOf(goal.id);
    final completedSubtasks = subtasks.where((s) => s.isCompleted).length;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return TaskCard(
      task: goal,
      showDueDate: true,
      extraActions: <Widget>[
        IconButton(
          tooltip: '分配到本周某天',
          icon: const Icon(Icons.event_available_outlined, size: 18),
          visualDensity: VisualDensity.compact,
          onPressed: () =>
              _showAssignDayDialog(context, provider, goal, weekDays),
        ),
        IconButton(
          tooltip: '拆解为日计划子任务',
          icon: const Icon(Icons.call_split_rounded, size: 18),
          visualDensity: VisualDensity.compact,
          onPressed: () =>
              _showBreakdownDialog(context, provider, goal, weekDays),
        ),
      ],
      onToggleComplete: () => provider.toggleTaskCompleted(goal.id),
      onEdit: () => showTaskEditorDialog(context, existingTask: goal),
      onDelete: () => _deleteWithUndo(context, provider, goal),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              ActionChip(
                avatar: const Icon(Icons.event_repeat_outlined, size: 15),
                label: Text(
                  goal.dueDate != null
                      ? '已分配 ${AppDateUtils.formatShortDueDate(goal.dueDate)}'
                      : '分配到某天',
                  style: const TextStyle(fontSize: 11),
                ),
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    _showAssignDayDialog(context, provider, goal, weekDays),
              ),
              ActionChip(
                avatar: const Icon(Icons.call_split_rounded, size: 15),
                label: Text(
                  subtasks.isEmpty
                      ? '拆解到日计划'
                      : '已拆解 $completedSubtasks/${subtasks.length}',
                  style: const TextStyle(fontSize: 11),
                ),
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    _showBreakdownDialog(context, provider, goal, weekDays),
              ),
            ],
          ),
          if (subtasks.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: subtasks.map((sub) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => provider.toggleTaskCompleted(sub.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            sub.isCompleted
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            size: 16,
                            color: sub.isCompleted
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              sub.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                decoration: sub.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: sub.isCompleted
                                    ? colorScheme.onSurfaceVariant
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            AppDateUtils.formatShortDueDate(sub.dueDate),
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSevenDaysBoard(
    BuildContext context,
    PlanProvider provider,
    List<DateTime> weekDays,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 3
            : (constraints.maxWidth >= 560 ? 2 : 1);
        final cardWidth =
            (constraints.maxWidth - (columns - 1) * 12) / columns;

        return SingleChildScrollView(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List<Widget>.generate(weekDays.length, (i) {
              return SizedBox(
                width: cardWidth,
                child: _buildWeekdayCard(context, provider, weekDays[i], i),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildWeekdayCard(
    BuildContext context,
    PlanProvider provider,
    DateTime day,
    int weekdayIndex,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    final isToday = AppDateUtils.isSameDay(day, AppDateUtils.today());
    final dayTasks = provider.tasksForDate(day);
    final completed = dayTasks.where((t) => t.isCompleted).length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isToday
              ? colorScheme.primary
              : colorScheme.outlineVariant.withAlpha(150),
          width: isToday ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isToday
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AppDateUtils.weekdayShortLabels[weekdayIndex],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isToday
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${day.month}月${day.day}日',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (dayTasks.isNotEmpty)
                Text(
                  '$completed/${dayTasks.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              IconButton(
                tooltip: '在该日添加任务',
                icon: const Icon(Icons.add_rounded, size: 18),
                visualDensity: VisualDensity.compact,
                onPressed: () => showTaskEditorDialog(
                  context,
                  initialDimension: PlanDimension.daily,
                  initialDueDate: day,
                ),
              ),
            ],
          ),
          const Divider(height: 12),
          if (dayTasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                '暂无日程安排',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final task in dayTasks)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => showTaskEditorDialog(context, existingTask: task),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: <Widget>[
                      InkWell(
                        onTap: () => provider.toggleTaskCompleted(task.id),
                        child: Icon(
                          task.isCompleted
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 18,
                          color: task.isCompleted
                              ? colorScheme.primary
                              : AppTheme.priorityColor(
                                  task.priority,
                                  brightness,
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: task.isCompleted
                                ? colorScheme.onSurfaceVariant
                                : colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (task.dimension == PlanDimension.weekly)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withAlpha(140),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '周',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _BreakdownWeeklyDialog extends StatefulWidget {
  const _BreakdownWeeklyDialog({
    required this.provider,
    required this.weeklyTask,
    required this.weekDays,
  });

  final PlanProvider provider;
  final TaskItem weeklyTask;
  final List<DateTime> weekDays;

  @override
  State<_BreakdownWeeklyDialog> createState() => _BreakdownWeeklyDialogState();
}

class _BreakdownWeeklyDialogState extends State<_BreakdownWeeklyDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  late DateTime _chosenDay;
  late TaskPriority _priority;

  @override
  void initState() {
    super.initState();
    _chosenDay = widget.weekDays.firstWhere(
      (d) => AppDateUtils.isSameDay(d, AppDateUtils.today()),
      orElse: () => widget.weekDays.first,
    );
    _priority = widget.weeklyTask.priority;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    await widget.provider.breakdownWeeklyTaskToDay(
      weeklyTask: widget.weeklyTask,
      subtaskTitle: title,
      targetDate: _chosenDay,
      notes: _notesController.text.trim(),
      priority: _priority,
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('拆解为日计划子任务'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                '所属周目标：${widget.weeklyTask.title}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '子任务标题 *',
                  hintText: '例如：完成前两节笔记整理',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '分配执行日期',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: List<Widget>.generate(widget.weekDays.length, (i) {
                  final day = widget.weekDays[i];
                  final selected = AppDateUtils.isSameDay(day, _chosenDay);
                  return ChoiceChip(
                    label: Text(
                      '${AppDateUtils.weekdayShortLabels[i]} ${day.month}/${day.day}',
                    ),
                    selected: selected,
                    onSelected: (_) => setState(() => _chosenDay = day),
                  );
                }),
              ),
              const SizedBox(height: 14),
              Text(
                '优先级',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              SegmentedButton<TaskPriority>(
                segments: const <ButtonSegment<TaskPriority>>[
                  ButtonSegment<TaskPriority>(
                    value: TaskPriority.high,
                    label: Text('高'),
                  ),
                  ButtonSegment<TaskPriority>(
                    value: TaskPriority.medium,
                    label: Text('中'),
                  ),
                  ButtonSegment<TaskPriority>(
                    value: TaskPriority.low,
                    label: Text('低'),
                  ),
                ],
                selected: <TaskPriority>{_priority},
                onSelectionChanged: (s) => setState(() => _priority = s.first),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.call_split_rounded),
          label: const Text('创建并同步到日计划'),
        ),
      ],
    );
  }
}
