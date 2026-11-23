import 'package:flutter/material.dart';
import '../services/secure_config_service.dart';

/// 主题状态管理（支持浅色 / 深色 / 跟随系统无缝切换并本地持久化）
class ThemeProvider extends ChangeNotifier {
  ThemeProvider({required SecureConfigService configService})
      : _configService = configService;

  final SecureConfigService _configService;

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  Future<void> initialize() async {
    _themeMode = await _configService.loadThemeMode();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _configService.saveThemeMode(mode);
  }

  /// 一键在浅色与深色间切换
  Future<void> toggleTheme(Brightness currentBrightness) async {
    final nextMode = currentBrightness == Brightness.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    await setThemeMode(nextMode);
  }
}
