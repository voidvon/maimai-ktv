class BaiduPanAuthToken {
  const BaiduPanAuthToken({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAtMillis,
    this.scope,
    this.sessionKey,
    this.sessionSecret,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresAtMillis;
  final String? scope;
  final String? sessionKey;
  final String? sessionSecret;

  bool get isExpired =>
      DateTime.now().millisecondsSinceEpoch >= expiresAtMillis;

  bool willExpireWithin(Duration duration) {
    final int thresholdMillis = DateTime.now()
        .add(duration)
        .millisecondsSinceEpoch;
    return expiresAtMillis <= thresholdMillis;
  }
}

class BaiduPanSourceConfig {
  const BaiduPanSourceConfig({
    required this.sourceRootId,
    required this.rootPath,
    required this.displayName,
    this.syncToken,
    this.lastSyncedAtMillis,
  });

  final String sourceRootId;
  final String rootPath;
  final String displayName;
  final String? syncToken;
  final int? lastSyncedAtMillis;
}

class BaiduPanAppCredentials {
  const BaiduPanAppCredentials({
    required this.appId,
    required this.appKey,
    required this.secretKey,
    required this.signKey,
    this.redirectUri = 'oob',
    this.scope = 'basic,netdisk',
  });

  final String appId;
  final String appKey;
  final String secretKey;
  final String signKey;
  final String redirectUri;
  final String scope;

  bool get isComplete =>
      appId.trim().isNotEmpty &&
      appKey.trim().isNotEmpty &&
      secretKey.trim().isNotEmpty &&
      signKey.trim().isNotEmpty;
}

class BaiduPanRemoteFile {
  const BaiduPanRemoteFile({
    required this.fsid,
    required this.path,
    required this.serverFilename,
    required this.isDirectory,
    required this.size,
    required this.modifiedAtMillis,
    this.md5,
    this.category,
    this.dlink,
    this.rawPayload,
  });

  final String fsid;
  final String path;
  final String serverFilename;
  final bool isDirectory;
  final int size;
  final int modifiedAtMillis;
  final String? md5;
  final int? category;
  final String? dlink;
  final Map<String, Object?>? rawPayload;
}

class BaiduPanUserInfo {
  const BaiduPanUserInfo({
    required this.uk,
    required this.displayName,
    this.avatarUrl,
    this.vipType,
  });

  final String uk;
  final String displayName;
  final String? avatarUrl;
  final int? vipType;
}

class BaiduPanQuotaInfo {
  const BaiduPanQuotaInfo({
    required this.totalBytes,
    required this.usedBytes,
    this.freeBytes,
  });

  final int totalBytes;
  final int usedBytes;
  final int? freeBytes;

  int get availableBytes =>
      freeBytes ?? (totalBytes - usedBytes).clamp(0, totalBytes);
}

class BaiduPanUnauthorizedException implements Exception {
  const BaiduPanUnauthorizedException([this.message = '百度网盘未授权']);

  final String message;

  @override
  String toString() => 'BaiduPanUnauthorizedException: $message';
}

class BaiduPanTokenExpiredException implements Exception {
  const BaiduPanTokenExpiredException([this.message = '百度网盘授权已过期']);

  final String message;

  @override
  String toString() => 'BaiduPanTokenExpiredException: $message';
}

class BaiduPanFileNotFoundException implements Exception {
  const BaiduPanFileNotFoundException([this.message = '百度网盘文件不存在']);

  final String message;

  @override
  String toString() => 'BaiduPanFileNotFoundException: $message';
}

class BaiduPanDownloadForbiddenException implements Exception {
  const BaiduPanDownloadForbiddenException([this.message = '百度网盘下载被拒绝']);

  final String message;

  @override
  String toString() => 'BaiduPanDownloadForbiddenException: $message';
}
