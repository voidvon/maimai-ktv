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
  static const String _deviceCodeEndpoint =
      'https://openapi.baidu.com/oauth/2.0/device/code';
  static const String _tokenEndpoint =
      'https://openapi.baidu.com/oauth/2.0/token';
  static const Duration _refreshThreshold = Duration(minutes: 5);

  final BaiduPanAppCredentials _appCredentials;
  final BaiduPanAuthStore _authStore;
  final HttpClient _httpClient;

  @override
  Future<BaiduPanDeviceCodeSession> createDeviceCodeSession() async {
    final Map<String, String> queryParameters = <String, String>{
      'response_type': 'device_code',
      'client_id': _appCredentials.appKey,
      'scope': _appCredentials.scope,
    };
    final Map<String, Object?> json = await _getJson(
      Uri.parse(_deviceCodeEndpoint).replace(queryParameters: queryParameters),
    );
    final String deviceCode = json['device_code']?.toString() ?? '';
    final String userCode = json['user_code']?.toString() ?? '';
    final String verificationUrl = json['verification_url']?.toString() ?? '';
    final String qrcodeUrl = json['qrcode_url']?.toString() ?? '';
    final int expiresIn =
        int.tryParse(json['expires_in']?.toString() ?? '') ?? 0;
    final int intervalSeconds =
        int.tryParse(json['interval']?.toString() ?? '') ?? 5;
    if (deviceCode.isEmpty ||
        userCode.isEmpty ||
        verificationUrl.isEmpty ||
        qrcodeUrl.isEmpty ||
        expiresIn <= 0) {
      throw StateError('百度网盘设备码响应缺少关键字段: $json');
    }
    return BaiduPanDeviceCodeSession(
      deviceCode: deviceCode,
      userCode: userCode,
      verificationUrl: verificationUrl,
      qrcodeUrl: qrcodeUrl,
      expiresAtMillis: DateTime.now()
          .add(Duration(seconds: expiresIn))
          .millisecondsSinceEpoch,
      intervalSeconds: intervalSeconds < 1 ? 5 : intervalSeconds,
    );
  }

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
  Future<BaiduPanAuthToken?> loginWithDeviceCode(String deviceCode) async {
    final String normalizedDeviceCode = deviceCode.trim();
    if (normalizedDeviceCode.isEmpty) {
      throw ArgumentError.value(deviceCode, 'deviceCode', '设备码不能为空');
    }
    final _BaiduPanTokenExchangeResult result =
        await _exchangeTokenForDeviceCode(<String, String>{
          'grant_type': 'device_token',
          'code': normalizedDeviceCode,
          'client_id': _appCredentials.appKey,
          'client_secret': _appCredentials.secretKey,
        });
    final BaiduPanAuthToken? token = result.token;
    if (token != null) {
      await _authStore.writeToken(token);
    }
    return token;
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

  Future<_BaiduPanTokenExchangeResult> _exchangeTokenForDeviceCode(
    Map<String, String> form,
  ) async {
    final Map<String, Object?> json = await _postForm(
      _tokenEndpoint,
      form,
      allowErrorResponse: true,
    );
    final String? error = json['error']?.toString();
    if (error == null || error.isEmpty) {
      return _BaiduPanTokenExchangeResult(token: _parseAuthToken(json));
    }
    final String description = json['error_description']?.toString() ?? '未知错误';
    if (error == 'authorization_pending' || error == 'slow_down') {
      return const _BaiduPanTokenExchangeResult();
    }
    if (error == 'expired_token' || description.contains('expired')) {
      throw const BaiduPanTokenExpiredException('百度网盘登录二维码已过期');
    }
    if (error == 'authorization_declined' || error == 'access_denied') {
      throw StateError('百度网盘授权已取消');
    }
    throw StateError('百度网盘授权失败: $error ($description)');
  }

  Future<BaiduPanAuthToken> _exchangeToken(Map<String, String> form) async {
    final Map<String, Object?> json = await _postForm(_tokenEndpoint, form);
    if (json.containsKey('error')) {
      final String error = json['error']?.toString() ?? 'unknown_error';
      final String description =
          json['error_description']?.toString() ?? '未知错误';
      throw StateError('百度网盘授权失败: $error ($description)');
    }
    return _parseAuthToken(json);
  }

  Future<Map<String, Object?>> _getJson(Uri uri) async {
    final HttpClientRequest request = await _httpClient.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.userAgentHeader, 'pan.baidu.com');
    final HttpClientResponse response = await request.close();
    return _readJsonResponse(response, uri: uri);
  }

  Future<Map<String, Object?>> _postForm(
    String endpoint,
    Map<String, String> form, {
    bool allowErrorResponse = false,
  }) async {
    final Uri uri = Uri.parse(endpoint);
    final List<int> bodyBytes = utf8.encode(Uri(queryParameters: form).query);
    final HttpClientRequest request = await _httpClient.postUrl(uri);
    request.headers.set(
      HttpHeaders.contentTypeHeader,
      'application/x-www-form-urlencoded',
    );
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.userAgentHeader, 'pan.baidu.com');
    request.contentLength = bodyBytes.length;
    request.add(bodyBytes);
    final HttpClientResponse response = await request.close();
    return _readJsonResponse(
      response,
      uri: uri,
      allowErrorResponse: allowErrorResponse,
    );
  }

  Map<String, Object?> _readJsonObject(Object? decoded) {
    if (decoded is! Map) {
      throw const FormatException('百度网盘接口响应不是 JSON 对象');
    }
    return decoded.map(
      (Object? key, Object? value) => MapEntry(key.toString(), value),
    );
  }

  Future<Map<String, Object?>> _readJsonResponse(
    HttpClientResponse response, {
    required Uri uri,
    bool allowErrorResponse = false,
  }) async {
    final String payload = await response.transform(utf8.decoder).join();
    final Object? decoded = payload.trim().isEmpty ? null : jsonDecode(payload);
    if (!allowErrorResponse &&
        (response.statusCode < 200 || response.statusCode >= 300)) {
      throw HttpException(
        '百度网盘 token 接口返回异常: ${response.statusCode} $payload',
        uri: uri,
      );
    }
    return _readJsonObject(decoded);
  }

  BaiduPanAuthToken _parseAuthToken(Map<String, Object?> json) {
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

class _BaiduPanTokenExchangeResult {
  const _BaiduPanTokenExchangeResult({this.token});

  final BaiduPanAuthToken? token;
}
