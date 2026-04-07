import 'dart:io';
import 'dart:convert';

import 'package:lpinyin/lpinyin.dart';
import 'package:path/path.dart' as path;
import 'package:ktv2_example/core/media/supported_video_formats.dart';

import '../../../core/models/song_identity.dart';
import 'media_index_store.dart';
import 'song_metadata_parser.dart';

class MediaLibraryDataSource {
  MediaLibraryDataSource({SongMetadataParser? songMetadataParser})
    : _songMetadataParser = songMetadataParser ?? const SongMetadataParser();

  final SongMetadataParser _songMetadataParser;

  Future<List<LibrarySong>> scanLibrary(
    String rootPath, {
    Map<String, CachedLocalSongFingerprint> cachedFingerprintsByPath =
        const <String, CachedLocalSongFingerprint>{},
  }) async {
    final Directory directory = Directory(rootPath);
    if (!await directory.exists()) {
      throw FileSystemException('媒体库目录不存在', rootPath);
    }

    final List<LibrarySong> songs = <LibrarySong>[];
    final List<Directory> directories = <Directory>[directory];

    while (directories.isNotEmpty) {
      final Directory current = directories.removeLast();
      List<FileSystemEntity> entities;

      try {
        entities = await current.list(followLinks: false).toList();
      } on FileSystemException {
        continue;
      }

      for (final FileSystemEntity entity in entities) {
        if (entity is Directory) {
          directories.add(entity);
          continue;
        }

        if (entity is! File) {
          continue;
        }

        final FileStat stat = await entity.stat();

        final String fileName = _extractFileName(entity.path);
        final String extension = extractVideoExtension(fileName);
        if (!supportedVideoExtensionSet.contains(extension)) {
          continue;
        }

        final ParsedSongMetadata metadata = _songMetadataParser.parseFileName(
          fileName,
        );
        final String relativePathValue = path.relative(
          entity.path,
          from: rootPath,
        );
        final CachedLocalSongFingerprint? cachedFingerprint =
            cachedFingerprintsByPath[entity.path] ??
            cachedFingerprintsByPath[relativePathValue];
        final String sourceFingerprint = await _buildLocalSourceFingerprint(
          entity,
          stat,
          cachedFingerprint: cachedFingerprint,
        );
        songs.add(
          LibrarySong(
            title: metadata.title,
            artist: metadata.artist,
            mediaPath: entity.path,
            fileName: fileName,
            relativePath: relativePathValue,
            fileSize: stat.size,
            modifiedAtMillis: stat.modified.millisecondsSinceEpoch,
            sourceFingerprint: sourceFingerprint,
            extension: extension,
            languages: metadata.languages,
            tags: metadata.tags,
          ),
        );
      }
    }

    songs.sort((LibrarySong left, LibrarySong right) {
      final int titleCompare = left.title.compareTo(right.title);
      if (titleCompare != 0) {
        return titleCompare;
      }
      return left.artist.compareTo(right.artist);
    });

    return songs;
  }

  String _extractFileName(String path) {
    final String normalizedPath = path.replaceAll('\\', '/');
    return normalizedPath.split('/').last;
  }

  Future<String> _buildLocalSourceFingerprint(
    File file,
    FileStat stat, {
    CachedLocalSongFingerprint? cachedFingerprint,
  }) async {
    if (cachedFingerprint != null &&
        cachedFingerprint.matches(
          nextFileSize: stat.size,
          nextModifiedAtMillis: stat.modified.millisecondsSinceEpoch,
        ) &&
        cachedFingerprint.sourceFingerprint.trim().isNotEmpty) {
      return cachedFingerprint.sourceFingerprint;
    }
    try {
      const int chunkSize = 64 * 1024;
      final int fileSize = stat.size;
      final RandomAccessFile randomAccessFile = await file.open();
      try {
        final List<List<int>> chunks = <List<int>>[
          utf8.encode('v1:$fileSize:'),
        ];
        final int headSize = fileSize < chunkSize ? fileSize : chunkSize;
        if (headSize > 0) {
          chunks.add(await randomAccessFile.read(headSize));
        }
        if (fileSize > chunkSize) {
          final int tailSize = fileSize <= chunkSize * 2
              ? fileSize - headSize
              : chunkSize;
          if (tailSize > 0) {
            await randomAccessFile.setPosition(fileSize - tailSize);
            chunks.add(await randomAccessFile.read(tailSize));
          }
        }
        final int hashValue = _computeFnv1a64(chunks);
        final String hashText = hashValue
            .toUnsigned(64)
            .toRadixString(16)
            .padLeft(16, '0');
        return 'content:$fileSize:$hashText';
      } finally {
        await randomAccessFile.close();
      }
    } on FileSystemException {
      return buildLocalMetadataFingerprint(
        locator: file.path,
        fileSize: stat.size,
        modifiedAtMillis: stat.modified.millisecondsSinceEpoch,
      );
    }
  }
}

class LibrarySong {
  const LibrarySong({
    required this.title,
    required this.artist,
    required this.mediaPath,
    required this.fileName,
    required this.relativePath,
    required this.fileSize,
    required this.modifiedAtMillis,
    required this.sourceFingerprint,
    required this.extension,
    this.languages = const <String>['其它'],
    this.tags = const <String>[],
  });

  final String title;
  final String artist;
  final String mediaPath;
  final String fileName;
  final String relativePath;
  final int fileSize;
  final int modifiedAtMillis;
  final String sourceFingerprint;
  final String extension;
  final List<String> languages;
  final List<String> tags;

  String get sourceSongId =>
      buildLocalSourceSongId(fingerprint: sourceFingerprint);

  String get searchIndex {
    final String raw =
        '$title $artist ${languages.join(' ')} ${tags.join(' ')} $fileName $extension'
            .toLowerCase();
    final String titleInitials = _buildPinyinInitials(title);
    final String artistInitials = _buildPinyinInitials(artist);
    return '$raw $titleInitials $artistInitials'.trim();
  }
}

int _computeFnv1a64(Iterable<List<int>> chunks) {
  const int offsetBasis = 0xcbf29ce484222325;
  const int prime = 0x100000001b3;
  const int mask = 0xffffffffffffffff;
  int hash = offsetBasis;
  for (final List<int> chunk in chunks) {
    for (final int byte in chunk) {
      hash ^= byte & 0xff;
      hash = (hash * prime) & mask;
    }
  }
  return hash;
}

String _buildPinyinInitials(String source) {
  final String normalizedSource = source.trim();
  if (normalizedSource.isEmpty) {
    return '';
  }

  // Intentionally use only initials, not full pinyin.
  final String initials = PinyinHelper.getShortPinyin(
    normalizedSource,
  ).toLowerCase();
  return initials.replaceAll(RegExp(r'[^a-z0-9]'), '');
}
