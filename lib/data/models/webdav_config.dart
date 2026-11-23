import '../../core/constants/app_constants.dart';

/// WebDAV 云同步配置模型
class WebDavConfig {
  const WebDavConfig({
    this.serverUrl = AppConstants.defaultWebDavUrl,
    this.remoteDir = AppConstants.defaultRemoteDir,
    this.username = '',
    this.password = '',
    this.autoSyncEnabled = true,
  });

  /// 服务器地址（默认兼容坚果云 https://dav.jianguoyun.com/dav/）
  final String serverUrl;

  /// 同步目录名（坚果云需在 /dav/ 下建立应用子目录再写文件）
  final String remoteDir;

  /// WebDAV 账号（如坚果云注册邮箱）
  final String username;

  /// WebDAV 应用密码
  final String password;

  /// 是否开启启动与数据变更自动同步
  final bool autoSyncEnabled;

  /// 是否已具备基本同步凭据
  bool get isConfigured =>
      serverUrl.trim().isNotEmpty &&
      username.trim().isNotEmpty &&
      password.trim().isNotEmpty;

  /// 规范化后的服务器基地址（确保以 `/` 结尾）
  String get normalizedBaseUrl {
    final trimmed = serverUrl.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.endsWith('/') ? trimmed : '$trimmed/';
  }

  /// 规范化后的远端目录名（去除首尾斜杠）
  String get normalizedRemoteDir {
    return remoteDir.trim().replaceAll(RegExp(r'^/+|/+$'), '');
  }

  /// 远端同步目录 URI
  Uri get remoteFolderUri {
    final base = normalizedBaseUrl;
    final dir = normalizedRemoteDir;
    if (dir.isEmpty) {
      return Uri.parse(base);
    }
    final encodedSegments = dir
        .split('/')
        .where((s) => s.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');
    return Uri.parse('$base$encodedSegments/');
  }

  /// 远端同步文件 `plan_sync.json` 完整 URI
  Uri get syncFileUri {
    final folder = remoteFolderUri.toString();
    final withSlash = folder.endsWith('/') ? folder : '$folder/';
    return Uri.parse('$withSlash${AppConstants.syncFileName}');
  }

  WebDavConfig copyWith({
    String? serverUrl,
    String? remoteDir,
    String? username,
    String? password,
    bool? autoSyncEnabled,
  }) {
    return WebDavConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      remoteDir: remoteDir ?? this.remoteDir,
      username: username ?? this.username,
      password: password ?? this.password,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
    );
  }
}
