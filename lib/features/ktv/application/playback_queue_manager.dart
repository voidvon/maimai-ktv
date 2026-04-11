import 'dart:async';

import 'package:ktv2/ktv2.dart';

import '../../../core/models/song.dart';
import 'playable_song_resolver.dart';

class PlaybackQueueManager {
  const PlaybackQueueManager({
    required this.playerController,
    this.playableSongResolver = const DefaultPlayableSongResolver(),
  });

  final PlayerController playerController;
  final PlayableSongResolver playableSongResolver;

  Future<List<Song>> requestSong(List<Song> queuedSongs, Song song) async {
    final List<Song> nextQueue = List<Song>.of(queuedSongs);
    final bool hasCurrentSong =
        nextQueue.isNotEmpty && playerController.hasMedia;

    if (hasCurrentSong) {
      if (nextQueue.contains(song)) {
        return nextQueue;
      }
      nextQueue.add(song);
      return nextQueue;
    }

    nextQueue
      ..remove(song)
      ..insert(0, song);
    final PlayableMediaResolution media = await playableSongResolver.resolve(
      song,
    );
    await playerController.openMedia(
      MediaSource(path: media.localPath, displayName: media.displayName),
    );
    return nextQueue;
  }

  List<Song> prioritizeQueuedSong(List<Song> queuedSongs, Song song) {
    final List<Song> nextQueue = List<Song>.of(queuedSongs);
    final int currentIndex = nextQueue.indexOf(song);
    if (currentIndex <= 1) {
      return nextQueue;
    }
    nextQueue
      ..removeAt(currentIndex)
      ..insert(1, song);
    return nextQueue;
  }

  List<Song> removeQueuedSong(List<Song> queuedSongs, Song song) {
    final List<Song> nextQueue = List<Song>.of(queuedSongs);
    final int currentIndex = nextQueue.indexOf(song);
    if (currentIndex <= 0) {
      return nextQueue;
    }
    nextQueue.removeAt(currentIndex);
    return nextQueue;
  }

  void togglePlayback() {
    if (!playerController.hasMedia) {
      return;
    }
    unawaited(playerController.togglePlayback());
  }

  void toggleAudioMode() {
    if (!playerController.hasMedia) {
      return;
    }
    unawaited(playerController.toggleAudioOutputMode());
  }

  void restartPlayback() {
    if (!playerController.hasMedia) {
      return;
    }
    unawaited(playerController.seekToProgress(0));
  }

  Future<List<Song>> skipCurrentSong(List<Song> queuedSongs) async {
    if (!playerController.hasMedia && queuedSongs.isEmpty) {
      return queuedSongs;
    }

    final List<Song> remainingQueue = List<Song>.of(queuedSongs);
    if (remainingQueue.isNotEmpty) {
      remainingQueue.removeAt(0);
    }

    if (remainingQueue.isEmpty) {
      return queuedSongs;
    }

    final Song nextSong = remainingQueue.first;
    final PlayableMediaResolution media = await playableSongResolver.resolve(
      nextSong,
    );
    await playerController.openMedia(
      MediaSource(path: media.localPath, displayName: media.displayName),
    );
    return remainingQueue;
  }

  Future<void> stopPlayback() {
    return playerController.stopPlayback();
  }
}
