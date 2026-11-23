import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../data/models/enums.dart';
import '../../data/models/milestone.dart';
import '../../data/models/semester_plan.dart';
import '../../data/models/task_item.dart';
import '../../providers/plan_provider.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/task_editor_dialog.dart';

/// 学期计划页面（多学期创建/编辑/切换、长期目标、子里程碑勾选与总体完成率自动更新）
class SemesterPage extends StatelessWidget {
  const SemesterPage({super.key});

  Future<void> _showSemesterEditor(
    BuildContext context, {
    SemesterPlan? existing,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _SemesterEditorDialog(existing: existing),
    );
  }

  Future<void> _confirmDeleteSemester(
    BuildContext context,
    PlanProvider provider,
    SemesterPlan semester,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除学期'),
        content: Text(
          '确定删除「${semester.name}」吗？该学期下的长期目标与里程碑也将一并标记为已删除并同步至云端。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.deleteSemester(semester.id);
    }
  }

  Future<void> _showAddOrEditMilestoneDialog(
    BuildContext context, {
    required TaskItem goal,
    required String semesterId,
    Milestone? existing,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _MilestoneEditorDialog(
        goal: goal,
        semesterId: semesterId,
        existing: existing,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlanProvider>();
    final semesters = provider.semesters;
    final active = provider.activeSemester;
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppConstants.desktopBreakpoint;

    if (semesters.isEmpty || active == null) {
      return EmptyStateView(
        icon: Icons.school_outlined,
        title: '还没有创建学期计划',
        subtitle: '创建一个学期（设定起止日期），即可规划课程学习、期中期末考试与项目开发目标，并拆解子里程碑追踪进度',
        actionLabel: '创建第一个学期',
        onAction: () => _showSemesterEditor(context),
      );
    }

    final stats = provider.semesterProgressStats(active.id);
    final goals = provider.semesterGoals(active.id);

    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 左侧：多学期切换侧栏
            SizedBox(
              width: 300,
              child: _buildSemesterSidebar(context, provider, semesters, active),
            ),
            const SizedBox(width: 20),
            // 右侧：当前学期总览 + 长期目标与里程碑列表
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: <Widget>[
                  _buildActiveSemesterBanner(context, provider, active, stats),
                  const SizedBox(height: 16),
                  _buildGoalsHeader(context, active, goals.length),
                  const SizedBox(height: 10),
                  if (goals.isEmpty)
                    EmptyStateView(
                      icon: Icons.track_changes_rounded,
                      title: '本学期尚未添加长期目标',
                      subtitle: '添加课程学习、考试复习或项目开发目标，并为每个目标设置子里程碑',
                      actionLabel: '新建学期目标',
                      onAction: () => showTaskEditorDialog(
                        context,
                        initialDimension: PlanDimension.semester,
                        initialSemesterId: active.id,
                      ),
                    )
                  else
                    for (final goal in goals)
                      _SemesterGoalCard(
                        goal: goal,
                        semester: active,
                        onAddMilestone: () => _showAddOrEditMilestoneDialog(
                          context,
                          goal: goal,
                          semesterId: active.id,
                        ),
                        onEditMilestone: (ms) => _showAddOrEditMilestoneDialog(
                          context,
                          goal: goal,
                          semesterId: active.id,
                          existing: ms,
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 移动端布局
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 90),
      children: <Widget>[
        // 横向学期切换条
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              for (final s in semesters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: CircleAvatar(
                      radius: 6,
                      backgroundColor: Color(s.colorValue),
                    ),
                    label: Text(s.name),
                    selected: s.id == active.id,
                    onSelected: (_) => provider.selectSemester(s.id),
                  ),
                ),
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 18),
                label: const Text('新建学期'),
                onPressed: () => _showSemesterEditor(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildActiveSemesterBanner(context, provider, active, stats),
        const SizedBox(height: 14),
        _buildGoalsHeader(context, active, goals.length),
        const SizedBox(height: 10),
        if (goals.isEmpty)
          EmptyStateView(
            icon: Icons.track_changes_rounded,
            title: '本学期尚未添加长期目标',
            subtitle: '添加长期目标并为其配置子里程碑，勾选即可实时更新完成率',
            actionLabel: '新建学期目标',
            onAction: () => showTaskEditorDialog(
              context,
              initialDimension: PlanDimension.semester,
              initialSemesterId: active.id,
            ),
          )
        else
          for (final goal in goals)
            _SemesterGoalCard(
              goal: goal,
              semester: active,
              onAddMilestone: () => _showAddOrEditMilestoneDialog(
                context,
                goal: goal,
                semesterId: active.id,
              ),
              onEditMilestone: (ms) => _showAddOrEditMilestoneDialog(
                context,
                goal: goal,
                semesterId: active.id,
                existing: ms,
              ),
            ),
      ],
    );
  }

  Widget _buildSemesterSidebar(
    BuildContext context,
    PlanProvider provider,
    List<SemesterPlan> semesters,
    SemesterPlan active,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '我的学期（${semesters.length}）',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton.filledTonal(
                tooltip: '新建学期',
                icon: const Icon(Icons.add_rounded),
                onPressed: () => _showSemesterEditor(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: semesters.length,
              itemBuilder: (context, index) {
                final s = semesters[index];
                final isSelected = s.id == active.id;
                final sStats = provider.semesterProgressStats(s.id);
                final pct = (sStats.overallProgress * 100).round();

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primaryContainer.withAlpha(140)
                        : colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? Color(s.colorValue)
                          : colorScheme.outlineVariant.withAlpha(140),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onTap: () => provider.selectSemester(s.id),
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: Color(s.colorValue),
                      child: Text(
                        '$pct%',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    title: Text(
                      s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${s.startDate} ~ ${s.endDate}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSemesterBanner(
    BuildContext context,
    PlanProvider provider,
    SemesterPlan semester,
    SemesterProgressStats stats,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = Color(semester.colorValue);
    final percent = (stats.overallProgress * 100).round();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            accent.withAlpha(32),
            colorScheme.surfaceContainerLow,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  semester.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: '编辑学期',
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () =>
                    _showSemesterEditor(context, existing: semester),
              ),
              IconButton(
                tooltip: '删除学期',
                icon: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: colorScheme.error,
                ),
                onPressed: () =>
                    _confirmDeleteSemester(context, provider, semester),
              ),
            ],
          ),
          if (semester.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              semester.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: <Widget>[
              _StatChip(
                icon: Icons.date_range_outlined,
                label: '${semester.startDate} 至 ${semester.endDate}',
              ),
              _StatChip(
                icon: Icons.hourglass_bottom_rounded,
                label: semester.remainingDays > 0
                    ? '剩余 ${semester.remainingDays} 天'
                    : '学期已结束',
              ),
              _StatChip(
                icon: Icons.flag_outlined,
                label: '目标 ${stats.completedGoals}/${stats.totalGoals}',
              ),
              _StatChip(
                icon: Icons.checklist_rounded,
                label:
                    '里程碑 ${stats.completedMilestones}/${stats.totalMilestones}',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Text(
                '学期总体完成进度',
                style: theme.textTheme.labelLarge,
              ),
              const Spacer(),
              Text(
                '$percent%',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: stats.overallProgress),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 10,
                  color: accent,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsHeader(
    BuildContext context,
    SemesterPlan semester,
    int count,
  ) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            '学期长期目标与里程碑（$count）',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        FilledButton.icon(
          onPressed: () => showTaskEditorDialog(
            context,
            initialDimension: PlanDimension.semester,
            initialSemesterId: semester.id,
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('新增长期目标'),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest.withAlpha(210),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(130)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

/// 单个学期长期目标卡片（含自动进度条与子里程碑勾选清单）
class _SemesterGoalCard extends StatelessWidget {
  const _SemesterGoalCard({
    required this.goal,
    required this.semester,
    required this.onAddMilestone,
    required this.onEditMilestone,
  });

  final TaskItem goal;
  final SemesterPlan semester;
  final VoidCallback onAddMilestone;
  final ValueChanged<Milestone> onEditMilestone;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlanProvider>();
    final milestones = provider.milestonesForTask(goal.id);
    final progress = provider.taskProgress(goal);
    final percent = (progress * 100).round();
    final doneMs = milestones.where((m) => m.isCompleted).length;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    final priorityColor = AppTheme.priorityColor(goal.priority, brightness);
    final accent = Color(semester.colorValue);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(160)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (milestones.isEmpty)
                Checkbox(
                  value: goal.isCompleted,
                  onChanged: (_) => provider.toggleTaskCompleted(goal.id),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 10),
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: accent.withAlpha(32),
                    child: Text(
                      '$percent%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      goal.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        decoration:
                            goal.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (goal.notes.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        goal.notes,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.priorityContainerColor(
                              goal.priority,
                              brightness,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${goal.priority.label}优先级',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: priorityColor,
                            ),
                          ),
                        ),
                        if (goal.dueDate != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '截止 ${goal.dueDate}',
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                        for (final tag in goal.tags)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  colorScheme.secondaryContainer.withAlpha(130),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '#$tag',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '编辑目标',
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: () =>
                    showTaskEditorDialog(context, existingTask: goal),
              ),
              IconButton(
                tooltip: '删除目标',
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: colorScheme.error,
                ),
                onPressed: () async {
                  final removed = await provider.deleteTask(goal.id);
                  if (!context.mounted || removed == null) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已删除目标「${removed.title}」')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 目标进度条
          Row(
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    color: accent,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                milestones.isEmpty
                    ? '$percent%'
                    : '$doneMs/${milestones.length} 里程碑 ($percent%)',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(),

          // 里程碑清单
          if (milestones.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                children: milestones.map((ms) {
                  return Row(
                    children: <Widget>[
                      Checkbox(
                        value: ms.isCompleted,
                        visualDensity: VisualDensity.compact,
                        onChanged: (_) =>
                            provider.toggleMilestoneCompleted(ms.id),
                      ),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => provider.toggleMilestoneCompleted(ms.id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    ms.title,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      decoration: ms.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: ms.isCompleted
                                          ? colorScheme.onSurfaceVariant
                                          : colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                if (ms.dueDate != null)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Text(
                                      ms.dueDate!,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '编辑里程碑',
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onEditMilestone(ms),
                      ),
                      IconButton(
                        tooltip: '删除里程碑',
                        icon: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => provider.deleteMilestone(ms.id),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),

          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAddMilestone,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: const Text('添加子里程碑'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SemesterEditorDialog extends StatefulWidget {
  const _SemesterEditorDialog({this.existing});

  final SemesterPlan? existing;

  @override
  State<_SemesterEditorDialog> createState() => _SemesterEditorDialogState();
}

class _SemesterEditorDialogState extends State<_SemesterEditorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late DateTime _startDate;
  late DateTime _endDate;
  late int _colorValue;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final today = AppDateUtils.today();
    _nameController = TextEditingController(text: existing?.name ?? '');
    _descController = TextEditingController(text: existing?.description ?? '');
    _startDate = AppDateUtils.parseIsoDate(existing?.startDate) ?? today;
    _endDate = AppDateUtils.parseIsoDate(existing?.endDate) ??
        today.add(const Duration(days: 120));
    _colorValue =
        existing?.colorValue ?? AppConstants.semesterColorValues.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<PlanProvider>();
    final existing = widget.existing;
    if (existing == null) {
      await provider.createSemester(
        name: _nameController.text,
        description: _descController.text,
        startDate: _startDate,
        endDate: _endDate,
        colorValue: _colorValue,
      );
    } else {
      await provider.updateSemester(
        existing.copyWith(
          name: _nameController.text,
          description: _descController.text,
          startDate: AppDateUtils.toIsoDate(_startDate),
          endDate: AppDateUtils.toIsoDate(_endDate),
          colorValue: _colorValue,
        ),
      );
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    return AlertDialog(
      title: Text(existing == null ? '创建新学期' : '编辑学期信息'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  controller: _nameController,
                  autofocus: existing == null,
                  decoration: const InputDecoration(
                    labelText: '学期名称 *',
                    hintText: '例如：2026-2027 学年第一学期',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '请输入学期名称' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '学期总目标说明（可选）',
                    hintText: '例如：冲刺专业前 10%、完成毕业设计开题与核心模块开发',
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _startDate,
                            firstDate: DateTime(2020, 1, 1),
                            lastDate: DateTime(2040, 12, 31),
                            locale: const Locale('zh', 'CN'),
                          );
                          if (picked != null) {
                            setState(() {
                              _startDate = AppDateUtils.dateOnly(picked);
                              if (_endDate.isBefore(_startDate)) {
                                _endDate = _startDate.add(
                                  const Duration(days: 90),
                                );
                              }
                            });
                          }
                        },
                        icon: const Icon(Icons.date_range_outlined, size: 16),
                        label: Text(
                          '开始: ${AppDateUtils.toIsoDate(_startDate)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _endDate.isBefore(_startDate)
                                ? _startDate
                                : _endDate,
                            firstDate: _startDate,
                            lastDate: DateTime(2040, 12, 31),
                            locale: const Locale('zh', 'CN'),
                          );
                          if (picked != null) {
                            setState(
                              () => _endDate = AppDateUtils.dateOnly(picked),
                            );
                          }
                        },
                        icon: const Icon(Icons.event_outlined, size: 16),
                        label: Text(
                          '结束: ${AppDateUtils.toIsoDate(_endDate)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '学期标识色',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: AppConstants.semesterColorValues.map((c) {
                    final selected = c == _colorValue;
                    return InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => setState(() => _colorValue = c),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: selected
                              ? Border.all(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  width: 2.5,
                                )
                              : null,
                        ),
                        child: selected
                            ? const Icon(
                                Icons.check,
                                size: 18,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(existing == null ? '创建学期' : '保存'),
        ),
      ],
    );
  }
}

class _MilestoneEditorDialog extends StatefulWidget {
  const _MilestoneEditorDialog({
    required this.goal,
    required this.semesterId,
    this.existing,
  });

  final TaskItem goal;
  final String semesterId;
  final Milestone? existing;

  @override
  State<_MilestoneEditorDialog> createState() => _MilestoneEditorDialogState();
}

class _MilestoneEditorDialogState extends State<_MilestoneEditorDialog> {
  late final TextEditingController _titleController;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existing?.title ?? '',
    );
    _dueDate = AppDateUtils.parseIsoDate(widget.existing?.dueDate);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final provider = context.read<PlanProvider>();
    final dueIso = _dueDate != null ? AppDateUtils.toIsoDate(_dueDate!) : null;
    if (widget.existing == null) {
      await provider.addMilestone(
        taskId: widget.goal.id,
        semesterId: widget.semesterId,
        title: title,
        dueDate: dueIso,
      );
    } else {
      await provider.updateMilestone(
        widget.existing!.copyWith(title: title, dueDate: dueIso),
      );
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '添加子里程碑' : '编辑里程碑'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '所属目标：${widget.goal.title}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '里程碑名称 *',
                hintText: '例如：完成前五章复习 / 通过期中答辩',
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dueDate ?? AppDateUtils.today(),
                      firstDate: DateTime(2020, 1, 1),
                      lastDate: DateTime(2040, 12, 31),
                      locale: const Locale('zh', 'CN'),
                    );
                    if (picked != null) {
                      setState(() => _dueDate = AppDateUtils.dateOnly(picked));
                    }
                  },
                  icon: const Icon(Icons.event_outlined, size: 16),
                  label: Text(
                    _dueDate != null
                        ? '节点日期：${AppDateUtils.toIsoDate(_dueDate!)}'
                        : '设置节点日期（可选）',
                  ),
                ),
                if (_dueDate != null)
                  IconButton(
                    tooltip: '清除日期',
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() => _dueDate = null),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.existing == null ? '添加' : '保存'),
        ),
      ],
    );
  }
}
