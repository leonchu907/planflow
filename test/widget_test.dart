import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planflow/core/theme/app_theme.dart';
import 'package:planflow/data/models/enums.dart';
import 'package:planflow/data/models/task_item.dart';
import 'package:planflow/providers/plan_provider.dart';
import 'package:planflow/ui/widgets/empty_state_view.dart';
import 'package:planflow/ui/widgets/monthly_calendar_grid.dart';
import 'package:planflow/ui/widgets/task_card.dart';

void main() {
  testWidgets('TaskCard 渲染任务信息并响应勾选完成回调', (WidgetTester tester) async {
    var toggled = false;
    const sampleTask = TaskItem(
      id: 'task-widget-1',
      title: '完成编译原理期中复习',
      notes: '重点梳理语法分析与中间代码生成',
      dimension: PlanDimension.daily,
      dueDate: '2026-11-23',
      priority: TaskPriority.high,
      tags: <String>['学习', '考试'],
      createdAt: 1000,
      updatedAt: 1000,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        darkTheme: AppTheme.darkTheme(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: TaskCard(
              task: sampleTask,
              showDimensionBadge: true,
              onToggleComplete: () => toggled = true,
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('完成编译原理期中复习'), findsOneWidget);
    expect(find.text('高优'), findsOneWidget);
    expect(find.text('#学习'), findsOneWidget);
    expect(find.text('#考试'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(toggled, isTrue);
  });

  testWidgets('MonthlyCalendarGrid 渲染月历并响应日期点击', (WidgetTester tester) async {
    DateTime? selected;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: MonthlyCalendarGrid(
              year: 2026,
              month: 11,
              selectedDate: DateTime(2026, 11, 10),
              daySummaries: const <String, DayTaskSummary>{
                '2026-11-15': DayTaskSummary(
                  total: 3,
                  completed: 2,
                  hasHighPriorityPending: true,
                ),
              },
              compact: true,
              onSelectDate: (DateTime date) => selected = date,
            ),
          ),
        ),
      ),
    );

    expect(find.text('周一'), findsOneWidget);
    expect(find.text('周日'), findsOneWidget);

    await tester.tap(find.text('15').first);
    await tester.pump();
    expect(selected, DateTime(2026, 11, 15));
  });

  testWidgets('EmptyStateView 渲染占位文案与操作按钮', (WidgetTester tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme(),
        home: Scaffold(
          body: EmptyStateView(
            icon: Icons.wb_sunny_outlined,
            title: '暂无待办任务',
            subtitle: '点击下方按钮创建第一条任务',
            actionLabel: '新建任务',
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('暂无待办任务'), findsOneWidget);
    await tester.tap(find.text('新建任务'));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
