import 'dart:io';

import '../cloud/cloud_playback_cache.dart';
import 'smb_connection.dart';
import 'smb_credential_store.dart';
import 'smb_models.dart';
import 'smb_source_config_store.dart';

class SmbClient {
  SmbClient({
    required SmbSourceConfigStore configStore,
    required SmbCredentialStore credentialStore,
    SmbConnectionFactory? connectionFactory,
    SmbShareLister? shareLister,
  }) : _configStore = configStore,
       _credentialStore = credentialStore,
       _connectionFactory = connectionFactory ?? createPackageSmbConnection,
       _shareLister = shareLister ?? listPackageSmbShares;

  final SmbSourceConfigStore _configStore;
  final SmbCredentialStore _credentialStore;
  final SmbConnectionFactory _connectionFactory;
  final SmbShareLister _shareLister;

  Future<List<SmbShare>> listShares({
    required String host,
    required String username,
    required String password,
    required String domain,
  }) async {
    try {
      return await _shareLister(
        host: host,
        username: username,
        password: password,
        domain: domain,
      );
    } catch (error) {
      throw _wrapError('无法读取 SMB 共享列表', error);
    }
  }

  Future<void> testConnection({
    SmbSourceConfig? config,
    String? password,
  }) async {
    final _SmbResolvedConnection resolved = await _connect(
      config: config,
      password: password,
    );
    try {
      await resolved.connection.listDirectory(resolved.config.rootPath);
    } catch (error) {
      throw _wrapError('无法访问 SMB 歌曲目录', error);
    } finally {
      await resolved.connection.close();
    }
  }

  Future<List<SmbRemoteFile>> listDirectories({
    required String path,
    SmbSourceConfig? config,
    String? password,
  }) async {
    final _SmbResolvedConnection resolved = await _connect(
      config: config,
      password: password,
    );
    try {
      final List<SmbRemoteFile> entries = await resolved.connection
          .listDirectory(_normalizePath(path));
      return entries
          .where((SmbRemoteFile file) => file.isDirectory)
          .toList(growable: false);
    } catch (error) {
      throw _wrapError('读取 SMB 子目录失败', error);
    } finally {
      await resolved.connection.close();
    }
  }

  Future<List<SmbRemoteFile>> scanRoot(String rootPath) async {
    final _SmbResolvedConnection resolved = await _connect();
    try {
      final List<SmbRemoteFile> files = <SmbRemoteFile>[];
      final List<String> pending = <String>[_normalizePath(rootPath)];
      final Set<String> visited = <String>{};
      while (pending.isNotEmpty) {
        final String directory = pending.removeLast();
        if (!visited.add(directory)) {
          continue;
        }
        final List<SmbRemoteFile> children = await resolved.connection
            .listDirectory(directory);
        for (final SmbRemoteFile child in children) {
          files.add(child);
          if (child.isDirectory) {
            pending.add(child.path);
          }
        }
      }
      return files;
    } catch (error) {
      throw _wrapError('扫描 SMB 目录失败', error);
    } finally {
      await resolved.connection.close();
    }
  }

  Future<SmbRemoteFile> getFileMeta(String remotePath) async {
    final _SmbResolvedConnection resolved = await _connect();
    try {
      return await resolved.connection.stat(_normalizePath(remotePath));
    } catch (error) {
      throw _wrapError('读取 SMB 文件信息失败', error);
    } finally {
      await resolved.connection.close();
    }
  }

  Future<void> downloadFile({
    required String remotePath,
    required File targetFile,
    void Function(double progress)? onProgress,
    CloudDownloadCancellationToken? cancellationToken,
  }) async {
    final _SmbResolvedConnection resolved = await _connect();
    try {
      final SmbRemoteFile meta = await resolved.connection.stat(remotePath);
      await targetFile.parent.create(recursive: true);
      int existingBytes = await targetFile.exists()
          ? await targetFile.length()
          : 0;
      if (existingBytes > meta.size) {
        existingBytes = 0;
      }
      if (meta.size > 0 && existingBytes == meta.size) {
        onProgress?.call(1);
        return;
      }
      final Stream<List<int>> stream = await resolved.connection.openRead(
        remotePath,
        start: existingBytes,
      );
      int receivedBytes = existingBytes;
      final IOSink sink = targetFile.openWrite(
        mode: existingBytes > 0 ? FileMode.append : FileMode.write,
      );
      try {
        await for (final List<int> chunk in stream) {
          cancellationToken?.throwIfCancelled();
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (meta.size > 0) {
            onProgress?.call((receivedBytes / meta.size).clamp(0, 1));
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (meta.size > 0 && receivedBytes != meta.size) {
        throw SmbException('SMB 文件下载不完整：$receivedBytes / ${meta.size} 字节');
      }
      onProgress?.call(1);
    } catch (error) {
      if (error is CloudDownloadCancelledException) {
        rethrow;
      }
      throw _wrapError('下载 SMB 文件失败', error);
    } finally {
      await resolved.connection.close();
    }
  }

  Future<_SmbResolvedConnection> _connect({
    SmbSourceConfig? config,
    String? password,
  }) async {
    final SmbSourceConfig? resolvedConfig =
        config ?? await _configStore.loadConfig();
    if (resolvedConfig == null) {
      throw const SmbException('尚未配置 SMB');
    }
    final String resolvedPassword =
        password ?? await _credentialStore.readPassword() ?? '';
    try {
      return _SmbResolvedConnection(
        config: resolvedConfig,
        connection: await _connectionFactory(
          config: resolvedConfig,
          password: resolvedPassword,
        ),
      );
    } catch (error) {
      throw _wrapError('无法连接 SMB 服务器', error);
    }
  }

  String _normalizePath(String value) {
    final String normalized = value
        .trim()
        .replaceAll('\\', '/')
        .replaceAll(RegExp(r'/+'), '/');
    final List<String> segments = normalized
        .split('/')
        .where((String segment) => segment.isNotEmpty)
        .toList(growable: false);
    if (segments.contains('..')) {
      throw const SmbException('SMB 路径不能包含 ..');
    }
    return segments.isEmpty ? '/' : '/${segments.join('/')}';
  }

  SmbException _wrapError(String message, Object error) {
    return error is SmbException ? error : SmbException(message, error);
  }
}

class _SmbResolvedConnection {
  const _SmbResolvedConnection({
    required this.config,
    required this.connection,
  });

  final SmbSourceConfig config;
  final SmbConnection connection;
}
