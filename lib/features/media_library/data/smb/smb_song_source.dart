import '../cloud/cloud_song_source.dart';
import 'smb_models.dart';
import 'smb_remote_data_source.dart';
import 'smb_song_mapper.dart';
import 'smb_source_config_store.dart';

class SmbSongSource extends CloudSongSource<SmbSourceConfig, SmbRemoteFile> {
  SmbSongSource({
    required super.mediaLibraryRepository,
    required SmbSourceConfigStore sourceConfigStore,
    required SmbRemoteDataSource remoteDataSource,
    SmbSongMapper? songMapper,
  }) : super(
         sourceId: 'smb',
         sourceConfigStore: sourceConfigStore,
         remoteDataSource: remoteDataSource,
         sourceRecordMapper: _mapper(songMapper),
       );

  static CloudSourceSongRecordMapper<SmbSourceConfig, SmbRemoteFile> _mapper(
    SmbSongMapper? mapper,
  ) {
    final SmbSongMapper resolvedMapper = mapper ?? SmbSongMapper();
    return ({required SmbRemoteFile file, required SmbSourceConfig config}) {
      return resolvedMapper.mapRemoteFileToSourceRecord(
        file: file,
        sourceRootId: config.sourceRootId,
      );
    };
  }
}
