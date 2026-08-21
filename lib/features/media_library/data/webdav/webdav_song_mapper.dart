import 'dart:convert';

import '../../../../core/models/song_identity.dart';
import '../media_index_store.dart';
import '../song_metadata_parser.dart';
import 'webdav_models.dart';

class WebDavSongMapper {
  WebDavSongMapper({SongMetadataParser? songMetadataParser})
    : _songMetadataParser = songMetadataParser ?? const SongMetadataParser();

  final SongMetadataParser _songMetadataParser;

  SourceSongRecord mapRemoteFileToSourceRecord({
    required WebDavRemoteFile file,
    required String sourceRootId,
  }) {
    final ParsedSongMetadata metadata = _songMetadataParser.parseFileName(
      file.serverFilename,
    );
    final String fingerprint = file.etag?.trim().isNotEmpty == true
        ? 'etag:${file.etag}'
        : buildLocalMetadataFingerprint(
            locator: file.path,
            fileSize: file.size,
            modifiedAtMillis: file.modifiedAtMillis,
          );
    return SourceSongRecord(
      sourceType: 'webdav',
      sourceSongId: file.fileId,
      sourceRootId: sourceRootId,
      title: metadata.title,
      artist: metadata.artist,
      languages: metadata.languages,
      tags: metadata.tags,
      searchIndex:
          '${metadata.title} ${metadata.artist} ${metadata.languages.join(' ')} '
                  '${metadata.tags.join(' ')} ${file.serverFilename} ${file.path}'
              .toLowerCase(),
      mediaLocator: file.path,
      fileFingerprint: fingerprint,
      fileSize: file.size,
      modifiedAtMillis: file.modifiedAtMillis,
      rawPayloadJson: jsonEncode(file.rawPayload ?? <String, Object?>{}),
    );
  }
}
