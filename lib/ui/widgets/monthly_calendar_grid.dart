import 'package:flutter/material.dart';
import '../../core/utils/app_date_utils.dart';
import '../../providers/plan_provider.dart';

/// Material 3 自适应月历网格组件
///
/// 每个日期格通过圆点与角标清晰展示当日任务数量与完成状态，点击即可查看或新增当天任务。
class MonthlyCalendarGrid extends StatelessWidget {
  const MonthlyCalendarGrid({
    super.key,
    required this.year,
    required this.month,
    required this.selectedDate,
    required this.daySummaries,
    required this.onSelectDate,
    this.onQuickAddForDate,
    this.compact = false,
  });

  final int year;
  final int month;
  final DateTime selectedDate;
  final Map<String, DayTaskSummary> daySummaries;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<DateTime>? onQuickAddForDate;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final gridDates = AppDateUtils.monthCalendarGrid(year, month);
    final today = AppDateUtils.today();
    final rowCount = gridDates.length ~/ 7;

    return Container(
      padding: EdgeInsets.all(compact ? 10 : 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(150)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 星期标题行
          Row(
            children: List<Widget>.generate(7, (idx) {
              final isWeekend = idx >= 5;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    AppDateUtils.weekdayShortLabels[idx],
                    textAlign: TextAlign.center,
                    style: textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isWeekend
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          // 日期矩阵
          for (var row = 0; row < rowCount; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: List<Widget>.generate(7, (col) {
                  final date = gridDates[row * 7 + col];
                  final iso = AppDateUtils.toIsoDate(date);
                  final inCurrentMonth = date.month == month;
                  final isToday = AppDateUtils.isSameDay(date, today);
                  final isSelected = AppDateUtils.isSameDay(date, selectedDate);
                  final summary = daySummaries[iso];

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _CalendarDayCell(
                        date: date,
                        inCurrentMonth: inCurrentMonth,
                        isToday: isToday,
                        isSelected: isSelected,
                        summary: summary,
                        compact: compact,
                        onTap: () => onSelectDate(date),
                        onDoubleTap: onQuickAddForDate != null
                            ? () => onQuickAddForDate!(date)
                            : null,
                      ),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.inCurrentMonth,
    required this.isToday,
    required this.isSelected,
    required this.summary,
    required this.compact,
    required this.onTap,
    this.onDoubleTap,
  });

  final DateTime date;
  final bool inCurrentMonth;
  final bool isToday;
  final bool isSelected;
  final DayTaskSummary? summary;
  final bool compact;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = summary?.total ?? 0;
    final completed = summary?.completed ?? 0;
    final allDone = summary?.isAllCompleted ?? false;
    final hasHigh = summary?.hasHighPriorityPending ?? false;

    final Color bgColor;
    if (isSelected) {
      bgColor = colorScheme.primaryContainer;
    } else if (isToday) {
      bgColor = colorScheme.secondaryContainer.withAlpha(110);
    } else {
      bgColor = Colors.transparent;
    }

    final Color textColor;
    if (isSelected) {
      textColor = colorScheme.onPrimaryContainer;
    } else if (!inCurrentMonth) {
      textColor = colorScheme.onSurfaceVariant.withAlpha(105);
    } else if (isToday) {
      textColor = colorScheme.primary;
    } else {
      textColor = colorScheme.onSurface;
    }

    final Color dotColor;
    if (allDone) {
      dotColor = colorScheme.brightness == Brightness.dark
          ? const Color(0xFF4ADE80)
          : const Color(0xFF16A34A);
    } else if (hasHigh) {
      dotColor = colorScheme.error;
    } else {
      dotColor = colorScheme.primary;
    }

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Container(
          height: compact ? 52 : 68,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 4 : 6,
            vertical: compact ? 4 : 6,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : (isToday
                      ? colorScheme.primary.withAlpha(130)
                      : colorScheme.outlineVariant.withAlpha(70)),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: compact ? 13 : 14,
                      fontWeight: (isToday || isSelected)
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  if (total > 0 && !compact)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: dotColor.withAlpha(32),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$completed/$total',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: dotColor,
                        ),
                      ),
                    ),
                ],
              ),
              if (total > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    for (var i = 0; i < (total > 3 ? 3 : total); i++)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: i < completed
                              ? (colorScheme.brightness == Brightness.dark
                                  ? const Color(0xFF4ADE80)
                                  : const Color(0xFF16A34A))
                              : dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (compact && total > 3)
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Text(
                          '+',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: dotColor,
                          ),
                        ),
                      ),
                  ],
                )
              else
                const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}
