import '../cloud/cloud_remote_data_source.dart';
import 'smb_client.dart';
import 'smb_models.dart';

abstract class SmbRemoteDataSource
    extends CloudRemoteDataSource<SmbRemoteFile> {}

class DefaultSmbRemoteDataSource implements SmbRemoteDataSource {
  const DefaultSmbRemoteDataSource({required SmbClient client})
    : _client = client;

  final SmbClient _client;

  @override
  Future<SmbRemoteFile> getPlayableFileMeta(String fileId) {
    return _client.getFileMeta(fileId);
  }

  @override
  Future<List<SmbRemoteFile>> scanRoot(String rootPath) {
    return _client.scanRoot(rootPath);
  }

  @override
  Future<List<SmbRemoteFile>> searchFiles({
    required String keyword,
    String? rootPath,
  }) async {
    final String query = keyword.trim().toLowerCase();
    final List<SmbRemoteFile> files = await scanRoot(rootPath ?? '/');
    if (query.isEmpty) {
      return files;
    }
    return files
        .where(
          (SmbRemoteFile file) =>
              file.serverFilename.toLowerCase().contains(query) ||
              file.path.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }
}
