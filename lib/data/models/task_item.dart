import 'dart:convert';
import 'enums.dart';

const Object _unset = Object();

/// 核心任务实体（支持日/周/月/学期四维管理与 LWW 软删除同步）
class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    this.notes = '',
    required this.dimension,
    this.dueDate,
    this.weekStartDate,
    this.monthKey,
    this.semesterId,
    this.parentTaskId,
    this.priority = TaskPriority.medium,
    this.tags = const <String>[],
    this.isCompleted = false,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  /// 全局唯一 UUID
  final String id;

  /// 任务标题
  final String title;

  /// 详细备注
  final String notes;

  /// 所属时间维度
  final PlanDimension dimension;

  /// 截止日期 / 计划执行日期（ISO 格式 YYYY-MM-DD）
  final String? dueDate;

  /// 所属周的周一日期（ISO 格式 YYYY-MM-DD，用于周计划归属）
  final String? weekStartDate;

  /// 所属月份键（YYYY-MM，用于月度重点任务归属）
  final String? monthKey;

  /// 所属学期 ID（用于学期目标归属）
  final String? semesterId;

  /// 来源父任务 ID（用于周计划拆解到日计划的关联溯源）
  final String? parentTaskId;

  /// 优先级（高/中/低）
  final TaskPriority priority;

  /// 自定义标签列表
  final List<String> tags;

  /// 完成状态
  final bool isCompleted;

  /// 完成时间戳（毫秒）
  final int? completedAt;

  /// 创建时间戳（UTC 毫秒）
  final int createdAt;

  /// 最后更新时间戳（UTC 毫秒，多端 LWW 合并依据）
  final int updatedAt;

  /// 软删除标记（true 表示已删除，防止多端同步复活）
  final bool isDeleted;

  TaskItem copyWith({
    String? id,
    String? title,
    String? notes,
    PlanDimension? dimension,
    Object? dueDate = _unset,
    Object? weekStartDate = _unset,
    Object? monthKey = _unset,
    Object? semesterId = _unset,
    Object? parentTaskId = _unset,
    TaskPriority? priority,
    List<String>? tags,
    bool? isCompleted,
    Object? completedAt = _unset,
    int? createdAt,
    int? updatedAt,
    bool? isDeleted,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      dimension: dimension ?? this.dimension,
      dueDate: identical(dueDate, _unset) ? this.dueDate : dueDate as String?,
      weekStartDate: identical(weekStartDate, _unset)
          ? this.weekStartDate
          : weekStartDate as String?,
      monthKey:
          identical(monthKey, _unset) ? this.monthKey : monthKey as String?,
      semesterId: identical(semesterId, _unset)
          ? this.semesterId
          : semesterId as String?,
      parentTaskId: identical(parentTaskId, _unset)
          ? this.parentTaskId
          : parentTaskId as String?,
      priority: priority ?? this.priority,
      tags: tags ?? this.tags,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: identical(completedAt, _unset)
          ? this.completedAt
          : completedAt as int?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  /// 转为 SQLite 行映射
  Map<String, Object?> toSqlMap() {
    return <String, Object?>{
      'id': id,
      'title': title,
      'notes': notes,
      'dimension': dimension.dbValue,
      'due_date': dueDate,
      'week_start_date': weekStartDate,
      'month_key': monthKey,
      'semester_id': semesterId,
      'parent_task_id': parentTaskId,
      'priority': priority.weight,
      'tags_json': jsonEncode(tags),
      'is_completed': isCompleted ? 1 : 0,
      'completed_at': completedAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  /// 从 SQLite 行还原
  factory TaskItem.fromSqlMap(Map<String, Object?> map) {
    final rawTags = map['tags_json'] as String?;
    List<String> parsedTags = const <String>[];
    if (rawTags != null && rawTags.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTags);
        if (decoded is List<dynamic>) {
          parsedTags = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        parsedTags = const <String>[];
      }
    }

    return TaskItem(
      id: map['id'] as String,
      title: (map['title'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      dimension: PlanDimension.fromDbValue(map['dimension'] as String?),
      dueDate: map['due_date'] as String?,
      weekStartDate: map['week_start_date'] as String?,
      monthKey: map['month_key'] as String?,
      semesterId: map['semester_id'] as String?,
      parentTaskId: map['parent_task_id'] as String?,
      priority: TaskPriority.fromWeight(map['priority'] as int?),
      tags: parsedTags,
      isCompleted: (map['is_completed'] as int? ?? 0) == 1,
      completedAt: map['completed_at'] as int?,
      createdAt: (map['created_at'] as int?) ?? 0,
      updatedAt: (map['updated_at'] as int?) ?? 0,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
    );
  }

  /// 转为 WebDAV / 本地备份 JSON
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'notes': notes,
      'dimension': dimension.dbValue,
      'dueDate': dueDate,
      'weekStartDate': weekStartDate,
      'monthKey': monthKey,
      'semesterId': semesterId,
      'parentTaskId': parentTaskId,
      'priority': priority.weight,
      'tags': tags,
      'isCompleted': isCompleted,
      'completedAt': completedAt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isDeleted': isDeleted,
    };
  }

  /// 从 JSON 还原
  factory TaskItem.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    final parsedTags = rawTags is List<dynamic>
        ? rawTags.map((e) => e.toString()).toList()
        : const <String>[];

    return TaskItem(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      notes: (json['notes'] as String?) ?? '',
      dimension: PlanDimension.fromDbValue(json['dimension'] as String?),
      dueDate: json['dueDate'] as String?,
      weekStartDate: json['weekStartDate'] as String?,
      monthKey: json['monthKey'] as String?,
      semesterId: json['semesterId'] as String?,
      parentTaskId: json['parentTaskId'] as String?,
      priority: TaskPriority.fromWeight((json['priority'] as num?)?.toInt()),
      tags: parsedTags,
      isCompleted: (json['isCompleted'] as bool?) ?? false,
      completedAt: (json['completedAt'] as num?)?.toInt(),
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
      isDeleted: (json['isDeleted'] as bool?) ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TaskItem) return false;
    return id == other.id &&
        title == other.title &&
        notes == other.notes &&
        dimension == other.dimension &&
        dueDate == other.dueDate &&
        weekStartDate == other.weekStartDate &&
        monthKey == other.monthKey &&
        semesterId == other.semesterId &&
        parentTaskId == other.parentTaskId &&
        priority == other.priority &&
        _listEquals(tags, other.tags) &&
        isCompleted == other.isCompleted &&
        completedAt == other.completedAt &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt &&
        isDeleted == other.isDeleted;
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        notes,
        dimension,
        dueDate,
        weekStartDate,
        monthKey,
        semesterId,
        parentTaskId,
        priority,
        Object.hashAll(tags),
        isCompleted,
        completedAt,
        createdAt,
        updatedAt,
        isDeleted,
      );

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
