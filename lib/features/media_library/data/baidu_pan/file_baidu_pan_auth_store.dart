import 'dart:io';

import '_baidu_pan_file_store_support.dart';
import 'baidu_pan_auth_store.dart';
import 'baidu_pan_models.dart';

class FileBaiduPanAuthStore implements BaiduPanAuthStore {
  FileBaiduPanAuthStore({this.fileName = 'auth_token.json'});

  final String fileName;

  @override
  Future<BaiduPanAuthToken?> readToken() async {
    final File file = await resolveBaiduPanStoreFile(fileName);
    final Map<String, Object?>? json = await readJsonMapFile(file);
    if (json == null) {
      return null;
    }
    final int expiresAtMillis =
        int.tryParse(json['expiresAtMillis']?.toString() ?? '') ?? 0;
    return BaiduPanAuthToken(
      accessToken: json['accessToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      expiresAtMillis: expiresAtMillis,
      scope: json['scope']?.toString(),
      sessionKey: json['sessionKey']?.toString(),
      sessionSecret: json['sessionSecret']?.toString(),
    );
  }

  @override
  Future<void> writeToken(BaiduPanAuthToken token) async {
    final File file = await resolveBaiduPanStoreFile(fileName);
    await writeJsonMapFile(file, <String, Object?>{
      'accessToken': token.accessToken,
      'refreshToken': token.refreshToken,
      'expiresAtMillis': token.expiresAtMillis,
      'scope': token.scope,
      'sessionKey': token.sessionKey,
      'sessionSecret': token.sessionSecret,
    });
  }

  @override
  Future<void> clearToken() async {
    final File file = await resolveBaiduPanStoreFile(fileName);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
