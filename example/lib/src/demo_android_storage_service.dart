import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DemoAndroidStorageService {
  static const MethodChannel _channel = MethodChannel(
    'ktv2_example/android_storage',
  );

  bool isDocumentTreeUri(String path) => path.startsWith('content://');

  Future<String?> pickDirectory({String? initialDirectory}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }

    final String? selectedUri = await _channel.invokeMethod<String>(
      'pickDirectory',
      <String, Object?>{'initialDirectory': initialDirectory},
    );
    if (selectedUri == null || selectedUri.trim().isEmpty) {
      return null;
    }
    return selectedUri;
  }

  Future<bool> ensureDirectoryAccess(String path) async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        !isDocumentTreeUri(path)) {
      return true;
    }

    final bool? accessible = await _channel.invokeMethod<bool>(
      'ensureDirectoryAccess',
      <String, Object?>{'path': path},
    );
    return accessible ?? false;
  }

  Future<void> clearDirectoryAccess({String? path}) async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        path == null ||
        !isDocumentTreeUri(path)) {
      return;
    }

    await _channel.invokeMethod<void>('clearDirectoryAccess', <String, Object?>{
      'path': path,
    });
  }
}
