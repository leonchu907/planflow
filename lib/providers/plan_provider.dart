import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/app_date_utils.dart';
import '../data/local/plan_repository.dart';
import '../data/models/enums.dart';
import '../data/models/milestone.dart';
import '../data/models/semester_plan.dart';
import '../data/models/task_item.dart';
import '../services/secure_config_service.dart';

/// 某日任务统计信息
class DayTaskSummary {
  const DayTaskSummary({
    required this.total,
    required this.completed,
    required this.hasHighPriorityPending,
  });

  final int total;
  final int completed;
  final bool hasHighPriorityPending;

  bool get isAllCompleted => total > 0 && completed == total;
  double get completionRate => total == 0 ? 0.0 : completed / total;
}

/// 学期总体完成进度统计
class SemesterProgressStats {
  const SemesterProgressStats({
    required this.overallProgress,
    required this.completedGoals,
    required this.totalGoals,
    required this.completedMilestones,
    required this.totalMilestones,
  });

  final double overallProgress;
  final int completedGoals;
  final int totalGoals;
  final int completedMilestones;
  final int totalMilestones;
}

/// 四维计划核心状态管理（Local-First 本地优先读写 + 变更自动触发防抖云同步）
class PlanProvider extends ChangeNotifier {
  PlanProvider({
    required PlanRepository repository,
    required SecureConfigService configService,
    Uuid? uuid,
  })  : _repository = repository,
        _configService = configService,
        _uuid = uuid ?? const Uuid();

  final PlanRepository _repository;
  final SecureConfigService _configService;
  final Uuid _uuid;

  /// 当任何本地数据发生增删改时回调（用于触发 2 秒防抖 WebDAV 同步）
  VoidCallback? onDataMutated;

  bool _isInitialized = false;
  List<TaskItem> _tasks = <TaskItem>[];
  List<SemesterPlan> _semesters = <SemesterPlan>[];
  List<Milestone> _milestones = <Milestone>[];

  // ===================== 各维度视图状态 =====================
  DateTime _selectedDailyDate = AppDateUtils.today();
  DailySortOrder _dailySortOrder = DailySortOrder.priority;

  DateTime _selectedWeekStart = AppDateUtils.startOfWeek(AppDateUtils.today());

  int _selectedMonthYear = AppDateUtils.today().year;
  int _selectedMonth = AppDateUtils.today().month;
  DateTime _selectedMonthDate = AppDateUtils.today();

  String? _activeSemesterId;

  // ===================== 全局搜索与多条件筛选 =====================
  String _searchQuery = '';
  final Set<String> _filterTags = <String>{};
  TaskPriority? _filterPriority;
  TaskCompletionFilter _filterCompletion = TaskCompletionFilter.all;
  PlanDimension? _filterDimension;

  // ===================== Getters =====================
  bool get isInitialized => _isInitialized;
  List<TaskItem> get tasks => List<TaskItem>.unmodifiable(_tasks);
  List<SemesterPlan> get semesters => List<SemesterPlan>.unmodifiable(_semesters);
  List<Milestone> get milestones => List<Milestone>.unmodifiable(_milestones);

  DateTime get selectedDailyDate => _selectedDailyDate;
  DailySortOrder get dailySortOrder => _dailySortOrder;
  DateTime get selectedWeekStart => _selectedWeekStart;
  int get selectedMonthYear => _selectedMonthYear;
  int get selectedMonth => _selectedMonth;
  DateTime get selectedMonthDate => _selectedMonthDate;

  String get searchQuery => _searchQuery;
  Set<String> get filterTags => Set<String>.unmodifiable(_filterTags);
  TaskPriority? get filterPriority => _filterPriority;
  TaskCompletionFilter get filterCompletion => _filterCompletion;
  PlanDimension? get filterDimension => _filterDimension;

  bool get hasActiveSearchOrFilter =>
      _searchQuery.trim().isNotEmpty ||
      _filterTags.isNotEmpty ||
      _filterPriority != null ||
      _filterCompletion != TaskCompletionFilter.all ||
      _filterDimension != null;

