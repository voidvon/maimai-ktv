import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ktv2_example/features/media_library/data/baidu_pan/baidu_pan_api_client.dart';
import 'package:ktv2_example/features/media_library/data/baidu_pan/baidu_pan_auth_repository.dart';
import 'package:ktv2_example/features/media_library/data/baidu_pan/baidu_pan_models.dart';
import 'package:ktv2_example/features/media_library/data/baidu_pan/baidu_pan_source_config_store.dart';
import 'package:ktv2_example/features/settings/application/baidu_pan_settings_controller.dart';

void main() {
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('load restores saved baidu pan settings', () async {
    final _FakeBaiduPanSourceConfigStore sourceConfigStore =
        _FakeBaiduPanSourceConfigStore(
          config: const BaiduPanSourceConfig(
            sourceRootId: 'baidu_pan:/KTV',
            rootPath: '/KTV',
            displayName: '百度网盘',
          ),
        );
    final _FakeBaiduPanAuthRepository authRepository =
        _FakeBaiduPanAuthRepository(
          authorizeUri: Uri.parse('https://example.com/login'),
          token: BaiduPanAuthToken(
            accessToken: 'token',
            refreshToken: 'refresh',
            expiresAtMillis: DateTime.now()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch,
          ),
          hasValidSessionValue: true,
        );
    final BaiduPanSettingsController controller = BaiduPanSettingsController(
      appCredentials: const BaiduPanAppCredentials(
        appId: '122751914',
        appKey: 'app-key',
        secretKey: 'secret-key',
        signKey: 'sign-key',
      ),
      apiClient: _FakeBaiduPanApiClient(),
      authRepository: authRepository,
      sourceConfigStore: sourceConfigStore,
    );

    await controller.load();

    expect(controller.isConfigured, isTrue);
    expect(controller.isAuthorized, isTrue);
    expect(controller.authorizeUrlText, 'https://example.com/login');
    expect(controller.appId, '122751914');
    expect(controller.accountDisplayName, '测试账号');
    expect(controller.quotaSummary, isNotNull);
    expect(controller.rootPath, '/KTV');
    expect(controller.errorMessage, isNull);
  });

  test('load prepares device login session when unauthorized', () async {
    final BaiduPanSettingsController controller = BaiduPanSettingsController(
      appCredentials: const BaiduPanAppCredentials(
        appId: '122751914',
        appKey: 'app-key',
        secretKey: 'secret-key',
        signKey: 'sign-key',
      ),
      apiClient: _FakeBaiduPanApiClient(),
      authRepository: _FakeBaiduPanAuthRepository(
        authorizeUri: Uri.parse('https://example.com/login'),
        deviceCodeSession: BaiduPanDeviceCodeSession(
          deviceCode: 'device-code',
          userCode: 'user-code',
          verificationUrl: 'https://openapi.baidu.com/device',
          qrcodeUrl: 'https://openapi.baidu.com/device/qrcode/demo',
          expiresAtMillis: DateTime.now()
              .add(const Duration(minutes: 5))
              .millisecondsSinceEpoch,
          intervalSeconds: 5,
        ),
      ),
      sourceConfigStore: _FakeBaiduPanSourceConfigStore(),
    );

    await controller.load();

    expect(controller.isAuthorized, isFalse);
    expect(controller.deviceCodeSession, isNotNull);
    expect(controller.deviceCodeSession?.qrcodeUrl, contains('/qrcode/'));
  });

  test('ensureDeviceLoginSession reuses in-flight preparation', () async {
    final Completer<void> createCompleter = Completer<void>();
    final _FakeBaiduPanAuthRepository authRepository =
        _FakeBaiduPanAuthRepository(
          authorizeUri: Uri.parse('https://example.com/login'),
          createDeviceCodeSessionHandler: () async {
            await createCompleter.future;
            return BaiduPanDeviceCodeSession(
              deviceCode: 'device-code',
              userCode: 'user-code',
              verificationUrl: 'https://openapi.baidu.com/device',
              qrcodeUrl: 'https://openapi.baidu.com/device/qrcode/demo',
              expiresAtMillis: DateTime.now()
                  .add(const Duration(minutes: 5))
                  .millisecondsSinceEpoch,
              intervalSeconds: 5,
            );
          },
        );
    final BaiduPanSettingsController controller = BaiduPanSettingsController(
      appCredentials: const BaiduPanAppCredentials(
        appId: '122751914',
        appKey: 'app-key',
        secretKey: 'secret-key',
        signKey: 'sign-key',
      ),
      apiClient: _FakeBaiduPanApiClient(),
      authRepository: authRepository,
      sourceConfigStore: _FakeBaiduPanSourceConfigStore(),
    );

    final Future<void> first = controller.ensureDeviceLoginSession();
    final Future<void> second = controller.ensureDeviceLoginSession();
    createCompleter.complete();
    await Future.wait(<Future<void>>[first, second]);

    expect(authRepository.createDeviceCodeSessionCallCount, 1);
    expect(controller.deviceCodeSession, isNotNull);
  });

  test('load does not prepare qr login session on android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final _FakeBaiduPanAuthRepository authRepository =
        _FakeBaiduPanAuthRepository(
          authorizeUri: Uri.parse('https://example.com/login'),
        );
    final BaiduPanSettingsController controller = BaiduPanSettingsController(
      appCredentials: const BaiduPanAppCredentials(
        appId: '122751914',
        appKey: 'app-key',
        secretKey: 'secret-key',
        signKey: 'sign-key',
      ),
      apiClient: _FakeBaiduPanApiClient(),
      authRepository: authRepository,
      sourceConfigStore: _FakeBaiduPanSourceConfigStore(),
    );

    await controller.load();

    expect(controller.supportsQrLogin, isFalse);
    expect(controller.deviceCodeSession, isNull);
    expect(authRepository.createDeviceCodeSessionCallCount, 0);
  });

  test('saveSettings validates root path', () async {
    final BaiduPanSettingsController controller = BaiduPanSettingsController(
      appCredentials: const BaiduPanAppCredentials(
        appId: '122751914',
        appKey: 'app-key',
        secretKey: 'secret-key',
        signKey: 'sign-key',
      ),
      apiClient: _FakeBaiduPanApiClient(),
      authRepository: _FakeBaiduPanAuthRepository(
        authorizeUri: Uri.parse('https://example.com/login'),
      ),
      sourceConfigStore: _FakeBaiduPanSourceConfigStore(),
    );

    final bool saved = await controller.saveSettings(rootPath: ' ');

    expect(saved, isFalse);
    expect(controller.errorMessage, contains('歌曲根目录'));
  });

  test('saveSettings persists source config only', () async {
    final _FakeBaiduPanSourceConfigStore sourceConfigStore =
        _FakeBaiduPanSourceConfigStore();
    final BaiduPanSettingsController controller = BaiduPanSettingsController(
      appCredentials: const BaiduPanAppCredentials(
        appId: '122751914',
        appKey: 'app-key',
        secretKey: 'secret-key',
        signKey: 'sign-key',
      ),
      apiClient: _FakeBaiduPanApiClient(),
      authRepository: _FakeBaiduPanAuthRepository(
        authorizeUri: Uri.parse('https://example.com/login'),
      ),
      sourceConfigStore: sourceConfigStore,
    );

    final bool saved = await controller.saveSettings(rootPath: '/KTV');

    expect(saved, isTrue);
    expect(sourceConfigStore.savedConfig?.rootPath, '/KTV');
    expect(controller.isConfigured, isTrue);
  });

  test('clearSettings removes saved values', () async {
    final _FakeBaiduPanSourceConfigStore sourceConfigStore =
        _FakeBaiduPanSourceConfigStore();
    final BaiduPanSettingsController controller = BaiduPanSettingsController(
      appCredentials: const BaiduPanAppCredentials(
        appId: '122751914',
        appKey: 'app-key',
        secretKey: 'secret-key',
        signKey: 'sign-key',
      ),
      apiClient: _FakeBaiduPanApiClient(),
      authRepository: _FakeBaiduPanAuthRepository(
        authorizeUri: Uri.parse('https://example.com/login'),
      ),
      sourceConfigStore: sourceConfigStore,
    );

    await controller.saveSettings(rootPath: '/KTV');
    await controller.clearSettings();

    expect(sourceConfigStore.clearCallCount, 1);
    expect(controller.isConfigured, isFalse);
    expect(controller.rootPath, isNull);
  });

  test('loginWithAuthorizationCode updates authorized state', () async {
    final _FakeBaiduPanAuthRepository authRepository =
        _FakeBaiduPanAuthRepository(
          authorizeUri: Uri.parse('https://example.com/login'),
          token: BaiduPanAuthToken(
            accessToken: 'token',
            refreshToken: 'refresh',
            expiresAtMillis: DateTime.now()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch,
          ),
        );
    final BaiduPanSettingsController controller = BaiduPanSettingsController(
      appCredentials: const BaiduPanAppCredentials(
        appId: '122751914',
        appKey: 'app-key',
        secretKey: 'secret-key',
        signKey: 'sign-key',
      ),
      apiClient: _FakeBaiduPanApiClient(),
      authRepository: authRepository,
      sourceConfigStore: _FakeBaiduPanSourceConfigStore(),
    );

    final bool success = await controller.loginWithAuthorizationCode(
      'sample-code',
    );

    expect(success, isTrue);
    expect(authRepository.lastLoginCode, 'sample-code');
    expect(controller.isAuthorized, isTrue);
    expect(controller.accountDisplayName, '测试账号');
  });

  test('logout clears authorized state', () async {
    final _FakeBaiduPanAuthRepository authRepository =
        _FakeBaiduPanAuthRepository(
          authorizeUri: Uri.parse('https://example.com/login'),
          token: BaiduPanAuthToken(
            accessToken: 'token',
            refreshToken: 'refresh',
            expiresAtMillis: DateTime.now()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch,
          ),
          hasValidSessionValue: true,
        );
    final BaiduPanSettingsController controller = BaiduPanSettingsController(
      appCredentials: const BaiduPanAppCredentials(
        appId: '122751914',
        appKey: 'app-key',
        secretKey: 'secret-key',
        signKey: 'sign-key',
      ),
      apiClient: _FakeBaiduPanApiClient(),
      authRepository: authRepository,
      sourceConfigStore: _FakeBaiduPanSourceConfigStore(),
    );
    await controller.load();

    await controller.logout();

    expect(authRepository.logoutCallCount, 1);
    expect(controller.isAuthorized, isFalse);
    expect(controller.deviceCodeSession, isNotNull);
  });
}

