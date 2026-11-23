const Object _unset = Object();

/// 学期目标里程碑实体（勾选后自动驱动学期目标与整体完成百分比更新）
class Milestone {
  const Milestone({
    required this.id,
    required this.taskId,
    required this.semesterId,
    required this.title,
    this.dueDate,
    this.isCompleted = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  /// 全局唯一 UUID
  final String id;

  /// 所属学期目标 TaskItem.id
  final String taskId;

  /// 所属学期 SemesterPlan.id
  final String semesterId;

  /// 里程碑标题
  final String title;

  /// 可选节点日期（YYYY-MM-DD）
  final String? dueDate;

  /// 完成状态
  final bool isCompleted;

  /// 显示排序序号
  final int sortOrder;

  /// 创建时间戳（UTC 毫秒）
  final int createdAt;

  /// 更新时间戳（UTC 毫秒，LWW 依据）
  final int updatedAt;

  /// 软删除标记
  final bool isDeleted;

  Milestone copyWith({
    String? id,
    String? taskId,
    String? semesterId,
    String? title,
    Object? dueDate = _unset,
    bool? isCompleted,
    int? sortOrder,
    int? createdAt,
    int? updatedAt,
    bool? isDeleted,
  }) {
    return Milestone(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      semesterId: semesterId ?? this.semesterId,
      title: title ?? this.title,
      dueDate: identical(dueDate, _unset) ? this.dueDate : dueDate as String?,
      isCompleted: isCompleted ?? this.isCompleted,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, Object?> toSqlMap() {
    return <String, Object?>{
      'id': id,
      'task_id': taskId,
      'semester_id': semesterId,
      'title': title,
      'due_date': dueDate,
      'is_completed': isCompleted ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory Milestone.fromSqlMap(Map<String, Object?> map) {
    return Milestone(
      id: map['id'] as String,
      taskId: (map['task_id'] as String?) ?? '',
      semesterId: (map['semester_id'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      dueDate: map['due_date'] as String?,
      isCompleted: (map['is_completed'] as int? ?? 0) == 1,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      createdAt: (map['created_at'] as int?) ?? 0,
      updatedAt: (map['updated_at'] as int?) ?? 0,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'taskId': taskId,
      'semesterId': semesterId,
      'title': title,
      'dueDate': dueDate,
      'isCompleted': isCompleted,
      'sortOrder': sortOrder,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isDeleted': isDeleted,
    };
  }

  factory Milestone.fromJson(Map<String, dynamic> json) {
    return Milestone(
      id: json['id'] as String,
      taskId: (json['taskId'] as String?) ?? '',
      semesterId: (json['semesterId'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      dueDate: json['dueDate'] as String?,
      isCompleted: (json['isCompleted'] as bool?) ?? false,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
      isDeleted: (json['isDeleted'] as bool?) ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Milestone) return false;
    return id == other.id &&
        taskId == other.taskId &&
        semesterId == other.semesterId &&
        title == other.title &&
        dueDate == other.dueDate &&
        isCompleted == other.isCompleted &&
        sortOrder == other.sortOrder &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt &&
        isDeleted == other.isDeleted;
  }

  @override
  int get hashCode => Object.hash(
        id,
        taskId,
        semesterId,
        title,
        dueDate,
        isCompleted,
        sortOrder,
        createdAt,
        updatedAt,
        isDeleted,
      );
}