  /// 当前激活的学期
  SemesterPlan? get activeSemester {
    if (_semesters.isEmpty) return null;
    if (_activeSemesterId != null) {
      for (final semester in _semesters) {
        if (semester.id == _activeSemesterId) return semester;
      }
    }
    return _semesters.first;
  }

  /// 所有可用标签（预置标签 + 用户历史自定义标签去重合集）
  List<String> get allAvailableTags {
    final merged = <String>{...AppConstants.defaultTags};
    for (final task in _tasks) {
      for (final tag in task.tags) {
        final trimmed = tag.trim();
        if (trimmed.isNotEmpty) {
          merged.add(trimmed);
        }
      }
    }
    return merged.toList();
  }

  // ===================== 初始化与重新加载 =====================

  Future<void> initialize() async {
    _activeSemesterId = await _configService.loadActiveSemesterId();
    await reloadFromDatabase();
    _isInitialized = true;
    notifyListeners();
  }

  /// 从本地 SQLite 重新加载全量有效数据（启动与云端拉取合并后调用）
  Future<void> reloadFromDatabase() async {
    _tasks = await _repository.getActiveTasks();
    _semesters = await _repository.getActiveSemesters();
    _milestones = await _repository.getActiveMilestones();

    if (_semesters.isNotEmpty) {
      final stillExists = _semesters.any((s) => s.id == _activeSemesterId);
      if (!stillExists) {
        _activeSemesterId = _semesters.first.id;
        await _configService.saveActiveSemesterId(_activeSemesterId);
      }
    } else {
      _activeSemesterId = null;
    }
    notifyListeners();
  }

  void _notifyLocalMutation() {
    notifyListeners();
    onDataMutated?.call();
  }

  // ===================== 视图切换方法 =====================

  void setSelectedDailyDate(DateTime date) {
    _selectedDailyDate = AppDateUtils.dateOnly(date);
    notifyListeners();
  }

  void shiftDailyDate(int days) {
    setSelectedDailyDate(_selectedDailyDate.add(Duration(days: days)));
  }

  void setDailySortOrder(DailySortOrder order) {
    if (_dailySortOrder == order) return;
    _dailySortOrder = order;
    notifyListeners();
  }

  void setSelectedWeekAnchor(DateTime date) {
    _selectedWeekStart = AppDateUtils.startOfWeek(date);
    notifyListeners();
  }

  void shiftWeek(int weeks) {
    setSelectedWeekAnchor(_selectedWeekStart.add(Duration(days: weeks * 7)));
  }

  void setSelectedMonth(int year, int month) {
    final normalized = DateTime(year, month, 1);
    _selectedMonthYear = normalized.year;
    _selectedMonth = normalized.month;
    final today = AppDateUtils.today();
    if (today.year == normalized.year && today.month == normalized.month) {
      _selectedMonthDate = today;
    } else {
      _selectedMonthDate = normalized;
    }
    notifyListeners();
  }

  void shiftMonth(int deltaMonths) {
    setSelectedMonth(_selectedMonthYear, _selectedMonth + deltaMonths);
  }

  void setSelectedMonthDate(DateTime date) {
    final clean = AppDateUtils.dateOnly(date);
    _selectedMonthDate = clean;
    _selectedMonthYear = clean.year;
    _selectedMonth = clean.month;
    notifyListeners();
  }

  Future<void> selectSemester(String semesterId) async {
    if (_activeSemesterId == semesterId) return;
    _activeSemesterId = semesterId;
    notifyListeners();
    await _configService.saveActiveSemesterId(semesterId);
  }

  // ===================== 搜索与筛选操作 =====================

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  void toggleFilterTag(String tag) {
    if (_filterTags.contains(tag)) {
      _filterTags.remove(tag);
    } else {
      _filterTags.add(tag);
    }
    notifyListeners();
  }

  void setFilterPriority(TaskPriority? priority) {
    if (_filterPriority == priority) return;
    _filterPriority = priority;
    notifyListeners();
  }

  void setFilterCompletion(TaskCompletionFilter completion) {
    if (_filterCompletion == completion) return;
    _filterCompletion = completion;
    notifyListeners();
  }

  void setFilterDimension(PlanDimension? dimension) {
    if (_filterDimension == dimension) return;
    _filterDimension = dimension;
    notifyListeners();
  }

