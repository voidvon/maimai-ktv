import 'package:flutter/foundation.dart';

import '../../media_library/data/baidu_pan/baidu_pan_api_client.dart';
import '../../media_library/data/baidu_pan/baidu_pan_auth_repository.dart';
import '../../media_library/data/baidu_pan/baidu_pan_models.dart';
import '../../media_library/data/baidu_pan/baidu_pan_source_config_store.dart';

class BaiduPanSettingsController extends ChangeNotifier {
  BaiduPanSettingsController({
    required BaiduPanAppCredentials appCredentials,
    required BaiduPanApiClient apiClient,
    required BaiduPanAuthRepository authRepository,
    required BaiduPanSourceConfigStore sourceConfigStore,
  }) : _appCredentials = appCredentials,
       _apiClient = apiClient,
       _authRepository = authRepository,
       _sourceConfigStore = sourceConfigStore;

  final BaiduPanAppCredentials _appCredentials;
  final BaiduPanApiClient _apiClient;
  final BaiduPanAuthRepository _authRepository;
  final BaiduPanSourceConfigStore _sourceConfigStore;

  BaiduPanSourceConfig? _sourceConfig;
  BaiduPanAuthToken? _authToken;
  BaiduPanUserInfo? _userInfo;
  BaiduPanQuotaInfo? _quotaInfo;
  Uri? _authorizeUri;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isLoggingIn = false;
  String? _errorMessage;

  BaiduPanAppCredentials get appCredentials => _appCredentials;
  BaiduPanSourceConfig? get sourceConfig => _sourceConfig;
  BaiduPanAuthToken? get authToken => _authToken;
  BaiduPanUserInfo? get userInfo => _userInfo;
  BaiduPanQuotaInfo? get quotaInfo => _quotaInfo;
  Uri? get authorizeUri => _authorizeUri;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isLoggingIn => _isLoggingIn;
  String? get errorMessage => _errorMessage;

  bool get isConfigured =>
      _appCredentials.isComplete &&
      (_sourceConfig?.rootPath.trim().isNotEmpty ?? false);

  bool get isAppConfigured => _appCredentials.isComplete;
  bool get isAuthorized =>
      _authToken != null &&
      _authToken!.accessToken.trim().isNotEmpty &&
      !_authToken!.isExpired;

  String get displayStatus => isConfigured ? '已配置' : '未配置';

  String? get rootPath => _sourceConfig?.rootPath;
  String get appId => _appCredentials.appId;
  String get redirectUri => _appCredentials.redirectUri;
  String get scope => _appCredentials.scope;
  String? get authorizeUrlText => _authorizeUri?.toString();
  DateTime? get tokenExpiresAt => _authToken == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(_authToken!.expiresAtMillis);
  String? get accountDisplayName => _userInfo?.displayName;
  String? get quotaSummary {
    final BaiduPanQuotaInfo? quota = _quotaInfo;
    if (quota == null) {
      return null;
    }
    return '${_formatBytes(quota.usedBytes)} / ${_formatBytes(quota.totalBytes)}';
  }

  bool get canRefreshRemoteFolder =>
      isAuthorized && (rootPath?.trim().isNotEmpty ?? false);

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _sourceConfig = await _sourceConfigStore.loadConfig();
      _authorizeUri = await _authRepository.buildAuthorizeUri();
      final bool hasValidSession = await _authRepository.hasValidSession();
      _authToken = hasValidSession ? await _authRepository.readToken() : null;
      if (_authToken != null) {
        await _loadAccountSummary();
      } else {
        _userInfo = null;
        _quotaInfo = null;
      }
    } catch (error) {
      _errorMessage = '加载百度网盘配置失败：$error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAuthorizeUri() async {
    _errorMessage = null;
    try {
      _authorizeUri = await _authRepository.buildAuthorizeUri();
    } catch (error) {
      _errorMessage = '生成百度网盘登录链接失败：$error';
    }
    notifyListeners();
  }

  Future<bool> loginWithAuthorizationCode(String code) async {
    final String normalizedCode = code.trim();
    if (normalizedCode.isEmpty) {
      _errorMessage = '请输入百度网盘返回的授权码。';
      notifyListeners();
      return false;
    }

    _isLoggingIn = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authRepository.loginWithAuthorizationCode(normalizedCode);
      _authToken = await _authRepository.readToken();
      await _loadAccountSummary();
      return true;
    } catch (error) {
      _errorMessage = '百度网盘登录失败：$error';
      return false;
    } finally {
      _isLoggingIn = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoggingIn = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authRepository.logout();
      _authToken = null;
      _userInfo = null;
      _quotaInfo = null;
    } catch (error) {
      _errorMessage = '百度网盘退出登录失败：$error';
    } finally {
      _isLoggingIn = false;
      notifyListeners();
    }
  }

  Future<bool> saveSettings({required String rootPath}) async {
    final String normalizedRootPath = rootPath.trim();

    if (normalizedRootPath.isEmpty) {
      _errorMessage = '请填写百度网盘歌曲根目录。';
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final BaiduPanSourceConfig nextConfig = BaiduPanSourceConfig(
        sourceRootId: 'baidu_pan:$normalizedRootPath',
        rootPath: normalizedRootPath,
        displayName: '百度网盘',
      );
      await _sourceConfigStore.saveConfig(nextConfig);
      _sourceConfig = nextConfig;
      return true;
    } catch (error) {
      _errorMessage = '保存百度网盘配置失败：$error';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> clearSettings() async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _sourceConfigStore.clearConfig();
      _sourceConfig = null;
    } catch (error) {
      _errorMessage = '清空百度网盘配置失败：$error';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> _loadAccountSummary() async {
    _userInfo = await _apiClient.getUserInfo();
    _quotaInfo = await _apiClient.getQuota();
  }

  String _formatBytes(int bytes) {
    const List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
    double value = bytes.toDouble();
    int unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex += 1;
    }
    final String fixed = value >= 100 || unitIndex == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$fixed ${units[unitIndex]}';
  }
}
