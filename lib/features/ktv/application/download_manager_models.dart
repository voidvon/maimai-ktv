import '../../media_library/data/cloud/cloud_song_download_service.dart';
import '../../../core/models/song.dart';

enum DownloadTaskStatus { downloading, paused, failed }

final RegExp _retryableHttpStatusPattern = RegExp(
  r'(?:下载失败|接口返回异常):\s*(\d{3})',
);

String mapDownloadSourceLabel(String sourceId) {
  switch (sourceId) {
    case 'baidu_pan':
      return '百度网盘';
    case 'local':
      return '本地目录';
    default:
      return sourceId;
  }
}

class DownloadingSongItem {
  const DownloadingSongItem({
    required this.songId,
    required this.sourceId,
    required this.sourceSongId,
    required this.title,
    required this.artist,
    required this.startedAtMillis,
    required this.updatedAtMillis,
    this.preferredDirectory,
    this.status = DownloadTaskStatus.downloading,
    this.progress = 0,
    this.phaseLabel = '准备下载',
    this.errorMessage,
  });

  final String songId;
  final String sourceId;
  final String sourceSongId;
  final String title;
  final String artist;
  final int startedAtMillis;
  final int updatedAtMillis;
  final String? preferredDirectory;
  final DownloadTaskStatus status;
  final double progress;
  final String phaseLabel;
  final String? errorMessage;

  String get sourceLabel => mapDownloadSourceLabel(sourceId);
  String get displayArtist => artist.trim().isEmpty ? '未知歌手' : artist;
  int get progressPercent => (progress.clamp(0, 1) * 100).round();
  bool get isDownloading => status == DownloadTaskStatus.downloading;
  bool get isPaused => status == DownloadTaskStatus.paused;
  bool get isFailed => status == DownloadTaskStatus.failed;
  bool get canPause => isDownloading;
  bool get canResume => isPaused || isFailed;
  bool get isAutoRetryableFailure =>
      isFailed && isRetryableDownloadErrorMessage(errorMessage);
  bool get isAuthorizationFailure =>
      isFailed && isAuthorizationDownloadErrorMessage(errorMessage);
  String get displayErrorMessage =>
      buildDownloadErrorSummary(errorMessage, fallback: '下载失败');

  Song toSong() {
    return Song(
      songId: songId,
      sourceId: sourceId,
      sourceSongId: sourceSongId,
      title: title,
      artist: artist,
      languages: const <String>[],
      searchIndex: '$title $artist'.trim().toLowerCase(),
      mediaPath: '',
    );
  }

