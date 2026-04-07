import '../cloud/cloud_auth_repository.dart';
import 'baidu_pan_models.dart';

abstract class BaiduPanAuthRepository
    extends CloudAuthRepository<BaiduPanAuthToken> {
  Future<BaiduPanDeviceCodeSession> createDeviceCodeSession();

  Future<BaiduPanAuthToken?> loginWithDeviceCode(String deviceCode);
}
