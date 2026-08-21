import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../media_library/data/webdav/webdav_client.dart';
import '../../media_library/data/webdav/webdav_credential_store.dart';
import '../../media_library/data/webdav/webdav_models.dart';
import '../../media_library/data/webdav/webdav_network_policy.dart';
import '../../media_library/data/webdav/webdav_source_config_store.dart';

class WebDavSettingsController extends ChangeNotifier {
  WebDavSettingsController({
    required WebDavSourceConfigStore configStore,
    required WebDavCredentialStore credentialStore,
    required WebDavClient client,
  }) : _configStore = configStore,
       _credentialStore = credentialStore,
       _client = client;

  final WebDavSourceConfigStore _configStore;
  final WebDavCredentialStore _credentialStore;
  final WebDavClient _client;

  WebDavSourceConfig? _config;
  bool _hasPassword = false;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isTesting = false;
  bool _isBrowsing = false;
  String? _errorMessage;
  String? _successMessage;

  WebDavSourceConfig? get config => _config;
  String? get serverUrl => _config?.serverUrl;
  String? get username => _config?.username;
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
      _config!.serverUrl.isNotEmpty &&
      _config!.username.isNotEmpty &&
      _config!.rootPath.isNotEmpty &&
      _hasPassword;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _config = await _configStore.loadConfig();
      _hasPassword =
          (await _credentialStore.readPassword())?.isNotEmpty == true;
    } catch (error) {
      _errorMessage = '加载 WebDAV 配置失败：$error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> testConnection({
    required String serverUrl,
    required String username,
    required String password,
    required String rootPath,
  }) async {
    _isTesting = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
    try {
      final WebDavSourceConfig draft = _buildConfig(
        serverUrl: serverUrl,
        username: username,
        rootPath: rootPath,
      );
      final String effectivePassword = password.trim().isNotEmpty
          ? password
          : await _credentialStore.readPassword() ?? '';
      if (effectivePassword.isEmpty) {
        throw const WebDavException('请输入 WebDAV 密码');
      }
      await _client.testConnection(config: draft, password: effectivePassword);
      _successMessage = '连接成功，可以保存并扫描歌曲目录。';
      return true;
    } catch (error) {
      _errorMessage = 'WebDAV 连接失败：$error';
      return false;
    } finally {
      _isTesting = false;
      notifyListeners();
    }
  }

  Future<bool> saveSettings({
    required String serverUrl,
    required String username,
    required String password,
    required String rootPath,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
    try {
      final WebDavSourceConfig next = _buildConfig(
        serverUrl: serverUrl,
        username: username,
        rootPath: rootPath,
      );
      if (password.isEmpty && !_hasPassword) {
        throw const WebDavException('请输入 WebDAV 密码');
      }
      if (password.isNotEmpty) {
        await _credentialStore.writePassword(password);
        _hasPassword = true;
      }
      await _configStore.saveConfig(next);
      _config = next;
      _successMessage = 'WebDAV 配置已保存。';
      return true;
    } catch (error) {
      _errorMessage = '保存 WebDAV 配置失败：$error';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<List<WebDavRemoteFile>> listDirectories({
    required String serverUrl,
    required String username,
    required String password,
    required String path,
  }) async {
    _isBrowsing = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
    try {
      final WebDavSourceConfig draft = _buildConfig(
        serverUrl: serverUrl,
        username: username,
        rootPath: path,
      );
      final String effectivePassword = password.trim().isNotEmpty
          ? password
          : await _credentialStore.readPassword() ?? '';
      if (effectivePassword.isEmpty) {
        throw const WebDavException('请输入 WebDAV 密码');
      }
      return await _client.listDirectories(
        config: draft,
        password: effectivePassword,
        path: path,
      );
    } catch (error) {
      _errorMessage = '读取 WebDAV 目录失败：$error';
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
      _errorMessage = '清空 WebDAV 配置失败：$error';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  WebDavSourceConfig _buildConfig({
    required String serverUrl,
    required String username,
    required String rootPath,
  }) {
    final String normalizedUrl = serverUrl.trim().replaceFirst(
      RegExp(r'/+$'),
      '',
    );
    final String normalizedUsername = username.trim();
    final String normalizedRoot = _normalizeRootPath(rootPath);
    final Uri? uri = Uri.tryParse(normalizedUrl);
    if (uri == null || !WebDavNetworkPolicy.allows(uri)) {
      throw const WebDavException('服务器地址必须使用 HTTPS，局域网地址可以使用 HTTP');
    }
    if (normalizedUsername.isEmpty) {
      throw const WebDavException('用户名不能为空');
    }
    final String identity = sha1
        .convert(
          utf8.encode('$normalizedUrl\n$normalizedUsername\n$normalizedRoot'),
        )
        .toString();
    return WebDavSourceConfig(
      sourceRootId: 'webdav:$identity',
      rootPath: normalizedRoot,
      displayName: 'WebDAV',
      serverUrl: normalizedUrl,
      username: normalizedUsername,
    );
  }

  String _normalizeRootPath(String value) {
    final String normalized = value.trim().replaceAll(RegExp(r'/+'), '/');
    if (normalized.isEmpty || normalized == '/') {
      return '/';
    }
    final String path = normalized.startsWith('/')
        ? normalized
        : '/$normalized';
    return path.endsWith('/') ? path.substring(0, path.length - 1) : path;
  }
}
