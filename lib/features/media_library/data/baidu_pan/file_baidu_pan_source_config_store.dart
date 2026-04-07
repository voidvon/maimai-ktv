import 'dart:io';

import '_baidu_pan_file_store_support.dart';
import 'baidu_pan_models.dart';
import 'baidu_pan_source_config_store.dart';

class FileBaiduPanSourceConfigStore implements BaiduPanSourceConfigStore {
  FileBaiduPanSourceConfigStore({this.fileName = 'source_config.json'});

  final String fileName;

  @override
  Future<BaiduPanSourceConfig?> loadConfig() async {
    final File file = await resolveBaiduPanStoreFile(fileName);
    final Map<String, Object?>? json = await readJsonMapFile(file);
    if (json == null) {
      return null;
    }
    return BaiduPanSourceConfig(
      sourceRootId: json['sourceRootId']?.toString() ?? '',
      rootPath: json['rootPath']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '百度网盘',
      syncToken: json['syncToken']?.toString(),
      lastSyncedAtMillis: int.tryParse(
        json['lastSyncedAtMillis']?.toString() ?? '',
      ),
    );
  }

  @override
  Future<void> saveConfig(BaiduPanSourceConfig config) async {
    final File file = await resolveBaiduPanStoreFile(fileName);
    await writeJsonMapFile(file, <String, Object?>{
      'sourceRootId': config.sourceRootId,
      'rootPath': config.rootPath,
      'displayName': config.displayName,
      'syncToken': config.syncToken,
      'lastSyncedAtMillis': config.lastSyncedAtMillis,
    });
  }

  @override
  Future<void> clearConfig() async {
    final File file = await resolveBaiduPanStoreFile(fileName);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
