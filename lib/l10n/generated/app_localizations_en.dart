// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Karaoke Cinema';

  @override
  String get settings => 'Settings';

  @override
  String get home => 'Home';

  @override
  String get interfaceSection => 'Interface';

  @override
  String get language => 'Language';

  @override
  String get languageSubtitle => 'Choose the app display language';

  @override
  String get languagePageDescription =>
      'The app follows your system language by default. A manual choice is remembered.';

  @override
  String get followSystem => 'Follow system';

  @override
  String get simplifiedChinese => '简体中文';

  @override
  String get traditionalChinese => '繁體中文';

  @override
  String get english => 'English';

  @override
  String get dataSources => 'Data sources';

  @override
  String get settingsDescription =>
      'Manage sources for your song library. Configured sources are scanned and included in search results.';

  @override
  String get other => 'Other';

  @override
  String get downloadManager => 'Downloads';

  @override
  String downloadSummary(int pendingCount, int downloadedCount) {
    return '$pendingCount pending, $downloadedCount downloaded';
  }

  @override
  String downloadedSongsCount(int count) {
    return '$count songs downloaded';
  }

  @override
  String get downloadManagerSubtitle => 'View active and completed downloads';

  @override
  String get loading => 'Loading';

  @override
  String configuredPath(String path) {
    return 'Configured: $path';
  }

  @override
  String get configured => 'Configured';

  @override
  String get notConfigured => 'Not configured';

  @override
  String get notSignedIn => 'Not signed in';

  @override
  String get localDirectory => 'Local folder';

  @override
  String get baiduNetdisk => 'Baidu Netdisk';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get aboutUs => 'About';

  @override
  String get aboutUsSubtitle => 'App information and source code';

  @override
  String get charts => 'Charts';

  @override
  String get songTitle => 'Songs';

  @override
  String get artist => 'Artists';

  @override
  String get local => 'Local';

  @override
  String get favorites => 'Favorites';

  @override
  String get frequent => 'Frequent';

  @override
  String get categories => 'Categories';

  @override
  String get backToSongbook => 'Songbook';

  @override
  String get pause => 'Pause';

  @override
  String get play => 'Play';

  @override
  String get replay => 'Replay';

  @override
  String get skip => 'Skip';

  @override
  String get originalVocal => 'Original';

  @override
  String get accompaniment => 'Backing';

  @override
  String get pitchDown => 'Lower';

  @override
  String get pitchUp => 'Raise';

  @override
  String get originalKey => 'Original key';

  @override
  String pitchShiftValue(String value) {
    return 'Key $value';
  }

  @override
  String queuedCount(int count) {
    return 'Queue $count';
  }

  @override
  String get previousPage => 'Previous';

  @override
  String get nextPage => 'Next';

  @override
  String get searchQueueHint => 'Search queued songs or artists';

  @override
  String get searchArtistHint => 'Enter an artist name';

  @override
  String get searchSongHint => 'Enter a song title or Pinyin initials';

  @override
  String get noNextSong => 'No next song';

  @override
  String get addedToQueue => 'Added to queue';

  @override
  String get downloadResumed => 'Download resumed';

  @override
  String get downloading => 'Downloading';

  @override
  String downloadedToLocalDirectory(String fileName) {
    return 'Downloaded to local folder: $fileName';
  }

  @override
  String downloadedToAppDirectory(String fileName) {
    return 'Downloaded to app folder: $fileName';
  }

  @override
  String get cancelled => 'Cancelled';

  @override
  String get paused => 'Paused';

  @override
  String get downloadFailed => 'Download failed';

  @override
  String get allLanguages => 'All';

  @override
  String get mandarin => 'Mandarin';

  @override
  String get cantonese => 'Cantonese';

  @override
  String get minNan => 'Min Nan';

  @override
  String get englishLanguage => 'English';

  @override
  String get japanese => 'Japanese';

  @override
  String get korean => 'Korean';

  @override
  String get otherLanguage => 'Other';

  @override
  String get currentPlayback => 'Now playing';

  @override
  String get queued => 'Queued';

  @override
  String get back => 'Back';

  @override
  String queuePosition(int position) {
    return 'Queue $position';
  }

  @override
  String get waitingForDownload => 'Waiting';

  @override
  String get downloadPaused => 'Paused';

  @override
  String get downloadError => 'Download failed';

  @override
  String get noLocalDirectory =>
      'Choose a local folder in Settings. Songs will appear here after scanning.';

  @override
  String get noDataSource =>
      'Configure a data source in Settings to build your combined library.';

  @override
  String get scanningLocalSongs => 'Scanning songs in your local folder...';

  @override
  String get loadingArtists => 'Loading artists...';

  @override
  String get loadingSongs => 'Loading songs...';

  @override
  String get noMatchingArtists =>
      'No artists match. Try another language or clear the search.';

  @override
  String get noFavorites =>
      'No favorite songs here yet. Add some from the local list.';

  @override
  String get noFrequentSongs =>
      'No frequently played songs yet. Play a few songs to build this list.';

  @override
  String get noPlayableVideos =>
      'No playable videos were found. Check that the folder contains supported media files.';

  @override
  String get noArtistSongs =>
      'No songs match this artist. Try another language or clear the search.';

  @override
  String get emptyQueue => 'The queue is empty. Choose a song to add it here.';

  @override
  String get noQueueMatches =>
      'No queued songs match. Try clearing the search.';

  @override
  String get localFiles => 'Local files';

  @override
  String get iosLocalFilesDescription =>
      'iPhone and iPad cannot mount a folder like a desktop. Choose videos to import into the app. Future imports are added to the same local library.';

  @override
  String get localDirectoryDescription =>
      'Choose a local folder to scan for songs. Choosing another folder replaces the current scan location.';

  @override
  String get appLibraryDirectory => 'In-app library folder';

  @override
  String get currentDirectory => 'Current folder';

  @override
  String get noImportedVideos => 'No local videos have been imported.';

  @override
  String get noConfiguredDirectory => 'No local folder has been configured.';

  @override
  String get importing => 'Importing';

  @override
  String get selecting => 'Selecting';

  @override
  String get importFiles => 'Import files';

  @override
  String get selectDirectory => 'Choose folder';

  @override
  String get selectVideo => 'Choose video';

  @override
  String get webDavDescription =>
      'Connect a WebDAV drive, NAS, or private cloud. HTTP is allowed for local network addresses; public addresses must use HTTPS. Credentials are stored only in secure system storage.';

  @override
  String get serverAddress => 'Server address';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get passwordKeepHint => 'Password (leave blank to keep it)';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get songRootDirectory => 'Song root folder';

  @override
  String get testing => 'Testing';

  @override
  String get testConnection => 'Test connection';

  @override
  String get saving => 'Saving';

  @override
  String get saveAndScan => 'Save and scan';

  @override
  String get clearWebDavConfiguration => 'Clear WebDAV configuration';

  @override
  String pendingDownloadsTab(int count) {
    return 'Pending ($count)';
  }

  @override
  String downloadedTab(int count) {
    return 'Downloaded ($count)';
  }

  @override
  String get noPendingDownloads => 'There are no pending downloads.';

  @override
  String get noDownloadedSongs => 'There are no downloaded songs yet.';

  @override
  String get downloadComplete => 'Download complete';

  @override
  String get resumeDownload => 'Resume download';

  @override
  String get pauseDownload => 'Pause download';

  @override
  String get cancelDownload => 'Cancel download';

  @override
  String get deleteSourceFile => 'Delete source file';

  @override
  String get deleted => 'Deleted';

  @override
  String get deleteDownloadedFile => 'Delete downloaded file';

  @override
  String deleteDownloadedFileMessage(String title, String source) {
    return 'The local file will be deleted: $title\nSource: $source';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get versionInformation => 'Version';

  @override
  String get appIntroduction => 'About the app';

  @override
  String get appDescription =>
      'Karaoke Cinema is a video-first song selection and playback app for quickly finding and playing music videos from local or cloud libraries.';

  @override
  String get sourceCodeAddress => 'Source code';

  @override
  String get viewReleasePage => 'View releases';

  @override
  String get sourceCodeCopied => 'Source code address copied';

  @override
  String get copyAddress => 'Copy address';

  @override
  String get reading => 'Loading';

  @override
  String get notChecked => 'Not checked';

  @override
  String get unknown => 'Unknown';

  @override
  String versionSummary(
    String currentVersion,
    String latestVersion,
    String lastCheckedAt,
  ) {
    return 'Current version: $currentVersion\nLatest version: $latestVersion\nLast checked: $lastCheckedAt';
  }

  @override
  String get currentStatus => 'Current status';

  @override
  String get releaseNotes => 'Release notes';

  @override
  String get noReleaseNotes => 'No release notes are available.';

  @override
  String get checking => 'Checking';

  @override
  String get updateNow => 'Update now';

  @override
  String get updateStatusIdle => 'Not checked yet';

  @override
  String get updateStatusUnavailable => 'Online updates are unavailable';

  @override
  String get updateStatusCurrent => 'Up to date';

  @override
  String get updateStatusAvailable => 'A new version is available';

  @override
  String get updateStatusFailed => 'Update check failed';

  @override
  String get updateInitialMessage =>
      'View the current version or check for updates manually.';

  @override
  String updateSummary(
    String status,
    String currentVersion,
    String latestVersion,
    String publishedAt,
    String lastCheckedAt,
    String message,
  ) {
    return 'Status: $status\nCurrent version: $currentVersion\nLatest version: $latestVersion\nPublished: $publishedAt\nLast checked: $lastCheckedAt\nDetails: $message';
  }

  @override
  String get baiduDescription =>
      'Baidu Open Platform credentials are built into the app. A QR code opens automatically when you are signed out. After signing in, choose the song root folder.';

  @override
  String configuredSongRoot(String path) {
    return 'Configured song root: $path';
  }

  @override
  String savedRootNotSignedIn(String path) {
    return 'Signed out; saved song root: $path';
  }

  @override
  String get baiduNotConfigured => 'Baidu Netdisk is not configured';

  @override
  String get appAuthorizationConfiguration => 'App authorization';

  @override
  String get authorizationEmbedded => 'App authorization is built in';

  @override
  String get authorizationMissing => 'App authorization is missing';

  @override
  String get loginComplete => 'Signed in';

  @override
  String get scanToLogin => 'Scan to sign in';

  @override
  String get baiduAuthorizedDescription =>
      'Your Baidu Netdisk account is signed in. You can now choose and scan a song folder.';

  @override
  String get baiduQrDescription =>
      'A QR code was generated automatically. Scan it with the Baidu app to authorize and sign in.';

  @override
  String get loginStatus => 'Sign-in status';

  @override
  String signedInDetails(String account, String quota, String expiresAt) {
    return 'Signed in\nAccount: $account\nStorage: $quota\nToken expires: $expiresAt';
  }

  @override
  String get unknownAccount => 'Unknown account';

  @override
  String get saveQrToPhone => 'Save QR code to phone';

  @override
  String get generating => 'Generating';

  @override
  String get refreshQrCode => 'Refresh QR code';

  @override
  String get signedOut => 'Signed out';

  @override
  String get signOut => 'Sign out';

  @override
  String get rootPathExample => 'For example, /KTV';

  @override
  String get directorySaved => 'Folder saved';

  @override
  String get saveAndScanFolder => 'Save and scan folder';

  @override
  String get saveDirectory => 'Save folder';

  @override
  String get clear => 'Clear';

  @override
  String get loginQrCode => 'Sign-in QR code';

  @override
  String get qrCodeLoadFailed => 'QR code failed to load';

  @override
  String qrCodeDetails(String userCode, String verificationUrl) {
    return 'User code: $userCode\nVerification page: $verificationUrl';
  }

  @override
  String sourceLabel(String source) {
    return 'Source: $source';
  }

  @override
  String get saved => 'Saved';

  @override
  String saveQrFailed(Object error) {
    return 'Could not save QR code: $error';
  }
}
