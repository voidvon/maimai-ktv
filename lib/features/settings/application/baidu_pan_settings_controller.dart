import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../media_library/data/baidu_pan/baidu_pan_api_client.dart';
import '../../media_library/data/baidu_pan/baidu_pan_auth_repository.dart';
import '../../media_library/data/baidu_pan/baidu_pan_models.dart';
import '../../media_library/data/baidu_pan/baidu_pan_source_config_store.dart';
import 'cloud_source_settings_controller.dart';

class BaiduPanSettingsController
    extends
        CloudSourceSettingsController<
          BaiduPanSourceConfig,
          BaiduPanAuthToken,
          BaiduPanUserInfo,
          BaiduPanQuotaInfo
        > {
  BaiduPanSettingsController({
    required BaiduPanAppCredentials appCredentials,
    required BaiduPanApiClient apiClient,
    required BaiduPanAuthRepository authRepository,
    required BaiduPanSourceConfigStore sourceConfigStore,
  }) : super(
         providerLabel: '百度网盘',
         appCredentials: appCredentials,
         authRepository: authRepository,
         sourceConfigStore: sourceConfigStore,
         loadUserInfo: apiClient.getUserInfo,
         loadQuotaInfo: apiClient.getQuota,
         configFactory: (String rootPath) {
           return BaiduPanSourceConfig(
             sourceRootId: 'baidu_pan:$rootPath',
             rootPath: rootPath,
             displayName: '百度网盘',
           );
         },
       ) {
    _authRepository = authRepository;
  }

  late final BaiduPanAuthRepository _authRepository;
  Timer? _deviceLoginTimer;
  BaiduPanDeviceCodeSession? _deviceCodeSession;
  bool _isPreparingDeviceLogin = false;
  bool _isPollingDeviceLogin = false;
  Future<void>? _deviceLoginPreparation;
  int _deviceLoginGeneration = 0;

  BaiduPanDeviceCodeSession? get deviceCodeSession => _deviceCodeSession;
  bool get isPreparingDeviceLogin => _isPreparingDeviceLogin;
  bool get hasActiveDeviceLogin =>
      _deviceCodeSession != null && !_deviceCodeSession!.isExpired;
  bool get supportsQrLogin =>
      !kIsWeb &&
      switch (defaultTargetPlatform) {
        TargetPlatform.macOS ||
        TargetPlatform.windows ||
        TargetPlatform.linux => true,
        _ => false,
      };

  @override
  Future<void> load() async {
    await super.load();
    if (!isAuthorized && supportsQrLogin) {
      await ensureDeviceLoginSession();
    }
  }

  Future<void> ensureDeviceLoginSession({bool forceRefresh = false}) async {
    if (isAuthorized || !isAppConfigured || !supportsQrLogin) {
      _deviceLoginTimer?.cancel();
      _deviceCodeSession = null;
      _isPreparingDeviceLogin = false;
      return;
    }
    final BaiduPanDeviceCodeSession? currentSession = _deviceCodeSession;
    if (!forceRefresh && currentSession != null && !currentSession.isExpired) {
      _startDeviceLoginPolling();
      notifyListeners();
      return;
    }
    final Future<void>? inFlightPreparation = _deviceLoginPreparation;
    if (!forceRefresh && inFlightPreparation != null) {
      await inFlightPreparation;
      return;
    }

    final int generation = ++_deviceLoginGeneration;
    final Future<void> preparation = _prepareDeviceLoginSession(generation);
    _deviceLoginPreparation = preparation;
    try {
      await preparation;
    } finally {
      if (identical(_deviceLoginPreparation, preparation)) {
        _deviceLoginPreparation = null;
      }
    }
  }

  Future<void> _prepareDeviceLoginSession(int generation) async {
    _deviceLoginTimer?.cancel();
    _deviceCodeSession = null;
    _isPreparingDeviceLogin = true;
    setErrorMessage(null);
    notifyListeners();
    try {
      final BaiduPanDeviceCodeSession session = await _authRepository
          .createDeviceCodeSession();
      if (generation != _deviceLoginGeneration || isAuthorized) {
        return;
      }
      _deviceCodeSession = session;
      _startDeviceLoginPolling();
    } catch (error) {
      if (generation != _deviceLoginGeneration) {
        return;
      }
      setErrorMessage('生成百度网盘登录二维码失败：$error');
    } finally {
      if (generation == _deviceLoginGeneration) {
        _isPreparingDeviceLogin = false;
        notifyListeners();
      }
    }
  }

  @override
  Future<void> logout() async {
    await super.logout();
    if (!isAuthorized && supportsQrLogin) {
      await ensureDeviceLoginSession(forceRefresh: true);
    }
  }

  void _startDeviceLoginPolling() {
    final BaiduPanDeviceCodeSession? session = _deviceCodeSession;
    if (session == null || session.isExpired) {
      return;
    }
    _deviceLoginTimer?.cancel();
    _deviceLoginTimer = Timer.periodic(
      Duration(seconds: session.intervalSeconds),
      (Timer timer) {
        unawaited(_pollDeviceLogin(session, timer));
      },
    );
  }

  Future<void> _pollDeviceLogin(
    BaiduPanDeviceCodeSession session,
    Timer timer,
  ) async {
    if (_isPollingDeviceLogin) {
      return;
    }
    if (!identical(_deviceCodeSession, session)) {
      timer.cancel();
      return;
    }
    if (session.isExpired) {
      timer.cancel();
      _deviceCodeSession = null;
      setErrorMessage('百度网盘登录二维码已过期，请刷新二维码后重试。');
      notifyListeners();
      return;
    }

    _isPollingDeviceLogin = true;
    try {
      final BaiduPanAuthToken? token = await _authRepository
          .loginWithDeviceCode(session.deviceCode);
      if (token == null) {
        return;
      }
      timer.cancel();
      _deviceCodeSession = null;
      await applyAuthorizedToken(token);
    } catch (error) {
      timer.cancel();
      _deviceCodeSession = null;
      setErrorMessage('百度网盘登录失败：$error');
    } finally {
      _isPollingDeviceLogin = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _deviceLoginTimer?.cancel();
    super.dispose();
  }
}
