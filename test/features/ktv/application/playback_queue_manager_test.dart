import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ktv2/ktv2.dart';
import 'package:ktv2_example/core/models/song_identity.dart';
import 'package:ktv2_example/core/models/song.dart';
import 'package:ktv2_example/features/ktv/application/playback_queue_manager.dart';
import 'package:ktv2_example/features/ktv/application/playable_song_resolver.dart';

void main() {
  test('requestSong opens first song and appends later songs', () async {
    final _FakePlayerController playerController = _FakePlayerController();
    final PlaybackQueueManager manager = PlaybackQueueManager(
      playerController: playerController,
    );
    final Song first = _song('第一首');
    final Song second = _song('第二首');

    final List<Song> initialQueue = await manager.requestSong(
      const <Song>[],
      first,
    );
    final List<Song> nextQueue = await manager.requestSong(
      initialQueue,
      second,
    );

    expect(playerController.lastOpenedSource?.displayName, '第一首');
    expect(nextQueue, <Song>[first, second]);
  });

  test('skipCurrentSong keeps audio mode and advances queue', () async {
    final _FakePlayerController playerController = _FakePlayerController();
    final PlaybackQueueManager manager = PlaybackQueueManager(
      playerController: playerController,
    );
    final Song first = _song('第一首');
    final Song second = _song('第二首');

    final List<Song> queueAfterFirst = await manager.requestSong(
      const <Song>[],
      first,
    );
    final List<Song> queueAfterSecond = await manager.requestSong(
      queueAfterFirst,
      second,
    );

    manager.toggleAudioMode();
    expect(playerController.audioOutputMode, AudioOutputMode.accompaniment);

    final List<Song> remainingQueue = await manager.skipCurrentSong(
      queueAfterSecond,
    );

    expect(remainingQueue, <Song>[second]);
    expect(playerController.lastOpenedSource?.displayName, '第二首');
    expect(playerController.audioOutputMode, AudioOutputMode.accompaniment);
  });

  test('requestSong resolves playable media before opening player', () async {
    final _FakePlayerController playerController = _FakePlayerController();
    final PlaybackQueueManager manager = PlaybackQueueManager(
      playerController: playerController,
      playableSongResolver: _FakePlayableSongResolver(
        resolvedPath: '/cache/resolved.mp4',
        displayName: '缓存版第一首',
      ),
    );
    final Song first = _song('第一首');

    await manager.requestSong(const <Song>[], first);

    expect(playerController.lastOpenedSource?.path, '/cache/resolved.mp4');
    expect(playerController.lastOpenedSource?.displayName, '缓存版第一首');
  });

  test('skipCurrentSong keeps current playback when no next song exists', () async {
    final _FakePlayerController playerController = _FakePlayerController();
    final PlaybackQueueManager manager = PlaybackQueueManager(
      playerController: playerController,
    );
    final Song first = _song('第一首');

    final List<Song> queue = await manager.requestSong(const <Song>[], first);
    final List<Song> remainingQueue = await manager.skipCurrentSong(queue);

    expect(remainingQueue, <Song>[first]);
    expect(playerController.lastOpenedSource?.displayName, '第一首');
    expect(playerController.hasMedia, isTrue);
    expect(playerController.stopPlaybackCallCount, 0);
  });
}

Song _song(String title) {
  return Song(
    songId: buildAggregateSongId(title: title, artist: '歌手'),
    sourceId: 'local',
    sourceSongId: buildLocalSourceSongId(
      fingerprint: buildLocalMetadataFingerprint(locator: '/tmp/$title.mp4'),
    ),
    title: title,
    artist: '歌手',
    languages: const <String>['其它'],
    searchIndex: title.toLowerCase(),
    mediaPath: '/tmp/$title.mp4',
  );
}

class _FakePlayerController extends PlayerController {
  PlayerState _state = const PlayerState();
  MediaSource? lastOpenedSource;
  int stopPlaybackCallCount = 0;

  @override
  PlayerState get state => _state;

  @override
  Future<void> applyAudioOutputMode(AudioOutputMode mode) async {
    _state = PlayerState(
      audioOutputMode: mode,
      currentMediaPath: _state.currentMediaPath,
      isPlaying: _state.isPlaying,
      playbackDuration: _state.playbackDuration,
      playbackPosition: _state.playbackPosition,
    );
    notifyListeners();
  }

  @override
  Widget? buildVideoView() => null;

  @override
  Future<void> openMedia(MediaSource source) async {
    lastOpenedSource = source;
    _state = PlayerState(
      audioOutputMode: _state.audioOutputMode,
      currentMediaPath: source.path,
      isPlaying: true,
      playbackDuration: const Duration(minutes: 4),
      playbackPosition: Duration.zero,
    );
    notifyListeners();
  }

  @override
  Future<void> seekToProgress(double progress) async {
    _state = PlayerState(
      audioOutputMode: _state.audioOutputMode,
      currentMediaPath: _state.currentMediaPath,
      isPlaying: _state.isPlaying,
      playbackDuration: _state.playbackDuration,
      playbackPosition: Duration(
        milliseconds: (_state.playbackDuration.inMilliseconds * progress)
            .round(),
      ),
    );
    notifyListeners();
  }

  @override
  Future<void> togglePlayback() async {
    _state = PlayerState(
      audioOutputMode: _state.audioOutputMode,
      currentMediaPath: _state.currentMediaPath,
      isPlaying: !_state.isPlaying,
      playbackDuration: _state.playbackDuration,
      playbackPosition: _state.playbackPosition,
    );
    notifyListeners();
  }

  @override
  Future<void> stopPlayback() async {
    stopPlaybackCallCount += 1;
    _state = PlayerState(
      audioOutputMode: _state.audioOutputMode,
      currentMediaPath: null,
      isPlaying: false,
      playbackDuration: Duration.zero,
      playbackPosition: Duration.zero,
    );
    notifyListeners();
  }
}

class _FakePlayableSongResolver implements PlayableSongResolver {
  const _FakePlayableSongResolver({
    required this.resolvedPath,
    required this.displayName,
  });

  final String resolvedPath;
  final String displayName;

  @override
  Future<PlayableMediaResolution> resolve(Song song) async {
    return PlayableMediaResolution(
      song: song,
      localPath: resolvedPath,
      displayName: displayName,
      cacheHit: true,
    );
  }
}
