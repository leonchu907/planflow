import 'dart:convert';
import '../../core/constants/app_constants.dart';
import 'milestone.dart';
import 'semester_plan.dart';
import 'task_item.dart';

/// WebDAV 云同步（plan_sync.json）与本地 JSON 备份共享的全量载荷结构
class SyncPayload {
  const SyncPayload({
    this.schemaVersion = AppConstants.syncSchemaVersion,
    required this.exportedAt,
    required this.deviceId,
    required this.tasks,
    required this.semesters,
    required this.milestones,
  });

  final int schemaVersion;
  final int exportedAt;
  final String deviceId;
  final List<TaskItem> tasks;
  final List<SemesterPlan> semesters;
  final List<Milestone> milestones;

  factory SyncPayload.empty({required String deviceId}) {
    return SyncPayload(
      exportedAt: DateTime.now().millisecondsSinceEpoch,
      deviceId: deviceId,
      tasks: const <TaskItem>[],
      semesters: const <SemesterPlan>[],
      milestones: const <Milestone>[],
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'exportedAt': exportedAt,
      'deviceId': deviceId,
      'tasks': tasks.map((e) => e.toJson()).toList(),
      'semesters': semesters.map((e) => e.toJson()).toList(),
      'milestones': milestones.map((e) => e.toJson()).toList(),
    };
  }

  String toPrettyJsonString() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  factory SyncPayload.fromJson(Map<String, dynamic> json) {
    final rawTasks = json['tasks'];
    final rawSemesters = json['semesters'];
    final rawMilestones = json['milestones'];

    if (rawTasks != null && rawTasks is! List<dynamic>) {
      throw const FormatException('同步文件格式错误：tasks 必须为数组');
    }
    if (rawSemesters != null && rawSemesters is! List<dynamic>) {
      throw const FormatException('同步文件格式错误：semesters 必须为数组');
    }
    if (rawMilestones != null && rawMilestones is! List<dynamic>) {
      throw const FormatException('同步文件格式错误：milestones 必须为数组');
    }

    return SyncPayload(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      exportedAt: (json['exportedAt'] as num?)?.toInt() ?? 0,
      deviceId: (json['deviceId'] as String?) ?? 'unknown',
      tasks: (rawTasks as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(TaskItem.fromJson)
          .toList(),
      semesters: (rawSemesters as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(SemesterPlan.fromJson)
          .toList(),
      milestones: (rawMilestones as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(Milestone.fromJson)
          .toList(),
    );
  }

  factory SyncPayload.fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('JSON 根节点必须为对象');
    }
    return SyncPayload.fromJson(decoded);
  }
}
