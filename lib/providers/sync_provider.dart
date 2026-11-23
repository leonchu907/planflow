import 'package:flutter/foundation.dart';
import '../data/models/enums.dart';
import '../data/models/sync_payload.dart';
import '../data/models/webdav_config.dart';
import '../services/backup_service.dart';
import '../services/secure_config_service.dart';
import '../services/sync_service.dart';
import '../services/webdav_client.dart';

/// 云同步与本地备份状态管理
class SyncProvider extends ChangeNotifier {
  SyncProvider({
    required SyncService syncService,
    required SecureConfigService configService,
    required BackupService backupService,
  })  : _syncService = syncService,
        _configService = configService,
        _backupService = backupService {
    _syncService.onStatusChanged = _handleStatusChanged;
  }

  final SyncService _syncService;
  final SecureConfigService _configService;
  final BackupService _backupService;

  WebDavConfig _config = const WebDavConfig();
  SyncStatus _status = SyncStatus.idle;
  String? _statusMessage;
  int? _lastSyncAtMs;
  bool _isTestingConnection = false;
  bool _isBackupBusy = false;

  /// 当云端同步或本地导入刷新了数据库后回调（用于通知 PlanProvider 重新加载）
  Future<void> Function()? onDatabaseRefreshed;

  WebDavConfig get config => _config;
  SyncStatus get status => _status;
  String? get statusMessage => _statusMessage;
  int? get lastSyncAtMs => _lastSyncAtMs;
  bool get isTestingConnection => _isTestingConnection;
  bool get isBackupBusy => _isBackupBusy;
  bool get isConfigured => _config.isConfigured;

  Future<void> initialize() async {
    _syncService.onLocalDataChanged = () async {
      await onDatabaseRefreshed?.call();
    };
    _config = await _configService.loadWebDavConfig();
    _lastSyncAtMs = await _configService.loadLastSyncAt();
    if (_config.isConfigured && _lastSyncAtMs != null) {
      _status = SyncStatus.synced;
      _statusMessage = '已连接 WebDAV';
    } else {
      _status = SyncStatus.idle;
      _statusMessage = _config.isConfigured ? '等待首次同步' : '未配置云同步';
    }
    notifyListeners();
  }

  void _handleStatusChanged(
    SyncStatus status,
    String? message,
    int? syncedAtMs,
  ) {
    _status = status;
    _statusMessage = message;
    if (syncedAtMs != null) {
      _lastSyncAtMs = syncedAtMs;
    }
    notifyListeners();
  }

  /// 保存 WebDAV 配置
  Future<void> saveConfig(WebDavConfig newConfig) async {
    _config = newConfig;
    await _configService.saveWebDavConfig(newConfig);
    if (!newConfig.isConfigured) {
      _status = SyncStatus.idle;
      _statusMessage = '未配置云同步';
    }
    notifyListeners();
  }

  /// 切换自动同步开关
  Future<void> setAutoSyncEnabled(bool enabled) async {
    await saveConfig(_config.copyWith(autoSyncEnabled: enabled));
  }

  /// 清除已保存的 WebDAV 账号与密码
  Future<void> clearCredentials() async {
    await _configService.clearWebDavCredentials();
    _config = _config.copyWith(username: '', password: '');
    _status = SyncStatus.idle;
    _statusMessage = '已清除同步凭据';
    notifyListeners();
  }

  /// 测试 WebDAV 连接
  Future<WebDavTestResult> testConnection(WebDavConfig candidate) async {
    _isTestingConnection = true;
    notifyListeners();
    try {
      return await _syncService.testConnection(candidate);
    } finally {
      _isTestingConnection = false;
      notifyListeners();
    }
  }

  /// 立即执行同步
  Future<SyncExecutionResult> syncNow({WebDavConfig? overrideConfig}) async {
    if (overrideConfig != null) {
      await saveConfig(overrideConfig);
    }
    return _syncService.syncNow(
      autoTriggered: false,
      overrideConfig: overrideConfig ?? _config,
    );
  }

  /// App 启动进入首页时静默自动同步
  Future<void> triggerStartupSync() async {
    if (!_config.isConfigured || !_config.autoSyncEnabled) return;
    await _syncService.syncNow(autoTriggered: true, overrideConfig: _config);
  }

  /// 本地数据变更后触发 2 秒防抖静默同步
  void scheduleDebouncedSync() {
    if (!_config.isConfigured || !_config.autoSyncEnabled) return;
    _syncService.scheduleDebouncedSync();
  }

  /// 导出全量 JSON 备份
  Future<BackupResult> exportBackup() async {
    _isBackupBusy = true;
    notifyListeners();
    try {
      return await _backupService.exportToJsonFile();
    } finally {
      _isBackupBusy = false;
      notifyListeners();
    }
  }

  /// 选择并解析本地 JSON 备份文件
  Future<PickedBackupFile?> pickBackupFile() async {
    return _backupService.pickAndParseBackupFile();
  }

  /// 导入备份载荷并刷新内存状态
  Future<BackupResult> importBackup(
    SyncPayload payload, {
    required bool mergeMode,
  }) async {
    _isBackupBusy = true;
    notifyListeners();
    try {
      final result = await _backupService.importPayload(
        payload,
        mergeMode: mergeMode,
      );
      if (result.success) {
        await onDatabaseRefreshed?.call();
        scheduleDebouncedSync();
      }
      return result;
    } finally {
      _isBackupBusy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _syncService.dispose();
    super.dispose();
  }
}
