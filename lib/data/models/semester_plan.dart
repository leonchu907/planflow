import '../../core/utils/app_date_utils.dart';

/// 学期计划实体（支持多学期创建、编辑、切换与软删除同步）
class SemesterPlan {
  const SemesterPlan({
    required this.id,
    required this.name,
    this.description = '',
    required this.startDate,
    required this.endDate,
    this.colorValue = 0xFF3F51B5,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  /// 全局唯一 UUID
  final String id;

  /// 学期名称（如 "2026-2027 学年第一学期"）
  final String name;

  /// 学期长期目标描述
  final String description;

  /// 开始日期（ISO 格式 YYYY-MM-DD）
  final String startDate;

  /// 结束日期（ISO 格式 YYYY-MM-DD）
  final String endDate;

  /// 学期主题色（ARGB 整型）
  final int colorValue;

  /// 创建时间戳（UTC 毫秒）
  final int createdAt;

  /// 更新时间戳（UTC 毫秒，LWW 依据）
  final int updatedAt;

  /// 软删除标记
  final bool isDeleted;

  /// 学期总天数
  int get totalDays {
    final start = AppDateUtils.parseIsoDate(startDate);
    final end = AppDateUtils.parseIsoDate(endDate);
    if (start == null || end == null) return 0;
    final diff = end.difference(start).inDays + 1;
    return diff > 0 ? diff : 1;
  }

  /// 距离学期结束剩余天数（已结束则返回 0）
  int get remainingDays {
    final end = AppDateUtils.parseIsoDate(endDate);
    if (end == null) return 0;
    final diff = end.difference(AppDateUtils.today()).inDays;
    return diff > 0 ? diff : 0;
  }

  /// 学期时间消耗进度（0.0 ~ 1.0）
  double get timeProgress {
    final start = AppDateUtils.parseIsoDate(startDate);
    final end = AppDateUtils.parseIsoDate(endDate);
    if (start == null || end == null) return 0.0;
    final today = AppDateUtils.today();
    if (today.isBefore(start)) return 0.0;
    if (!today.isBefore(end)) return 1.0;
    final elapsed = today.difference(start).inDays;
    final total = totalDays;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  SemesterPlan copyWith({
    String? id,
    String? name,
    String? description,
    String? startDate,
    String? endDate,
    int? colorValue,
    int? createdAt,
    int? updatedAt,
    bool? isDeleted,
  }) {
    return SemesterPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, Object?> toSqlMap() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'description': description,
      'start_date': startDate,
      'end_date': endDate,
      'color_value': colorValue,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory SemesterPlan.fromSqlMap(Map<String, Object?> map) {
    return SemesterPlan(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      startDate: (map['start_date'] as String?) ?? '',
      endDate: (map['end_date'] as String?) ?? '',
      colorValue: (map['color_value'] as int?) ?? 0xFF3F51B5,
      createdAt: (map['created_at'] as int?) ?? 0,
      updatedAt: (map['updated_at'] as int?) ?? 0,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'startDate': startDate,
      'endDate': endDate,
      'colorValue': colorValue,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isDeleted': isDeleted,
    };
  }

  factory SemesterPlan.fromJson(Map<String, dynamic> json) {
    return SemesterPlan(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      startDate: (json['startDate'] as String?) ?? '',
      endDate: (json['endDate'] as String?) ?? '',
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF3F51B5,
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
      isDeleted: (json['isDeleted'] as bool?) ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SemesterPlan) return false;
    return id == other.id &&
        name == other.name &&
        description == other.description &&
        startDate == other.startDate &&
        endDate == other.endDate &&
        colorValue == other.colorValue &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt &&
        isDeleted == other.isDeleted;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        description,
        startDate,
        endDate,
        colorValue,
        createdAt,
        updatedAt,
        isDeleted,
      );
}
