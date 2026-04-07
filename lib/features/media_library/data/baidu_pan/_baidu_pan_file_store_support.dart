import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

Future<File> resolveBaiduPanStoreFile(String fileName) async {
  final Directory supportDirectory = await getApplicationSupportDirectory();
  final Directory storeDirectory = Directory(
    path.join(supportDirectory.path, 'baidu_pan'),
  );
  if (!await storeDirectory.exists()) {
    await storeDirectory.create(recursive: true);
  }
  return File(path.join(storeDirectory.path, fileName));
}

Future<Map<String, Object?>?> readJsonMapFile(File file) async {
  if (!await file.exists()) {
    return null;
  }
  final String raw = await file.readAsString();
  if (raw.trim().isEmpty) {
    return null;
  }
  final Object? decoded = jsonDecode(raw);
  if (decoded is Map<String, dynamic>) {
    return decoded.cast<String, Object?>();
  }
  if (decoded is Map) {
    return decoded.map(
      (Object? key, Object? value) => MapEntry(key.toString(), value),
    );
  }
  return null;
}

Future<void> writeJsonMapFile(File file, Map<String, Object?> json) async {
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(json),
    flush: true,
  );
}

Future<Directory> resolveBaiduPanCacheDirectory() async {
  final Directory supportDirectory = await getApplicationSupportDirectory();
  final Directory cacheDirectory = Directory(
    path.join(supportDirectory.path, 'baidu_pan', 'playback_cache'),
  );
  if (!await cacheDirectory.exists()) {
    await cacheDirectory.create(recursive: true);
  }
  return cacheDirectory;
}

Future<Directory> resolveBaiduPanDownloadsDirectory() async {
  final Directory supportDirectory = await getApplicationSupportDirectory();
  final Directory downloadsDirectory = Directory(
    path.join(supportDirectory.path, 'baidu_pan', 'downloads'),
  );
  if (!await downloadsDirectory.exists()) {
    await downloadsDirectory.create(recursive: true);
  }
  return downloadsDirectory;
}
