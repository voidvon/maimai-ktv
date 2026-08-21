import '../cloud/cloud_song_source.dart';
import 'webdav_models.dart';
import 'webdav_remote_data_source.dart';
import 'webdav_song_mapper.dart';
import 'webdav_source_config_store.dart';

class WebDavSongSource
    extends CloudSongSource<WebDavSourceConfig, WebDavRemoteFile> {
  WebDavSongSource({
    required super.mediaLibraryRepository,
    required WebDavSourceConfigStore sourceConfigStore,
    required WebDavRemoteDataSource remoteDataSource,
    WebDavSongMapper? songMapper,
  }) : super(
         sourceId: 'webdav',
         sourceConfigStore: sourceConfigStore,
         remoteDataSource: remoteDataSource,
         sourceRecordMapper: _mapper(songMapper),
       );

  static CloudSourceSongRecordMapper<WebDavSourceConfig, WebDavRemoteFile>
  _mapper(WebDavSongMapper? mapper) {
    final WebDavSongMapper resolvedMapper = mapper ?? WebDavSongMapper();
    return ({
      required WebDavRemoteFile file,
      required WebDavSourceConfig config,
    }) {
      return resolvedMapper.mapRemoteFileToSourceRecord(
        file: file,
        sourceRootId: config.sourceRootId,
      );
    };
  }
}