  DownloadingSongItem copyWith({
    int? updatedAtMillis,
    String? preferredDirectory,
    DownloadTaskStatus? status,
    double? progress,
    String? phaseLabel,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return DownloadingSongItem(
      songId: songId,
      sourceId: sourceId,
      sourceSongId: sourceSongId,
      title: title,
      artist: artist,
      startedAtMillis: startedAtMillis,
      updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
      preferredDirectory: preferredDirectory ?? this.preferredDirectory,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      phaseLabel: phaseLabel ?? this.phaseLabel,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'songId': songId,
      'sourceId': sourceId,
      'sourceSongId': sourceSongId,
      'title': title,
      'artist': artist,
      'startedAtMillis': startedAtMillis,
      'updatedAtMillis': updatedAtMillis,
      'preferredDirectory': preferredDirectory,
      'status': status.name,
      'progress': progress,
      'phaseLabel': phaseLabel,
      'errorMessage': errorMessage,
    };
  }

  factory DownloadingSongItem.fromJson(Map<String, Object?> json) {
    final String rawStatus = json['status']?.toString() ?? '';
    final DownloadTaskStatus status = DownloadTaskStatus.values.firstWhere(
      (DownloadTaskStatus value) => value.name == rawStatus,
      orElse: () => DownloadTaskStatus.paused,
    );
    return DownloadingSongItem(
      songId: json['songId']?.toString() ?? '',
      sourceId: json['sourceId']?.toString() ?? '',
      sourceSongId: json['sourceSongId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
      startedAtMillis:
          int.tryParse(json['startedAtMillis']?.toString() ?? '') ?? 0,
      updatedAtMillis:
          int.tryParse(json['updatedAtMillis']?.toString() ?? '') ?? 0,
      preferredDirectory: json['preferredDirectory']?.toString(),
      status: status,
      progress: double.tryParse(json['progress']?.toString() ?? '') ?? 0,
      phaseLabel: json['phaseLabel']?.toString() ?? '准备下载',
      errorMessage: json['errorMessage']?.toString(),
    );
  }
}

bool isRetryableDownloadErrorMessage(String? errorMessage) {
  final String normalized = errorMessage?.trim() ?? '';
  if (normalized.isEmpty) {
    return false;
  }

  final String lower = normalized.toLowerCase();
  if (lower.contains('socketexception') ||
      lower.contains('timeoutexception') ||
      lower.contains('clientexception') ||
      lower.contains('handshakeexception') ||
      lower.contains('connection reset') ||
      lower.contains('broken pipe') ||
      lower.contains('connection aborted') ||
      lower.contains('software caused connection abort') ||
      lower.contains('network is unreachable') ||
      lower.contains('failed host lookup') ||
      lower.contains('temporary failure in name resolution') ||
      lower.contains('connection closed before full header was received') ||
      lower.contains('connection terminated') ||
      lower.contains('connection closed') ||
      lower.contains('operation timed out')) {
    return true;
  }

  final RegExpMatch? statusMatch = _retryableHttpStatusPattern.firstMatch(
    normalized,
  );
  if (statusMatch != null) {
    final int? statusCode = int.tryParse(statusMatch.group(1) ?? '');
    if (statusCode == null) {
      return false;
    }
    return statusCode == 408 ||
        statusCode == 425 ||
        statusCode == 429 ||
        statusCode >= 500;
  }

  return false;
}

bool isAuthorizationDownloadErrorMessage(String? errorMessage) {
  final String normalized = errorMessage?.trim() ?? '';
  if (normalized.isEmpty) {
    return false;
  }

  final String lower = normalized.toLowerCase();
  if (lower.contains('baidupanunauthorizedexception') ||
      lower.contains('baidupantokenexpiredexception') ||
      lower.contains('未授权') ||
      lower.contains('授权已过期') ||
      lower.contains('授权失败') ||
      lower.contains('token 接口返回异常') ||
      lower.contains('access_denied') ||
      lower.contains('expired_token')) {
    return true;
  }

  final RegExpMatch? statusMatch = _retryableHttpStatusPattern.firstMatch(
    normalized,
  );
  if (statusMatch != null) {
    final int? statusCode = int.tryParse(statusMatch.group(1) ?? '');
    return statusCode == 401 || statusCode == 403;
  }

  return false;
}

String buildDownloadErrorSummary(
  String? errorMessage, {
  String fallback = '下载失败',
}) {
  final String normalized = errorMessage?.trim() ?? '';
  if (normalized.isEmpty) {
    return fallback;
  }
  if (isAuthorizationDownloadErrorMessage(normalized)) {
    return '登录已失效，请重新登录';
  }
  if (isRetryableDownloadErrorMessage(normalized)) {
    return '下载失败，请稍后重试';
  }

  final String lower = normalized.toLowerCase();
  if (lower.contains('缺少可下载 dlink') ||
      lower.contains('filenotfound') ||
      lower.contains('文件不存在')) {
    return '下载失败，文件不可用';
  }
  if (lower.contains('下载服务未启用')) {
    return '下载失败，下载服务不可用';
  }

  return fallback;
}

class DownloadedSongItem {
  const DownloadedSongItem({
    required this.sourceId,
    required this.sourceSongId,
    required this.title,
    required this.artist,
    required this.savedPath,
    required this.savedAtMillis,
  });

  final String sourceId;
  final String sourceSongId;
  final String title;
  final String artist;
  final String savedPath;
  final int savedAtMillis;

  String get sourceLabel => mapDownloadSourceLabel(sourceId);
  String get displayTitle {
    final String normalizedPath = savedPath.replaceAll('\\', '/');
    final String fileName = normalizedPath.split('/').last;
    final int extensionIndex = fileName.lastIndexOf('.');
    final String fallbackTitle = extensionIndex > 0
        ? fileName.substring(0, extensionIndex)
        : fileName;
    return title.trim().isEmpty ? fallbackTitle : title;
  }

  String get displayArtist => artist.trim().isEmpty ? '未知歌手' : artist;

  factory DownloadedSongItem.fromRecord(CloudDownloadedSongRecord record) {
    return DownloadedSongItem(
      sourceId: record.sourceId,
      sourceSongId: record.sourceSongId,
      title: record.title,
      artist: record.artist,
      savedPath: record.savedPath,
      savedAtMillis: record.savedAtMillis,
    );
  }
}
