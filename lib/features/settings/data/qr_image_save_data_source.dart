import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class QrImageSaveDataSource {
  static const MethodChannel _channel = MethodChannel('ktv2_example/qr_image');

  const QrImageSaveDataSource();

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> saveQrImage({
    required String imageUrl,
    required String fileName,
  }) async {
    if (!isSupported) {
      throw UnsupportedError('当前平台不支持保存二维码到手机');
    }

    final Uint8List bytes = await _downloadImage(Uri.parse(imageUrl));
    await _channel.invokeMethod<void>('saveQrImage', <String, Object?>{
      'bytes': bytes,
      'fileName': fileName,
    });
  }

  Future<Uint8List> _downloadImage(Uri uri) async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'image/*');
      request.headers.set(HttpHeaders.userAgentHeader, 'pan.baidu.com');
      final HttpClientResponse response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final String payload = await response.transform(utf8.decoder).join();
        throw HttpException(
          '二维码下载失败：${response.statusCode} $payload',
          uri: uri,
        );
      }
      return consolidateHttpClientResponseBytes(response);
    } finally {
      client.close(force: true);
    }
  }
}
