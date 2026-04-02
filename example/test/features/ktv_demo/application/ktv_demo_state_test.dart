import 'package:flutter_test/flutter_test.dart';
import 'package:ktv2_example/core/models/demo_song.dart';
import 'package:ktv2_example/features/ktv_demo/application/ktv_demo_controller.dart';

void main() {
  test('copyWith updates nested library and playback state compatibly', () {
    final KtvDemoState state = const KtvDemoState().copyWith(
      searchQuery: 'jay',
      scanDirectoryPath: '/music',
      libraryTotalCount: 8,
      libraryPageSongs: const <DemoSong>[
        DemoSong(
          title: '夜曲',
          artist: '周杰伦',
          languages: <String>['国语'],
          searchIndex: 'yequ zhoujielun',
          mediaPath: '/music/yequ.mp4',
        ),
      ],
      queuedSongs: const <DemoSong>[
        DemoSong(
          title: '青花瓷',
          artist: '周杰伦',
          languages: <String>['国语'],
          searchIndex: 'qinghuaci zhoujielun',
          mediaPath: '/music/qinghuaci.mp4',
        ),
      ],
    );

    expect(state.library.searchQuery, 'jay');
    expect(state.searchQuery, 'jay');
    expect(state.library.scanDirectoryPath, '/music');
    expect(state.library.totalCount, 8);
    expect(state.playback.queuedSongs, hasLength(1));
    expect(state.queuedSongs.single.title, '青花瓷');
    expect(state.libraryPageSongs.single.title, '夜曲');
  });
}
