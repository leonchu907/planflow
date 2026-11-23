import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_date_utils.dart';
import '../../data/models/enums.dart';
import '../../data/models/webdav_config.dart';
import '../../providers/plan_provider.dart';
import '../../providers/sync_provider.dart';
import '../../providers/theme_provider.dart';

/// 设置页面（浅色/深色主题切换、WebDAV 双端自动云同步配置与测试、全量 JSON 本地备份兜底）
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _serverUrlController;
  late final TextEditingController _remoteDirController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  bool _obscurePassword = true;
  bool _autoSyncEnabled = true;
  String? _testFeedback;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    final cfg = context.read<SyncProvider>().config;
    _serverUrlController = TextEditingController(text: cfg.serverUrl);
    _remoteDirController = TextEditingController(text: cfg.remoteDir);
    _usernameController = TextEditingController(text: cfg.username);
    _passwordController = TextEditingController(text: cfg.password);
    _autoSyncEnabled = cfg.autoSyncEnabled;
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _remoteDirController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  WebDavConfig _buildConfigFromForm() {
    return WebDavConfig(
      serverUrl: _serverUrlController.text.trim(),
      remoteDir: _remoteDirController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      autoSyncEnabled: _autoSyncEnabled,
    );
  }

  Future<void> _saveWebDavConfig() async {
    if (!_formKey.currentState!.validate()) return;
    final syncProvider = context.read<SyncProvider>();
    await syncProvider.saveConfig(_buildConfigFromForm());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('WebDAV 同步配置已加密保存')),
    );
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    final syncProvider = context.read<SyncProvider>();
    final candidate = _buildConfigFromForm();
    final result = await syncProvider.testConnection(candidate);
    if (!mounted) return;
    setState(() {
      _testSuccess = result.success;
      _testFeedback = result.message;
    });
  }

  Future<void> _syncNow() async {
    if (!_formKey.currentState!.validate()) return;
    final syncProvider = context.read<SyncProvider>();
    final candidate = _buildConfigFromForm();
    final result = await syncProvider.syncNow(overrideConfig: candidate);
    if (!mounted) return;
    setState(() {
      _testSuccess = result.success;
      _testFeedback = result.message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  Future<void> _clearCredentials() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清除同步凭据'),
        content: const Text('确定清除本机安全存储中的 WebDAV 账号与应用密码吗？本地任务数据不会被删除。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认清除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await context.read<SyncProvider>().clearCredentials();
    if (!mounted) return;
    setState(() {
      _usernameController.clear();
      _passwordController.clear();
      _testFeedback = null;
      _testSuccess = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已清除已保存的 WebDAV 账号与密码')),
    );
  }

  Future<void> _handleExportBackup() async {
    final syncProvider = context.read<SyncProvider>();
    final result = await syncProvider.exportBackup();
    if (!mounted || result.cancelled) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  Future<void> _handleImportBackup() async {
    final syncProvider = context.read<SyncProvider>();
    try {
      final picked = await syncProvider.pickBackupFile();
      if (picked == null || !mounted) return;

      var mergeMode = true;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
                title: const Text('确认导入 JSON 备份'),
                content: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text('备份文件：${picked.fileName}'),
                      const SizedBox(height: 6),
                      Text(
                        '包含有效数据：${picked.activeTaskCount} 条任务、${picked.activeSemesterCount} 个学期、${picked.activeMilestoneCount} 个里程碑',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '选择导入方式',
                        style: Theme.of(ctx).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<bool>(
                        segments: const <ButtonSegment<bool>>[
                          ButtonSegment<bool>(
                            value: true,
                            label: Text('增量合并（推荐）'),
                          ),
                          ButtonSegment<bool>(
                            value: false,
                            label: Text('覆盖本地'),
                          ),
                        ],
                        selected: <bool>{mergeMode},
                        onSelectionChanged: (s) =>
                            setDialogState(() => mergeMode = s.first),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        mergeMode
                            ? '按每条记录的 ID 与 updatedAt 时间戳合并，保留更新的一方，不丢失本机新增任务。'
                            : '注意：覆盖模式将清空当前本地数据库并完全替换为备份文件内容。',
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: mergeMode
                                  ? Theme.of(ctx).colorScheme.onSurfaceVariant
                                  : Theme.of(ctx).colorScheme.error,
                            ),
                      ),
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('开始导入'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (confirmed != true || !mounted) return;
      final result = await syncProvider.importBackup(
        picked.payload,
        mergeMode: mergeMode,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('解析备份文件失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeProvider = context.watch<ThemeProvider>();
    final syncProvider = context.watch<SyncProvider>();
    final planProvider = context.watch<PlanProvider>();
    final isSyncing = syncProvider.status == SyncStatus.syncing;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 48),
          children: <Widget>[
            // ========== 1. 主题与外观 ==========
            _SettingsSectionCard(
              icon: Icons.palette_outlined,
              title: '外观主题',
              subtitle: '遵循 Material Design 3 规范，支持浅色与深色模式无缝切换',
              child: SegmentedButton<ThemeMode>(
                segments: const <ButtonSegment<ThemeMode>>[
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('浅色'),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('深色'),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_outlined),
                    label: Text('跟随系统'),
                  ),
                ],
                selected: <ThemeMode>{themeProvider.themeMode},
                onSelectionChanged: (s) => themeProvider.setThemeMode(s.first),
              ),
            ),
            const SizedBox(height: 16),

            // ========== 2. WebDAV 双端自动云同步 ==========
            _SettingsSectionCard(
              icon: Icons.cloud_sync_outlined,
              title: '云同步（WebDAV）',
              subtitle:
                  '基于 LWW（最新时间戳优先）+ 软删除规范实现 Windows 与 Android 双端自动增量同步；账号密码由系统安全加密存储',
              trailing: TextButton(
                onPressed: () {
                  setState(() {
                    _serverUrlController.text = AppConstants.defaultWebDavUrl;
                    if (_remoteDirController.text.trim().isEmpty) {
                      _remoteDirController.text = AppConstants.defaultRemoteDir;
                    }
                  });
                },
                child: const Text('填入坚果云默认地址'),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextFormField(
                      controller: _serverUrlController,
                      decoration: const InputDecoration(
                        labelText: 'WebDAV 服务器地址 *',
                        hintText: AppConstants.defaultWebDavUrl,
                        prefixIcon: Icon(Icons.dns_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return '请填写 WebDAV 服务器地址';
                        }
                        if (!v.trim().startsWith('http://') &&
                            !v.trim().startsWith('https://')) {
                          return '地址必须以 https:// 或 http:// 开头';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _remoteDirController,
                      decoration: const InputDecoration(
                        labelText: '远端同步子目录',
                        hintText: AppConstants.defaultRemoteDir,
                        helperText:
                            '坚果云需在 /dav/ 下建立应用子目录（如 PlanFlow），同步文件名为 plan_sync.json',
                        prefixIcon: Icon(Icons.folder_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'WebDAV 账号 *',
                        hintText: '例如：your_name@example.com',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '请填写账号' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: '应用密码 *',
                        hintText: '坚果云请在「账户信息 -> 安全选项 -> 第三方应用管理」中生成应用密码',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '请填写应用密码' : null,
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('开启自动后台静默同步'),
                      subtitle: const Text(
                        'App 启动进入首页自动同步，任务增删改勾选后防抖 2 秒自动同步',
                      ),
                      value: _autoSyncEnabled,
                      onChanged: (value) async {
                        setState(() => _autoSyncEnabled = value);
                        await syncProvider.setAutoSyncEnabled(value);
                      },
                    ),
                    const SizedBox(height: 8),

                    // 状态摘要条
                    if (syncProvider.lastSyncAtMs != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          '上次成功同步：${AppDateUtils.formatSyncTime(syncProvider.lastSyncAtMs!)}  ·  状态：${syncProvider.statusMessage ?? syncProvider.status.label}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),

                    if (_testFeedback != null) ...<Widget>[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (_testSuccess == true
                                  ? Colors.green
                                  : colorScheme.error)
                              .withAlpha(24),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (_testSuccess == true
                                    ? Colors.green
                                    : colorScheme.error)
                                .withAlpha(110),
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              _testSuccess == true
                                  ? Icons.check_circle_outline
                                  : Icons.error_outline,
                              color: _testSuccess == true
                                  ? Colors.green
                                  : colorScheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _testFeedback!,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        FilledButton.icon(
                          onPressed: isSyncing ? null : _syncNow,
                          icon: isSyncing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.sync_rounded),
                          label: Text(isSyncing ? '同步中...' : '立即同步'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: syncProvider.isTestingConnection
                              ? null
                              : _testConnection,
                          icon: syncProvider.isTestingConnection
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.wifi_tethering_rounded),
                          label: const Text('测试连接'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _saveWebDavConfig,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('仅保存配置'),
                        ),
                        if (syncProvider.isConfigured)
                          TextButton.icon(
                            onPressed: _clearCredentials,
                            icon: Icon(
                              Icons.delete_outline,
                              color: colorScheme.error,
                            ),
                            label: Text(
                              '清除凭据',
                              style: TextStyle(color: colorScheme.error),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ========== 3. 手动本地备份兜底 ==========
            _SettingsSectionCard(
              icon: Icons.folder_zip_outlined,
              title: '本地 JSON 备份与恢复',
              subtitle:
                  '当前本地数据：${planProvider.tasks.length} 条任务 · ${planProvider.semesters.length} 个学期 · ${planProvider.milestones.length} 个里程碑',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  FilledButton.tonalIcon(
                    onPressed:
                        syncProvider.isBackupBusy ? null : _handleExportBackup,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('导出全量 JSON 备份'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        syncProvider.isBackupBusy ? null : _handleImportBackup,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('导入 JSON 备份'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ========== 4. 关于与架构说明 ==========
            const _SettingsSectionCard(
              icon: Icons.info_outline_rounded,
              title: '关于 ${AppConstants.appName}',
              subtitle: 'Local-First 跨平台计划清单软件（Windows 桌面端 & Android 移动端）',
              child: Text(
                '所有数据优先存储于本机 SQLite 数据库，离线无延迟可用；每条任务、学期与里程碑均具备全局 UUID、毫秒级 updatedAt 时间戳与 isDeleted 软删除标记，确保多端 WebDAV 增量合并无冲突、已删数据不复活。',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(150)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
