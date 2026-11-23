import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../data/models/sync_payload.dart';
import '../data/models/webdav_config.dart';

/// WebDAV 通信异常
class WebDavException implements Exception {
  const WebDavException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      statusCode != null ? '$message (HTTP $statusCode)' : message;
}

/// 测试连接结果
class WebDavTestResult {
  const WebDavTestResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

/// 轻量级 RFC 4918 WebDAV 客户端（原生兼容坚果云 / Nextcloud / Alist 等服务）
class WebDavClient {
  WebDavClient({http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  final http.Client _client;

  Map<String, String> _authHeaders(
    WebDavConfig config, {
    Map<String, String>? extra,
  }) {
    final credentials =
        base64Encode(utf8.encode('${config.username}:${config.password}'));
    return <String, String>{
      'Authorization': 'Basic $credentials',
      'User-Agent': 'PlanFlow/1.0 (Flutter WebDAV Client)',
      if (extra != null) ...extra,
    };
  }

  void _validateConfig(WebDavConfig config) {
    if (config.serverUrl.trim().isEmpty) {
      throw const WebDavException('请先填写 WebDAV 服务器地址');
    }
    final uri = Uri.tryParse(config.normalizedBaseUrl);
    if (uri == null ||
        (!uri.isScheme('https') && !uri.isScheme('http')) ||
        uri.host.isEmpty) {
      throw const WebDavException('服务器地址格式无效，请以 https:// 或 http:// 开头');
    }
    if (config.username.trim().isEmpty || config.password.trim().isEmpty) {
      throw const WebDavException('请填写完整的 WebDAV 账号与应用密码');
    }
  }

  /// 测试连接并确认远端同步目录可用
  Future<WebDavTestResult> testConnection(WebDavConfig config) async {
    try {
      _validateConfig(config);

      // 1. 先向服务器根路径发送 PROPFIND 校验连通性与认证
      final baseUri = Uri.parse(config.normalizedBaseUrl);
      final propRequest = http.Request('PROPFIND', baseUri)
        ..headers.addAll(
          _authHeaders(
            config,
            extra: const <String, String>{'Depth': '0'},
          ),
        );
      final streamed =
          await _client.send(propRequest).timeout(AppConstants.httpTimeout);
      final propResponse = await http.Response.fromStream(streamed);

      if (propResponse.statusCode == 401) {
        return const WebDavTestResult(
          success: false,
          message: '认证失败（401）：请检查账号与 WebDAV 应用密码是否正确',
        );
      }
      if (propResponse.statusCode == 403) {
        return const WebDavTestResult(
          success: false,
          message: '拒绝访问（403）：当前账号无权访问该 WebDAV 地址',
        );
      }
      if (propResponse.statusCode != 200 &&
          propResponse.statusCode != 204 &&
          propResponse.statusCode != 207) {
        return WebDavTestResult(
          success: false,
          message: '服务器返回异常状态码 HTTP ${propResponse.statusCode}',
        );
      }

      // 2. 验证/自动创建远端同步目录（坚果云需在 /dav/ 下使用子目录）
      await ensureRemoteDirectory(config);

      return WebDavTestResult(
        success: true,
        message: '连接成功！同步路径：${config.syncFileUri}',
      );
    } on WebDavException catch (e) {
      return WebDavTestResult(success: false, message: e.message);
    } catch (e) {
      return WebDavTestResult(
        success: false,
        message: _friendlyErrorMessage(e),
      );
    }
  }

  /// 确保远端同步目录存在（逐级执行 MKCOL，兼容 405 已存在响应）
  Future<void> ensureRemoteDirectory(WebDavConfig config) async {
    _validateConfig(config);
    final dirPath = config.normalizedRemoteDir;
    if (dirPath.isEmpty) return;

    final segments = dirPath.split('/').where((s) => s.isNotEmpty).toList();
    var currentUrl = config.normalizedBaseUrl;

    for (final segment in segments) {
      currentUrl = '$currentUrl${Uri.encodeComponent(segment)}/';
      final uri = Uri.parse(currentUrl);
      try {
        final request = http.Request('MKCOL', uri)
          ..headers.addAll(_authHeaders(config));
        final streamed =
            await _client.send(request).timeout(AppConstants.httpTimeout);
        final response = await http.Response.fromStream(streamed);

        // 201 Created: 新建成功；405 Method Not Allowed / 301 / 200: 目录已存在
        final code = response.statusCode;
        if (code == 201 ||
            code == 200 ||
            code == 204 ||
            code == 301 ||
            code == 302 ||
            code == 405) {
          continue;
        }
        if (code == 401) {
          throw const WebDavException('认证失败，请检查账号与应用密码', statusCode: 401);
        }
        if (code == 403) {
          throw const WebDavException('无权创建同步目录，请检查坚果云目录权限', statusCode: 403);
        }
        throw WebDavException('创建远端目录失败', statusCode: code);
      } on WebDavException {
        rethrow;
      } catch (e) {
        throw WebDavException(_friendlyErrorMessage(e));
      }
    }
  }

  /// 从 WebDAV 拉取远端 `plan_sync.json`；若首次同步远端文件不存在（404）返回 null
  Future<SyncPayload?> downloadSyncPayload(WebDavConfig config) async {
    _validateConfig(config);
    try {
      final response = await _client
          .get(
            config.syncFileUri,
            headers: _authHeaders(config),
          )
          .timeout(AppConstants.httpTimeout);

      final code = response.statusCode;
      if (code == 404) {
        return null;
      }
      if (code == 401) {
        throw const WebDavException('认证失败，请检查账号与应用密码', statusCode: 401);
      }
      if (code == 403) {
        throw const WebDavException('无权读取同步文件', statusCode: 403);
      }
      if (code < 200 || code >= 300) {
        throw WebDavException('拉取远端同步文件失败', statusCode: code);
      }

      final bodyText = utf8.decode(response.bodyBytes).trim();
      if (bodyText.isEmpty) {
        return null;
      }
      return SyncPayload.fromJsonString(bodyText);
    } on WebDavException {
      rethrow;
    } on FormatException catch (e) {
      throw WebDavException('远端 plan_sync.json 解析失败：${e.message}');
    } catch (e) {
      throw WebDavException(_friendlyErrorMessage(e));
    }
  }

  /// 将合并后的最新全量数据覆盖上传至 WebDAV `plan_sync.json`
  Future<void> uploadSyncPayload(
    WebDavConfig config,
    SyncPayload payload,
  ) async {
    _validateConfig(config);
    await ensureRemoteDirectory(config);

    try {
      final bytes = utf8.encode(payload.toPrettyJsonString());
      final response = await _client
          .put(
            config.syncFileUri,
            headers: _authHeaders(
              config,
              extra: const <String, String>{
                'Content-Type': 'application/json; charset=utf-8',
              },
            ),
            body: bytes,
          )
          .timeout(AppConstants.httpTimeout);

      final code = response.statusCode;
      if (code == 200 || code == 201 || code == 204) {
        return;
      }
      if (code == 401) {
        throw const WebDavException('上传失败：WebDAV 认证无效', statusCode: 401);
      }
      if (code == 403) {
        throw const WebDavException(
          '上传被拒绝（403）：请确保同步目录不为空（坚果云不支持直接写入 /dav/ 根目录）',
          statusCode: 403,
        );
      }
      if (code == 409) {
        throw const WebDavException('远端目录冲突（409），请检查目录路径', statusCode: 409);
      }
      throw WebDavException('上传同步文件失败', statusCode: code);
    } on WebDavException {
      rethrow;
    } catch (e) {
      throw WebDavException(_friendlyErrorMessage(e));
    }
  }

  String _friendlyErrorMessage(Object error) {
    if (error is TimeoutException) {
      return '连接超时，请检查网络或 WebDAV 服务器响应';
    }
    if (error is SocketException) {
      return '无法连接服务器，当前可能处于离线状态';
    }
    if (error is HandshakeException) {
      return 'HTTPS 证书校验失败，请检查服务器地址';
    }
    if (error is http.ClientException) {
      return '网络请求异常：${error.message}';
    }
    return '同步通信异常：$error';
  }

  void dispose() {
    _client.close();
  }
}
