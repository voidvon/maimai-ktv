import 'baidu_pan_models.dart';

abstract class BaiduPanSourceConfigStore {
  Future<BaiduPanSourceConfig?> loadConfig();

  Future<void> saveConfig(BaiduPanSourceConfig config);

  Future<void> clearConfig();
}
