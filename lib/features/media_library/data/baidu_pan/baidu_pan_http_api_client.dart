import 'dart:convert';
import 'dart:io';

import 'baidu_pan_api_client.dart';
import 'baidu_pan_auth_repository.dart';
import 'baidu_pan_models.dart';

class BaiduPanHttpApiClient implements BaiduPanApiClient {
  BaiduPanHttpApiClient({
    required BaiduPanAuthRepository authRepository,
    HttpClient? httpClient,
  }) : _authRepository = authRepository,
       _httpClient = httpClient ?? HttpClient();

  static const String _uinfoEndpoint =
      'https://pan.baidu.com/rest/2.0/xpan/nas';
  static const String _quotaEndpoint = 'https://pan.baidu.com/api/quota';
  static const String _fileEndpoint =
      'https://pan.baidu.com/rest/2.0/xpan/file';
  static const String _multimediaEndpoint =
      'https://pan.baidu.com/rest/2.0/xpan/multimedia';

  final BaiduPanAuthRepository _authRepository;
  final HttpClient _httpClient;

  @override
  Future<BaiduPanUserInfo> getUserInfo() async {
    final Map<String, Object?> json = await _getJson(
      Uri.parse(_uinfoEndpoint),
      <String, String>{'method': 'uinfo'},
    );
    final Map<String, Object?> data = _unwrapDataMap(json);
    return BaiduPanUserInfo(
      uk: _readString(data, <String>['uk', 'userid', 'user_id']),
      displayName: _readString(data, <String>[
        'netdisk_name',
        'baidu_name',
        'name',
      ]),
      avatarUrl: _readNullableString(data, <String>['avatar_url', 'avatar']),
      vipType: _readNullableInt(data, <String>['vip_type']),
    );
  }

  @override
  Future<BaiduPanQuotaInfo> getQuota() async {
    final Map<String, Object?> json = await _getJson(
      Uri.parse(_quotaEndpoint),
      <String, String>{'checkfree': '1', 'checkexpire': '1'},
    );
    final Map<String, Object?> data = _unwrapDataMap(json);
    final int total = _readInt(data, <String>['total']);
    final int used = _readInt(data, <String>['used']);
    final int? free = _readNullableInt(data, <String>['free']);
    return BaiduPanQuotaInfo(
      totalBytes: total,
      usedBytes: used,
      freeBytes: free,
    );
  }

  @override
  Future<List<BaiduPanRemoteFile>> listDirectory({
    required String path,
    int start = 0,
    int limit = 1000,
  }) async {
    final Map<String, Object?> json = await _getJson(
      Uri.parse(_fileEndpoint),
      <String, String>{
        'method': 'list',
        'dir': path,
        'start': '$start',
        'limit': '$limit',
      },
    );
    return _parseRemoteFiles(json);
  }

  @override
  Future<List<BaiduPanRemoteFile>> listAll({
    required String path,
    int start = 0,
    int limit = 1000,
  }) async {
    final Map<String, Object?> json = await _getJson(
      Uri.parse(_multimediaEndpoint),
      <String, String>{
        'method': 'listall',
        'path': path,
        'start': '$start',
        'limit': '$limit',
      },
    );
    return _parseRemoteFiles(json);
  }

  @override
  Future<List<BaiduPanRemoteFile>> search({
    required String key,
    String? path,
    int page = 1,
    int num = 100,
  }) async {
    final Map<String, String> query = <String, String>{
      'method': 'search',
      'key': key,
      'page': '$page',
      'num': '$num',
    };
    final String normalizedPath = path?.trim() ?? '';
    if (normalizedPath.isNotEmpty) {
      query['dir'] = normalizedPath;
    }
    final Map<String, Object?> json = await _getJson(
      Uri.parse(_fileEndpoint),
      query,
    );
    return _parseRemoteFiles(json);
  }

