import 'dart:io';

import '_baidu_pan_file_store_support.dart';
import 'baidu_pan_credentials_store.dart';
import 'baidu_pan_models.dart';

class FileBaiduPanCredentialsStore implements BaiduPanCredentialsStore {
  FileBaiduPanCredentialsStore({this.fileName = 'credentials.json'});

  final String fileName;

  @override
  Future<BaiduPanAppCredentials?> loadCredentials() async {
    final File file = await resolveBaiduPanStoreFile(fileName);
    final Map<String, Object?>? json = await readJsonMapFile(file);
    if (json == null) {
      return null;
    }
    return BaiduPanAppCredentials(
      appId: json['appId']?.toString() ?? '',
      appKey: json['appKey']?.toString() ?? '',
      secretKey: json['secretKey']?.toString() ?? '',
      signKey: json['signKey']?.toString() ?? '',
      redirectUri: json['redirectUri']?.toString() ?? 'oob',
      scope: json['scope']?.toString() ?? 'basic,netdisk',
    );
  }

  @override
  Future<void> saveCredentials(BaiduPanAppCredentials credentials) async {
    final File file = await resolveBaiduPanStoreFile(fileName);
    await writeJsonMapFile(file, <String, Object?>{
      'appId': credentials.appId,
      'appKey': credentials.appKey,
      'secretKey': credentials.secretKey,
      'signKey': credentials.signKey,
      'redirectUri': credentials.redirectUri,
      'scope': credentials.scope,
    });
  }

  @override
  Future<void> clearCredentials() async {
    final File file = await resolveBaiduPanStoreFile(fileName);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