  void clearSearchAndFilters() {
    _searchQuery = '';
    _filterTags.clear();
    _filterPriority = null;
    _filterCompletion = TaskCompletionFilter.all;
    _filterDimension = null;
    notifyListeners();
  }

  /// 全局搜索与组合筛选结果（支持标题、备注、标签及下属里程碑关键词检索）
  List<TaskItem> get filteredGlobalTasks {
    final query = _searchQuery.trim().toLowerCase();
    final result = _tasks.where((task) {
      if (_filterDimension != null && task.dimension != _filterDimension) {
        return false;
      }
      if (_filterPriority != null && task.priority != _filterPriority) {
        return false;
      }
      if (_filterCompletion == TaskCompletionFilter.incomplete &&
          task.isCompleted) {
        return false;
      }
      if (_filterCompletion == TaskCompletionFilter.completed &&
          !task.isCompleted) {
        return false;
      }
      if (_filterTags.isNotEmpty) {
        final hasMatchedTag =
            task.tags.any((tag) => _filterTags.contains(tag));
        if (!hasMatchedTag) return false;
      }
      if (query.isNotEmpty) {
        final matchTitle = task.title.toLowerCase().contains(query);
        final matchNotes = task.notes.toLowerCase().contains(query);
        final matchTag =
            task.tags.any((t) => t.toLowerCase().contains(query));
        final matchMilestone = _milestones.any(
          (m) => m.taskId == task.id && m.title.toLowerCase().contains(query),
        );
        if (!matchTitle && !matchNotes && !matchTag && !matchMilestone) {
          return false;
        }
      }
      return true;
    }).toList();

    result.sort(_compareTasksByPriority);
    return result;
  }

  // ===================== 日计划查询与统计 =====================

  /// 查询某一天的所有待办任务（包含当日日任务、分配到当天的周/月/学期任务）
  List<TaskItem> tasksForDate(
    DateTime date, {
    DailySortOrder? sortOrder,
  }) {
    final iso = AppDateUtils.toIsoDate(date);
    final list = _tasks.where((t) => t.dueDate == iso).toList();
    final order = sortOrder ?? _dailySortOrder;
    list.sort((a, b) => _compareTasks(a, b, order));
    return list;
  }

  /// 获取某日完成率与统计
  DayTaskSummary daySummary(DateTime date) {
    final list = tasksForDate(date);
    var completed = 0;
    var hasHighPending = false;
    for (final task in list) {
      if (task.isCompleted) {
        completed++;
      } else if (task.priority == TaskPriority.high) {
        hasHighPending = true;
      }
    }
    return DayTaskSummary(
      total: list.length,
      completed: completed,
      hasHighPriorityPending: hasHighPending,
    );
  }

  // ===================== 周计划查询 =====================

  /// 获取指定周的核心目标列表（`dimension == weekly`）
  List<TaskItem> weeklyGoalsForWeek(DateTime weekAnchor) {
    final monday = AppDateUtils.startOfWeek(weekAnchor);
    final mondayIso = AppDateUtils.toIsoDate(monday);
    final sunday = monday.add(const Duration(days: 6));

    final list = _tasks.where((t) {
      if (t.dimension != PlanDimension.weekly) return false;
      if (t.weekStartDate == mondayIso) return true;
      if (t.weekStartDate == null && t.dueDate != null) {
        final due = AppDateUtils.parseIsoDate(t.dueDate);
        if (due != null && !due.isBefore(monday) && !due.isAfter(sunday)) {
          return true;
        }
      }
      return false;
    }).toList();

    list.sort(_compareTasksByPriority);
    return list;
  }

  /// 获取某周计划任务拆解出的子日任务
  List<TaskItem> subtasksOf(String parentTaskId) {
    final list =
        _tasks.where((t) => t.parentTaskId == parentTaskId).toList();
    list.sort((a, b) {
      final dateCmp = (a.dueDate ?? '').compareTo(b.dueDate ?? '');
      if (dateCmp != 0) return dateCmp;
      return a.createdAt.compareTo(b.createdAt);
    });
    return list;
  }

  // ===================== 月计划查询 =====================

