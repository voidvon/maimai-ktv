import 'package:flutter/material.dart';

import '../../../core/models/artist.dart';
import '../../../core/models/song.dart';
import '../application/download_manager_models.dart';
import '../application/ktv_controller.dart';

class SongBookViewModel {
  const SongBookViewModel({
    required this.navigation,
    required this.library,
    required this.playback,
  });

  final SongBookNavigationViewModel navigation;
  final SongBookLibraryViewModel library;
  final SongBookPlaybackViewModel playback;
}

class SongBookNavigationViewModel {
  const SongBookNavigationViewModel({
    required this.route,
    required this.songBookMode,
    required this.libraryScope,
    required this.selectedArtist,
    required this.breadcrumbLabel,
  });

  final KtvRoute route;
  final SongBookMode songBookMode;
  final LibraryScope libraryScope;
  final String? selectedArtist;
  final String breadcrumbLabel;
}

class SongBookLibraryViewModel {
  const SongBookLibraryViewModel({
    required this.searchQuery,
    required this.selectedLanguage,
    required this.songs,
    required this.artists,
    required this.favoriteSongIds,
    required this.downloadableSourceIds,
    required this.downloadingSongIds,
    this.downloadingSongProgressByKey = const <String, double>{},
    this.downloadTaskStatusByKey = const <String, DownloadTaskStatus>{},
    required this.downloadedSongKeys,
    required this.totalCount,
    required this.pageIndex,
    required this.hasMore,
    required this.hasConfiguredDirectory,
    required this.hasConfiguredAggregatedSources,
    required this.isScanning,
    required this.isLoadingPage,
    required this.scanErrorMessage,
    required this.loadMoreErrorMessage,
  });

  final String searchQuery;
  final String selectedLanguage;
  final List<Song> songs;
  final List<Artist> artists;
  final Set<String> favoriteSongIds;
  final Set<String> downloadableSourceIds;
  final Set<String> downloadingSongIds;
  final Map<String, double> downloadingSongProgressByKey;
  final Map<String, DownloadTaskStatus> downloadTaskStatusByKey;
  final Set<String> downloadedSongKeys;
  final int totalCount;
  final int pageIndex;
  final bool hasMore;
  final bool hasConfiguredDirectory;
  final bool hasConfiguredAggregatedSources;
  final bool isScanning;
  final bool isLoadingPage;
  final String? scanErrorMessage;
  final String? loadMoreErrorMessage;

  bool supportsDownload(Song song) =>
      downloadableSourceIds.contains(song.sourceId);

  bool isSongDownloaded(Song song) {
    final String sourceSongId = song.sourceSongId.trim();
    if (sourceSongId.isEmpty) {
      return false;
    }
    return downloadedSongKeys.contains('${song.sourceId}::$sourceSongId');
  }

  double? downloadProgressForSong(Song song) {
    final String sourceSongId = song.sourceSongId.trim();
    if (sourceSongId.isEmpty) {
      return null;
    }
    return downloadingSongProgressByKey['${song.sourceId}::$sourceSongId'];
  }

  DownloadTaskStatus? downloadTaskStatusForSong(Song song) {
    final String sourceSongId = song.sourceSongId.trim();
    if (sourceSongId.isEmpty) {
      return null;
    }
    return downloadTaskStatusByKey['${song.sourceId}::$sourceSongId'];
  }
}

class SongBookPlaybackViewModel {
  const SongBookPlaybackViewModel({required this.queuedSongs});

  final List<Song> queuedSongs;
}

class SongBookCallbacks {
  const SongBookCallbacks({
    required this.navigation,
    required this.library,
    required this.playback,
  });

  final SongBookNavigationCallbacks navigation;
  final SongBookLibraryCallbacks library;
  final SongBookPlaybackCallbacks playback;
}

class SongBookNavigationCallbacks {
  const SongBookNavigationCallbacks({
    required this.onBackPressed,
    required this.onQueuePressed,
    required this.onSelectArtist,
    required this.onSettingsPressed,
  });

  final VoidCallback onBackPressed;
  final VoidCallback onQueuePressed;
  final ValueChanged<String> onSelectArtist;
  final VoidCallback onSettingsPressed;
}

class SongBookLibraryCallbacks {
  const SongBookLibraryCallbacks({
    required this.onLanguageSelected,
    required this.onAppendSearchToken,
    required this.onRemoveSearchCharacter,
    required this.onClearSearch,
    required this.onLoadMore,
    required this.onRequestSong,
    required this.onToggleFavorite,
    required this.onDownloadSong,
  });

  final ValueChanged<String> onLanguageSelected;
  final ValueChanged<String> onAppendSearchToken;
  final VoidCallback onRemoveSearchCharacter;
  final VoidCallback onClearSearch;
  final VoidCallback onLoadMore;
  final ValueChanged<Song> onRequestSong;
  final ValueChanged<Song> onToggleFavorite;
  final ValueChanged<Song> onDownloadSong;
}

class SongBookPlaybackCallbacks {
  const SongBookPlaybackCallbacks({
    required this.onPrioritizeQueuedSong,
    required this.onRemoveQueuedSong,
    required this.onToggleAudioMode,
    required this.onTogglePlayback,
    required this.onRestartPlayback,
    required this.onSkipSong,
  });

  final ValueChanged<Song> onPrioritizeQueuedSong;
  final ValueChanged<Song> onRemoveQueuedSong;
  final VoidCallback onToggleAudioMode;
  final VoidCallback onTogglePlayback;
  final VoidCallback onRestartPlayback;
  final VoidCallback onSkipSong;
}
