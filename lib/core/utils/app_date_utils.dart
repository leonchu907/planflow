import 'package:intl/intl.dart';

/// 无时区偏移的日期处理工具类
///
/// 所有业务日期均以 ISO 格式 `YYYY-MM-DD` 存储与比较，避免跨平台或跨时区导致的日期错位。
class AppDateUtils {
  AppDateUtils._();

  static const List<String> weekdayShortLabels = <String>[
    '周一',
    '周二',
    '周三',
    '周四',
    '周五',
    '周六',
    '周日',
  ];

  /// 剥离时分秒，返回纯日期对象
  static DateTime dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// 获取今日纯日期
  static DateTime today() => dateOnly(DateTime.now());

  /// 格式化为 `YYYY-MM-DD`
  static String toIsoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// 格式化为 `YYYY-MM`
  static String toMonthKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$y-$m';
  }

  /// 解析 `YYYY-MM-DD` 为纯本地 DateTime，解析失败返回 null
  static DateTime? parseIsoDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  /// 获取所在周的周一日期
  static DateTime startOfWeek(DateTime date) {
    final clean = dateOnly(date);
    final diff = clean.weekday - DateTime.monday;
    return clean.subtract(Duration(days: diff));
  }

  /// 获取所在周的周一到周日 7 天列表
  static List<DateTime> daysOfWeek(DateTime anchor) {
    final monday = startOfWeek(anchor);
    return List<DateTime>.generate(
      7,
      (index) => monday.add(Duration(days: index)),
    );
  }

  /// 判断两个日期是否为同一天
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 获取月历网格所需的完整日期列表（周一为首列，42格或35格）
  static List<DateTime> monthCalendarGrid(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    final leadingDays = firstDay.weekday - DateTime.monday;
    final gridStart = firstDay.subtract(Duration(days: leadingDays));

    final lastDay = DateTime(year, month + 1, 0);
    final totalCellsNeeded = leadingDays + lastDay.day;
    final totalCells = totalCellsNeeded <= 35 ? 35 : 42;

    return List<DateTime>.generate(
      totalCells,
      (index) => gridStart.add(Duration(days: index)),
    );
  }

  /// 友好的中文日期展示，例如 `11月23日 周一` 或 `今天 · 11月23日`
  static String formatFriendlyDate(DateTime date) {
    final t = today();
    final wd = weekdayShortLabels[date.weekday - 1];
    final md = '${date.month}月${date.day}日';
    if (isSameDay(date, t)) {
      return '今天 · $md $wd';
    }
    if (isSameDay(date, t.add(const Duration(days: 1)))) {
      return '明天 · $md $wd';
    }
    if (isSameDay(date, t.subtract(const Duration(days: 1)))) {
      return '昨天 · $md $wd';
    }
    if (date.year != t.year) {
      return '${date.year}年$md $wd';
    }
    return '$md $wd';
  }

  /// 紧凑日期标签，例如 `11/23` 或 `今天`
  static String formatShortDueDate(String? isoDate) {
    final date = parseIsoDate(isoDate);
    if (date == null) return '无截止日期';
    final t = today();
    if (isSameDay(date, t)) return '今天';
    if (isSameDay(date, t.add(const Duration(days: 1)))) return '明天';
    if (isSameDay(date, t.subtract(const Duration(days: 1)))) return '昨天';
    if (date.year == t.year) {
      return '${date.month}/${date.day}';
    }
    return '${date.year}/${date.month}/${date.day}';
  }

  /// 判断截止日期是否已逾期（严格早于今日）
  static bool isOverdue(String? isoDate) {
    final date = parseIsoDate(isoDate);
    if (date == null) return false;
    return date.isBefore(today());
  }

  /// 格式化周范围，例如 `11月23日 - 11月29日`
  static String formatWeekRange(DateTime weekStart) {
    final monday = startOfWeek(weekStart);
    final sunday = monday.add(const Duration(days: 6));
    if (monday.year != sunday.year) {
      return '${monday.year}/${monday.month}/${monday.day} - ${sunday.year}/${sunday.month}/${sunday.day}';
    }
    return '${monday.month}月${monday.day}日 - ${sunday.month}月${sunday.day}日';
  }

  /// 格式化年月，例如 `2026年11月`
  static String formatYearMonth(int year, int month) {
    return '$year年$month月';
  }

  /// 格式化同步时间戳为 `HH:mm:ss` 或 `MM-dd HH:mm`
  static String formatSyncTime(int epochMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final now = DateTime.now();
    if (isSameDay(dt, now)) {
      return DateFormat('HH:mm:ss').format(dt);
    }
    return DateFormat('MM-dd HH:mm').format(dt);
  }
}
