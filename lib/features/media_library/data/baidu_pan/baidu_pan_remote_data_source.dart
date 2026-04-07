import 'baidu_pan_api_client.dart';
import 'baidu_pan_models.dart';

abstract class BaiduPanRemoteDataSource {
  Future<List<BaiduPanRemoteFile>> scanRoot(String rootPath);

  Future<List<BaiduPanRemoteFile>> searchFiles({
    required String keyword,
    String? rootPath,
  });

  Future<BaiduPanRemoteFile> getPlayableFileMeta(String fsid);
}

class DefaultBaiduPanRemoteDataSource implements BaiduPanRemoteDataSource {
  const DefaultBaiduPanRemoteDataSource({required BaiduPanApiClient apiClient})
    : _apiClient = apiClient;

  final BaiduPanApiClient _apiClient;

  @override
  Future<BaiduPanRemoteFile> getPlayableFileMeta(String fsid) {
    return _apiClient.getFileMeta(fsid: fsid, withDlink: true);
  }

  @override
  Future<List<BaiduPanRemoteFile>> scanRoot(String rootPath) {
    return _apiClient.listAll(path: rootPath);
  }

  @override
  Future<List<BaiduPanRemoteFile>> searchFiles({
    required String keyword,
    String? rootPath,
  }) {
    return _apiClient.search(key: keyword, path: rootPath);
  }
}
