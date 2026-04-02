import 'package:flutter/material.dart';

import '../../../core/models/demo_artist.dart';
import '../../../core/models/demo_song.dart';
import '../application/ktv_demo_controller.dart';

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
    required this.selectedArtist,
    required this.breadcrumbLabel,
  });

  final DemoRoute route;
  final DemoSongBookMode songBookMode;
  final String? selectedArtist;
  final String breadcrumbLabel;
}

class SongBookLibraryViewModel {
  const SongBookLibraryViewModel({
    required this.searchQuery,
    required this.selectedLanguage,
    required this.songs,
    required this.artists,
    required this.totalCount,
    required this.pageIndex,
    required this.totalPages,
    required this.pageSize,
    required this.hasConfiguredDirectory,
    required this.isScanning,
    required this.isLoadingPage,
    required this.scanErrorMessage,
  });

  final String searchQuery;
  final String selectedLanguage;
  final List<DemoSong> songs;
  final List<DemoArtist> artists;
  final int totalCount;
  final int pageIndex;
  final int totalPages;
  final int pageSize;
  final bool hasConfiguredDirectory;
  final bool isScanning;
  final bool isLoadingPage;
  final String? scanErrorMessage;
}

class SongBookPlaybackViewModel {
  const SongBookPlaybackViewModel({required this.queuedSongs});

  final List<DemoSong> queuedSongs;
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
    required this.onRequestLibraryPage,
    required this.onRequestSong,
  });

  final ValueChanged<String> onLanguageSelected;
  final ValueChanged<String> onAppendSearchToken;
  final VoidCallback onRemoveSearchCharacter;
  final VoidCallback onClearSearch;
  final void Function(int pageIndex, int pageSize) onRequestLibraryPage;
  final ValueChanged<DemoSong> onRequestSong;
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

  final ValueChanged<DemoSong> onPrioritizeQueuedSong;
  final ValueChanged<DemoSong> onRemoveQueuedSong;
  final VoidCallback onToggleAudioMode;
  final VoidCallback onTogglePlayback;
  final VoidCallback onRestartPlayback;
  final VoidCallback onSkipSong;
}
