import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../data/models/task_item.dart';

/// 响应式任务卡片
///
/// - 桌面宽屏（>= 840px）：支持鼠标悬停高亮并显示快捷编辑/删除/扩展操作图标；
/// - 移动窄屏（< 840px）：支持右滑快速勾选完成、左滑软删除（带撤回提示）。
class TaskCard extends StatefulWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onToggleComplete,
    required this.onEdit,
    required this.onDelete,
    this.showDimensionBadge = false,
    this.showDueDate = true,
    this.extraActions = const <Widget>[],
    this.footer,
  });

  final TaskItem task;
  final VoidCallback onToggleComplete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool showDimensionBadge;
  final bool showDueDate;
  final List<Widget> extraActions;
  final Widget? footer;

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppConstants.desktopBreakpoint;
    final cardContent = _buildCardBody(context, isDesktop: isDesktop);

    if (isDesktop) {
      return MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: cardContent,
      );
    }

    // 移动端：支持右滑完成、左滑删除手势
    return Dismissible(
      key: ValueKey<String>('dismiss_${widget.task.id}'),
      background: _buildSwipeBackground(
        context,
        alignment: Alignment.centerLeft,
        color: const Color(0xFF16A34A),
        icon: widget.task.isCompleted
            ? Icons.undo_rounded
            : Icons.check_circle_outline,
        label: widget.task.isCompleted ? '标为未完成' : '标记完成',
      ),
      secondaryBackground: _buildSwipeBackground(
        context,
        alignment: Alignment.centerRight,
        color: Theme.of(context).colorScheme.error,
        icon: Icons.delete_outline_rounded,
        label: '删除任务',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          widget.onToggleComplete();
          return false;
        }
        if (direction == DismissDirection.endToStart) {
          return true;
        }
        return false;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          widget.onDelete();
        }
      },
      child: cardContent,
    );
  }

  Widget _buildSwipeBackground(
    BuildContext context, {
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    final isLeft = alignment == Alignment.centerLeft;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: alignment,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (isLeft) ...<Widget>[
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else ...<Widget>[
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: Colors.white),
          ],
        ],
      ),
    );
  }

  Widget _buildCardBody(BuildContext context, {required bool isDesktop}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    final task = widget.task;

    final priorityColor = AppTheme.priorityColor(task.priority, brightness);
    final priorityBg =
        AppTheme.priorityContainerColor(task.priority, brightness);
    final overdue = !task.isCompleted && AppDateUtils.isOverdue(task.dueDate);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: task.isCompleted
            ? colorScheme.surfaceContainerLow.withAlpha(160)
            : colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isHovered
              ? colorScheme.primary.withAlpha(150)
              : colorScheme.outlineVariant.withAlpha(160),
          width: _isHovered ? 1.3 : 1.0,
        ),
        boxShadow: _isHovered
            ? <BoxShadow>[
                BoxShadow(
                  color: colorScheme.shadow.withAlpha(18),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onEdit,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // 左侧优先级色条
                  Container(
                    width: 4,
                    color: task.isCompleted
                        ? colorScheme.outlineVariant
                        : priorityColor,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Transform.scale(
                                scale: 1.05,
                                child: Checkbox(
                                  value: task.isCompleted,
                                  onChanged: (_) => widget.onToggleComplete(),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        task.title,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          decoration: task.isCompleted
                                              ? TextDecoration.lineThrough
                                              : null,
                                          color: task.isCompleted
                                              ? colorScheme.onSurfaceVariant
                                              : colorScheme.onSurface,
                                        ),
                                      ),
                                      if (task.notes.isNotEmpty) ...<Widget>[
                                        const SizedBox(height: 4),
                                        Text(
                                          task.notes,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              // 桌面端悬停操作按钮 / 扩展动作
                              if (isDesktop)
                                AnimatedOpacity(
                                  opacity: _isHovered ? 1.0 : 0.25,
                                  duration: const Duration(milliseconds: 140),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      ...widget.extraActions,
                                      IconButton(
                                        tooltip: '编辑任务',
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        onPressed: widget.onEdit,
                                      ),
                                      IconButton(
                                        tooltip: '删除任务',
                                        icon: Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: colorScheme.error,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        onPressed: widget.onDelete,
                                      ),
                                    ],
                                  ),
                                )
                              else if (widget.extraActions.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: widget.extraActions,
                                ),
                            ],
                          ),
                          // 标签、优先级、维度与截止日期元数据行
                          Padding(
                            padding: const EdgeInsets.only(left: 36, top: 6),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: <Widget>[
                                _MetaPill(
                                  label: '${task.priority.label}优',
                                  foreground: priorityColor,
                                  background: priorityBg,
                                  icon: Icons.flag_rounded,
                                ),
                                if (widget.showDimensionBadge)
                                  _MetaPill(
                                    label: task.dimension.label,
                                    foreground: colorScheme.primary,
                                    background: colorScheme.primaryContainer
                                        .withAlpha(120),
                                  ),
                                if (widget.showDueDate &&
                                    task.dueDate != null)
                                  _MetaPill(
                                    label: AppDateUtils.formatShortDueDate(
                                      task.dueDate,
                                    ),
                                    foreground: overdue
                                        ? colorScheme.error
                                        : colorScheme.onSurfaceVariant,
                                    background: overdue
                                        ? colorScheme.errorContainer
                                            .withAlpha(130)
                                        : colorScheme.surfaceContainerHighest
                                            .withAlpha(150),
                                    icon: Icons.event_outlined,
                                  ),
                                for (final tag in task.tags)
                                  _MetaPill(
                                    label: '#$tag',
                                    foreground: colorScheme.onSecondaryContainer,
                                    background: colorScheme.secondaryContainer
                                        .withAlpha(120),
                                  ),
                              ],
                            ),
                          ),
                          if (widget.footer != null) ...<Widget>[
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.only(left: 36),
                              child: widget.footer!,
                            ),
                          ],
                        ],
                      ),
                    ),
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

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.label,
    required this.foreground,
    required this.background,
    this.icon,
  });

  final String label;
  final Color foreground;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
