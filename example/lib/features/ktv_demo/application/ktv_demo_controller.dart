import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ktv2/ktv2.dart';

import '../../../core/models/demo_song.dart';
import '../../media_library/data/demo_media_library_repository.dart';
import 'ktv_demo_state.dart';

export 'ktv_demo_state.dart' show DemoRoute, KtvDemoState;

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

  KtvDemoState _state = const KtvDemoState();
  bool _didInitialize = false;

  DemoMediaLibraryRepository get mediaLibraryRepository =>
      _mediaLibraryRepository;
  KtvDemoState get state => _state;

  DemoRoute get route => _state.route;
  String get selectedLanguage => _state.selectedLanguage;
  String? get libraryScanErrorMessage => _state.libraryScanErrorMessage;
  String? get scanDirectoryPath => _state.scanDirectoryPath;
  bool get isScanningLibrary => _state.isScanningLibrary;
  bool get hasConfiguredDirectory => _state.hasConfiguredDirectory;
  List<DemoSong> get queuedSongs =>
      List<DemoSong>.unmodifiable(_state.queuedSongs);
  List<DemoSong> get librarySongs =>
      List<DemoSong>.unmodifiable(_state.librarySongs);

  List<DemoSong> get filteredSongs => _state.filteredSongs(allLanguagesLabel);

  String get currentTitle => _state.currentTitle;

  String get currentSubtitle => _state.currentSubtitle;

  Future<void> initialize() async {
    if (_didInitialize) {
      return;
    }
    _didInitialize = true;
    await _restoreSavedDirectory();
  }

  void setSearchQuery(String query) {
    if (_state.searchQuery == query) {
      return;
    }
    _setState(_state.copyWith(searchQuery: query));
  }

  void enterSongBook() {
    if (_state.route == DemoRoute.songBook) {
      return;
    }
    _setState(_state.copyWith(route: DemoRoute.songBook));
  }

  void returnHome() {
    if (_state.route == DemoRoute.home) {
      return;
    }
    _setState(_state.copyWith(route: DemoRoute.home));
  }

  void selectLanguage(String language) {
    if (_state.selectedLanguage == language) {
      return;
    }
    _setState(_state.copyWith(selectedLanguage: language));
  }

  Future<void> handleSelectedDirectory(String directory) async {
    _setState(_state.copyWith(scanDirectoryPath: directory));
    await _mediaLibraryRepository.saveSelectedDirectory(directory);
    await scanLibrary(directory);
  }

  Future<bool> scanLibrary(String directory) async {
    _setState(
      _state.copyWith(isScanningLibrary: true, libraryScanErrorMessage: null),
    );

    try {
      final List<DemoSong> songs = await _mediaLibraryRepository.scanLibrary(
        directory,
      );
      _setState(
        _state.copyWith(
          librarySongs: songs,
          libraryScanErrorMessage: null,
          selectedLanguage: allLanguagesLabel,
          route: DemoRoute.songBook,
          searchQuery: '',
        ),
      );
      return true;
    } catch (error) {
      _setState(
        _state.copyWith(
          librarySongs: <DemoSong>[],
          libraryScanErrorMessage: '扫描目录失败：$error',
        ),
      );
      return false;
    } finally {
      _setState(_state.copyWith(isScanningLibrary: false));
    }
  }

  Future<void> playSong(DemoSong song) async {
    await playerController.openMedia(
      MediaSource(path: song.mediaPath, displayName: song.title),
    );
    final List<DemoSong> queuedSongs = List<DemoSong>.of(_state.queuedSongs)
      ..remove(song)
      ..insert(0, song);
    _setState(_state.copyWith(queuedSongs: queuedSongs));
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

  Future<void> stopPlayback() {
    return playerController.stopPlayback();
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

    _setState(_state.copyWith(scanDirectoryPath: savedDirectory));
    await scanLibrary(savedDirectory);
  }

  void _setState(KtvDemoState nextState) {
    if (identical(_state, nextState)) {
      return;
    }
    _state = nextState;
    notifyListeners();
  }

  @override
  void dispose() {
    playerController.dispose();
    super.dispose();
  }
}
