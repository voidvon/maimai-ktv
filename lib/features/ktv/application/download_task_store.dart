import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'download_manager_models.dart';

typedef DownloadTaskFileProvider = Future<File> Function();

class DownloadTaskStore {
  DownloadTaskStore({DownloadTaskFileProvider? fileProvider})
    : _fileProvider = fileProvider ?? _defaultFileProvider;

  final DownloadTaskFileProvider _fileProvider;

  Future<List<DownloadingSongItem>> loadTasks() async {
    final File file = await _fileProvider();
    if (!await file.exists()) {
      return const <DownloadingSongItem>[];
    }
    final String raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return const <DownloadingSongItem>[];
    }

    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return const <DownloadingSongItem>[];
    }
    final Object? tasksObject = decoded['tasks'];
    if (tasksObject is! List) {
      return const <DownloadingSongItem>[];
    }

    return tasksObject
        .whereType<Map>()
        .map(
          (Map<Object?, Object?> item) => DownloadingSongItem.fromJson(
            item.map(
              (Object? key, Object? value) => MapEntry(key.toString(), value),
            ),
          ),
        )
        .where(
          (DownloadingSongItem item) =>
              item.songId.trim().isNotEmpty &&
              item.sourceId.trim().isNotEmpty &&
              item.sourceSongId.trim().isNotEmpty,
        )
        .toList(growable: false);
  }

  Future<void> saveTasks(List<DownloadingSongItem> tasks) async {
    final File file = await _fileProvider();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'version': 1,
        'tasks': tasks
            .map((DownloadingSongItem item) => item.toJson())
            .toList(),
      }),
      flush: true,
    );
  }

  static Future<File> _defaultFileProvider() async {
    final Directory supportDirectory = await getApplicationSupportDirectory();
    final Directory storeDirectory = Directory(
      path.join(supportDirectory.path, 'ktv'),
    );
    if (!await storeDirectory.exists()) {
      await storeDirectory.create(recursive: true);
    }
    return File(path.join(storeDirectory.path, 'download_tasks.json'));
  }
}
