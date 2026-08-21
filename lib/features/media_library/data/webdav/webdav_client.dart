import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

import '../cloud/cloud_playback_cache.dart';
import 'webdav_credential_store.dart';
import 'webdav_models.dart';
import 'webdav_network_policy.dart';
import 'webdav_source_config_store.dart';

typedef WebDavHttpClientFactory = HttpClient Function();

class WebDavClient {
  WebDavClient({
    required WebDavSourceConfigStore configStore,
    required WebDavCredentialStore credentialStore,
    WebDavHttpClientFactory? httpClientFactory,
  }) : _configStore = configStore,
       _credentialStore = credentialStore,
       _httpClientFactory = httpClientFactory ?? HttpClient.new;

  final WebDavSourceConfigStore _configStore;
  final WebDavCredentialStore _credentialStore;
  final WebDavHttpClientFactory _httpClientFactory;

  Future<void> testConnection({
    WebDavSourceConfig? config,
    String? password,
  }) async {
    final _WebDavConnection connection = await _resolveConnection(
      config: config,
      password: password,
    );
    await _propfind(connection, config?.rootPath ?? connection.config.rootPath);
  }

  Future<List<WebDavRemoteFile>> listDirectories({
    required String path,
    WebDavSourceConfig? config,
    String? password,
  }) async {
    final _WebDavConnection connection = await _resolveConnection(
      config: config,
      password: password,
    );
    final List<WebDavRemoteFile> entries = await _propfind(connection, path);
    return entries
        .where((WebDavRemoteFile file) => file.isDirectory)
        .toList(growable: false);
  }

  Future<List<WebDavRemoteFile>> scanRoot(String rootPath) async {
    final _WebDavConnection connection = await _resolveConnection();
    final List<WebDavRemoteFile> files = <WebDavRemoteFile>[];
    final List<String> pendingDirectories = <String>[
      _normalizeRemotePath(rootPath),
    ];
    final Set<String> visitedDirectories = <String>{};

    while (pendingDirectories.isNotEmpty) {
      final String directory = pendingDirectories.removeLast();
      if (!visitedDirectories.add(directory)) {
        continue;
      }
      final List<WebDavRemoteFile> children = await _propfind(
        connection,
        directory,
      );
      for (final WebDavRemoteFile child in children) {
        files.add(child);
        if (child.isDirectory) {
          pendingDirectories.add(child.path);
        }
      }
    }
    return files;
  }

  Future<WebDavRemoteFile> getFileMeta(String remotePath) async {
    final _WebDavConnection connection = await _resolveConnection();
    final List<WebDavRemoteFile> responses = await _propfind(
      connection,
      remotePath,
      depth: 0,
      includeSelf: true,
    );
    if (responses.isEmpty) {
      throw WebDavException('文件不存在：$remotePath');
    }
    return responses.first;
  }

