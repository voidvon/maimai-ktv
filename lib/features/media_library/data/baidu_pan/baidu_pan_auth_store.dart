import 'baidu_pan_models.dart';

abstract class BaiduPanAuthStore {
  Future<BaiduPanAuthToken?> readToken();

  Future<void> writeToken(BaiduPanAuthToken token);

  Future<void> clearToken();
}
