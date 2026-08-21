import '../cloud/cloud_models.dart';

class SmbSourceConfig extends CloudSourceConfig {
  const SmbSourceConfig({
    required super.sourceRootId,
    required super.rootPath,
    required super.displayName,
    required this.host,
    required this.share,
    required this.username,
    this.domain = '',
    super.syncToken,
    super.lastSyncedAtMillis,
  });

  final String host;
  final String share;
  final String username;
  final String domain;
}

class SmbRemoteFile extends CloudRemoteFile {
  const SmbRemoteFile({
    required super.fileId,
    required super.path,
    required super.serverFilename,
    required super.isDirectory,
    required super.size,
    required super.modifiedAtMillis,
    super.rawPayload,
  });
}

class SmbShare {
  const SmbShare({required this.name});

  final String name;
}

class SmbException implements Exception {
  const SmbException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'SmbException: $message'
      : 'SmbException: $message ($cause)';
}
