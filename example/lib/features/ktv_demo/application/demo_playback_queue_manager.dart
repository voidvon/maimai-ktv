import 'dart:async';

import 'package:ktv2/ktv2.dart';

import '../../../core/models/demo_song.dart';

class DemoPlaybackQueueManager {
  const DemoPlaybackQueueManager({required this.playerController});

  final PlayerController playerController;

  Future<List<DemoSong>> requestSong(
    List<DemoSong> queuedSongs,
    DemoSong song,
  ) async {
    final List<DemoSong> nextQueue = List<DemoSong>.of(queuedSongs);
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
    await playerController.openMedia(
      MediaSource(path: song.mediaPath, displayName: song.title),
    );
    return nextQueue;
  }

  List<DemoSong> prioritizeQueuedSong(
    List<DemoSong> queuedSongs,
    DemoSong song,
  ) {
    final List<DemoSong> nextQueue = List<DemoSong>.of(queuedSongs);
    final int currentIndex = nextQueue.indexOf(song);
    if (currentIndex <= 1) {
      return nextQueue;
    }
    nextQueue
      ..removeAt(currentIndex)
      ..insert(1, song);
    return nextQueue;
  }

  List<DemoSong> removeQueuedSong(List<DemoSong> queuedSongs, DemoSong song) {
    final List<DemoSong> nextQueue = List<DemoSong>.of(queuedSongs);
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

  Future<List<DemoSong>> skipCurrentSong(List<DemoSong> queuedSongs) async {
    if (!playerController.hasMedia && queuedSongs.isEmpty) {
      return queuedSongs;
    }

    final List<DemoSong> remainingQueue = List<DemoSong>.of(queuedSongs);
    if (remainingQueue.isNotEmpty) {
      remainingQueue.removeAt(0);
    }

    if (remainingQueue.isEmpty) {
      await playerController.stopPlayback();
      return const <DemoSong>[];
    }

    final DemoSong nextSong = remainingQueue.first;
    await playerController.openMedia(
      MediaSource(path: nextSong.mediaPath, displayName: nextSong.title),
    );
    return remainingQueue;
  }

  Future<void> stopPlayback() {
    return playerController.stopPlayback();
  }
}
