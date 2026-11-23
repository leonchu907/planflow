import 'package:flutter_test/flutter_test.dart';
import 'package:planflow/core/utils/app_date_utils.dart';
import 'package:planflow/data/models/enums.dart';
import 'package:planflow/data/models/milestone.dart';
import 'package:planflow/data/models/semester_plan.dart';
import 'package:planflow/data/models/sync_payload.dart';
import 'package:planflow/data/models/task_item.dart';
import 'package:planflow/services/sync_merger.dart';

void main() {
  group('SyncMerger LWW 增量合并与软删除防复活测试', () {
    test('单端独有记录应互相补齐到合并快照与本地待写列表', () {
      const localTask = TaskItem(
        id: 't-local',
        title: 'Windows 端新建任务',
        dimension: PlanDimension.daily,
        dueDate: '2026-11-23',
        priority: TaskPriority.high,
        createdAt: 1000,
        updatedAt: 1000,
      );
      const remoteTask = TaskItem(
        id: 't-remote',
        title: 'Android 端新建任务',
        dimension: PlanDimension.weekly,
        weekStartDate: '2026-11-23',
        priority: TaskPriority.medium,
        createdAt: 2000,
        updatedAt: 2000,
      );

      final result = SyncMerger.mergePayloads(
        local: const SyncPayload(
          exportedAt: 1000,
          deviceId: 'win-device',
          tasks: <TaskItem>[localTask],
          semesters: <SemesterPlan>[],
          milestones: <Milestone>[],
        ),
        remote: const SyncPayload(
          exportedAt: 2000,
          deviceId: 'android-device',
          tasks: <TaskItem>[remoteTask],
          semesters: <SemesterPlan>[],
          milestones: <Milestone>[],
        ),
        deviceId: 'win-device',
        exportedAtMs: 3000,
      );

      expect(result.mergedPayload.tasks.length, 2);
      expect(result.tasksToWriteLocal.map((e) => e.id), <String>['t-remote']);
      expect(result.pulledCount, 1);
      expect(result.pushedCount, 1);
    });

    test('双端均存在同 ID 记录时严格保留 updatedAt 较新的一方', () {
      const localOlder = TaskItem(
        id: 't-shared',
        title: '旧标题',
        dimension: PlanDimension.daily,
        dueDate: '2026-11-23',
        isCompleted: false,
        createdAt: 1000,
        updatedAt: 1500,
      );
      const remoteNewer = TaskItem(
        id: 't-shared',
        title: '新标题（远端已完成）',
        dimension: PlanDimension.daily,
        dueDate: '2026-11-24',
        isCompleted: true,
        completedAt: 2500,
        createdAt: 1000,
        updatedAt: 2500,
      );

      final result = SyncMerger.mergePayloads(
        local: const SyncPayload(
          exportedAt: 1500,
          deviceId: 'win',
          tasks: <TaskItem>[localOlder],
          semesters: <SemesterPlan>[],
          milestones: <Milestone>[],
        ),
        remote: const SyncPayload(
          exportedAt: 2500,
          deviceId: 'android',
          tasks: <TaskItem>[remoteNewer],
          semesters: <SemesterPlan>[],
          milestones: <Milestone>[],
        ),
        deviceId: 'win',
      );

      expect(result.mergedPayload.tasks.single.title, '新标题（远端已完成）');
      expect(result.mergedPayload.tasks.single.isCompleted, isTrue);
      expect(result.tasksToWriteLocal.single.id, 't-shared');
      expect(result.pulledCount, 1);
      expect(result.pushedCount, 0);
    });

    test('软删除标记（isDeleted=true）时间戳更新时应同步删除，防止已删数据复活', () {
      const localAlive = TaskItem(
        id: 't-del',
        title: '即将被远端删除的任务',
        dimension: PlanDimension.monthly,
        monthKey: '2026-11',
        createdAt: 1000,
        updatedAt: 2000,
        isDeleted: false,
      );
      const remoteDeleted = TaskItem(
        id: 't-del',
        title: '即将被远端删除的任务',
        dimension: PlanDimension.monthly,
        monthKey: '2026-11',
        createdAt: 1000,
        updatedAt: 3000,
        isDeleted: true,
      );

      const localDeletedSemester = SemesterPlan(
        id: 's-1',
        name: '2026秋季学期',
        startDate: '2026-09-01',
        endDate: '2027-01-15',
        createdAt: 1000,
        updatedAt: 5000,
        isDeleted: true,
      );
      const remoteStaleSemester = SemesterPlan(
        id: 's-1',
        name: '2026秋季学期',
        startDate: '2026-09-01',
        endDate: '2027-01-15',
        createdAt: 1000,
        updatedAt: 4000,
        isDeleted: false,
      );

      const localMilestone = Milestone(
        id: 'm-1',
        taskId: 'g-1',
        semesterId: 's-1',
        title: '期中答辩',
        isCompleted: false,
        createdAt: 1000,
        updatedAt: 2000,
      );
      const remoteMilestoneCompleted = Milestone(
        id: 'm-1',
        taskId: 'g-1',
        semesterId: 's-1',
        title: '期中答辩',
        isCompleted: true,
        createdAt: 1000,
        updatedAt: 2800,
      );

      final result = SyncMerger.mergePayloads(
        local: const SyncPayload(
          exportedAt: 5000,
          deviceId: 'win',
          tasks: <TaskItem>[localAlive],
          semesters: <SemesterPlan>[localDeletedSemester],
          milestones: <Milestone>[localMilestone],
        ),
        remote: const SyncPayload(
          exportedAt: 4000,
          deviceId: 'android',
          tasks: <TaskItem>[remoteDeleted],
          semesters: <SemesterPlan>[remoteStaleSemester],
          milestones: <Milestone>[remoteMilestoneCompleted],
        ),
        deviceId: 'win',
      );

      // 远端更新的软删除覆盖本地
      expect(result.mergedPayload.tasks.single.isDeleted, isTrue);
      expect(result.tasksToWriteLocal.single.isDeleted, isTrue);

      // 本地更新的软删除胜出，不会因远端旧数据而复活
      expect(result.mergedPayload.semesters.single.isDeleted, isTrue);
      expect(result.semestersToWriteLocal, isEmpty);

      // 远端里程碑勾选状态同步回本地
      expect(result.mergedPayload.milestones.single.isCompleted, isTrue);
      expect(result.milestonesToWriteLocal.single.isCompleted, isTrue);
    });

    test('SyncPayload JSON 序列化与反序列化保持完整一致', () {
      const original = SyncPayload(
        exportedAt: 1763888400000,
        deviceId: 'device-001',
        tasks: <TaskItem>[
          TaskItem(
            id: 't-1',
            title: '完成编译原理实验',
            notes: '注意词法分析器边界用例',
            dimension: PlanDimension.semester,
            dueDate: '2026-12-20',
            semesterId: 's-1',
            priority: TaskPriority.high,
            tags: <String>['学习', '项目'],
            isCompleted: false,
            createdAt: 1000,
            updatedAt: 2000,
          ),
        ],
        semesters: <SemesterPlan>[
          SemesterPlan(
            id: 's-1',
            name: '2026-2027 第一学期',
            description: '冲刺绩点与科研项目',
            startDate: '2026-09-01',
            endDate: '2027-01-20',
            colorValue: 0xFF3F51B5,
            createdAt: 900,
            updatedAt: 1500,
          ),
        ],
        milestones: <Milestone>[
          Milestone(
            id: 'm-1',
            taskId: 't-1',
            semesterId: 's-1',
            title: '完成词法分析模块',
            dueDate: '2026-11-30',
            isCompleted: true,
            sortOrder: 0,
            createdAt: 1000,
            updatedAt: 2200,
          ),
        ],
      );

      final encoded = original.toPrettyJsonString();
      final decoded = SyncPayload.fromJsonString(encoded);

      expect(decoded.tasks, original.tasks);
      expect(decoded.semesters, original.semesters);
      expect(decoded.milestones, original.milestones);
    });
  });

  group('AppDateUtils 日期工具测试', () {
    test('startOfWeek 正确返回所在周周一', () {
      // 2026-11-25 为周三
      final wed = DateTime(2026, 11, 25);
      final monday = AppDateUtils.startOfWeek(wed);
      expect(AppDateUtils.toIsoDate(monday), '2026-11-23');
      expect(monday.weekday, DateTime.monday);
    });

    test('monthCalendarGrid 返回完整的周一至周日网格（35 或 42 格）', () {
      final grid = AppDateUtils.monthCalendarGrid(2026, 11);
      expect(grid.length == 35 || grid.length == 42, isTrue);
      expect(grid.first.weekday, DateTime.monday);
      expect(grid.last.weekday, DateTime.sunday);
    });
  });
}