  /// 获取指定年月的月度重点任务（`dimension == monthly`）
  List<TaskItem> monthlyKeyTasks(int year, int month) {
    final key = AppDateUtils.toMonthKey(DateTime(year, month, 1));
    final list = _tasks.where((t) {
      if (t.dimension != PlanDimension.monthly) return false;
      if (t.monthKey == key) return true;
      if (t.monthKey == null &&
          t.dueDate != null &&
          t.dueDate!.startsWith(key)) {
        return true;
      }
      return false;
    }).toList();

    list.sort(_compareTasksByPriority);
    return list;
  }

  /// 预计算月历网格中所有日期的任务数量与完成情况映射（键：`YYYY-MM-DD`）
  Map<String, DayTaskSummary> buildDaySummaryMapForDates(
    List<DateTime> dates,
  ) {
    final isoSet = dates.map(AppDateUtils.toIsoDate).toSet();
    final counts = <String, int>{};
    final doneCounts = <String, int>{};
    final highPending = <String, bool>{};

    for (final task in _tasks) {
      final due = task.dueDate;
      if (due == null || !isoSet.contains(due)) continue;
      counts[due] = (counts[due] ?? 0) + 1;
      if (task.isCompleted) {
        doneCounts[due] = (doneCounts[due] ?? 0) + 1;
      } else if (task.priority == TaskPriority.high) {
        highPending[due] = true;
      }
    }

    return <String, DayTaskSummary>{
      for (final iso in counts.keys)
        iso: DayTaskSummary(
          total: counts[iso] ?? 0,
          completed: doneCounts[iso] ?? 0,
          hasHighPriorityPending: highPending[iso] ?? false,
        ),
    };
  }

  // ===================== 学期与里程碑查询 =====================

  /// 获取指定学期的长期目标列表
  List<TaskItem> semesterGoals(String semesterId) {
    final list = _tasks
        .where(
          (t) =>
              t.dimension == PlanDimension.semester &&
              t.semesterId == semesterId,
        )
        .toList();
    list.sort(_compareTasksByPriority);
    return list;
  }

  /// 获取某学期目标下的全部有效里程碑
  List<Milestone> milestonesForTask(String taskId) {
    final list = _milestones.where((m) => m.taskId == taskId).toList();
    list.sort((a, b) {
      final orderCmp = a.sortOrder.compareTo(b.sortOrder);
      if (orderCmp != 0) return orderCmp;
      return a.createdAt.compareTo(b.createdAt);
    });
    return list;
  }

  /// 计算单个目标的完成百分比（优先依据里程碑勾选比例，无里程碑则按目标完成状态）
  double taskProgress(TaskItem task) {
    final ms = milestonesForTask(task.id);
    if (ms.isEmpty) {
      return task.isCompleted ? 1.0 : 0.0;
    }
    final completed = ms.where((m) => m.isCompleted).length;
    return completed / ms.length;
  }

  /// 计算整个学期的综合进度统计
  SemesterProgressStats semesterProgressStats(String semesterId) {
    final goals = semesterGoals(semesterId);
    if (goals.isEmpty) {
      return const SemesterProgressStats(
        overallProgress: 0.0,
        completedGoals: 0,
        totalGoals: 0,
        completedMilestones: 0,
        totalMilestones: 0,
      );
    }

    var progressSum = 0.0;
    var completedGoals = 0;
    var totalMilestones = 0;
    var completedMilestones = 0;

    for (final goal in goals) {
      final ms = milestonesForTask(goal.id);
      totalMilestones += ms.length;
      final doneMs = ms.where((m) => m.isCompleted).length;
      completedMilestones += doneMs;

      final p = ms.isEmpty ? (goal.isCompleted ? 1.0 : 0.0) : doneMs / ms.length;
      progressSum += p;
      if (goal.isCompleted || (ms.isNotEmpty && doneMs == ms.length)) {
        completedGoals++;
      }
    }

    return SemesterProgressStats(
      overallProgress: (progressSum / goals.length).clamp(0.0, 1.0),
      completedGoals: completedGoals,
      totalGoals: goals.length,
      completedMilestones: completedMilestones,
      totalMilestones: totalMilestones,
    );
  }

