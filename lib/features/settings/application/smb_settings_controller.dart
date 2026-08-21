import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../media_library/data/smb/smb_client.dart';
import '../../media_library/data/smb/smb_credential_store.dart';
import '../../media_library/data/smb/smb_models.dart';
import '../../media_library/data/smb/smb_source_config_store.dart';

class SmbSettingsController extends ChangeNotifier {
  SmbSettingsController({
    required SmbSourceConfigStore configStore,
    required SmbCredentialStore credentialStore,
    required SmbClient client,
  }) : _configStore = configStore,
       _credentialStore = credentialStore,
       _client = client;

  final SmbSourceConfigStore _configStore;
  final SmbCredentialStore _credentialStore;
  final SmbClient _client;

  SmbSourceConfig? _config;
  bool _hasPassword = false;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isTesting = false;
  bool _isBrowsing = false;
  String? _errorMessage;
  String? _successMessage;

  String? get host => _config?.host;
  String? get share => _config?.share;
  String? get username => _config?.username;
  String? get domain => _config?.domain;
  String? get rootPath => _config?.rootPath;
  bool get hasPassword => _hasPassword;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isTesting => _isTesting;
  bool get isBrowsing => _isBrowsing;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  bool get isConfigured =>
      _config != null &&
      _config!.host.isNotEmpty &&
      _config!.share.isNotEmpty &&
      _config!.rootPath.isNotEmpty;

  void clearMessages() {
    if (_errorMessage == null && _successMessage == null) {
      return;
    }
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _config = await _configStore.loadConfig();
      _hasPassword =
          (await _credentialStore.readPassword())?.isNotEmpty == true;
    } catch (error) {
      _errorMessage = '加载 SMB 配置失败：$error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> testConnection({
    required String host,
    required String share,
    required String username,
    required String password,
    required String domain,
    required String rootPath,
  }) async {
    _isTesting = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
    try {
      final SmbSourceConfig draft = _buildConfig(
        host: host,
        share: share,
        username: username,
        domain: domain,
        rootPath: rootPath,
      );
      final String effectivePassword = password.isNotEmpty
          ? password
          : await _credentialStore.readPassword() ?? '';
      await _client.testConnection(config: draft, password: effectivePassword);
      _successMessage = '连接成功，可以保存并扫描歌曲目录。';
      return true;
    } catch (error) {
      _errorMessage = 'SMB 连接失败：$error';
      return false;
    } finally {
      _isTesting = false;
      notifyListeners();
    }
  }

  Future<bool> saveSettings({
    required String host,
    required String share,
    required String username,
    required String password,
    required String domain,
    required String rootPath,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
    try {
      final SmbSourceConfig next = _buildConfig(
        host: host,
        share: share,
        username: username,
        domain: domain,
        rootPath: rootPath,
      );
      if (password.isNotEmpty) {
        await _credentialStore.writePassword(password);
        _hasPassword = true;
      } else if (username.trim().isEmpty) {
        await _credentialStore.clearPassword();
        _hasPassword = false;
      }
      await _configStore.saveConfig(next);
      _config = next;
      _successMessage = 'SMB 配置已保存。';
      return true;
    } catch (error) {
      _errorMessage = '保存 SMB 配置失败：$error';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<List<SmbShare>> listShares({
    required String host,
    required String username,
    required String password,
    required String domain,
    bool useStoredPassword = true,
  }) async {
    _isBrowsing = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
    try {
      final String normalizedHost = _normalizeHost(host);
      final String effectivePassword = password.isNotEmpty
          ? password
          : useStoredPassword
          ? await _credentialStore.readPassword() ?? ''
          : '';
      return await _client.listShares(
        host: normalizedHost,
        username: username.trim(),
        password: effectivePassword,
        domain: domain.trim(),
      );
    } catch (error) {
      _errorMessage = '读取 SMB 共享失败：$error';
      rethrow;
    } finally {
      _isBrowsing = false;
      notifyListeners();
    }
  }

  Future<List<SmbRemoteFile>> listDirectories({
    required String host,
    required String share,
    required String username,
    required String password,
    required String domain,
    required String path,
  }) async {
    _isBrowsing = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final SmbSourceConfig draft = _buildConfig(
        host: host,
        share: share,
        username: username,
        domain: domain,
        rootPath: path,
      );
      final String effectivePassword = password.isNotEmpty
          ? password
          : await _credentialStore.readPassword() ?? '';
      return await _client.listDirectories(
        config: draft,
        password: effectivePassword,
        path: path,
      );
    } catch (error) {
      _errorMessage = '读取 SMB 目录失败：$error';
      rethrow;
    } finally {
      _isBrowsing = false;
      notifyListeners();
    }
  }

  Future<void> clearSettings() async {
    _isSaving = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
    try {
      await _configStore.clearConfig();
      await _credentialStore.clearPassword();
      _config = null;
      _hasPassword = false;
    } catch (error) {
      _errorMessage = '清空 SMB 配置失败：$error';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  SmbSourceConfig _buildConfig({
    required String host,
    required String share,
    required String username,
    required String domain,
    required String rootPath,
  }) {
    final String normalizedHost = _normalizeHost(host);
    final String normalizedShare = share.trim().replaceAll('\\', '/');
    final String normalizedUsername = username.trim();
    final String normalizedDomain = domain.trim();
    final String normalizedRoot = _normalizeRootPath(rootPath);
    if (normalizedShare.isEmpty ||
        normalizedShare.contains('/') ||
        normalizedShare == '.' ||
        normalizedShare == '..') {
      throw const SmbException('共享名称不能为空且不能包含路径');
    }
    final String identity = sha1
        .convert(
          utf8.encode(
            '$normalizedHost\n$normalizedShare\n$normalizedDomain\n'
            '$normalizedUsername\n$normalizedRoot',
          ),
        )
        .toString();
    return SmbSourceConfig(
      sourceRootId: 'smb:$identity',
      rootPath: normalizedRoot,
      displayName: 'SMB',
      host: normalizedHost,
      share: normalizedShare,
      username: normalizedUsername,
      domain: normalizedDomain,
    );
  }

  String _normalizeHost(String value) {
    final String normalizedHost = value.trim();
    if (normalizedHost.isEmpty ||
        normalizedHost.contains('://') ||
        normalizedHost.contains('/') ||
        normalizedHost.contains(RegExp(r'\s'))) {
      throw const SmbException('服务器地址应只填写主机名或 IP 地址');
    }
    return normalizedHost;
  }

  String _normalizeRootPath(String value) {
    final String normalized = value
        .trim()
        .replaceAll('\\', '/')
        .replaceAll(RegExp(r'/+'), '/');
    final List<String> segments = normalized
        .split('/')
        .where((String segment) => segment.isNotEmpty)
        .toList(growable: false);
    if (segments.contains('..')) {
      throw const SmbException('歌曲目录不能包含 ..');
    }
    return segments.isEmpty ? '/' : '/${segments.join('/')}';
  }
}
