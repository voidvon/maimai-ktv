import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ktv2_example/features/media_library/data/baidu_pan/baidu_pan_auth_store.dart';
import 'package:ktv2_example/features/media_library/data/baidu_pan/baidu_pan_models.dart';
import 'package:ktv2_example/features/media_library/data/baidu_pan/baidu_pan_oauth_repository.dart';

void main() {
  test('buildAuthorizeUri includes expected baidu oauth params', () async {
    final BaiduPanOAuthRepository repository = BaiduPanOAuthRepository(
      appCredentials: const BaiduPanAppCredentials(
        appId: '122751914',
        appKey: 'app-key',
        secretKey: 'secret-key',
        signKey: 'sign-key',
      ),
      authStore: _FakeBaiduPanAuthStore(),
      httpClient: _FakeHttpClient.forJson(<String, Object?>{
        'access_token': 'token',
        'refresh_token': 'refresh',
        'expires_in': 3600,
      }),
    );

    final Uri uri = await repository.buildAuthorizeUri();

    expect(uri.host, 'openapi.baidu.com');
    expect(uri.queryParameters['response_type'], 'code');
    expect(uri.queryParameters['client_id'], 'app-key');
    expect(uri.queryParameters['redirect_uri'], 'oob');
    expect(uri.queryParameters['scope'], 'basic,netdisk');
    expect(uri.queryParameters['qrcode'], '1');
  });

  test('loginWithAuthorizationCode stores parsed token response', () async {
    final _FakeBaiduPanAuthStore authStore = _FakeBaiduPanAuthStore();
    final BaiduPanOAuthRepository repository = BaiduPanOAuthRepository(
      appCredentials: const BaiduPanAppCredentials(
        appId: '122751914',
        appKey: 'app-key',
        secretKey: 'secret-key',
        signKey: 'sign-key',
      ),
      authStore: authStore,
      httpClient: _FakeHttpClient.forJson(<String, Object?>{
        'access_token': 'token',
        'refresh_token': 'refresh',
        'expires_in': 3600,
        'scope': 'basic,netdisk',
      }),
    );

    await repository.loginWithAuthorizationCode('sample-code');

    expect(authStore.savedToken, isNotNull);
    expect(authStore.savedToken?.accessToken, 'token');
    expect(authStore.savedToken?.refreshToken, 'refresh');
    expect(authStore.savedToken?.scope, 'basic,netdisk');
  });
}

class _FakeBaiduPanAuthStore implements BaiduPanAuthStore {
  BaiduPanAuthToken? savedToken;

  @override
  Future<void> clearToken() async {
    savedToken = null;
  }

  @override
  Future<BaiduPanAuthToken?> readToken() async => savedToken;

  @override
  Future<void> writeToken(BaiduPanAuthToken token) async {
    savedToken = token;
  }
}

class _FakeHttpClient implements HttpClient {
  _FakeHttpClient.forJson(Map<String, Object?> json)
    : _payload = jsonEncode(json).codeUnits;

  final List<int> _payload;

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    return _FakeHttpClientRequest(_payload);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this._payload);

  final List<int> _payload;
  int? _contentLength;

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  set contentLength(int value) {
    _contentLength = value;
  }

  @override
  Future<HttpClientResponse> close() async {
    return _FakeHttpClientResponse(_payload);
  }

  @override
  void add(List<int> data) {
    _contentLength ??= data.length;
  }

  @override
  void write(Object? object) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse(this._payload);

  final List<int> _payload;

  @override
  int get statusCode => 200;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable(<List<int>>[_payload]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
