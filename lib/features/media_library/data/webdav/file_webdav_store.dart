import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'webdav_models.dart';
import 'webdav_source_config_store.dart';

Future<File> resolveWebDavStoreFile(String fileName) async {
  final Directory supportDirectory = await getApplicationSupportDirectory();
  final Directory directory = Directory(
    path.join(supportDirectory.path, 'webdav'),
  );
  await directory.create(recursive: true);
  return File(path.join(directory.path, fileName));
}

Future<Directory> resolveWebDavCacheDirectory() async {
  final Directory supportDirectory = await getApplicationSupportDirectory();
  final Directory directory = Directory(
    path.join(supportDirectory.path, 'webdav', 'playback_cache'),
  );
  await directory.create(recursive: true);
  return directory;
}

Future<Directory> resolveWebDavDownloadsDirectory() async {
  final Directory supportDirectory = await getApplicationSupportDirectory();
  final Directory directory = Directory(
    path.join(supportDirectory.path, 'webdav', 'downloads'),
  );
  await directory.create(recursive: true);
  return directory;
}

Future<Map<String, Object?>?> readWebDavJsonMap(File file) async {
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

Future<void> writeWebDavJsonMap(File file, Map<String, Object?> value) async {
  await file.parent.create(recursive: true);
  await file.writeAsString(jsonEncode(value), flush: true);
}

class FileWebDavSourceConfigStore implements WebDavSourceConfigStore {
  FileWebDavSourceConfigStore({this.fileName = 'source_config.json'});

  final String fileName;

  @override
  Future<WebDavSourceConfig?> loadConfig() async {
    final Map<String, Object?>? json = await readWebDavJsonMap(
      await resolveWebDavStoreFile(fileName),
    );
    if (json == null) {
      return null;
    }
    return WebDavSourceConfig(
      sourceRootId: json['sourceRootId']?.toString() ?? '',
      rootPath: json['rootPath']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? 'WebDAV',
      serverUrl: json['serverUrl']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      lastSyncedAtMillis: int.tryParse(
        json['lastSyncedAtMillis']?.toString() ?? '',
      ),
    );
  }

  @override
  Future<void> saveConfig(WebDavSourceConfig config) async {
    await writeWebDavJsonMap(
      await resolveWebDavStoreFile(fileName),
      <String, Object?>{
        'sourceRootId': config.sourceRootId,
        'rootPath': config.rootPath,
        'displayName': config.displayName,
        'serverUrl': config.serverUrl,
        'username': config.username,
        'lastSyncedAtMillis': config.lastSyncedAtMillis,
      },
    );
  }

  @override
  Future<void> clearConfig() async {
    final File file = await resolveWebDavStoreFile(fileName);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
