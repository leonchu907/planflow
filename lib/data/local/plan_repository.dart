import 'package:sqflite/sqflite.dart';
import '../models/milestone.dart';
import '../models/semester_plan.dart';
import '../models/sync_payload.dart';
import '../models/task_item.dart';
import 'app_database.dart';

/// 本地优先（Local-First）数据仓库
///
/// 封装所有 SQLite 读写操作；删除一律使用软删除（`is_deleted = 1` + 刷新 `updated_at`）。
class PlanRepository {
  PlanRepository({AppDatabase? database})
      : _appDatabase = database ?? AppDatabase.instance;

  final AppDatabase _appDatabase;

  Future<Database> get _db => _appDatabase.database;

  // ===================== 读取操作 =====================

  Future<List<TaskItem>> getActiveTasks() async {
    final db = await _db;
    final rows = await db.query(
      'tasks',
      where: 'is_deleted = 0',
      orderBy: 'priority DESC, created_at ASC',
    );
    return rows.map(TaskItem.fromSqlMap).toList();
  }

  Future<List<TaskItem>> getAllTasksIncludingDeleted() async {
    final db = await _db;
    final rows = await db.query('tasks');
    return rows.map(TaskItem.fromSqlMap).toList();
  }

  Future<List<SemesterPlan>> getActiveSemesters() async {
    final db = await _db;
    final rows = await db.query(
      'semesters',
      where: 'is_deleted = 0',
      orderBy: 'start_date DESC, created_at DESC',
    );
    return rows.map(SemesterPlan.fromSqlMap).toList();
  }

  Future<List<SemesterPlan>> getAllSemestersIncludingDeleted() async {
    final db = await _db;
    final rows = await db.query('semesters');
    return rows.map(SemesterPlan.fromSqlMap).toList();
  }

  Future<List<Milestone>> getActiveMilestones() async {
    final db = await _db;
    final rows = await db.query(
      'milestones',
      where: 'is_deleted = 0',
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return rows.map(Milestone.fromSqlMap).toList();
  }

  Future<List<Milestone>> getAllMilestonesIncludingDeleted() async {
    final db = await _db;
    final rows = await db.query('milestones');
    return rows.map(Milestone.fromSqlMap).toList();
  }

  // ===================== 任务写入与软删除 =====================

  Future<void> upsertTask(TaskItem task) async {
    final db = await _db;
    await db.insert(
      'tasks',
      task.toSqlMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> batchUpsertTasks(List<TaskItem> tasks) async {
    if (tasks.isEmpty) return;
    final db = await _db;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final task in tasks) {
        batch.insert(
          'tasks',
          task.toSqlMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> softDeleteTask(String taskId, int nowMs) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update(
        'tasks',
        <String, Object?>{
          'is_deleted': 1,
          'updated_at': nowMs,
        },
        where: 'id = ?',
        whereArgs: <Object?>[taskId],
      );
      // 同步软删除该任务下属的里程碑（若存在）
      await txn.update(
        'milestones',
        <String, Object?>{
          'is_deleted': 1,
          'updated_at': nowMs,
        },
        where: 'task_id = ? AND is_deleted = 0',
        whereArgs: <Object?>[taskId],
      );
    });
  }

  /// 撤销软删除（如移动端左滑删除后的撤销操作）
  Future<void> restoreTask(TaskItem task, int nowMs) async {
    final restored = task.copyWith(isDeleted: false, updatedAt: nowMs);
    await upsertTask(restored);
  }

  // ===================== 学期写入与软删除 =====================

  Future<void> upsertSemester(SemesterPlan semester) async {
    final db = await _db;
    await db.insert(
      'semesters',
      semester.toSqlMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> softDeleteSemester(String semesterId, int nowMs) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update(
        'semesters',
        <String, Object?>{
          'is_deleted': 1,
          'updated_at': nowMs,
        },
        where: 'id = ?',
        whereArgs: <Object?>[semesterId],
      );
      await txn.update(
        'tasks',
        <String, Object?>{
          'is_deleted': 1,
          'updated_at': nowMs,
        },
        where: 'semester_id = ? AND is_deleted = 0',
        whereArgs: <Object?>[semesterId],
      );
      await txn.update(
        'milestones',
        <String, Object?>{
          'is_deleted': 1,
          'updated_at': nowMs,
        },
        where: 'semester_id = ? AND is_deleted = 0',
        whereArgs: <Object?>[semesterId],
      );
    });
  }

  // ===================== 里程碑写入与软删除 =====================

  Future<void> upsertMilestone(Milestone milestone) async {
    final db = await _db;
    await db.insert(
      'milestones',
      milestone.toSqlMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> softDeleteMilestone(String milestoneId, int nowMs) async {
    final db = await _db;
    await db.update(
      'milestones',
      <String, Object?>{
        'is_deleted': 1,
        'updated_at': nowMs,
      },
      where: 'id = ?',
      whereArgs: <Object?>[milestoneId],
    );
  }

  // ===================== 同步与备份原子操作 =====================

  /// 导出包含软删除标记的全量同步快照
  Future<SyncPayload> buildFullPayload(String deviceId) async {
    final tasks = await getAllTasksIncludingDeleted();
    final semesters = await getAllSemestersIncludingDeleted();
    final milestones = await getAllMilestonesIncludingDeleted();
    return SyncPayload(
      exportedAt: DateTime.now().millisecondsSinceEpoch,
      deviceId: deviceId,
      tasks: tasks,
      semesters: semesters,
      milestones: milestones,
    );
  }

  /// 将增量合并结果在单个事务内原子写回本地 SQLite
  Future<void> applyMergedRecords({
    required List<TaskItem> tasksToWrite,
    required List<SemesterPlan> semestersToWrite,
    required List<Milestone> milestonesToWrite,
  }) async {
    if (tasksToWrite.isEmpty &&
        semestersToWrite.isEmpty &&
        milestonesToWrite.isEmpty) {
      return;
    }
    final db = await _db;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final semester in semestersToWrite) {
        batch.insert(
          'semesters',
          semester.toSqlMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final task in tasksToWrite) {
        batch.insert(
          'tasks',
          task.toSqlMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final milestone in milestonesToWrite) {
        batch.insert(
          'milestones',
          milestone.toSqlMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// 覆盖模式导入备份（清空三表后写入备份数据）
  Future<void> replaceAllWithPayload(SyncPayload payload) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('milestones');
      await txn.delete('tasks');
      await txn.delete('semesters');
      final batch = txn.batch();
      for (final semester in payload.semesters) {
        batch.insert(
          'semesters',
          semester.toSqlMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final task in payload.tasks) {
        batch.insert(
          'tasks',
          task.toSqlMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final milestone in payload.milestones) {
        batch.insert(
          'milestones',
          milestone.toSqlMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }
}
