import 'baidu_pan_models.dart';

abstract class BaiduPanAuthRepository {
  Future<Uri> buildAuthorizeUri();

  Future<void> loginWithAuthorizationCode(String code);

  Future<void> logout();

  Future<String> getValidAccessToken();

  Future<bool> hasValidSession();

  Future<BaiduPanAuthToken?> readToken();
}