class _FakeBaiduPanAuthRepository implements BaiduPanAuthRepository {
  _FakeBaiduPanAuthRepository({
    required this.authorizeUri,
    this.token,
    this.deviceCodeSession,
    this.hasValidSessionValue = false,
    this.createDeviceCodeSessionHandler,
  });

  final Uri authorizeUri;
  BaiduPanAuthToken? token;
  BaiduPanDeviceCodeSession? deviceCodeSession;
  bool hasValidSessionValue;
  final Future<BaiduPanDeviceCodeSession> Function()?
  createDeviceCodeSessionHandler;
  String? lastLoginCode;
  int logoutCallCount = 0;
  int createDeviceCodeSessionCallCount = 0;

  @override
  Future<Uri> buildAuthorizeUri() async => authorizeUri;

  @override
  Future<BaiduPanDeviceCodeSession> createDeviceCodeSession() async {
    createDeviceCodeSessionCallCount += 1;
    final Future<BaiduPanDeviceCodeSession> Function()? createHandler =
        createDeviceCodeSessionHandler;
    if (createHandler != null) {
      return createHandler();
    }
    return deviceCodeSession ??
        BaiduPanDeviceCodeSession(
          deviceCode: 'device-code',
          userCode: 'user-code',
          verificationUrl: 'https://openapi.baidu.com/device',
          qrcodeUrl: 'https://openapi.baidu.com/device/qrcode/demo',
          expiresAtMillis: DateTime.now()
              .add(const Duration(minutes: 5))
              .millisecondsSinceEpoch,
          intervalSeconds: 5,
        );
  }

