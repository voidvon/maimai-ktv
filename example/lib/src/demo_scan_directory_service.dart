import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

import 'demo_android_storage_service.dart';

class DemoScanDirectoryService {
  final DemoAndroidStorageService _androidStorageService =
      DemoAndroidStorageService();

  Future<String?> pickDirectory({String? initialDirectory}) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return _androidStorageService.pickDirectory(
        initialDirectory: initialDirectory,
      );
    }

    return getDirectoryPath(initialDirectory: initialDirectory);
  }

  Future<bool> ensureDirectoryAccess(String path) {
    return _androidStorageService.ensureDirectoryAccess(path);
  }

  Future<void> clearDirectoryAccess({String? path}) {
    return _androidStorageService.clearDirectoryAccess(path: path);
  }
}
