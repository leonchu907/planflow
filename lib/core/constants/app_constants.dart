/// 全局常量定义
class AppConstants {
  AppConstants._();

  static const String appName = 'PlanFlow';
  static const String appSubtitle = '四维计划清单';

  /// 桌面端与移动端响应式断点（宽度 >= 840px 使用桌面侧边栏与多栏布局）
  static const double desktopBreakpoint = 840.0;
  static const double wideDesktopBreakpoint = 1200.0;

  /// WebDAV 默认配置（默认兼容坚果云）
  static const String defaultWebDavUrl = 'https://dav.jianguoyun.com/dav/';
  static const String defaultRemoteDir = 'PlanFlow';
  static const String syncFileName = 'plan_sync.json';
  static const int syncSchemaVersion = 1;

  /// 自动同步防抖时间（2 秒）
  static const Duration syncDebounceDuration = Duration(seconds: 2);

  /// HTTP 请求超时时间
  static const Duration httpTimeout = Duration(seconds: 20);

  /// 预置常用标签
  static const List<String> defaultTags = <String>[
    '学习',
    '考试',
    '项目',
    '生活',
    '科研',
    '阅读',
    '健康',
    '社团',
  ];

  /// 学期可选强调色（ARGB 整型存储，避免依赖特定版本 Color.value API）
  static const List<int> semesterColorValues = <int>[
    0xFF3F51B5, // 靛蓝
    0xFF00897B, // 青绿
    0xFF1E88E5, // 蔚蓝
    0xFF8E24AA, // 雅紫
    0xFFEF6C00, // 琥珀橙
    0xFFD81B60, // 玫瑰红
    0xFF43A047, // 翠绿
    0xFF546E7A, // 蓝灰
  ];

  /// SharedPreferences 键名
  static const String prefThemeMode = 'pref_theme_mode';
  static const String prefActiveSemesterId = 'pref_active_semester_id';
  static const String prefAutoSyncEnabled = 'pref_auto_sync_enabled';
  static const String prefWebDavServerUrl = 'pref_webdav_server_url';
  static const String prefWebDavRemoteDir = 'pref_webdav_remote_dir';
  static const String prefLastSyncAt = 'pref_last_sync_at';
  static const String prefDeviceId = 'pref_device_id';

  /// SecureStorage 键名
  static const String secureWebDavUsername = 'secure_webdav_username';
  static const String secureWebDavPassword = 'secure_webdav_password';
}
