import 'package:flutter_test/flutter_test.dart';
import 'package:maimai_ktv/core/models/song.dart';
import 'package:maimai_ktv/core/search/song_search_matcher.dart';

void main() {
  final Song song = Song(
    songId: 'song-1',
    sourceId: 'local',
    sourceSongId: 'source-song-1',
    title: '中文歌曲 Hello',
    artist: '周杰伦',
    languages: const <String>['国语'],
    searchIndex: '中文歌曲 hello 周杰伦 国语',
    mediaPath: '/music/song-1.mp4',
  );

  test('matches Chinese title and artist by consecutive pinyin initials', () {
    expect(matchesSongSearch(song, 'zw'), isTrue);
    expect(matchesSongSearch(song, 'ZJL'), isTrue);
  });

  test('preserves exact Chinese and case-insensitive text search', () {
    expect(matchesSongSearch(song, '中文'), isTrue);
    expect(matchesSongSearch(song, 'HELLO'), isTrue);
  });

  test('does not enable full-pinyin search', () {
    expect(matchesSongSearch(song, 'zhongwen'), isFalse);
    expect(matchesSongSearch(song, 'zhoujielun'), isFalse);
  });

  test('matches any supported reading of a polyphonic character', () {
    expect(matchesPinyinInitials('重庆', 'cq'), isTrue);
    expect(matchesPinyinInitials('重庆', 'zq'), isTrue);
  });

  test('requires initials to map to consecutive characters', () {
    expect(matchesPinyinInitials('中间文本', 'zw'), isFalse);
  });
}
