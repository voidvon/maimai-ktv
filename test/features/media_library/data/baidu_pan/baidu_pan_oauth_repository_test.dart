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

  test('createDeviceCodeSession parses qrcode session response', () async {
    final BaiduPanOAuthRepository repository = BaiduPanOAuthRepository(
      appCredentials: const BaiduPanAppCredentials(
        appId: '122751914',
        appKey: 'app-key',
        secretKey: 'secret-key',
        signKey: 'sign-key',
      ),
      authStore: _FakeBaiduPanAuthStore(),
      httpClient: _FakeHttpClient(
        getResponses: <_FakeResponseData>[
          _FakeResponseData(<String, Object?>{
            'device_code': 'device-code',
            'user_code': 'user-code',
            'verification_url': 'https://openapi.baidu.com/device',
            'qrcode_url': 'https://openapi.baidu.com/device/qrcode/demo',
            'expires_in': 300,
            'interval': 5,
          }),
        ],
      ),
    );

    final BaiduPanDeviceCodeSession session = await repository
        .createDeviceCodeSession();

    expect(session.deviceCode, 'device-code');
    expect(session.userCode, 'user-code');
    expect(session.verificationUrl, 'https://openapi.baidu.com/device');
    expect(session.qrcodeUrl, 'https://openapi.baidu.com/device/qrcode/demo');
    expect(session.intervalSeconds, 5);
    expect(session.isExpired, isFalse);
  });

  test(
    'loginWithDeviceCode stores token when authorization completed',
    () async {
      final _FakeBaiduPanAuthStore authStore = _FakeBaiduPanAuthStore();
      final BaiduPanOAuthRepository repository = BaiduPanOAuthRepository(
        appCredentials: const BaiduPanAppCredentials(
          appId: '122751914',
          appKey: 'app-key',
          secretKey: 'secret-key',
          signKey: 'sign-key',
        ),
        authStore: authStore,
        httpClient: _FakeHttpClient(
          postResponses: <_FakeResponseData>[
            _FakeResponseData(<String, Object?>{
              'access_token': 'token',
              'refresh_token': 'refresh',
              'expires_in': 3600,
            }),
          ],
        ),
      );

      final BaiduPanAuthToken? token = await repository.loginWithDeviceCode(
        'device-code',
      );

      expect(token, isNotNull);
      expect(authStore.savedToken?.accessToken, 'token');
      expect(authStore.savedToken?.refreshToken, 'refresh');
    },
  );

  test(
    'loginWithDeviceCode returns null while authorization pending',
    () async {
      final _FakeBaiduPanAuthStore authStore = _FakeBaiduPanAuthStore();
      final BaiduPanOAuthRepository repository = BaiduPanOAuthRepository(
        appCredentials: const BaiduPanAppCredentials(
          appId: '122751914',
          appKey: 'app-key',
          secretKey: 'secret-key',
          signKey: 'sign-key',
        ),
        authStore: authStore,
        httpClient: _FakeHttpClient(
          postResponses: <_FakeResponseData>[
            _FakeResponseData(<String, Object?>{
              'error': 'authorization_pending',
              'error_description': 'pending',
            }, statusCode: 400),
          ],
        ),
      );

      final BaiduPanAuthToken? token = await repository.loginWithDeviceCode(
        'device-code',
      );

      expect(token, isNull);
      expect(authStore.savedToken, isNull);
    },
  );
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
  _FakeHttpClient({
    List<_FakeResponseData>? getResponses,
    List<_FakeResponseData>? postResponses,
  }) : _getResponses = getResponses ?? <_FakeResponseData>[],
       _postResponses = postResponses ?? <_FakeResponseData>[];

  factory _FakeHttpClient.forJson(Map<String, Object?> json) {
    return _FakeHttpClient(
      postResponses: <_FakeResponseData>[_FakeResponseData(json)],
    );
  }

  final List<_FakeResponseData> _getResponses;
  final List<_FakeResponseData> _postResponses;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _FakeHttpClientRequest(_takeResponse(_getResponses));
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    return _FakeHttpClientRequest(_takeResponse(_postResponses));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  _FakeResponseData _takeResponse(List<_FakeResponseData> queue) {
    if (queue.isEmpty) {
      throw StateError('No queued fake response available');
    }
    return queue.removeAt(0);
  }
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this._responseData);

  final _FakeResponseData _responseData;
  int? _contentLength;

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  set contentLength(int value) {
    _contentLength = value;
  }

  @override
  Future<HttpClientResponse> close() async {
    return _FakeHttpClientResponse(_responseData);
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
  _FakeHttpClientResponse(this._responseData);

  final _FakeResponseData _responseData;

  @override
  int get statusCode => _responseData.statusCode;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable(<List<int>>[
      _responseData.payload,
    ]).listen(
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
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    final bool unusedPreserveHeaderCase = preserveHeaderCase;
    if (unusedPreserveHeaderCase) {
      return;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeResponseData {
  _FakeResponseData(Map<String, Object?> json, {this.statusCode = 200})
    : payload = jsonEncode(json).codeUnits;

  final int statusCode;
  final List<int> payload;
}
