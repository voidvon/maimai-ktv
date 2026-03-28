import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

import '../models/media_source.dart';
import '../platform/app_platform.dart';

class VideoPickerService {
  static const MethodChannel _channel = MethodChannel('ktv/video_picker');

  Future<MediaSource?> pickVideo() async {
    if (isMacOS) {
      return _pickVideoOnDesktop();
    }

    final result = await _channel.invokeMapMethod<String, Object?>('pickVideo');
    if (result == null) {
      return null;
    }

    final path = result['uri'] as String?;
    if (path == null || path.isEmpty) {
      return null;
    }

    final displayName =
        (result['displayName'] as String?)?.trim().isNotEmpty == true
        ? (result['displayName'] as String).trim()
        : path.split('/').last;

    return MediaSource(path: path, displayName: displayName);
  }

  Future<MediaSource?> _pickVideoOnDesktop() async {
    const typeGroup = XTypeGroup(
      label: 'video',
      extensions: <String>[
        'mp4',
        'mkv',
        'avi',
        'mov',
        'dat',
        'rmvb',
        'rm',
        'mpg',
        'mpeg',
        'vob',
      ],
    );

    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    if (file == null) {
      return null;
    }

    return MediaSource(path: file.path, displayName: file.name);
  }
}
