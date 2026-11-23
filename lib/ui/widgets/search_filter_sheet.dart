import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/enums.dart';
import '../../providers/plan_provider.dart';
import 'empty_state_view.dart';
import 'task_card.dart';
import 'task_editor_dialog.dart';

/// 全局搜索与多条件组合筛选面板（关键词 + 标签 + 优先级 + 完成状态 + 维度）
Future<void> showGlobalSearchFilterDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => const _GlobalSearchFilterDialog(),
  );
}

class _GlobalSearchFilterDialog extends StatefulWidget {
  const _GlobalSearchFilterDialog();

  @override
  State<_GlobalSearchFilterDialog> createState() =>
      _GlobalSearchFilterDialogState();
}

class _GlobalSearchFilterDialogState extends State<_GlobalSearchFilterDialog> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: context.read<PlanProvider>().searchQuery,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlanProvider>();
    final results = provider.filteredGlobalTasks;
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 顶部搜索栏
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: '搜索任务标题、备注、标签或里程碑...',
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  provider.setSearchQuery('');
                                },
                              )
                            : null,
                      ),
                      onChanged: provider.setSearchQuery,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (provider.hasActiveSearchOrFilter)
                    TextButton.icon(
                      onPressed: () {
                        _searchController.clear();
                        provider.clearSearchAndFilters();
                      },
                      icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                      label: const Text('重置'),
                    ),
                  IconButton(
                    tooltip: '关闭',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 组合筛选条件区
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  // 完成状态
                  SegmentedButton<TaskCompletionFilter>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: TaskCompletionFilter.values
                        .map(
                          (f) => ButtonSegment<TaskCompletionFilter>(
                            value: f,
                            label: Text(f.label),
                          ),
                        )
                        .toList(),
                    selected: <TaskCompletionFilter>{
                      provider.filterCompletion,
                    },
                    onSelectionChanged: (s) =>
                        provider.setFilterCompletion(s.first),
                  ),

                  // 优先级筛选
                  for (final priority in <TaskPriority>[
                    TaskPriority.high,
                    TaskPriority.medium,
                    TaskPriority.low,
                  ])
                    FilterChip(
                      label: Text('${priority.label}优'),
                      selected: provider.filterPriority == priority,
                      avatar: Icon(
                        Icons.flag_rounded,
                        size: 16,
                        color: AppTheme.priorityColor(priority, brightness),
                      ),
                      onSelected: (selected) => provider.setFilterPriority(
                        selected ? priority : null,
                      ),
                    ),

                  // 维度筛选
                  for (final dim in PlanDimension.values)
                    FilterChip(
                      label: Text(dim.label),
                      selected: provider.filterDimension == dim,
                      onSelected: (selected) => provider.setFilterDimension(
                        selected ? dim : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // 标签筛选横滚栏
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: provider.allAvailableTags.map((tag) {
                    final selected = provider.filterTags.contains(tag);
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text('#$tag'),
                        selected: selected,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => provider.toggleFilterTag(tag),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: <Widget>[
                  Text(
                    '匹配结果：${results.length} 条任务',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),

              // 搜索结果列表
              Expanded(
                child: results.isEmpty
                    ? const EmptyStateView(
                        icon: Icons.manage_search_rounded,
                        title: '未找到匹配的任务',
                        subtitle: '尝试调整关键词、标签、优先级或完成状态筛选条件',
                      )
                    : ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final task = results[index];
                          return TaskCard(
                            task: task,
                            showDimensionBadge: true,
                            onToggleComplete: () =>
                                provider.toggleTaskCompleted(task.id),
                            onEdit: () => showTaskEditorDialog(
                              context,
                              existingTask: task,
                            ),
                            onDelete: () async {
                              final removed =
                                  await provider.deleteTask(task.id);
                              if (!context.mounted || removed == null) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('已删除「${removed.title}」'),
                                  action: SnackBarAction(
                                    label: '撤销',
                                    onPressed: () =>
                                        provider.restoreDeletedTask(removed),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
