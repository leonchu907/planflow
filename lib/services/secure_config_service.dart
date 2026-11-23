import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/app_constants.dart';
import '../data/models/webdav_config.dart';

/// 应用配置与安全凭据存储服务
///
/// - 敏感凭据（WebDAV 账号、应用密码）：使用 `flutter_secure_storage` 加密存储
///   （Android 使用 Keystore / EncryptedSharedPreferences，Windows 使用系统 Credential Manager）。
/// - 常规偏好（主题、选中学期、服务器地址、上次同步时间）：使用 `SharedPreferences`。
class SecureConfigService {
  SecureConfigService({
    FlutterSecureStorage? secureStorage,
    Uuid? uuid,
  })  : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            ),
        _uuid = uuid ?? const Uuid();

  final FlutterSecureStorage _secureStorage;
  final Uuid _uuid;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// 获取或初始化本机唯一设备 ID
  Future<String> getOrCreateDeviceId() async {
    final prefs = await _prefs;
    final existing = prefs.getString(AppConstants.prefDeviceId);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final generated = _uuid.v4();
    await prefs.setString(AppConstants.prefDeviceId, generated);
    return generated;
  }

  /// 读取 WebDAV 完整配置
  Future<WebDavConfig> loadWebDavConfig() async {
    final prefs = await _prefs;
    final serverUrl = prefs.getString(AppConstants.prefWebDavServerUrl) ??
        AppConstants.defaultWebDavUrl;
    final remoteDir = prefs.getString(AppConstants.prefWebDavRemoteDir) ??
        AppConstants.defaultRemoteDir;
    final autoSyncEnabled =
        prefs.getBool(AppConstants.prefAutoSyncEnabled) ?? true;

    String username = '';
    String password = '';
    try {
      username =
          await _secureStorage.read(key: AppConstants.secureWebDavUsername) ??
              '';
      password =
          await _secureStorage.read(key: AppConstants.secureWebDavPassword) ??
              '';
    } catch (_) {
      // 若系统安全存储因重装或 Keystore 异常无法解密，安全回退为空避免应用崩溃
      username = '';
      password = '';
    }

    return WebDavConfig(
      serverUrl: serverUrl,
      remoteDir: remoteDir,
      username: username,
      password: password,
      autoSyncEnabled: autoSyncEnabled,
    );
  }

  /// 保存 WebDAV 完整配置
  Future<void> saveWebDavConfig(WebDavConfig config) async {
    final prefs = await _prefs;
    await prefs.setString(
      AppConstants.prefWebDavServerUrl,
      config.serverUrl.trim(),
    );
    await prefs.setString(
      AppConstants.prefWebDavRemoteDir,
      config.remoteDir.trim(),
    );
    await prefs.setBool(
      AppConstants.prefAutoSyncEnabled,
      config.autoSyncEnabled,
    );

    await _secureStorage.write(
      key: AppConstants.secureWebDavUsername,
      value: config.username.trim(),
    );
    await _secureStorage.write(
      key: AppConstants.secureWebDavPassword,
      value: config.password,
    );
  }

  /// 清除已保存的 WebDAV 敏感凭据
  Future<void> clearWebDavCredentials() async {
    await _secureStorage.delete(key: AppConstants.secureWebDavUsername);
    await _secureStorage.delete(key: AppConstants.secureWebDavPassword);
  }

  /// 读取上次成功同步时间戳（毫秒）
  Future<int?> loadLastSyncAt() async {
    final prefs = await _prefs;
    return prefs.getInt(AppConstants.prefLastSyncAt);
  }

  /// 保存上次成功同步时间戳（毫秒）
  Future<void> saveLastSyncAt(int epochMs) async {
    final prefs = await _prefs;
    await prefs.setInt(AppConstants.prefLastSyncAt, epochMs);
  }

  /// 读取主题模式
  Future<ThemeMode> loadThemeMode() async {
    final prefs = await _prefs;
    final raw = prefs.getString(AppConstants.prefThemeMode);
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  /// 保存主题模式
  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await _prefs;
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(AppConstants.prefThemeMode, value);
  }

  /// 读取当前选中学期 ID
  Future<String?> loadActiveSemesterId() async {
    final prefs = await _prefs;
    return prefs.getString(AppConstants.prefActiveSemesterId);
  }

  /// 保存当前选中学期 ID
  Future<void> saveActiveSemesterId(String? semesterId) async {
    final prefs = await _prefs;
    if (semesterId == null || semesterId.isEmpty) {
      await prefs.remove(AppConstants.prefActiveSemesterId);
    } else {
      await prefs.setString(AppConstants.prefActiveSemesterId, semesterId);
    }
  }
}
