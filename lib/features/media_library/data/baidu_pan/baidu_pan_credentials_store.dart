import 'baidu_pan_models.dart';

abstract class BaiduPanCredentialsStore {
  Future<BaiduPanAppCredentials?> loadCredentials();

  Future<void> saveCredentials(BaiduPanAppCredentials credentials);

  Future<void> clearCredentials();
}
