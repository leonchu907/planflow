import 'package:flutter/material.dart';
import '../../data/models/enums.dart';

/// Material Design 3 应用主题与优先级语义色板
class AppTheme {
  AppTheme._();

  static const Color _seedColor = Color(0xFF2B6CB0);

  static ThemeData lightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );
    return _buildTheme(colorScheme);
  }

  static ThemeData darkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    );
    return _buildTheme(colorScheme);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark
          ? colorScheme.surface
          : colorScheme.surfaceContainerLowest,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: isDark
            ? colorScheme.surface
            : colorScheme.surfaceContainerLowest,
        foregroundColor: colorScheme.onSurface,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        indicatorColor: colorScheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: colorScheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        indicatorColor: colorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withAlpha(140),
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// 获取优先级前景色（高：玫瑰红，中：琥珀橙，低：青绿）
  static Color priorityColor(TaskPriority priority, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    switch (priority) {
      case TaskPriority.high:
        return isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
      case TaskPriority.medium:
        return isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
      case TaskPriority.low:
        return isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488);
    }
  }

  /// 获取优先级浅色背景
  static Color priorityContainerColor(
    TaskPriority priority,
    Brightness brightness,
  ) {
    final color = priorityColor(priority, brightness);
    return color.withAlpha(brightness == Brightness.dark ? 45 : 28);
  }

  /// 同步状态颜色
  static Color syncStatusColor(SyncStatus status, ColorScheme scheme) {
    switch (status) {
      case SyncStatus.idle:
        return scheme.onSurfaceVariant;
      case SyncStatus.syncing:
        return scheme.primary;
      case SyncStatus.synced:
        return scheme.brightness == Brightness.dark
            ? const Color(0xFF4ADE80)
            : const Color(0xFF16A34A);
      case SyncStatus.error:
        return scheme.error;
    }
  }
}
