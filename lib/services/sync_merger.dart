import '../data/models/milestone.dart';
import '../data/models/semester_plan.dart';
import '../data/models/sync_payload.dart';
import '../data/models/task_item.dart';

/// 增量合并结果统计与待写回本地的数据集
class SyncMergeResult {
  const SyncMergeResult({
    required this.mergedPayload,
    required this.tasksToWriteLocal,
    required this.semestersToWriteLocal,
    required this.milestonesToWriteLocal,
    required this.pulledCount,
    required this.pushedCount,
  });

  /// 合并后的最新全量数据（用于覆盖上传至 WebDAV）
  final SyncPayload mergedPayload;

  /// 需要写回本地数据库的增量任务
  final List<TaskItem> tasksToWriteLocal;

  /// 需要写回本地数据库的增量学期
  final List<SemesterPlan> semestersToWriteLocal;

  /// 需要写回本地数据库的增量里程碑
  final List<Milestone> milestonesToWriteLocal;

  /// 从远端合并到本地的记录条数
  final int pulledCount;

  /// 本地较新或独有、需要同步到远端的记录条数
  final int pushedCount;

  bool get hasLocalChanges =>
      tasksToWriteLocal.isNotEmpty ||
      semestersToWriteLocal.isNotEmpty ||
      milestonesToWriteLocal.isNotEmpty;
}

class _CollectionMergeOutcome<T> {
  const _CollectionMergeOutcome({
    required this.merged,
    required this.toWriteLocal,
    required this.pulledCount,
    required this.pushedCount,
  });

  final List<T> merged;
  final List<T> toWriteLocal;
  final int pulledCount;
  final int pushedCount;
}

/// 纯函数 LWW（Last-Write-Wins）增量合并引擎
///
/// 合并规则：
/// 1. 仅存在于单端的记录，自动补充到另一端；
/// 2. 两端均存在的同 `id` 记录，严格保留 `updatedAt` 更大（更新）的一方（包含 `isDeleted` 软删除态）；
/// 3. 若极少数情况下毫秒级 `updatedAt` 完全相同但内容不同，优先保留 `isDeleted == true` 以防已删数据复活。
class SyncMerger {
  SyncMerger._();

  static SyncMergeResult mergePayloads({
    required SyncPayload local,
    required SyncPayload remote,
    required String deviceId,
    int? exportedAtMs,
  }) {
    final tasksOutcome = _mergeCollection<TaskItem>(
      localItems: local.tasks,
      remoteItems: remote.tasks,
      getId: (item) => item.id,
      getUpdatedAt: (item) => item.updatedAt,
      getIsDeleted: (item) => item.isDeleted,
    );

    final semestersOutcome = _mergeCollection<SemesterPlan>(
      localItems: local.semesters,
      remoteItems: remote.semesters,
      getId: (item) => item.id,
      getUpdatedAt: (item) => item.updatedAt,
      getIsDeleted: (item) => item.isDeleted,
    );

    final milestonesOutcome = _mergeCollection<Milestone>(
      localItems: local.milestones,
      remoteItems: remote.milestones,
      getId: (item) => item.id,
      getUpdatedAt: (item) => item.updatedAt,
      getIsDeleted: (item) => item.isDeleted,
    );

    final mergedPayload = SyncPayload(
      exportedAt: exportedAtMs ?? DateTime.now().millisecondsSinceEpoch,
      deviceId: deviceId,
      tasks: tasksOutcome.merged,
      semesters: semestersOutcome.merged,
      milestones: milestonesOutcome.merged,
    );

    return SyncMergeResult(
      mergedPayload: mergedPayload,
      tasksToWriteLocal: tasksOutcome.toWriteLocal,
      semestersToWriteLocal: semestersOutcome.toWriteLocal,
      milestonesToWriteLocal: milestonesOutcome.toWriteLocal,
      pulledCount: tasksOutcome.pulledCount +
          semestersOutcome.pulledCount +
          milestonesOutcome.pulledCount,
      pushedCount: tasksOutcome.pushedCount +
          semestersOutcome.pushedCount +
          milestonesOutcome.pushedCount,
    );
  }

  static _CollectionMergeOutcome<T> _mergeCollection<T>({
    required List<T> localItems,
    required List<T> remoteItems,
    required String Function(T) getId,
    required int Function(T) getUpdatedAt,
    required bool Function(T) getIsDeleted,
  }) {
    final localMap = <String, T>{
      for (final item in localItems) getId(item): item,
    };
    final remoteMap = <String, T>{
      for (final item in remoteItems) getId(item): item,
    };

    final allIds = <String>{...localMap.keys, ...remoteMap.keys};
    final merged = <T>[];
    final toWriteLocal = <T>[];
    var pulledCount = 0;
    var pushedCount = 0;

    for (final id in allIds) {
      final localItem = localMap[id];
      final remoteItem = remoteMap[id];

      if (localItem != null && remoteItem == null) {
        // 仅存在于本地 -> 保留并推送到远端
        merged.add(localItem);
        pushedCount++;
      } else if (localItem == null && remoteItem != null) {
        // 仅存在于远端 -> 写入本地并保留在全量快照中
        merged.add(remoteItem);
        toWriteLocal.add(remoteItem);
        pulledCount++;
      } else if (localItem != null && remoteItem != null) {
        final localTs = getUpdatedAt(localItem);
        final remoteTs = getUpdatedAt(remoteItem);

        if (remoteTs > localTs) {
          // 远端更新 -> 覆盖本地（含 isDeleted 软删除状态）
          merged.add(remoteItem);
          toWriteLocal.add(remoteItem);
          pulledCount++;
        } else if (localTs > remoteTs) {
          // 本地更新 -> 覆盖远端（含 isDeleted 软删除状态）
          merged.add(localItem);
          pushedCount++;
        } else {
          // 时间戳完全相等时的确定性裁决
          if (localItem == remoteItem) {
            merged.add(localItem);
          } else if (getIsDeleted(remoteItem) && !getIsDeleted(localItem)) {
            merged.add(remoteItem);
            toWriteLocal.add(remoteItem);
            pulledCount++;
          } else {
            merged.add(localItem);
            pushedCount++;
          }
        }
      }
    }

    return _CollectionMergeOutcome<T>(
      merged: merged,
      toWriteLocal: toWriteLocal,
      pulledCount: pulledCount,
      pushedCount: pushedCount,
    );
  }
}