  @override
  Future<BaiduPanRemoteFile> getFileMeta({
    required String fsid,
    bool withDlink = false,
  }) async {
    final Map<String, Object?> json = await _getJson(
      Uri.parse(_multimediaEndpoint),
      <String, String>{
        'method': 'filemetas',
        'fsids': '[$fsid]',
        if (withDlink) 'dlink': '1',
      },
    );
    final List<BaiduPanRemoteFile> files = _parseRemoteFiles(json);
    if (files.isEmpty) {
      throw const BaiduPanFileNotFoundException();
    }
    return files.first;
  }

  Future<Map<String, Object?>> _getJson(
    Uri baseUri,
    Map<String, String> queryParameters,
  ) async {
    final String accessToken = await _authRepository.getValidAccessToken();
    final Uri uri = baseUri.replace(
      queryParameters: <String, String>{
        ...queryParameters,
        'access_token': accessToken,
      },
    );
    final HttpClientRequest request = await _httpClient.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final HttpClientResponse response = await request.close();
    final String payload = await response.transform(utf8.decoder).join();
    final Object? decoded = payload.trim().isEmpty ? null : jsonDecode(payload);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        '百度网盘接口返回异常: ${response.statusCode} $payload',
        uri: uri,
      );
    }
    if (decoded is! Map) {
      throw const FormatException('百度网盘接口响应不是 JSON 对象');
    }
    final Map<String, Object?> json = decoded.map(
      (Object? key, Object? value) => MapEntry(key.toString(), value),
    );
    final int? errno = _readNullableInt(json, <String>['errno', 'error_code']);
    if (errno != null && errno != 0) {
      throw StateError('百度网盘接口错误 errno=$errno payload=$json');
    }
    return json;
  }

  List<BaiduPanRemoteFile> _parseRemoteFiles(Map<String, Object?> json) {
    final List<Map<String, Object?>> items = _unwrapDataList(json);
    return items.map(_mapRemoteFile).toList(growable: false);
  }

  BaiduPanRemoteFile _mapRemoteFile(Map<String, Object?> item) {
    return BaiduPanRemoteFile(
      fsid: _readString(item, <String>['fs_id', 'fsid']),
      path: _readString(item, <String>['path']),
      serverFilename: _readString(item, <String>[
        'server_filename',
        'filename',
        'name',
      ]),
      isDirectory: _readInt(item, <String>['isdir']) == 1,
      size: _readInt(item, <String>['size']),
      modifiedAtMillis:
          _readInt(item, <String>['server_mtime', 'mtime']) * 1000,
      md5: _readNullableString(item, <String>['md5']),
      category: _readNullableInt(item, <String>['category']),
      dlink: _readNullableString(item, <String>['dlink']),
      rawPayload: item,
    );
  }

  Map<String, Object?> _unwrapDataMap(Map<String, Object?> json) {
    final Object? data = json['data'];
    if (data is Map) {
      return data.map(
        (Object? key, Object? value) => MapEntry(key.toString(), value),
      );
    }
    return json;
  }

  List<Map<String, Object?>> _unwrapDataList(Map<String, Object?> json) {
    final Object? data = json['list'] ?? json['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((Map item) {
            return item.map(
              (Object? key, Object? value) => MapEntry(key.toString(), value),
            );
          })
          .toList(growable: false);
    }
    if (data is Map) {
      final Object? list = data['list'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((Map item) {
              return item.map(
                (Object? key, Object? value) => MapEntry(key.toString(), value),
              );
            })
            .toList(growable: false);
      }
    }
    return const <Map<String, Object?>>[];
  }

  String _readString(Map<String, Object?> json, List<String> keys) {
    for (final String key in keys) {
      final String value = json[key]?.toString() ?? '';
      if (value.trim().isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  String? _readNullableString(Map<String, Object?> json, List<String> keys) {
    final String value = _readString(json, keys);
    return value.isEmpty ? null : value;
  }

  int _readInt(Map<String, Object?> json, List<String> keys) {
    final int? value = _readNullableInt(json, keys);
    return value ?? 0;
  }

  int? _readNullableInt(Map<String, Object?> json, List<String> keys) {
    for (final String key in keys) {
      final Object? raw = json[key];
      if (raw is int) {
        return raw;
      }
      if (raw is num) {
        return raw.toInt();
      }
      final int? parsed = int.tryParse(raw?.toString() ?? '');
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }
}
