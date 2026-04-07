import '../../media_library/data/cloud/cloud_song_download_service.dart';

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
    this.progress = 0,
    this.phaseLabel = '准备下载',
  });

  final String songId;
  final String sourceId;
  final String sourceSongId;
  final String title;
  final String artist;
  final int startedAtMillis;
  final double progress;
  final String phaseLabel;

  String get sourceLabel => mapDownloadSourceLabel(sourceId);
  String get displayArtist => artist.trim().isEmpty ? '未知歌手' : artist;
  int get progressPercent => (progress.clamp(0, 1) * 100).round();

  DownloadingSongItem copyWith({double? progress, String? phaseLabel}) {
    return DownloadingSongItem(
      songId: songId,
      sourceId: sourceId,
      sourceSongId: sourceSongId,
      title: title,
      artist: artist,
      startedAtMillis: startedAtMillis,
      progress: progress ?? this.progress,
      phaseLabel: phaseLabel ?? this.phaseLabel,
    );
  }
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
