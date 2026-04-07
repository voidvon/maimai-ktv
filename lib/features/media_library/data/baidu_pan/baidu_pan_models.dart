import '../cloud/cloud_models.dart';

class BaiduPanAuthToken extends CloudAuthToken {
  const BaiduPanAuthToken({
    required super.accessToken,
    required super.refreshToken,
    required super.expiresAtMillis,
    super.scope,
    this.sessionKey,
    this.sessionSecret,
  });

  final String? sessionKey;
  final String? sessionSecret;
}

class BaiduPanSourceConfig extends CloudSourceConfig {
  const BaiduPanSourceConfig({
    required super.sourceRootId,
    required super.rootPath,
    required super.displayName,
    super.syncToken,
    super.lastSyncedAtMillis,
  });
}

class BaiduPanAppCredentials extends CloudAppCredentials {
  const BaiduPanAppCredentials({
    required super.appId,
    required super.appKey,
    required super.secretKey,
    required super.signKey,
    super.redirectUri = 'oob',
    super.scope = 'basic,netdisk',
  });
}

class BaiduPanRemoteFile extends CloudRemoteFile {
  const BaiduPanRemoteFile({
    required this.fsid,
    required super.path,
    required super.serverFilename,
    required super.isDirectory,
    required super.size,
    required super.modifiedAtMillis,
    super.md5,
    super.category,
    super.dlink,
    super.rawPayload,
  }) : super(fileId: fsid);

  final String fsid;
}

class BaiduPanUserInfo extends CloudUserInfo {
  const BaiduPanUserInfo({
    required this.uk,
    required super.displayName,
    super.avatarUrl,
    this.vipType,
  }) : super(accountId: uk, accountTier: vipType);

  final String uk;
  final int? vipType;
}

class BaiduPanQuotaInfo extends CloudQuotaInfo {
  const BaiduPanQuotaInfo({
    required super.totalBytes,
    required super.usedBytes,
    super.freeBytes,
  });
}

class BaiduPanDeviceCodeSession {
  const BaiduPanDeviceCodeSession({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUrl,
    required this.qrcodeUrl,
    required this.expiresAtMillis,
    required this.intervalSeconds,
  });

  final String deviceCode;
  final String userCode;
  final String verificationUrl;
  final String qrcodeUrl;
  final int expiresAtMillis;
  final int intervalSeconds;

  bool get isExpired =>
      DateTime.now().millisecondsSinceEpoch >= expiresAtMillis;
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
