import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../data/models/enums.dart';
import '../../providers/sync_provider.dart';

/// 顶部栏轻量云同步状态指示器（同步中 / 已同步 / 同步失败或离线 / 未配置）
class SyncStatusIndicator extends StatefulWidget {
  const SyncStatusIndicator({
    super.key,
    required this.onOpenSettings,
    this.showLabel = false,
  });

  final VoidCallback onOpenSettings;
  final bool showLabel;

  @override
  State<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends State<SyncStatusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  void _syncAnimation(SyncStatus status) {
    if (status == SyncStatus.syncing) {
      if (!_spinController.isAnimating) {
        _spinController.repeat();
      }
    } else {
      if (_spinController.isAnimating) {
        _spinController.stop();
        _spinController.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncProvider = context.watch<SyncProvider>();
    final status = syncProvider.status;
    _syncAnimation(status);

    final colorScheme = Theme.of(context).colorScheme;
    final color = AppTheme.syncStatusColor(status, colorScheme);

    final IconData iconData = switch (status) {
      SyncStatus.idle => syncProvider.isConfigured
          ? Icons.cloud_queue_outlined
          : Icons.cloud_off_outlined,
      SyncStatus.syncing => Icons.sync,
      SyncStatus.synced => Icons.cloud_done_outlined,
      SyncStatus.error => Icons.cloud_off_rounded,
    };

    final String shortLabel = switch (status) {
      SyncStatus.idle => syncProvider.isConfigured ? '待同步' : '未配置',
      SyncStatus.syncing => '同步中',
      SyncStatus.synced => '已同步',
      SyncStatus.error => '同步异常',
    };

    final String tooltipText = _buildTooltip(syncProvider);

    Widget iconWidget = Icon(iconData, size: 20, color: color);
    if (status == SyncStatus.syncing) {
      iconWidget = RotationTransition(
        turns: _spinController,
        child: iconWidget,
      );
    }

    return Tooltip(
      message: tooltipText,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _handleTap(context, syncProvider),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.showLabel ? 10 : 8,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: color.withAlpha(24),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withAlpha(70)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              iconWidget,
              if (widget.showLabel) ...<Widget>[
                const SizedBox(width: 6),
                Text(
                  shortLabel,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _buildTooltip(SyncProvider syncProvider) {
    if (!syncProvider.isConfigured) {
      return '未配置 WebDAV 云同步，点击前往设置';
    }
    final lastMs = syncProvider.lastSyncAtMs;
    final lastText = lastMs != null
        ? '上次同步：${AppDateUtils.formatSyncTime(lastMs)}'
        : '尚未同步';
    final detail = syncProvider.statusMessage;
    return switch (syncProvider.status) {
      SyncStatus.syncing => '正在与 WebDAV 双向同步...',
      SyncStatus.synced => '$lastText（点击立即同步）',
      SyncStatus.error => '${detail ?? "同步失败或离线"}（点击重试）',
      SyncStatus.idle => '$lastText（点击立即同步）',
    };
  }

  Future<void> _handleTap(
    BuildContext context,
    SyncProvider syncProvider,
  ) async {
    if (!syncProvider.isConfigured) {
      widget.onOpenSettings();
      return;
    }
    if (syncProvider.status == SyncStatus.syncing) return;

    final result = await syncProvider.syncNow();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
