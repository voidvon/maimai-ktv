import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class QrImageSaveDataSource {
  static const MethodChannel _channel = MethodChannel('ktv2_example/qr_image');

  const QrImageSaveDataSource();

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> saveQrImageBytes({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (!isSupported) {
      throw UnsupportedError('当前平台不支持保存二维码到手机');
    }
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', '二维码图片内容不能为空');
    }
    await _channel.invokeMethod<void>('saveQrImage', <String, Object?>{
      'bytes': bytes,
      'fileName': fileName,
    });
  }
}
