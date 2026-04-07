import 'dart:convert';

import '../../../../core/models/song.dart';
import '../../../../core/models/song_identity.dart';
import '../media_index_store.dart';
import '../song_metadata_parser.dart';
import 'baidu_pan_models.dart';

class BaiduPanSongMapper {
  BaiduPanSongMapper({SongMetadataParser? songMetadataParser})
    : _songMetadataParser = songMetadataParser ?? const SongMetadataParser();

  final SongMetadataParser _songMetadataParser;

  Song mapRemoteFileToSong(BaiduPanRemoteFile file) {
    if (file.isDirectory) {
      throw ArgumentError.value(file.path, 'file', '目录不能映射成歌曲');
    }

    final ParsedSongMetadata metadata = _songMetadataParser.parseFileName(
      file.serverFilename,
    );
    return Song(
      songId: buildAggregateSongId(
        title: metadata.title,
        artist: metadata.artist,
      ),
      sourceId: 'baidu_pan',
      sourceSongId: file.fsid,
      title: metadata.title,
      artist: metadata.artist,
      languages: metadata.languages,
      tags: metadata.tags,
      searchIndex:
          '${metadata.title} ${metadata.artist} ${metadata.languages.join(' ')} '
                  '${metadata.tags.join(' ')} ${file.serverFilename} ${file.path}'
              .toLowerCase(),
      mediaPath: '',
    );
  }

  SourceSongRecord mapRemoteFileToSourceRecord({
    required BaiduPanRemoteFile file,
    required String sourceRootId,
  }) {
    if (file.isDirectory) {
      throw ArgumentError.value(file.path, 'file', '目录不能映射成歌曲');
    }

    final Song song = mapRemoteFileToSong(file);
    return SourceSongRecord(
      sourceType: 'baidu_pan',
      sourceSongId: file.fsid,
      sourceRootId: sourceRootId,
      title: song.title,
      artist: song.artist,
      languages: song.languages,
      tags: song.tags,
      searchIndex: song.searchIndex,
      mediaLocator: file.path,
      fileFingerprint: file.md5?.trim().isNotEmpty == true
          ? 'md5:${file.md5}'
          : buildLocalMetadataFingerprint(
              locator: file.path,
              fileSize: file.size,
              modifiedAtMillis: file.modifiedAtMillis,
            ),
      fileSize: file.size,
      modifiedAtMillis: file.modifiedAtMillis,
      rawPayloadJson: jsonEncode(file.rawPayload ?? <String, Object?>{}),
    );
  }
}
