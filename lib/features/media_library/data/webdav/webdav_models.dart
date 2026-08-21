import '../cloud/cloud_models.dart';

class WebDavSourceConfig extends CloudSourceConfig {
  const WebDavSourceConfig({
    required super.sourceRootId,
    required super.rootPath,
    required super.displayName,
    required this.serverUrl,
    required this.username,
    super.syncToken,
    super.lastSyncedAtMillis,
  });

  final String serverUrl;
  final String username;
}

class WebDavRemoteFile extends CloudRemoteFile {
  const WebDavRemoteFile({
    required super.fileId,
    required super.path,
    required super.serverFilename,
    required super.isDirectory,
    required super.size,
    required super.modifiedAtMillis,
    this.etag,
    super.rawPayload,
  }) : super(md5: etag);

  final String? etag;
}

class WebDavException implements Exception {
  const WebDavException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() {
    final int? code = statusCode;
    return code == null
        ? 'WebDavException: $message'
        : 'WebDavException($code): $message';
  }
}
