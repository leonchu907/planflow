import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../data/local/plan_repository.dart';
import '../data/models/sync_payload.dart';
import 'secure_config_service.dart';
import 'sync_merger.dart';

/// 选中待导入的备份文件解析结果
class PickedBackupFile {
  const PickedBackupFile({
    required this.fileName,
    required this.payload,
  });

  final String fileName;
  final SyncPayload payload;

  int get activeTaskCount => payload.tasks.where((t) => !t.isDeleted).length;
  int get activeSemesterCount =>
      payload.semesters.where((s) => !s.isDeleted).length;
  int get activeMilestoneCount =>
      payload.milestones.where((m) => !m.isDeleted).length;
}

/// 本地备份导出/导入操作反馈
class BackupResult {
  const BackupResult({
    required this.success,
    required this.message,
    this.cancelled = false,
  });

  final bool success;
  final String message;
  final bool cancelled;
}

/// 本地全量 JSON 备份导出与导入服务（兼容 Windows 桌面文件对话框与 Android SAF）
class BackupService {
  BackupService({
    required PlanRepository repository,
    required SecureConfigService configService,
  })  : _repository = repository,
        _configService = configService;

  final PlanRepository _repository;
  final SecureConfigService _configService;

  /// 导出全量 JSON 备份到本地文件
  Future<BackupResult> exportToJsonFile() async {
    try {
      final deviceId = await _configService.getOrCreateDeviceId();
      final payload = await _repository.buildFullPayload(deviceId);
      final jsonText = payload.toPrettyJsonString();
      final bytes = Uint8List.fromList(utf8.encode(jsonText));

      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final suggestedName = 'planflow_backup_$stamp.json';

      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: '导出 PlanFlow 全量备份',
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: const <String>['json'],
        bytes: bytes,
      );

      if (savedPath == null) {
        return const BackupResult(
          success: false,
          cancelled: true,
          message: '已取消导出',
        );
      }

      // Windows / Linux / macOS 桌面端 saveFile 仅返回用户选中的目标路径，需要手动写入字节
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        final outputFile = File(savedPath);
        await outputFile.writeAsBytes(bytes, flush: true);
      }

      final activeTasks = payload.tasks.where((t) => !t.isDeleted).length;
      final activeSemesters =
          payload.semesters.where((s) => !s.isDeleted).length;
      final activeMilestones =
          payload.milestones.where((m) => !m.isDeleted).length;

      return BackupResult(
        success: true,
        message:
            '导出成功：$activeTasks 条任务、$activeSemesters 个学期、$activeMilestones 个里程碑',
      );
    } catch (e) {
      return BackupResult(success: false, message: '导出失败：$e');
    }
  }

  /// 选择并解析本地 JSON 备份文件
  Future<PickedBackupFile?> pickAndParseBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择 PlanFlow JSON 备份文件',
      type: FileType.custom,
      allowedExtensions: const <String>['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.single;
    String rawContent;
    if (file.bytes != null) {
      rawContent = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      rawContent = await File(file.path!).readAsString(encoding: utf8);
    } else {
      throw const FormatException('无法读取所选文件内容');
    }

    final payload = SyncPayload.fromJsonString(rawContent);
    return PickedBackupFile(
      fileName: file.name,
      payload: payload,
    );
  }

  /// 执行导入：`mergeMode == true` 采用 LWW 增量合并，`false` 则覆盖本地数据库
  Future<BackupResult> importPayload(
    SyncPayload backupPayload, {
    required bool mergeMode,
  }) async {
    try {
      if (mergeMode) {
        final deviceId = await _configService.getOrCreateDeviceId();
        final localPayload = await _repository.buildFullPayload(deviceId);
        final mergeResult = SyncMerger.mergePayloads(
          local: localPayload,
          remote: backupPayload,
          deviceId: deviceId,
        );
        await _repository.applyMergedRecords(
          tasksToWrite: mergeResult.tasksToWriteLocal,
          semestersToWrite: mergeResult.semestersToWriteLocal,
          milestonesToWrite: mergeResult.milestonesToWriteLocal,
        );
        return BackupResult(
          success: true,
          message: '增量合并导入成功，更新本地 ${mergeResult.pulledCount} 条记录',
        );
      } else {
        await _repository.replaceAllWithPayload(backupPayload);
        final taskCount =
            backupPayload.tasks.where((t) => !t.isDeleted).length;
        return BackupResult(
          success: true,
          message: '覆盖导入成功，共载入 $taskCount 条有效任务',
        );
      }
    } catch (e) {
      return BackupResult(success: false, message: '导入失败：$e');
    }
  }
}
