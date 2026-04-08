import 'package:flutter_test/flutter_test.dart';
import 'package:ktv2_example/features/ktv/application/download_manager_models.dart';

void main() {
  test('retryable network errors are auto retried', () {
    expect(
      isRetryableDownloadErrorMessage(
        'SocketException: Connection reset by peer',
      ),
      isTrue,
    );
    expect(
      isRetryableDownloadErrorMessage('HttpException: 百度网盘下载失败: 503'),
      isTrue,
    );
    expect(
      const DownloadingSongItem(
        songId: 'song-1',
        sourceId: 'baidu_pan',
        sourceSongId: 'fsid-1',
        title: '夜曲',
        artist: '周杰伦',
        startedAtMillis: 1,
        updatedAtMillis: 2,
        status: DownloadTaskStatus.failed,
        errorMessage: 'TimeoutException: request timed out',
      ).isAutoRetryableFailure,
      isTrue,
    );
  });

  test('non-network errors are not auto retried', () {
    expect(
      isRetryableDownloadErrorMessage('StateError: 百度网盘歌曲 song-1 缺少可下载 dlink'),
      isFalse,
    );
    expect(
      isRetryableDownloadErrorMessage('HttpException: 百度网盘下载失败: 401'),
      isFalse,
    );
    expect(
      isRetryableDownloadErrorMessage('HttpException: 百度网盘下载失败: 404'),
      isFalse,
    );
    expect(
      const DownloadingSongItem(
        songId: 'song-2',
        sourceId: 'baidu_pan',
        sourceSongId: 'fsid-2',
        title: '晴天',
        artist: '周杰伦',
        startedAtMillis: 1,
        updatedAtMillis: 2,
        status: DownloadTaskStatus.failed,
        errorMessage: 'StateError: baidu_pan 下载服务未启用',
      ).isAutoRetryableFailure,
      isFalse,
    );
  });

  test('authorization errors are classified for foreground notice', () {
    expect(
      isAuthorizationDownloadErrorMessage(
        'BaiduPanUnauthorizedException: 百度网盘未授权',
      ),
      isTrue,
    );
    expect(
      isAuthorizationDownloadErrorMessage(
        'BaiduPanTokenExpiredException: 百度网盘授权已过期',
      ),
      isTrue,
    );
    expect(
      isAuthorizationDownloadErrorMessage('HttpException: 百度网盘下载失败: 401'),
      isTrue,
    );
    expect(
      isAuthorizationDownloadErrorMessage('HttpException: 百度网盘下载失败: 403'),
      isTrue,
    );
    expect(
      const DownloadingSongItem(
        songId: 'song-3',
        sourceId: 'baidu_pan',
        sourceSongId: 'fsid-3',
        title: '青花瓷',
        artist: '周杰伦',
        startedAtMillis: 1,
        updatedAtMillis: 2,
        status: DownloadTaskStatus.failed,
        errorMessage: 'BaiduPanUnauthorizedException: 百度网盘未授权',
      ).isAuthorizationFailure,
      isTrue,
    );
    expect(
      isAuthorizationDownloadErrorMessage(
        'StateError: 百度网盘歌曲 song-1 缺少可下载 dlink',
      ),
      isFalse,
    );
  });

  test('download error summary hides raw url and exception details', () {
    expect(
      buildDownloadErrorSummary(
        'HttpException: 百度网盘接口返回异常: 503 https://pan.baidu.com/rest/2.0/xpan/file?access_token=abc',
        fallback: '下载失败',
      ),
      '下载失败，请稍后重试',
    );
    expect(
      buildDownloadErrorSummary(
        'BaiduPanUnauthorizedException: 百度网盘未授权',
        fallback: '下载失败',
      ),
      '登录已失效，请重新登录',
    );
    expect(
      buildDownloadErrorSummary(
        'StateError: 百度网盘歌曲 song-1 缺少可下载 dlink',
        fallback: '下载失败',
      ),
      '下载失败，文件不可用',
    );
    expect(
      buildDownloadErrorSummary(
        'StateError: baidu_pan 下载服务未启用',
        fallback: '下载失败',
      ),
      '下载失败，下载服务不可用',
    );
  });
}
