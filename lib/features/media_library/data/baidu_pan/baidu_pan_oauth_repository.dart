import 'dart:convert';
import 'dart:io';

import 'baidu_pan_auth_repository.dart';
import 'baidu_pan_auth_store.dart';
import 'baidu_pan_models.dart';

class BaiduPanOAuthRepository implements BaiduPanAuthRepository {
  BaiduPanOAuthRepository({
    required BaiduPanAppCredentials appCredentials,
    required BaiduPanAuthStore authStore,
    HttpClient? httpClient,
  }) : _appCredentials = appCredentials,
       _authStore = authStore,
       _httpClient = httpClient ?? HttpClient();

  static const String _authorizeEndpoint =
      'https://openapi.baidu.com/oauth/2.0/authorize';
  static const String _tokenEndpoint =
      'https://openapi.baidu.com/oauth/2.0/token';
  static const Duration _refreshThreshold = Duration(minutes: 5);

  final BaiduPanAppCredentials _appCredentials;
  final BaiduPanAuthStore _authStore;
  final HttpClient _httpClient;

  @override
  Future<Uri> buildAuthorizeUri() async {
    return Uri.parse(_authorizeEndpoint).replace(
      queryParameters: <String, String>{
        'response_type': 'code',
        'client_id': _appCredentials.appKey,
        'redirect_uri': _appCredentials.redirectUri,
        'scope': _appCredentials.scope,
        'display': 'tv',
        'qrcode': '1',
        'force_login': '1',
      },
    );
  }

  @override
  Future<void> loginWithAuthorizationCode(String code) async {
    final String normalizedCode = code.trim();
    if (normalizedCode.isEmpty) {
      throw ArgumentError.value(code, 'code', '授权码不能为空');
    }
    final BaiduPanAuthToken token = await _exchangeToken(<String, String>{
      'grant_type': 'authorization_code',
      'code': normalizedCode,
      'client_id': _appCredentials.appKey,
      'client_secret': _appCredentials.secretKey,
      'redirect_uri': _appCredentials.redirectUri,
    });
    await _authStore.writeToken(token);
  }

  @override
  Future<void> logout() {
    return _authStore.clearToken();
  }

  @override
  Future<String> getValidAccessToken() async {
    final BaiduPanAuthToken? token = await _authStore.readToken();
    if (token == null || token.accessToken.trim().isEmpty) {
      throw const BaiduPanUnauthorizedException();
    }
    if (!token.willExpireWithin(_refreshThreshold)) {
      return token.accessToken;
    }
    final BaiduPanAuthToken refreshedToken = await _refreshToken(token);
    await _authStore.writeToken(refreshedToken);
    return refreshedToken.accessToken;
  }

  @override
  Future<bool> hasValidSession() async {
    final BaiduPanAuthToken? token = await _authStore.readToken();
    if (token == null || token.accessToken.trim().isEmpty) {
      return false;
    }
    if (!token.willExpireWithin(_refreshThreshold)) {
      return true;
    }
    try {
      final BaiduPanAuthToken refreshedToken = await _refreshToken(token);
      await _authStore.writeToken(refreshedToken);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<BaiduPanAuthToken?> readToken() {
    return _authStore.readToken();
  }

  Future<BaiduPanAuthToken> _refreshToken(BaiduPanAuthToken token) {
    final String refreshToken = token.refreshToken.trim();
    if (refreshToken.isEmpty) {
      throw const BaiduPanTokenExpiredException('缺少 refresh_token');
    }
    return _exchangeToken(<String, String>{
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
      'client_id': _appCredentials.appKey,
      'client_secret': _appCredentials.secretKey,
    });
  }

  Future<BaiduPanAuthToken> _exchangeToken(Map<String, String> form) async {
    final Uri uri = Uri.parse(_tokenEndpoint);
    final List<int> bodyBytes = utf8.encode(Uri(queryParameters: form).query);
    final HttpClientRequest request = await _httpClient.postUrl(uri);
    request.headers.set(
      HttpHeaders.contentTypeHeader,
      'application/x-www-form-urlencoded',
    );
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.contentLength = bodyBytes.length;
    request.add(bodyBytes);
    final HttpClientResponse response = await request.close();
    final String payload = await response.transform(utf8.decoder).join();
    final Object? decoded = payload.trim().isEmpty ? null : jsonDecode(payload);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        '百度网盘 token 接口返回异常: ${response.statusCode} $payload',
        uri: uri,
      );
    }
    if (decoded is! Map) {
      throw const FormatException('百度网盘 token 响应不是 JSON 对象');
    }
    final Map<String, Object?> json = decoded.map(
      (Object? key, Object? value) => MapEntry(key.toString(), value),
    );
    if (json.containsKey('error')) {
      final String error = json['error']?.toString() ?? 'unknown_error';
      final String description =
          json['error_description']?.toString() ?? '未知错误';
      throw StateError('百度网盘授权失败: $error ($description)');
    }

    final String accessToken = json['access_token']?.toString() ?? '';
    final String refreshToken = json['refresh_token']?.toString() ?? '';
    final int expiresIn =
        int.tryParse(json['expires_in']?.toString() ?? '') ?? 0;
    if (accessToken.isEmpty || refreshToken.isEmpty || expiresIn <= 0) {
      throw StateError('百度网盘 token 响应缺少关键字段: $json');
    }
    return BaiduPanAuthToken(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAtMillis: DateTime.now()
          .add(Duration(seconds: expiresIn))
          .millisecondsSinceEpoch,
      scope: json['scope']?.toString(),
      sessionKey: json['session_key']?.toString(),
      sessionSecret: json['session_secret']?.toString(),
    );
  }
}
