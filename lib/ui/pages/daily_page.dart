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

/// 日计划页面（当日待办、优先级排序、实时完成率进度条、一键顺延至次日）
class DailyPage extends StatefulWidget {
  const DailyPage({super.key});

  @override
  State<DailyPage> createState() => _DailyPageState();
}

class _DailyPageState extends State<DailyPage> {
  final TextEditingController _quickAddController = TextEditingController();
  TaskPriority _quickPriority = TaskPriority.medium;

  @override
  void dispose() {
    _quickAddController.dispose();
    super.dispose();
  }

  Future<void> _submitQuickAdd(PlanProvider provider) async {
    final title = _quickAddController.text.trim();
    if (title.isEmpty) return;

    await provider.createTask(
      title: title,
      dimension: PlanDimension.daily,
      dueDate: AppDateUtils.toIsoDate(provider.selectedDailyDate),
      priority: _quickPriority,
    );
    _quickAddController.clear();
  }

  Future<void> _pickDate(BuildContext context, PlanProvider provider) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: provider.selectedDailyDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2040, 12, 31),
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null) {
      provider.setSelectedDailyDate(picked);
    }
  }

  Future<void> _confirmPostpone(
    BuildContext context,
    PlanProvider provider,
    int incompleteCount,
  ) async {
    if (incompleteCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当天没有未完成的任务需要顺延')),
      );
      return;
    }

    final currentDate = provider.selectedDailyDate;
    final nextDate = currentDate.add(const Duration(days: 1));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('一键顺延未完成任务'),
        content: Text(
          '确定将 ${AppDateUtils.toIsoDate(currentDate)} 尚未完成的 $incompleteCount 条任务批量顺延至次日（${AppDateUtils.toIsoDate(nextDate)}）吗？',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.fast_forward_rounded),
            label: const Text('确认顺延'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final moved = await provider.postponeIncompleteTasks(currentDate);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已将 $moved 条未完成任务顺延至明天')),
    );
  }

  Future<void> _handleDelete(
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
    final date = provider.selectedDailyDate;
    final tasks = provider.tasksForDate(date);
    final summary = provider.daySummary(date);
    final incompleteCount = summary.total - summary.completed;
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppConstants.desktopBreakpoint;

    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 左侧主待办区
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildDateHeader(context, provider, date),
                  const SizedBox(height: 12),
                  _buildQuickAddBar(context, provider),
                  const SizedBox(height: 12),
                  _buildSortBar(context, provider, tasks.length),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _buildTaskList(context, provider, tasks, date),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            // 右侧统计与操作面板
            SizedBox(
              width: 340,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _buildProgressOverviewCard(
                      context,
                      provider,
                      summary,
                      incompleteCount,
                      isCompact: false,
                    ),
                    const SizedBox(height: 14),
                    _buildPriorityBreakdownCard(context, tasks),
                    const SizedBox(height: 14),
                    _buildShortcutTipsCard(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 移动端单列布局
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildDateHeader(context, provider, date),
          const SizedBox(height: 10),
          _buildProgressOverviewCard(
            context,
            provider,
            summary,
            incompleteCount,
            isCompact: true,
          ),
          const SizedBox(height: 10),
          _buildQuickAddBar(context, provider),
          const SizedBox(height: 8),
          _buildSortBar(context, provider, tasks.length),
          const SizedBox(height: 6),
          Expanded(
            child: _buildTaskList(context, provider, tasks, date),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(
    BuildContext context,
    PlanProvider provider,
    DateTime date,
  ) {
    final theme = Theme.of(context);
    final isToday = AppDateUtils.isSameDay(date, AppDateUtils.today());

    return Row(
      children: <Widget>[
        IconButton.filledTonal(
          tooltip: '前一天',
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => provider.shiftDailyDate(-1),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _pickDate(context, provider),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      AppDateUtils.formatFriendlyDate(date),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isToday) ...<Widget>[
          TextButton(
            onPressed: () => provider.setSelectedDailyDate(AppDateUtils.today()),
            child: const Text('今天'),
          ),
          const SizedBox(width: 4),
        ],
        IconButton.filledTonal(
          tooltip: '后一天',
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () => provider.shiftDailyDate(1),
        ),
      ],
    );
  }

  Widget _buildProgressOverviewCard(
    BuildContext context,
    PlanProvider provider,
    DayTaskSummary summary,
    int incompleteCount, {
    required bool isCompact,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final percent = (summary.completionRate * 100).round();

    return Container(
      padding: EdgeInsets.all(isCompact ? 14 : 18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(150)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '今日完成率',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Text(
                          '$percent%',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '已完成 ${summary.completed} / ${summary.total}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: incompleteCount == 0
                    ? null
                    : () => _confirmPostpone(
                          context,
                          provider,
                          incompleteCount,
                        ),
                icon: const Icon(Icons.fast_forward_rounded, size: 18),
                label: Text(
                  incompleteCount > 0 ? '一键顺延 ($incompleteCount)' : '一键顺延',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: summary.completionRate),
              duration: const Duration(milliseconds: 280),
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddBar(BuildContext context, PlanProvider provider) {
    final brightness = Theme.of(context).brightness;
    final priorityColor = AppTheme.priorityColor(_quickPriority, brightness);

    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: _quickAddController,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: '快速添加当日待办，按回车保存...',
              prefixIcon: const Icon(Icons.add_circle_outline_rounded),
              suffixIcon: PopupMenuButton<TaskPriority>(
                tooltip: '选择默认优先级',
                initialValue: _quickPriority,
                onSelected: (p) => setState(() => _quickPriority = p),
                icon: Icon(Icons.flag_rounded, color: priorityColor),
                itemBuilder: (_) => <PopupMenuEntry<TaskPriority>>[
                  for (final p in <TaskPriority>[
                    TaskPriority.high,
                    TaskPriority.medium,
                    TaskPriority.low,
                  ])
                    PopupMenuItem<TaskPriority>(
                      value: p,
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.flag_rounded,
                            size: 18,
                            color: AppTheme.priorityColor(p, brightness),
                          ),
                          const SizedBox(width: 8),
                          Text('${p.label}优先级'),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            onSubmitted: (_) => _submitQuickAdd(provider),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () => _submitQuickAdd(provider),
          child: const Text('添加'),
        ),
      ],
    );
  }

  Widget _buildSortBar(
    BuildContext context,
    PlanProvider provider,
    int totalCount,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Text(
          '待办清单（$totalCount）',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        DropdownButtonHideUnderline(
          child: DropdownButton<DailySortOrder>(
            value: provider.dailySortOrder,
            isDense: true,
            borderRadius: BorderRadius.circular(12),
            items: DailySortOrder.values
                .map(
                  (o) => DropdownMenuItem<DailySortOrder>(
                    value: o,
                    child: Text(
                      o.label,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) provider.setDailySortOrder(value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTaskList(
    BuildContext context,
    PlanProvider provider,
    List<TaskItem> tasks,
    DateTime date,
  ) {
    if (tasks.isEmpty) {
      return EmptyStateView(
        icon: Icons.wb_sunny_outlined,
        title: '这一天还没有安排任务',
        subtitle: '在上方输入框快速添加，或点击下方按钮创建带备注、标签的详细任务',
        actionLabel: '新建今日任务',
        onAction: () => showTaskEditorDialog(
          context,
          initialDimension: PlanDimension.daily,
          initialDueDate: date,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 84),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return TaskCard(
          task: task,
          showDimensionBadge: task.dimension != PlanDimension.daily,
          showDueDate: false,
          onToggleComplete: () => provider.toggleTaskCompleted(task.id),
          onEdit: () => showTaskEditorDialog(context, existingTask: task),
          onDelete: () => _handleDelete(context, provider, task),
        );
      },
    );
  }

  Widget _buildPriorityBreakdownCard(
    BuildContext context,
    List<TaskItem> tasks,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;

    int countPending(TaskPriority p) =>
        tasks.where((t) => !t.isCompleted && t.priority == p).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(150)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '未完成优先级分布',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          for (final p in <TaskPriority>[
            TaskPriority.high,
            TaskPriority.medium,
            TaskPriority.low,
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.flag_rounded,
                    size: 18,
                    color: AppTheme.priorityColor(p, brightness),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${p.label}优先级待办')),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.priorityContainerColor(p, brightness),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${countPending(p)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.priorityColor(p, brightness),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShortcutTipsCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(150)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.keyboard_outlined,
                  size: 18, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                '桌面端快捷键',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _ShortcutRow(keys: 'Ctrl + N', desc: '快速新建当前维度任务'),
          const _ShortcutRow(keys: 'Ctrl + F', desc: '全局搜索与组合筛选'),
          const _ShortcutRow(keys: 'Ctrl + S', desc: '立即触发 WebDAV 云同步'),
          const _ShortcutRow(keys: 'Ctrl + 1~5', desc: '快速切换导航视图'),
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.keys, required this.desc});

  final String keys;
  final String desc;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              keys,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              desc,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