  @override
  Future<String> getValidAccessToken() async => token?.accessToken ?? '';

  @override
  Future<bool> hasValidSession() async => hasValidSessionValue;

  @override
  Future<void> loginWithAuthorizationCode(String code) async {
    lastLoginCode = code;
    token ??= BaiduPanAuthToken(
      accessToken: 'token',
      refreshToken: 'refresh',
      expiresAtMillis: DateTime.now()
          .add(const Duration(hours: 1))
          .millisecondsSinceEpoch,
    );
    hasValidSessionValue = true;
  }

  @override
  Future<BaiduPanAuthToken?> loginWithDeviceCode(String deviceCode) async {
    token ??= BaiduPanAuthToken(
      accessToken: 'token',
      refreshToken: 'refresh',
      expiresAtMillis: DateTime.now()
          .add(const Duration(hours: 1))
          .millisecondsSinceEpoch,
    );
    hasValidSessionValue = true;
    return token;
  }

  @override
  Future<void> logout() async {
    logoutCallCount += 1;
    token = null;
    hasValidSessionValue = false;
  }

  @override
  Future<BaiduPanAuthToken?> readToken() async => token;
}

class _FakeBaiduPanApiClient implements BaiduPanApiClient {
  @override
  Future<BaiduPanQuotaInfo> getQuota() async {
    return const BaiduPanQuotaInfo(totalBytes: 1024, usedBytes: 256);
  }

  @override
  Future<BaiduPanUserInfo> getUserInfo() async {
    return const BaiduPanUserInfo(
      uk: '12345',
      displayName: '测试账号',
      avatarUrl: 'https://example.com/avatar.png',
    );
  }

  @override
  Future<BaiduPanRemoteFile> getFileMeta({
    required String fsid,
    bool withDlink = false,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<BaiduPanRemoteFile>> listAll({
    required String path,
    int start = 0,
    int limit = 1000,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<BaiduPanRemoteFile>> listDirectory({
    required String path,
    int start = 0,
    int limit = 1000,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<BaiduPanRemoteFile>> search({
    required String key,
    String? path,
    int page = 1,
    int num = 100,
  }) async {
    throw UnimplementedError();
  }
}

class _FakeBaiduPanSourceConfigStore implements BaiduPanSourceConfigStore {
  _FakeBaiduPanSourceConfigStore({this.config});

  BaiduPanSourceConfig? config;
  BaiduPanSourceConfig? savedConfig;
  int clearCallCount = 0;

  @override
  Future<void> clearConfig() async {
    clearCallCount += 1;
    config = null;
  }

  @override
  Future<BaiduPanSourceConfig?> loadConfig() async => config;

  @override
  Future<void> saveConfig(BaiduPanSourceConfig config) async {
    this.config = config;
    savedConfig = config;
  }
}
