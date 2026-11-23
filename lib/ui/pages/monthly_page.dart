import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_date_utils.dart';
import '../../data/models/enums.dart';
import '../../data/models/task_item.dart';
import '../../providers/plan_provider.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/monthly_calendar_grid.dart';
import '../widgets/task_card.dart';
import '../widgets/task_editor_dialog.dart';

/// 月计划页面（月历网格视图 + 任务数量/完成状态圆点角标 + 点击日期查看/新增 + 月度重点任务）
class MonthlyPage extends StatelessWidget {
  const MonthlyPage({super.key});

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
    final year = provider.selectedMonthYear;
    final month = provider.selectedMonth;
    final selectedDate = provider.selectedMonthDate;
    final gridDates = AppDateUtils.monthCalendarGrid(year, month);
    final daySummaries = provider.buildDaySummaryMapForDates(gridDates);
    final selectedDayTasks = provider.tasksForDate(selectedDate);
    final monthlyGoals = provider.monthlyKeyTasks(year, month);
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppConstants.desktopBreakpoint;

    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildMonthHeader(context, provider, year, month),
            const SizedBox(height: 14),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // 左侧：月历网格 + 月度重点任务
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          MonthlyCalendarGrid(
                            year: year,
                            month: month,
                            selectedDate: selectedDate,
                            daySummaries: daySummaries,
                            onSelectDate: provider.setSelectedMonthDate,
                            onQuickAddForDate: (date) => showTaskEditorDialog(
                              context,
                              initialDimension: PlanDimension.daily,
                              initialDueDate: date,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _buildMonthlyGoalsSection(
                            context,
                            provider,
                            monthlyGoals,
                            year,
                            month,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  // 右侧：选中日期的任务详情与快捷新增
                  Expanded(
                    flex: 2,
                    child: _buildSelectedDatePanel(
                      context,
                      provider,
                      selectedDate,
                      selectedDayTasks,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 移动端单列视图
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
      children: <Widget>[
        _buildMonthHeader(context, provider, year, month),
        const SizedBox(height: 10),
        MonthlyCalendarGrid(
          year: year,
          month: month,
          selectedDate: selectedDate,
          daySummaries: daySummaries,
          compact: true,
          onSelectDate: provider.setSelectedMonthDate,
        ),
        const SizedBox(height: 14),
        _buildSelectedDateHeader(
          context,
          selectedDate,
          selectedDayTasks.length,
        ),
        const SizedBox(height: 8),
        if (selectedDayTasks.isEmpty)
          EmptyStateView(
            icon: Icons.event_note_outlined,
            title: '${selectedDate.month}月${selectedDate.day}日暂无任务',
            subtitle: '点击下方按钮直接为该日期新增任务',
            actionLabel: '新增当天任务',
            onAction: () => showTaskEditorDialog(
              context,
              initialDimension: PlanDimension.daily,
              initialDueDate: selectedDate,
            ),
          )
        else
          for (final task in selectedDayTasks)
            TaskCard(
              task: task,
              showDimensionBadge: task.dimension != PlanDimension.daily,
              showDueDate: false,
              onToggleComplete: () => provider.toggleTaskCompleted(task.id),
              onEdit: () => showTaskEditorDialog(context, existingTask: task),
              onDelete: () => _deleteWithUndo(context, provider, task),
            ),
        const SizedBox(height: 16),
        _buildMonthlyGoalsSection(context, provider, monthlyGoals, year, month),
      ],
    );
  }

  Widget _buildMonthHeader(
    BuildContext context,
    PlanProvider provider,
    int year,
    int month,
  ) {
    final theme = Theme.of(context);
    final today = AppDateUtils.today();
    final isCurrentMonth = year == today.year && month == today.month;

    return Row(
      children: <Widget>[
        IconButton.filledTonal(
          tooltip: '上个月',
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => provider.shiftMonth(-1),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            AppDateUtils.formatYearMonth(year, month),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (!isCurrentMonth) ...<Widget>[
          TextButton(
            onPressed: () => provider.setSelectedMonth(today.year, today.month),
            child: const Text('本月'),
          ),
          const SizedBox(width: 4),
        ],
        IconButton.filledTonal(
          tooltip: '下个月',
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () => provider.shiftMonth(1),
        ),
      ],
    );
  }

  Widget _buildSelectedDateHeader(
    BuildContext context,
    DateTime selectedDate,
    int count,
  ) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            '${AppDateUtils.formatFriendlyDate(selectedDate)}（$count）',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: () => showTaskEditorDialog(
            context,
            initialDimension: PlanDimension.daily,
            initialDueDate: selectedDate,
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('新增当天任务'),
        ),
      ],
    );
  }

  Widget _buildSelectedDatePanel(
    BuildContext context,
    PlanProvider provider,
    DateTime selectedDate,
    List<TaskItem> tasks,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(140)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildSelectedDateHeader(context, selectedDate, tasks.length),
          const SizedBox(height: 12),
          Expanded(
            child: tasks.isEmpty
                ? EmptyStateView(
                    icon: Icons.event_available_outlined,
                    title: '当日暂无任务',
                    subtitle: '点击日历任意日期查看日程，双击日期也可快速新建',
                    actionLabel: '新增当天任务',
                    onAction: () => showTaskEditorDialog(
                      context,
                      initialDimension: PlanDimension.daily,
                      initialDueDate: selectedDate,
                    ),
                  )
                : ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return TaskCard(
                        task: task,
                        showDimensionBadge:
                            task.dimension != PlanDimension.daily,
                        showDueDate: false,
                        onToggleComplete: () =>
                            provider.toggleTaskCompleted(task.id),
                        onEdit: () =>
                            showTaskEditorDialog(context, existingTask: task),
                        onDelete: () =>
                            _deleteWithUndo(context, provider, task),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyGoalsSection(
    BuildContext context,
    PlanProvider provider,
    List<TaskItem> monthlyGoals,
    int year,
    int month,
  ) {
    final monthKey = AppDateUtils.toMonthKey(DateTime(year, month, 1));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '$month月重点任务（${monthlyGoals.length}）',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => showTaskEditorDialog(
                context,
                initialDimension: PlanDimension.monthly,
                initialMonthKey: monthKey,
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('新增月度重点'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (monthlyGoals.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '本月尚未添加重点任务，可在此规划月度考核、阶段性交付或大项清单。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          )
        else
          for (final task in monthlyGoals)
            TaskCard(
              task: task,
              showDueDate: true,
              onToggleComplete: () => provider.toggleTaskCompleted(task.id),
              onEdit: () => showTaskEditorDialog(context, existingTask: task),
              onDelete: () => _deleteWithUndo(context, provider, task),
            ),
      ],
    );
  }
}
