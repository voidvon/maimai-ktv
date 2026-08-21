import 'dart:convert';

import '../../../../core/models/song_identity.dart';
import '../media_index_store.dart';
import '../song_metadata_parser.dart';
import 'smb_models.dart';

class SmbSongMapper {
  SmbSongMapper({SongMetadataParser? songMetadataParser})
    : _songMetadataParser = songMetadataParser ?? const SongMetadataParser();

  final SongMetadataParser _songMetadataParser;

  SourceSongRecord mapRemoteFileToSourceRecord({
    required SmbRemoteFile file,
    required String sourceRootId,
  }) {
    final ParsedSongMetadata metadata = _songMetadataParser.parseFileName(
      file.serverFilename,
    );
    return SourceSongRecord(
      sourceType: 'smb',
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
      fileFingerprint: buildLocalMetadataFingerprint(
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
