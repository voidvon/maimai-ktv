import 'package:flutter_test/flutter_test.dart';
import 'package:ktv2_example/features/media_library/data/baidu_pan/baidu_pan_models.dart';
import 'package:ktv2_example/features/media_library/data/baidu_pan/baidu_pan_song_mapper.dart';

void main() {
  test('mapRemoteFileToSong converts remote video metadata into Song', () {
    final BaiduPanSongMapper mapper = BaiduPanSongMapper();
    const BaiduPanRemoteFile file = BaiduPanRemoteFile(
      fsid: '123456',
      path: '/KTV/周杰伦-青花瓷-国语.mp4',
      serverFilename: '周杰伦-青花瓷-国语.mp4',
      isDirectory: false,
      size: 1024,
      modifiedAtMillis: 1710000000000,
    );

    final song = mapper.mapRemoteFileToSong(file);

    expect(song.sourceId, 'baidu_pan');
    expect(song.sourceSongId, '123456');
    expect(song.artist, '周杰伦');
    expect(song.title, '青花瓷');
    expect(song.languages, <String>['国语']);
    expect(song.mediaPath, isEmpty);
  });
}