  // ===================== 任务 CRUD 与核心操作 =====================

  Future<TaskItem> createTask({
    required String title,
    String notes = '',
    required PlanDimension dimension,
    String? dueDate,
    String? weekStartDate,
    String? monthKey,
    String? semesterId,
    String? parentTaskId,
    TaskPriority priority = TaskPriority.medium,
    List<String> tags = const <String>[],
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final cleanTags = tags
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    // 根据维度补全归属键
    String? resolvedDueDate = dueDate;
    String? resolvedWeekStart = weekStartDate;
    String? resolvedMonthKey = monthKey;

    if (dimension == PlanDimension.daily && resolvedDueDate == null) {
      resolvedDueDate = AppDateUtils.toIsoDate(_selectedDailyDate);
    }
    if (dimension == PlanDimension.weekly && resolvedWeekStart == null) {
      final anchor = AppDateUtils.parseIsoDate(resolvedDueDate) ??
          _selectedWeekStart;
      resolvedWeekStart = AppDateUtils.toIsoDate(
        AppDateUtils.startOfWeek(anchor),
      );
    }
    if (dimension == PlanDimension.monthly && resolvedMonthKey == null) {
      final anchor = AppDateUtils.parseIsoDate(resolvedDueDate) ??
          DateTime(_selectedMonthYear, _selectedMonth, 1);
      resolvedMonthKey = AppDateUtils.toMonthKey(anchor);
    }

    final item = TaskItem(
      id: _uuid.v4(),
      title: title.trim(),
      notes: notes.trim(),
      dimension: dimension,
      dueDate: resolvedDueDate,
      weekStartDate: resolvedWeekStart,
      monthKey: resolvedMonthKey,
      semesterId: semesterId,
      parentTaskId: parentTaskId,
      priority: priority,
      tags: cleanTags,
      isCompleted: false,
      createdAt: nowMs,
      updatedAt: nowMs,
      isDeleted: false,
    );

    await _repository.upsertTask(item);
    _tasks.add(item);
    _notifyLocalMutation();
    return item;
  }

  Future<void> updateTask(TaskItem updated) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final cleanTags = updated.tags
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    final stamped = updated.copyWith(
      title: updated.title.trim(),
      notes: updated.notes.trim(),
      tags: cleanTags,
      updatedAt: nowMs,
    );

    await _repository.upsertTask(stamped);
    final idx = _tasks.indexWhere((t) => t.id == stamped.id);
    if (idx >= 0) {
      _tasks[idx] = stamped;
    } else {
      _tasks.add(stamped);
    }
    _notifyLocalMutation();
  }

  Future<void> toggleTaskCompleted(String taskId) async {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx < 0) return;

    final current = _tasks[idx];
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final nextDone = !current.isCompleted;
    final updated = current.copyWith(
      isCompleted: nextDone,
      completedAt: nextDone ? nowMs : null,
      updatedAt: nowMs,
    );

