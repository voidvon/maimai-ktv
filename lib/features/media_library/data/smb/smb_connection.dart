import 'dart:typed_data';

import 'package:dart_smb2/dart_smb2.dart';

import 'smb_models.dart';

abstract class SmbConnection {
  Future<SmbRemoteFile> stat(String path);

  Future<List<SmbRemoteFile>> listDirectory(String path);

  Future<Stream<Uint8List>> openRead(String path, {int start = 0});

  Future<void> close();
}

typedef SmbConnectionFactory =
    Future<SmbConnection> Function({
      required SmbSourceConfig config,
      required String password,
    });

typedef SmbShareLister =
    Future<List<SmbShare>> Function({
      required String host,
      required String username,
      required String password,
      required String domain,
    });

Future<List<SmbShare>> listPackageSmbShares({
  required String host,
  required String username,
  required String password,
  required String domain,
}) async {
  final List<Smb2ShareInfo> shares = await Smb2Pool.listSharesOn(
    host: host,
    user: username.trim().isEmpty ? null : username,
    password: password.trim().isEmpty ? null : password,
    domain: domain.trim().isEmpty ? null : domain,
  );
  return shares
      .where(
        (Smb2ShareInfo share) =>
            share.isDisk && !share.isHidden && share.name.trim().isNotEmpty,
      )
      .map((Smb2ShareInfo share) => SmbShare(name: share.name.trim()))
      .toList(growable: false);
}

Future<SmbConnection> createPackageSmbConnection({
  required SmbSourceConfig config,
  required String password,
}) async {
  final Smb2Pool connection = await Smb2Pool.connect(
    host: config.host,
    share: config.share,
    user: config.username.trim().isEmpty ? null : config.username,
    password: password.trim().isEmpty ? null : password,
    domain: config.domain.trim().isEmpty ? null : config.domain,
    workers: 1,
    version: Smb2Version.any3,
    signing: true,
  );
  return DartSmb2Connection(connection);
}

class DartSmb2Connection implements SmbConnection {
  DartSmb2Connection(this._connection);

  final Smb2Pool _connection;

  @override
  Future<SmbRemoteFile> stat(String path) async {
    final String relativePath = _toRelativePath(path);
    try {
      final Smb2Stat stat = await _connection.stat(relativePath);
      return _mapStat(path, stat);
    } on Smb2Exception catch (error) {
      throw SmbException('SMB 路径不存在：$path', error);
    }
  }

  @override
  Future<List<SmbRemoteFile>> listDirectory(String path) async {
    final String normalizedPath = _normalizeRemotePath(path);
    final String relativePath = _toRelativePath(normalizedPath);
    try {
      final List<Smb2DirEntry> entries = await _connection.listDirectory(
        relativePath,
      );
      return entries
          .map(
            (Smb2DirEntry entry) =>
                _mapEntry(parentPath: normalizedPath, entry: entry),
          )
          .toList(growable: false);
    } on Smb2Exception catch (error) {
      throw SmbException('SMB 目录不存在：$path', error);
    }
  }

  @override
  Future<Stream<Uint8List>> openRead(String path, {int start = 0}) async {
    if (start < 0) {
      throw const SmbException('SMB 读取偏移不能小于 0');
    }
    final String relativePath = _toRelativePath(path);
    final (Smb2PoolHandle handle, int size) = await _connection
        .openFileWithSize(relativePath);
    if (start >= size) {
      await _connection.closeHandle(handle);
      return const Stream<Uint8List>.empty();
    }
    return _readFromHandle(handle, start: start, size: size);
  }

  @override
  Future<void> close() => _connection.disconnect();

  Stream<Uint8List> _readFromHandle(
    Smb2PoolHandle handle, {
    required int start,
    required int size,
  }) async* {
    int offset = start;
    try {
      while (offset < size) {
        final int length = (size - offset).clamp(1, 1024 * 1024);
        final Uint8List chunk = await _connection.readFromHandle(
          handle,
          offset: offset,
          length: length,
        );
        if (chunk.isEmpty) {
          throw SmbException('SMB 文件读取不完整：$offset / $size 字节');
        }
        offset += chunk.length;
        yield chunk;
      }
    } finally {
      await _connection.closeHandle(handle);
    }
  }

  SmbRemoteFile _mapEntry({
    required String parentPath,
    required Smb2DirEntry entry,
  }) {
    final String path = _joinRemotePath(parentPath, entry.name);
    return SmbRemoteFile(
      fileId: path,
      path: path,
      serverFilename: entry.name,
      isDirectory: entry.isDirectory,
      size: entry.size,
      modifiedAtMillis: entry.stat.modified.millisecondsSinceEpoch,
      rawPayload: <String, Object?>{
        'type': entry.stat.type.name,
        'createdAtMillis': entry.stat.created.millisecondsSinceEpoch,
      },
    );
  }

  SmbRemoteFile _mapStat(String path, Smb2Stat stat) {
    final String normalizedPath = _normalizeRemotePath(path);
    final String name = normalizedPath == '/'
        ? '/'
        : normalizedPath.split('/').last;
    return SmbRemoteFile(
      fileId: normalizedPath,
      path: normalizedPath,
      serverFilename: name,
      isDirectory: stat.isDirectory,
      size: stat.size,
      modifiedAtMillis: stat.modified.millisecondsSinceEpoch,
      rawPayload: <String, Object?>{
        'type': stat.type.name,
        'createdAtMillis': stat.created.millisecondsSinceEpoch,
      },
    );
  }

  String _toRelativePath(String value) {
    final String normalized = _normalizeRemotePath(value);
    return normalized == '/' ? '' : normalized.substring(1);
  }

  String _normalizeRemotePath(String value) {
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

  String _joinRemotePath(String parentPath, String name) {
    final String normalizedParent = _normalizeRemotePath(parentPath);
    final String normalizedName = name.trim().replaceAll('/', '');
    if (normalizedName.isEmpty ||
        normalizedName == '.' ||
        normalizedName == '..') {
      throw const SmbException('SMB 返回了无效的文件名');
    }
    return normalizedParent == '/'
        ? '/$normalizedName'
        : '$normalizedParent/$normalizedName';
  }
}
