import 'package:flutter/foundation.dart';

import '../../media_library/data/cloud/cloud_auth_repository.dart';
import '../../media_library/data/cloud/cloud_models.dart';
import '../../media_library/data/cloud/cloud_source_config_store.dart';

typedef CloudSourceConfigFactory<TConfig extends CloudSourceConfig> =
    TConfig Function(String rootPath);

class CloudSourceSettingsController<
  TConfig extends CloudSourceConfig,
  TToken extends CloudAuthToken,
  TUserInfo extends CloudUserInfo,
  TQuotaInfo extends CloudQuotaInfo
>
    extends ChangeNotifier {
  CloudSourceSettingsController({
    required String providerLabel,
    required CloudAppCredentials appCredentials,
    required CloudAuthRepository<TToken> authRepository,
    required CloudSourceConfigStore<TConfig> sourceConfigStore,
    required Future<TUserInfo> Function() loadUserInfo,
    required Future<TQuotaInfo> Function() loadQuotaInfo,
    required CloudSourceConfigFactory<TConfig> configFactory,
    this.rootPathLabel = '歌曲根目录',
  }) : _providerLabel = providerLabel,
       _appCredentials = appCredentials,
       _authRepository = authRepository,
       _sourceConfigStore = sourceConfigStore,
       _loadUserInfo = loadUserInfo,
       _loadQuotaInfo = loadQuotaInfo,
       _configFactory = configFactory;

  final String _providerLabel;
  final CloudAppCredentials _appCredentials;
  final CloudAuthRepository<TToken> _authRepository;
  final CloudSourceConfigStore<TConfig> _sourceConfigStore;
  final Future<TUserInfo> Function() _loadUserInfo;
  final Future<TQuotaInfo> Function() _loadQuotaInfo;
  final CloudSourceConfigFactory<TConfig> _configFactory;
  final String rootPathLabel;

  TConfig? _sourceConfig;
  TToken? _authToken;
  TUserInfo? _userInfo;
  TQuotaInfo? _quotaInfo;
  Uri? _authorizeUri;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isLoggingIn = false;
  String? _errorMessage;

  CloudAppCredentials get appCredentials => _appCredentials;
  TConfig? get sourceConfig => _sourceConfig;
  TToken? get authToken => _authToken;
  TUserInfo? get userInfo => _userInfo;
  TQuotaInfo? get quotaInfo => _quotaInfo;
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
    final TQuotaInfo? quota = _quotaInfo;
    if (quota == null) {
      return null;
    }
    return '${_formatBytes(quota.usedBytes)} / ${_formatBytes(quota.totalBytes)}';
  }

  bool get canRefreshRemoteFolder =>
      isAuthorized && (rootPath?.trim().isNotEmpty ?? false);

  @protected
  String get expiredSessionMessage => '$_providerLabel登录已过期，请重新登录。';

  @protected
  void setErrorMessage(String? message) {
    _errorMessage = message;
  }

  @protected
  Future<void> applyAuthorizedToken(TToken token) async {
    _authToken = token;
    _errorMessage = null;
    await _loadAccountSummary();
  }

  @protected
  void clearAuthorizedSessionState() {
    _authToken = null;
    _userInfo = null;
    _quotaInfo = null;
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _sourceConfig = await _sourceConfigStore.loadConfig();
      _authorizeUri = await _authRepository.buildAuthorizeUri();
      final TToken? storedToken = await _authRepository.readToken();
      final bool hasStoredSession =
          storedToken != null && storedToken.accessToken.trim().isNotEmpty;
      final bool hasValidSession = hasStoredSession
          ? await _authRepository.hasValidSession()
          : false;
      _authToken = hasValidSession ? await _authRepository.readToken() : null;
      if (_authToken != null) {
        await _loadAccountSummary();
      } else {
        clearAuthorizedSessionState();
        if (hasStoredSession) {
          _errorMessage = expiredSessionMessage;
        }
      }
    } catch (error) {
      _errorMessage = '加载$_providerLabel配置失败：$error';
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
      _errorMessage = '生成$_providerLabel登录链接失败：$error';
    }
    notifyListeners();
  }

  Future<bool> loginWithAuthorizationCode(String code) async {
    final String normalizedCode = code.trim();
    if (normalizedCode.isEmpty) {
      _errorMessage = '请输入$_providerLabel返回的授权码。';
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
      _errorMessage = '$_providerLabel登录失败：$error';
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
      clearAuthorizedSessionState();
    } catch (error) {
      _errorMessage = '$_providerLabel退出登录失败：$error';
    } finally {
      _isLoggingIn = false;
      notifyListeners();
    }
  }

  Future<bool> saveSettings({required String rootPath}) async {
    final String normalizedRootPath = rootPath.trim();

    if (normalizedRootPath.isEmpty) {
      _errorMessage = '请填写$_providerLabel$rootPathLabel。';
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final TConfig nextConfig = _configFactory(normalizedRootPath);
      await _sourceConfigStore.saveConfig(nextConfig);
      _sourceConfig = nextConfig;
      return true;
    } catch (error) {
      _errorMessage = '保存$_providerLabel配置失败：$error';
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
      _errorMessage = '清空$_providerLabel配置失败：$error';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> _loadAccountSummary() async {
    _userInfo = await _loadUserInfo();
    _quotaInfo = await _loadQuotaInfo();
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
