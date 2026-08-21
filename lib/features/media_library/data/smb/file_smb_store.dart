import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'smb_models.dart';
import 'smb_source_config_store.dart';

Future<File> resolveSmbStoreFile(String fileName) async {
  final Directory supportDirectory = await getApplicationSupportDirectory();
  final Directory directory = Directory(
    path.join(supportDirectory.path, 'smb'),
  );
  await directory.create(recursive: true);
  return File(path.join(directory.path, fileName));
}

Future<Directory> resolveSmbCacheDirectory() async {
  final Directory supportDirectory = await getApplicationSupportDirectory();
  final Directory directory = Directory(
    path.join(supportDirectory.path, 'smb', 'playback_cache'),
  );
  await directory.create(recursive: true);
  return directory;
}

Future<Directory> resolveSmbDownloadsDirectory() async {
  final Directory supportDirectory = await getApplicationSupportDirectory();
  final Directory directory = Directory(
    path.join(supportDirectory.path, 'smb', 'downloads'),
  );
  await directory.create(recursive: true);
  return directory;
}

Future<Map<String, Object?>?> readSmbJsonMap(File file) async {
  if (!await file.exists()) {
    return null;
  }
  final Object? decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map) {
    return null;
  }
  return decoded.map(
    (Object? key, Object? value) => MapEntry(key.toString(), value),
  );
}

Future<void> writeSmbJsonMap(File file, Map<String, Object?> value) async {
  await file.parent.create(recursive: true);
  await file.writeAsString(jsonEncode(value), flush: true);
}

class FileSmbSourceConfigStore implements SmbSourceConfigStore {
  FileSmbSourceConfigStore({this.fileName = 'source_config.json'});

  final String fileName;

  @override
  Future<SmbSourceConfig?> loadConfig() async {
    final Map<String, Object?>? json = await readSmbJsonMap(
      await resolveSmbStoreFile(fileName),
    );
    if (json == null) {
      return null;
    }
    return SmbSourceConfig(
      sourceRootId: json['sourceRootId']?.toString() ?? '',
      rootPath: json['rootPath']?.toString() ?? '/',
      displayName: json['displayName']?.toString() ?? 'SMB',
      host: json['host']?.toString() ?? '',
      share: json['share']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      domain: json['domain']?.toString() ?? '',
      lastSyncedAtMillis: int.tryParse(
        json['lastSyncedAtMillis']?.toString() ?? '',
      ),
    );
  }

  @override
  Future<void> saveConfig(SmbSourceConfig config) async {
    await writeSmbJsonMap(
      await resolveSmbStoreFile(fileName),
      <String, Object?>{
        'sourceRootId': config.sourceRootId,
        'rootPath': config.rootPath,
        'displayName': config.displayName,
        'host': config.host,
        'share': config.share,
        'username': config.username,
        'domain': config.domain,
        'lastSyncedAtMillis': config.lastSyncedAtMillis,
      },
    );
  }

  @override
  Future<void> clearConfig() async {
    final File file = await resolveSmbStoreFile(fileName);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
