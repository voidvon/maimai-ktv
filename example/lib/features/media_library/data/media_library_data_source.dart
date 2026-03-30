import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lpinyin/lpinyin.dart';

import 'android_storage_data_source.dart';

class DemoMediaLibraryDataSource {
  static const List<String> supportedExtensions = <String>[
    'mp4',
    'mkv',
    'avi',
    'mov',
    'dat',
    'rmvb',
    'rm',
    'mpg',
    'mpeg',
    'vob',
  ];

  final DemoAndroidStorageDataSource _androidStorageDataSource =
      DemoAndroidStorageDataSource();

  Future<List<DemoLibrarySong>> scanLibrary(String rootPath) async {
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        _androidStorageDataSource.isDocumentTreeUri(rootPath)) {
      final List<DemoAndroidLibrarySong> songs = await _androidStorageDataSource
          .scanLibrary(rootPath);
      return songs
          .map(
            (DemoAndroidLibrarySong song) => DemoLibrarySong(
              title: song.title,
              artist: song.artist,
              mediaPath: song.mediaPath,
              fileName: song.fileName,
              extension: song.extension,
            ),
          )
          .toList(growable: false);
    }

    final Directory directory = Directory(rootPath);
    if (!await directory.exists()) {
      throw FileSystemException('媒体库目录不存在', rootPath);
    }

    final List<DemoLibrarySong> songs = <DemoLibrarySong>[];
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

        final String fileName = _extractFileName(entity.path);
        final String extension = _extractExtension(fileName);
        if (!supportedExtensions.contains(extension)) {
          continue;
        }

        final _ParsedName metadata = _parseFileName(fileName);
        songs.add(
          DemoLibrarySong(
            title: metadata.title,
            artist: metadata.artist,
            mediaPath: entity.path,
            fileName: fileName,
            extension: extension,
          ),
        );
      }
    }

    songs.sort((DemoLibrarySong left, DemoLibrarySong right) {
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

  String _extractExtension(String fileName) {
    final int dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) {
      return '';
    }
    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  _ParsedName _parseFileName(String fileName) {
    final int dotIndex = fileName.lastIndexOf('.');
    final String baseName = dotIndex == -1
        ? fileName
        : fileName.substring(0, dotIndex);

    const List<String> separators = <String>[' - ', ' — ', ' – ', '_', '-'];
    for (final String separator in separators) {
      final int separatorIndex = baseName.indexOf(separator);
      if (separatorIndex <= 0 ||
          separatorIndex >= baseName.length - separator.length) {
        continue;
      }

      final String artist = baseName.substring(0, separatorIndex).trim();
      final String title = baseName
          .substring(separatorIndex + separator.length)
          .trim();
      if (artist.isNotEmpty && title.isNotEmpty) {
        return _ParsedName(title: title, artist: artist);
      }
    }

    return _ParsedName(title: baseName.trim(), artist: '未识别歌手');
  }
}

class DemoLibrarySong {
  const DemoLibrarySong({
    required this.title,
    required this.artist,
    required this.mediaPath,
    required this.fileName,
    required this.extension,
  });

  final String title;
  final String artist;
  final String mediaPath;
  final String fileName;
  final String extension;

  String get language => '其它';

  String get searchIndex {
    final String raw = '$title $artist $fileName $extension'.toLowerCase();
    final String titleInitials = _buildPinyinInitials(title);
    final String artistInitials = _buildPinyinInitials(artist);
    return '$raw $titleInitials $artistInitials'.trim();
  }
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

class _ParsedName {
  const _ParsedName({required this.title, required this.artist});

  final String title;
  final String artist;
}
