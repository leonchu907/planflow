import 'dart:async';
import '../core/constants/app_constants.dart';
import '../data/local/plan_repository.dart';
import '../data/models/enums.dart';
import '../data/models/webdav_config.dart';
import 'secure_config_service.dart';
import 'sync_merger.dart';
import 'webdav_client.dart';

/// 单次同步执行结果
class SyncExecutionResult {
  const SyncExecutionResult({
    required this.success,
    required this.message,
    this.pulledCount = 0,
    this.pushedCount = 0,
    this.syncedAtMs,
  });

  final bool success;
  final String message;
  final int pulledCount;
  final int pushedCount;
  final int? syncedAtMs;
}

/// WebDAV 自动同步调度服务
///
/// 负责：
/// 1. 启动自动同步与本地变更 2 秒防抖（Debounce）静默同步；
/// 2. 并发互斥锁与挂起重试，确保同步期间的新编辑不会遗漏；
/// 3. 拉取 -> LWW 逐条合并 -> 本地事务写回 -> 远端全量覆盖上传。
class SyncService {
  SyncService({
    required PlanRepository repository,
    required SecureConfigService configService,
    WebDavClient? webDavClient,
  })  : _repository = repository,
        _configService = configService,
        _webDavClient = webDavClient ?? WebDavClient();

  final PlanRepository _repository;
  final SecureConfigService _configService;
  final WebDavClient _webDavClient;

  Timer? _debounceTimer;
  bool _isSyncing = false;
  bool _pendingFollowUpSync = false;

  /// 当云端合并写入本地新数据时回调（由上层触发 UI 刷新）
  Future<void> Function()? onLocalDataChanged;

  /// 同步状态变更回调
  void Function(SyncStatus status, String? message, int? syncedAtMs)?
      onStatusChanged;

  Future<WebDavTestResult> testConnection(WebDavConfig config) {
    return _webDavClient.testConnection(config);
  }

  /// 本地增删改后调用：防抖 2 秒后台静默同步
  void scheduleDebouncedSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(AppConstants.syncDebounceDuration, () {
      unawaited(syncNow(autoTriggered: true));
    });
  }

  /// 取消等待中的防抖同步
  void cancelPendingDebounce() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  /// 执行一次完整的双端 WebDAV 增量合并同步
  Future<SyncExecutionResult> syncNow({
    bool autoTriggered = false,
    WebDavConfig? overrideConfig,
  }) async {
    final config = overrideConfig ?? await _configService.loadWebDavConfig();

    if (!config.isConfigured) {
      if (!autoTriggered) {
        onStatusChanged?.call(SyncStatus.idle, '尚未配置 WebDAV 账号与密码', null);
      }
      return const SyncExecutionResult(
        success: false,
        message: '尚未配置 WebDAV 服务器账号与应用密码',
      );
    }

    if (autoTriggered && !config.autoSyncEnabled) {
      return const SyncExecutionResult(
        success: false,
        message: '已关闭自动同步',
      );
    }

    if (_isSyncing) {
      _pendingFollowUpSync = true;
      return const SyncExecutionResult(
        success: true,
        message: '正在同步中，新变更将在本次同步后自动续传',
      );
    }

    _isSyncing = true;
    onStatusChanged?.call(SyncStatus.syncing, '正在同步...', null);

    try {
      final deviceId = await _configService.getOrCreateDeviceId();

      // 1. 拉取远端 plan_sync.json（若为首次同步 404 则返回 null）
      final remotePayload = await _webDavClient.downloadSyncPayload(config);

      // 2. 读取本地全量数据（含 isDeleted == true 软删除记录）
      final localPayload = await _repository.buildFullPayload(deviceId);

      int pulledCount = 0;
      int pushedCount = 0;

      if (remotePayload == null) {
        // 首次同步：远端无文件，直接将本地全量上传
        pushedCount = localPayload.tasks.length +
            localPayload.semesters.length +
            localPayload.milestones.length;
        await _webDavClient.uploadSyncPayload(config, localPayload);
      } else {
        // 3. 逐条按 id + updatedAt 进行 LWW 增量合并
        final mergeResult = SyncMerger.mergePayloads(
          local: localPayload,
          remote: remotePayload,
          deviceId: deviceId,
        );
        pulledCount = mergeResult.pulledCount;
        pushedCount = mergeResult.pushedCount;

        // 4. 合并结果原子写回本地 SQLite
        if (mergeResult.hasLocalChanges) {
          await _repository.applyMergedRecords(
            tasksToWrite: mergeResult.tasksToWriteLocal,
            semestersToWrite: mergeResult.semestersToWriteLocal,
            milestonesToWrite: mergeResult.milestonesToWriteLocal,
          );
          await onLocalDataChanged?.call();
        }

        // 5. 将最新全量数据覆盖上传至 WebDAV
        await _webDavClient.uploadSyncPayload(
          config,
          mergeResult.mergedPayload,
        );
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await _configService.saveLastSyncAt(nowMs);

      final summary = (pulledCount == 0 && pushedCount == 0)
          ? '数据已是最新'
          : '同步完成：拉取 $pulledCount 条，推送 $pushedCount 条';
      onStatusChanged?.call(SyncStatus.synced, summary, nowMs);

      return SyncExecutionResult(
        success: true,
        message: summary,
        pulledCount: pulledCount,
        pushedCount: pushedCount,
        syncedAtMs: nowMs,
      );
    } on WebDavException catch (e) {
      onStatusChanged?.call(SyncStatus.error, e.message, null);
      return SyncExecutionResult(success: false, message: e.message);
    } catch (e) {
      final msg = '同步失败：$e';
      onStatusChanged?.call(SyncStatus.error, msg, null);
      return SyncExecutionResult(success: false, message: msg);
    } finally {
      _isSyncing = false;
      if (_pendingFollowUpSync) {
        _pendingFollowUpSync = false;
        scheduleDebouncedSync();
      }
    }
  }

  void dispose() {
    _debounceTimer?.cancel();
    _webDavClient.dispose();
  }
}
