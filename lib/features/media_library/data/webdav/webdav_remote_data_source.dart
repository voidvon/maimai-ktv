import '../cloud/cloud_remote_data_source.dart';
import 'webdav_client.dart';
import 'webdav_models.dart';

abstract class WebDavRemoteDataSource
    extends CloudRemoteDataSource<WebDavRemoteFile> {}

class DefaultWebDavRemoteDataSource implements WebDavRemoteDataSource {
  const DefaultWebDavRemoteDataSource({required WebDavClient client})
    : _client = client;

  final WebDavClient _client;

  @override
  Future<WebDavRemoteFile> getPlayableFileMeta(String fileId) {
    return _client.getFileMeta(fileId);
  }

  @override
  Future<List<WebDavRemoteFile>> scanRoot(String rootPath) {
    return _client.scanRoot(rootPath);
  }

  @override
  Future<List<WebDavRemoteFile>> searchFiles({
    required String keyword,
    String? rootPath,
  }) async {
    final String query = keyword.trim().toLowerCase();
    final List<WebDavRemoteFile> files = await scanRoot(rootPath ?? '/');
    if (query.isEmpty) {
      return files;
    }
    return files
        .where(
          (WebDavRemoteFile file) =>
              file.serverFilename.toLowerCase().contains(query) ||
              file.path.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }
}