  Future<void> downloadFile({
    required String remotePath,
    required File targetFile,
    void Function(double progress)? onProgress,
    CloudDownloadCancellationToken? cancellationToken,
  }) async {
    final _WebDavConnection connection = await _resolveConnection();
    final HttpClient client = _httpClientFactory();
    try {
      await targetFile.parent.create(recursive: true);
      int existingBytes = await targetFile.exists()
          ? await targetFile.length()
          : 0;
      final HttpClientRequest request = await client.getUrl(
        _buildRemoteUri(connection.config, remotePath),
      );
      _applyAuthorization(request, connection);
      request.followRedirects = true;
      request.maxRedirects = 5;
      if (existingBytes > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$existingBytes-');
      }
      final HttpClientResponse response = await request.close();
      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        await response.drain<void>();
        throw WebDavException('下载失败', statusCode: response.statusCode);
      }

      final bool append =
          response.statusCode == HttpStatus.partialContent && existingBytes > 0;
      if (!append) {
        existingBytes = 0;
      }
      final int responseBytes = response.contentLength;
      final int totalBytes = responseBytes < 0
          ? 0
          : existingBytes + responseBytes;
      int receivedBytes = existingBytes;
      final IOSink sink = targetFile.openWrite(
        mode: append ? FileMode.append : FileMode.write,
      );
      try {
        await for (final List<int> chunk in response) {
          cancellationToken?.throwIfCancelled();
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0) {
            onProgress?.call((receivedBytes / totalBytes).clamp(0, 1));
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      onProgress?.call(1);
    } finally {
      client.close(force: true);
    }
  }

  Future<List<WebDavRemoteFile>> _propfind(
    _WebDavConnection connection,
    String remotePath, {
    int depth = 1,
    bool includeSelf = false,
  }) async {
    final HttpClient client = _httpClientFactory();
    final String normalizedRequestPath = _normalizeRemotePath(remotePath);
    try {
      final HttpClientRequest request = await client.openUrl(
        'PROPFIND',
        _buildRemoteUri(
          connection.config,
          normalizedRequestPath,
          directory: depth > 0,
        ),
      );
      _applyAuthorization(request, connection);
      request.headers.set('Depth', depth.toString());
      request.headers.contentType = ContentType(
        'application',
        'xml',
        charset: 'utf-8',
      );
      request.write(_propertyRequestBody);
      final HttpClientResponse response = await request.close();
      final String body = await utf8.decoder.bind(response).join();
      if (response.statusCode != HttpStatus.multiStatus &&
          response.statusCode != HttpStatus.ok) {
        throw WebDavException(
          _statusMessage(response.statusCode),
          statusCode: response.statusCode,
        );
      }
      final XmlDocument document;
      try {
        document = XmlDocument.parse(body);
      } on XmlParserException catch (error) {
        throw WebDavException('服务器返回了无效的 WebDAV XML：$error');
      }

      final List<WebDavRemoteFile> result = <WebDavRemoteFile>[];
      for (final XmlElement responseElement
          in document.descendants.whereType<XmlElement>().where(
            (XmlElement element) => element.name.local == 'response',
          )) {
        final WebDavRemoteFile? file = _parseResponse(
          responseElement,
          connection.config,
        );
        if (file == null ||
            (!includeSelf && file.path == normalizedRequestPath)) {
          continue;
        }
        result.add(file);
      }
      return result;
    } finally {
      client.close(force: true);
    }
  }

  WebDavRemoteFile? _parseResponse(
    XmlElement response,
    WebDavSourceConfig config,
  ) {
    final String? href = _firstText(response, 'href');
    if (href == null || href.trim().isEmpty) {
      return null;
    }
    final String remotePath = _remotePathFromHref(config, href.trim());
    final XmlElement? property = response.descendants
        .whereType<XmlElement>()
        .where((XmlElement element) => element.name.local == 'prop')
        .firstOrNull;
    if (property == null) {
      return null;
    }
    final bool isDirectory = property.descendants.whereType<XmlElement>().any(
      (XmlElement element) => element.name.local == 'collection',
    );
    final String? modifiedText = _firstText(property, 'getlastmodified');
    int modifiedAtMillis = 0;
    if (modifiedText != null && modifiedText.isNotEmpty) {
      try {
        modifiedAtMillis = HttpDate.parse(modifiedText).millisecondsSinceEpoch;
      } on FormatException {
        modifiedAtMillis =
            DateTime.tryParse(modifiedText)?.millisecondsSinceEpoch ?? 0;
      }
    }
    final String normalizedPath = _normalizeRemotePath(remotePath);
    final String name = Uri.parse(normalizedPath).pathSegments.lastOrNull ?? '';
    final String? etag = _firstText(property, 'getetag')?.trim();
    return WebDavRemoteFile(
      fileId: normalizedPath,
      path: normalizedPath,
      serverFilename: name,
      isDirectory: isDirectory,
      size: int.tryParse(_firstText(property, 'getcontentlength') ?? '') ?? 0,
      modifiedAtMillis: modifiedAtMillis,
      etag: etag,
      rawPayload: <String, Object?>{'href': href, 'etag': etag},
    );
  }

  Future<_WebDavConnection> _resolveConnection({
    WebDavSourceConfig? config,
    String? password,
  }) async {
    final WebDavSourceConfig? resolvedConfig =
        config ?? await _configStore.loadConfig();
    if (resolvedConfig == null) {
      throw const WebDavException('尚未配置 WebDAV');
    }
    _validateServerUri(resolvedConfig.serverUrl);
    final String resolvedPassword =
        password ?? await _credentialStore.readPassword() ?? '';
    if (resolvedPassword.isEmpty) {
      throw const WebDavException('WebDAV 密码为空');
    }
    return _WebDavConnection(
      config: resolvedConfig,
      password: resolvedPassword,
    );
  }

  void _applyAuthorization(
    HttpClientRequest request,
    _WebDavConnection connection,
  ) {
    final String credentials = base64Encode(
      utf8.encode('${connection.config.username}:${connection.password}'),
    );
    request.headers.set(HttpHeaders.authorizationHeader, 'Basic $credentials');
    request.headers.set(HttpHeaders.userAgentHeader, 'MaimaiKTV-WebDAV/1.0');
  }

  Uri _buildRemoteUri(
    WebDavSourceConfig config,
    String remotePath, {
    bool directory = false,
  }) {
    final Uri base = _validateServerUri(config.serverUrl);
    final String baseText = base.toString().endsWith('/')
        ? base.toString()
        : '${base.toString()}/';
    String encodedPath = _normalizeRemotePath(remotePath)
        .substring(1)
        .split('/')
        .where((String segment) => segment.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');
    if (directory && encodedPath.isNotEmpty && !encodedPath.endsWith('/')) {
      encodedPath = '$encodedPath/';
    }
    return Uri.parse(baseText).resolve(encodedPath);
  }

  Uri _validateServerUri(String value) {
    final Uri? uri = Uri.tryParse(value.trim());
    if (uri == null || !WebDavNetworkPolicy.allows(uri)) {
      throw const WebDavException('服务器地址必须使用 HTTPS，局域网地址可以使用 HTTP');
    }
    return uri;
  }

  String _remotePathFromHref(WebDavSourceConfig config, String href) {
    final Uri base = Uri.parse(config.serverUrl.trim());
    final Uri hrefUri = base.resolve(href);
    final String decodedBasePath = Uri.decodeFull(base.path);
    final String basePath = decodedBasePath.endsWith('/')
        ? decodedBasePath
        : '$decodedBasePath/';
    String path = Uri.decodeFull(hrefUri.path);
    if (path == decodedBasePath) {
      return '/';
    }
    if (path.startsWith(basePath)) {
      path = path.substring(basePath.length);
    }
    return _normalizeRemotePath(path);
  }

  String _normalizeRemotePath(String value) {
    final String normalized = value.trim().replaceAll(RegExp(r'/+'), '/');
    if (normalized.isEmpty || normalized == '/') {
      return '/';
    }
    final String withLeadingSlash = normalized.startsWith('/')
        ? normalized
        : '/$normalized';
    return withLeadingSlash.endsWith('/')
        ? withLeadingSlash.substring(0, withLeadingSlash.length - 1)
        : withLeadingSlash;
  }

  String? _firstText(XmlElement parent, String localName) {
    return parent.descendants
        .whereType<XmlElement>()
        .where((XmlElement element) => element.name.local == localName)
        .map((XmlElement element) => element.innerText.trim())
        .firstOrNull;
  }

  String _statusMessage(int statusCode) {
    return switch (statusCode) {
      HttpStatus.unauthorized => '用户名或密码错误',
      HttpStatus.forbidden => '服务器拒绝访问该目录',
      HttpStatus.notFound => 'WebDAV 路径不存在',
      _ => 'WebDAV 请求失败',
    };
  }
}

class _WebDavConnection {
  const _WebDavConnection({required this.config, required this.password});

  final WebDavSourceConfig config;
  final String password;
}

const String _propertyRequestBody = '''<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:resourcetype />
    <d:getcontentlength />
    <d:getlastmodified />
    <d:getetag />
  </d:prop>
</d:propfind>''';
