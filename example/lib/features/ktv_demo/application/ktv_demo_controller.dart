import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ktv2/ktv2.dart';

import '../../../core/models/demo_song.dart';
import '../../media_library/data/demo_media_library_repository.dart';

enum DemoRoute { home, songBook }

class KtvDemoController extends ChangeNotifier {
  KtvDemoController({
    DemoMediaLibraryRepository? mediaLibraryRepository,
    PlayerController? playerController,
  }) : _mediaLibraryRepository =
           mediaLibraryRepository ?? DemoMediaLibraryRepository(),
       playerController = playerController ?? createPlayerController();

  static const String allLanguagesLabel = '全部';

  final DemoMediaLibraryRepository _mediaLibraryRepository;
  final PlayerController playerController;

  final List<DemoSong> _queuedSongs = <DemoSong>[];
  List<DemoSong> _librarySongs = <DemoSong>[];

  DemoRoute _route = DemoRoute.home;
  String _selectedLanguage = allLanguagesLabel;
  String? _libraryScanErrorMessage;
  String? _scanDirectoryPath;
  String _searchQuery = '';
  bool _isScanningLibrary = false;
  bool _didInitialize = false;

  DemoMediaLibraryRepository get mediaLibraryRepository =>
      _mediaLibraryRepository;

  DemoRoute get route => _route;
  String get selectedLanguage => _selectedLanguage;
  String? get libraryScanErrorMessage => _libraryScanErrorMessage;
  String? get scanDirectoryPath => _scanDirectoryPath;
  bool get isScanningLibrary => _isScanningLibrary;
  bool get hasConfiguredDirectory => _scanDirectoryPath != null;
  List<DemoSong> get queuedSongs => List<DemoSong>.unmodifiable(_queuedSongs);
  List<DemoSong> get librarySongs => List<DemoSong>.unmodifiable(_librarySongs);

  List<DemoSong> get filteredSongs {
    final String normalizedQuery = _searchQuery.trim().toLowerCase();
    return _librarySongs
        .where((DemoSong song) {
          final bool languageMatches =
              _selectedLanguage == allLanguagesLabel ||
              song.language == _selectedLanguage;
          if (!languageMatches) {
            return false;
          }
          if (normalizedQuery.isEmpty) {
            return true;
          }
          final String haystack =
              '${song.title} ${song.artist} ${song.searchIndex}'.toLowerCase();
          return haystack.contains(normalizedQuery);
        })
        .toList(growable: false);
  }

  String get currentTitle {
    if (_queuedSongs.isNotEmpty) {
      return _queuedSongs.first.title;
    }
    return '等待点唱';
  }

  String get currentSubtitle {
    if (_queuedSongs.isNotEmpty) {
      return '${_queuedSongs.first.artist} · 已从目录中加载 ${_librarySongs.length} 首';
    }
    if (_scanDirectoryPath != null && _librarySongs.isNotEmpty) {
      return '已从扫描目录加载 ${_librarySongs.length} 首歌曲。';
    }
    return '请先在设置中选择扫描目录。';
  }

  Future<void> initialize() async {
    if (_didInitialize) {
      return;
    }
    _didInitialize = true;
    await _restoreSavedDirectory();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) {
      return;
    }
    _searchQuery = query;
    notifyListeners();
  }

  void enterSongBook() {
    if (_route == DemoRoute.songBook) {
      return;
    }
    _route = DemoRoute.songBook;
    notifyListeners();
  }

  void returnHome() {
    if (_route == DemoRoute.home) {
      return;
    }
    _route = DemoRoute.home;
    notifyListeners();
  }

  void selectLanguage(String language) {
    if (_selectedLanguage == language) {
      return;
    }
    _selectedLanguage = language;
    notifyListeners();
  }

  Future<void> handleSelectedDirectory(String directory) async {
    _scanDirectoryPath = directory;
    notifyListeners();
    await _mediaLibraryRepository.saveSelectedDirectory(directory);
    await scanLibrary(directory);
  }

  Future<bool> scanLibrary(String directory) async {
    _isScanningLibrary = true;
    _libraryScanErrorMessage = null;
    notifyListeners();

    try {
      final List<DemoSong> songs = await _mediaLibraryRepository.scanLibrary(
        directory,
      );
      _librarySongs = songs;
      _libraryScanErrorMessage = null;
      _selectedLanguage = allLanguagesLabel;
      _route = DemoRoute.songBook;
      _searchQuery = '';
      notifyListeners();
      return true;
    } catch (error) {
      _librarySongs = <DemoSong>[];
      _libraryScanErrorMessage = '扫描目录失败：$error';
      notifyListeners();
      return false;
    } finally {
      _isScanningLibrary = false;
      notifyListeners();
    }
  }

  Future<void> playSong(DemoSong song) async {
    await playerController.openMedia(
      MediaSource(path: song.mediaPath, displayName: song.title),
    );
    _queuedSongs
      ..remove(song)
      ..insert(0, song);
    notifyListeners();
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

  Future<void> _restoreSavedDirectory() async {
    final String? savedDirectory = await _mediaLibraryRepository
        .loadSelectedDirectory();
    if (savedDirectory == null) {
      return;
    }

    final bool hasAccess = await _mediaLibraryRepository.ensureDirectoryAccess(
      savedDirectory,
    );
    if (!hasAccess) {
      await _mediaLibraryRepository.clearDirectoryAccess(path: savedDirectory);
      return;
    }

    _scanDirectoryPath = savedDirectory;
    notifyListeners();
    await scanLibrary(savedDirectory);
  }

  @override
  void dispose() {
    playerController.dispose();
    super.dispose();
  }
}