    await _repository.upsertTask(updated);
    _tasks[idx] = updated;
    _notifyLocalMutation();
  }

  /// 软删除任务（返回原任务以便移动端 SnackBar 提供撤销）
  Future<TaskItem?> deleteTask(String taskId) async {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx < 0) return null;

    final removed = _tasks[idx];
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _repository.softDeleteTask(taskId, nowMs);

    _tasks.removeAt(idx);
    _milestones.removeWhere((m) => m.taskId == taskId);
    _notifyLocalMutation();
    return removed;
  }

  /// 撤销刚删除的任务
  Future<void> restoreDeletedTask(TaskItem task) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final restored = task.copyWith(isDeleted: false, updatedAt: nowMs);
    await _repository.restoreTask(task, nowMs);
    _tasks.add(restored);
    _notifyLocalMutation();
  }

  /// 日计划「一键顺延」：将指定日期所有未完成任务的截止日期批量顺延至次日
  Future<int> postponeIncompleteTasks(DateTime sourceDate) async {
    final sourceIso = AppDateUtils.toIsoDate(sourceDate);
    final nextDate = AppDateUtils.dateOnly(sourceDate).add(
      const Duration(days: 1),
    );
    final nextIso = AppDateUtils.toIsoDate(nextDate);
    final nextWeekIso = AppDateUtils.toIsoDate(
      AppDateUtils.startOfWeek(nextDate),
    );
    final nextMonthKey = AppDateUtils.toMonthKey(nextDate);
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final updatedList = <TaskItem>[];
    for (var i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      if (task.dueDate == sourceIso && !task.isCompleted) {
        final nextTask = task.copyWith(
          dueDate: nextIso,
          weekStartDate: task.dimension == PlanDimension.weekly
              ? nextWeekIso
              : task.weekStartDate,
          monthKey: task.dimension == PlanDimension.monthly
              ? nextMonthKey
              : task.monthKey,
          updatedAt: nowMs,
        );
        _tasks[i] = nextTask;
        updatedList.add(nextTask);
      }
    }

    if (updatedList.isEmpty) return 0;

    await _repository.batchUpsertTasks(updatedList);
    _notifyLocalMutation();
    return updatedList.length;
  }

  /// 周计划 -> 直接分配到本周具体某一天（自动同步显示在对应日期的日计划中）
  Future<void> assignWeeklyTaskToDate(
    String taskId,
    DateTime targetDate,
  ) async {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx < 0) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final cleanDate = AppDateUtils.dateOnly(targetDate);
    final updated = _tasks[idx].copyWith(
      dueDate: AppDateUtils.toIsoDate(cleanDate),
      weekStartDate: AppDateUtils.toIsoDate(
        AppDateUtils.startOfWeek(cleanDate),
      ),
      updatedAt: nowMs,
    );

    await _repository.upsertTask(updated);
    _tasks[idx] = updated;
    _notifyLocalMutation();
  }

  /// 周计划 -> 取消具体日期分配（保留在本周目标池中）
  Future<void> unassignWeeklyTaskDate(String taskId) async {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx < 0) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final updated = _tasks[idx].copyWith(
      dueDate: null,
      updatedAt: nowMs,
    );

    await _repository.upsertTask(updated);
    _tasks[idx] = updated;
    _notifyLocalMutation();
  }

  /// 周计划 -> 拆解为具体某天的日计划子任务
  Future<TaskItem> breakdownWeeklyTaskToDay({
    required TaskItem weeklyTask,
    required String subtaskTitle,
    required DateTime targetDate,
    String notes = '',
    TaskPriority? priority,
  }) async {
    return createTask(
      title: subtaskTitle,
      notes: notes,
      dimension: PlanDimension.daily,
      dueDate: AppDateUtils.toIsoDate(targetDate),
      parentTaskId: weeklyTask.id,
      priority: priority ?? weeklyTask.priority,
      tags: List<String>.from(weeklyTask.tags),
    );
  }

  // ===================== 学期 CRUD =====================

  Future<SemesterPlan> createSemester({
    required String name,
    String description = '',
    required DateTime startDate,
    required DateTime endDate,
    int colorValue = 0xFF3F51B5,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final semester = SemesterPlan(
      id: _uuid.v4(),
      name: name.trim(),
      description: description.trim(),
      startDate: AppDateUtils.toIsoDate(startDate),
      endDate: AppDateUtils.toIsoDate(endDate),
      colorValue: colorValue,
      createdAt: nowMs,
      updatedAt: nowMs,
      isDeleted: false,
    );

    await _repository.upsertSemester(semester);
    _semesters.insert(0, semester);
    _activeSemesterId = semester.id;
    await _configService.saveActiveSemesterId(semester.id);
    _notifyLocalMutation();
    return semester;
  }

  Future<void> updateSemester(SemesterPlan semester) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final stamped = semester.copyWith(
      name: semester.name.trim(),
      description: semester.description.trim(),
      updatedAt: nowMs,
    );

    await _repository.upsertSemester(stamped);
    final idx = _semesters.indexWhere((s) => s.id == stamped.id);
    if (idx >= 0) {
      _semesters[idx] = stamped;
    } else {
      _semesters.add(stamped);
    }
    _notifyLocalMutation();
  }

  Future<void> deleteSemester(String semesterId) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _repository.softDeleteSemester(semesterId, nowMs);
    _semesters.removeWhere((s) => s.id == semesterId);
    _tasks.removeWhere((t) => t.semesterId == semesterId);
    _milestones.removeWhere((m) => m.semesterId == semesterId);

    if (_activeSemesterId == semesterId) {
      _activeSemesterId = _semesters.isNotEmpty ? _semesters.first.id : null;
      await _configService.saveActiveSemesterId(_activeSemesterId);
    }
    _notifyLocalMutation();
  }

  // ===================== 里程碑 CRUD =====================

  Future<Milestone> addMilestone({
    required String taskId,
    required String semesterId,
    required String title,
    String? dueDate,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final existing = milestonesForTask(taskId);
    final milestone = Milestone(
      id: _uuid.v4(),
      taskId: taskId,
      semesterId: semesterId,
      title: title.trim(),
      dueDate: dueDate,
      isCompleted: false,
      sortOrder: existing.length,
      createdAt: nowMs,
      updatedAt: nowMs,
      isDeleted: false,
    );

    await _repository.upsertMilestone(milestone);
    _milestones.add(milestone);
    await _syncGoalCompletionFromMilestones(taskId, nowMs);
    _notifyLocalMutation();
    return milestone;
  }

  Future<void> updateMilestone(Milestone milestone) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final stamped = milestone.copyWith(
      title: milestone.title.trim(),
      updatedAt: nowMs,
    );
    await _repository.upsertMilestone(stamped);
    final idx = _milestones.indexWhere((m) => m.id == stamped.id);
    if (idx >= 0) {
      _milestones[idx] = stamped;
    }
    _notifyLocalMutation();
  }

  Future<void> toggleMilestoneCompleted(String milestoneId) async {
    final idx = _milestones.indexWhere((m) => m.id == milestoneId);
    if (idx < 0) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final current = _milestones[idx];
    final updated = current.copyWith(
      isCompleted: !current.isCompleted,
      updatedAt: nowMs,
    );

    await _repository.upsertMilestone(updated);
    _milestones[idx] = updated;
    await _syncGoalCompletionFromMilestones(updated.taskId, nowMs);
    _notifyLocalMutation();
  }

  Future<void> deleteMilestone(String milestoneId) async {
    final idx = _milestones.indexWhere((m) => m.id == milestoneId);
    if (idx < 0) return;

    final taskId = _milestones[idx].taskId;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _repository.softDeleteMilestone(milestoneId, nowMs);
    _milestones.removeAt(idx);
    await _syncGoalCompletionFromMilestones(taskId, nowMs);
    _notifyLocalMutation();
  }

  /// 当里程碑全部勾选或取消勾选时，自动同步所属学期目标的完成状态
  Future<void> _syncGoalCompletionFromMilestones(
    String taskId,
    int nowMs,
  ) async {
    final taskIdx = _tasks.indexWhere((t) => t.id == taskId);
    if (taskIdx < 0) return;
    final taskMilestones = milestonesForTask(taskId);
    if (taskMilestones.isEmpty) return;

    final allDone = taskMilestones.every((m) => m.isCompleted);
    final current = _tasks[taskIdx];
    if (current.isCompleted != allDone) {
      final updatedGoal = current.copyWith(
        isCompleted: allDone,
        completedAt: allDone ? nowMs : null,
        updatedAt: nowMs,
      );
      await _repository.upsertTask(updatedGoal);
      _tasks[taskIdx] = updatedGoal;
    }
  }

  // ===================== 排序工具 =====================

  int _compareTasks(TaskItem a, TaskItem b, DailySortOrder order) {
    // 未完成任务优先展示
    if (a.isCompleted != b.isCompleted) {
      return a.isCompleted ? 1 : -1;
    }
    switch (order) {
      case DailySortOrder.priority:
        final pCmp = b.priority.weight.compareTo(a.priority.weight);
        if (pCmp != 0) return pCmp;
        return a.createdAt.compareTo(b.createdAt);
      case DailySortOrder.createdAt:
        return b.createdAt.compareTo(a.createdAt);
      case DailySortOrder.title:
        return a.title.compareTo(b.title);
    }
  }

  int _compareTasksByPriority(TaskItem a, TaskItem b) {
    return _compareTasks(a, b, DailySortOrder.priority);
  }
}
