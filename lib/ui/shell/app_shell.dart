import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_date_utils.dart';
import '../../data/models/enums.dart';
import '../../providers/plan_provider.dart';
import '../../providers/sync_provider.dart';
import '../../providers/theme_provider.dart';
import '../pages/daily_page.dart';
import '../pages/monthly_page.dart';
import '../pages/semester_page.dart';
import '../pages/settings_page.dart';
import '../pages/weekly_page.dart';
import '../widgets/search_filter_sheet.dart';
import '../widgets/sync_status_indicator.dart';
import '../widgets/task_editor_dialog.dart';

/// 双端自适应应用主壳
///
/// - Windows 宽屏（>= 840px）：左侧固定 NavigationRail + 顶部功能栏 + 全局快捷键（Ctrl+N/F/S/1~5）
/// - Android 窄屏（< 840px）：底部 NavigationBar + 悬浮新建按钮
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const List<({String label, IconData icon, IconData selectedIcon})>
      _destinations =
      <({String label, IconData icon, IconData selectedIcon})>[
    (
      label: '日计划',
      icon: Icons.today_outlined,
      selectedIcon: Icons.today_rounded,
    ),
    (
      label: '周计划',
      icon: Icons.view_week_outlined,
      selectedIcon: Icons.view_week_rounded,
    ),
    (
      label: '月计划',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month_rounded,
    ),
    (
      label: '学期计划',
      icon: Icons.school_outlined,
      selectedIcon: Icons.school_rounded,
    ),
    (
      label: '设置',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // 启动进入首页时静默触发一次 WebDAV 自动同步
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SyncProvider>().triggerStartupSync();
    });
  }

  void _openQuickCreateTask() {
    final provider = context.read<PlanProvider>();
    switch (_selectedIndex) {
      case 0:
        showTaskEditorDialog(
          context,
          initialDimension: PlanDimension.daily,
          initialDueDate: provider.selectedDailyDate,
        );
      case 1:
        showTaskEditorDialog(
          context,
          initialDimension: PlanDimension.weekly,
          initialWeekStart: provider.selectedWeekStart,
        );
      case 2:
        showTaskEditorDialog(
          context,
          initialDimension: PlanDimension.monthly,
          initialDueDate: provider.selectedMonthDate,
          initialMonthKey: AppDateUtils.toMonthKey(
            DateTime(provider.selectedMonthYear, provider.selectedMonth, 1),
          ),
        );
      case 3:
        showTaskEditorDialog(
          context,
          initialDimension: PlanDimension.semester,
          initialSemesterId: provider.activeSemester?.id,
        );
      default:
        showTaskEditorDialog(
          context,
          initialDimension: PlanDimension.daily,
          initialDueDate: AppDateUtils.today(),
        );
    }
  }

  Future<void> _triggerManualSync() async {
    final syncProvider = context.read<SyncProvider>();
    if (!syncProvider.isConfigured) {
      setState(() => _selectedIndex = 4);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在设置中配置 WebDAV 同步信息')),
      );
      return;
    }
    final result = await syncProvider.syncNow();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return const DailyPage();
      case 1:
        return const WeeklyPage();
      case 2:
        return const MonthlyPage();
      case 3:
        return const SemesterPage();
      case 4:
      default:
        return const SettingsPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppConstants.desktopBreakpoint;
    final isWideDesktop = width >= AppConstants.wideDesktopBreakpoint;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeProvider = context.watch<ThemeProvider>();

    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyN, control: true):
          _openQuickCreateTask,
      const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
          showGlobalSearchFilterDialog(context),
      const SingleActivator(LogicalKeyboardKey.keyS, control: true):
          _triggerManualSync,
      const SingleActivator(LogicalKeyboardKey.digit1, control: true): () =>
          setState(() => _selectedIndex = 0),
      const SingleActivator(LogicalKeyboardKey.digit2, control: true): () =>
          setState(() => _selectedIndex = 1),
      const SingleActivator(LogicalKeyboardKey.digit3, control: true): () =>
          setState(() => _selectedIndex = 2),
      const SingleActivator(LogicalKeyboardKey.digit4, control: true): () =>
          setState(() => _selectedIndex = 3),
      const SingleActivator(LogicalKeyboardKey.digit5, control: true): () =>
          setState(() => _selectedIndex = 4),
    };

    return CallbackShortcuts(
      bindings: shortcuts,
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            titleSpacing: isDesktop ? 20 : 16,
            title: Row(
              children: <Widget>[
                if (!isDesktop) ...<Widget>[
                  Icon(
                    Icons.event_available_rounded,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  _destinations[_selectedIndex].label,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              // 全局搜索与筛选入口
              if (isDesktop)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => showGlobalSearchFilterDialog(context),
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: const Text('搜索与筛选 (Ctrl+F)'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                )
              else
                IconButton(
                  tooltip: '全局搜索与筛选',
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () => showGlobalSearchFilterDialog(context),
                ),

              // 顶部栏轻量同步状态指示器
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: SyncStatusIndicator(
                  showLabel: isDesktop,
                  onOpenSettings: () => setState(() => _selectedIndex = 4),
                ),
              ),

              // 浅色/深色主题快速切换按钮
              IconButton(
                tooltip: theme.brightness == Brightness.dark
                    ? '切换到浅色模式'
                    : '切换到深色模式',
                icon: Icon(
                  theme.brightness == Brightness.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
                onPressed: () => themeProvider.toggleTheme(theme.brightness),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: isDesktop
              ? Row(
                  children: <Widget>[
                    NavigationRail(
                      selectedIndex: _selectedIndex,
                      extended: isWideDesktop,
                      minExtendedWidth: 210,
                      onDestinationSelected: (index) =>
                          setState(() => _selectedIndex = index),
                      leading: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: isWideDesktop ? 12 : 8,
                        ),
                        child: Column(
                          children: <Widget>[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.event_available_rounded,
                                    color: colorScheme.onPrimary,
                                    size: 22,
                                  ),
                                ),
                                if (isWideDesktop) ...<Widget>[
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        AppConstants.appName,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        AppConstants.appSubtitle,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (isWideDesktop)
                              SizedBox(
                                width: 176,
                                child: FilledButton.icon(
                                  onPressed: _openQuickCreateTask,
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('新建任务'),
                                ),
                              )
                            else
                              FloatingActionButton.small(
                                heroTag: 'rail_add_task',
                                tooltip: '新建任务 (Ctrl+N)',
                                onPressed: _openQuickCreateTask,
                                child: const Icon(Icons.add_rounded),
                              ),
                          ],
                        ),
                      ),
                      destinations: _destinations
                          .map(
                            (d) => NavigationRailDestination(
                              icon: Icon(d.icon),
                              selectedIcon: Icon(d.selectedIcon),
                              label: Text(d.label),
                            ),
                          )
                          .toList(),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: _buildCurrentPage()),
                  ],
                )
              : _buildCurrentPage(),
          bottomNavigationBar: isDesktop
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) =>
                      setState(() => _selectedIndex = index),
                  destinations: _destinations
                      .map(
                        (d) => NavigationDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: d.label,
                        ),
                      )
                      .toList(),
                ),
          floatingActionButton: (!isDesktop && _selectedIndex < 4)
              ? FloatingActionButton.extended(
                  onPressed: _openQuickCreateTask,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('新建'),
                )
              : null,
        ),
      ),
    );
  }
}
