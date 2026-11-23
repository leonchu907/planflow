/// 计划时间维度：日 / 周 / 月 / 学期
enum PlanDimension {
  daily('daily', '日计划', '日'),
  weekly('weekly', '周计划', '周'),
  monthly('monthly', '月计划', '月'),
  semester('semester', '学期计划', '学期');

  const PlanDimension(this.dbValue, this.label, this.shortLabel);

  final String dbValue;
  final String label;
  final String shortLabel;

  static PlanDimension fromDbValue(String? raw) {
    for (final value in PlanDimension.values) {
      if (value.dbValue == raw) return value;
    }
    return PlanDimension.daily;
  }
}

/// 任务优先级（高 / 中 / 低）
enum TaskPriority {
  low(0, '低'),
  medium(1, '中'),
  high(2, '高');

  const TaskPriority(this.weight, this.label);

  final int weight;
  final String label;

  static TaskPriority fromWeight(int? raw) {
    switch (raw) {
      case 2:
        return TaskPriority.high;
      case 1:
        return TaskPriority.medium;
      case 0:
      default:
        return TaskPriority.low;
    }
  }
}

/// 云同步状态
enum SyncStatus {
  idle('未同步'),
  syncing('同步中'),
  synced('已同步'),
  error('同步失败');

  const SyncStatus(this.label);

  final String label;
}

/// 完成状态筛选枚举
enum TaskCompletionFilter {
  all('全部'),
  incomplete('未完成'),
  completed('已完成');

  const TaskCompletionFilter(this.label);

  final String label;
}

/// 日计划排序方式
enum DailySortOrder {
  priority('按优先级'),
  createdAt('按创建时间'),
  title('按标题');

  const DailySortOrder(this.label);

  final String label;
}
