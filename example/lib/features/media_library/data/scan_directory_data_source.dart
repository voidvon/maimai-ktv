import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'android_storage_data_source.dart';

class DemoScanDirectoryDataSource {
  static const MethodChannel _macosChannel = MethodChannel(
    'ktv2_example/macos_directory_picker',
  );
  final DemoAndroidStorageDataSource _androidStorageDataSource =
      DemoAndroidStorageDataSource();

  Future<String?> pickDirectory({String? initialDirectory}) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return _androidStorageDataSource.pickDirectory(
        initialDirectory: initialDirectory,
      );
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      final String? selectedPath = await _macosChannel.invokeMethod<String>(
        'pickDirectory',
        <String, Object?>{'initialDirectory': initialDirectory},
      );
      if (selectedPath == null || selectedPath.trim().isEmpty) {
        debugPrint('macOS directory picker returned no selection');
        return null;
      }
      return selectedPath;
    }

    return getDirectoryPath(initialDirectory: initialDirectory);
  }

  Future<bool> ensureDirectoryAccess(String path) {
    return _androidStorageDataSource.ensureDirectoryAccess(path);
  }

  Future<void> clearDirectoryAccess({String? path}) {
    return _androidStorageDataSource.clearDirectoryAccess(path: path);
  }

  Future<void> saveSelectedDirectory(String path) {
    return _androidStorageDataSource.saveSelectedDirectory(path);
  }

  Future<String?> loadSelectedDirectory() {
    return _androidStorageDataSource.loadSelectedDirectory();
  }
}
