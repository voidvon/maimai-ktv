import 'baidu_pan_models.dart';

abstract class BaiduPanApiClient {
  Future<BaiduPanUserInfo> getUserInfo();

  Future<BaiduPanQuotaInfo> getQuota();

  Future<List<BaiduPanRemoteFile>> listDirectory({
    required String path,
    int start = 0,
    int limit = 1000,
  });

  Future<List<BaiduPanRemoteFile>> listAll({
    required String path,
    int start = 0,
    int limit = 1000,
  });

  Future<List<BaiduPanRemoteFile>> search({
    required String key,
    String? path,
    int page = 1,
    int num = 100,
  });

  Future<BaiduPanRemoteFile> getFileMeta({
    required String fsid,
    bool withDlink = false,
  });
}
