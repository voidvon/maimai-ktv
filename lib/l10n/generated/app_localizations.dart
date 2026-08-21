import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'麦麦KTV'**
  String get appName;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @home.
  ///
  /// In zh, this message translates to:
  /// **'主页'**
  String get home;

  /// No description provided for @interfaceSection.
  ///
  /// In zh, this message translates to:
  /// **'界面'**
  String get interfaceSection;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @languageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择应用显示语言'**
  String get languageSubtitle;

  /// No description provided for @languagePageDescription.
  ///
  /// In zh, this message translates to:
  /// **'默认跟随系统语言。手动选择后，应用会记住你的设置。'**
  String get languagePageDescription;

  /// No description provided for @followSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get followSystem;

  /// No description provided for @simplifiedChinese.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get simplifiedChinese;

  /// No description provided for @traditionalChinese.
  ///
  /// In zh, this message translates to:
  /// **'繁體中文'**
  String get traditionalChinese;

  /// No description provided for @english.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @dataSources.
  ///
  /// In zh, this message translates to:
  /// **'数据源'**
  String get dataSources;

  /// No description provided for @settingsDescription.
  ///
  /// In zh, this message translates to:
  /// **'管理当前点歌库的数据来源。已配置的数据源会用于扫描、检索和展示歌曲列表。'**
  String get settingsDescription;

  /// No description provided for @other.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get other;

  /// No description provided for @downloadManager.
  ///
  /// In zh, this message translates to:
  /// **'下载管理'**
  String get downloadManager;

  /// No description provided for @downloadSummary.
  ///
  /// In zh, this message translates to:
  /// **'未完成 {pendingCount} 首，已下载 {downloadedCount} 首'**
  String downloadSummary(int pendingCount, int downloadedCount);

  /// No description provided for @downloadedSongsCount.
  ///
  /// In zh, this message translates to:
  /// **'已下载 {count} 首歌曲'**
  String downloadedSongsCount(int count);

  /// No description provided for @downloadManagerSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'查看下载中和已下载的歌曲列表'**
  String get downloadManagerSubtitle;

  /// No description provided for @loading.
  ///
  /// In zh, this message translates to:
  /// **'加载中'**
  String get loading;

  /// No description provided for @configuredPath.
  ///
  /// In zh, this message translates to:
  /// **'已配置 {path}'**
  String configuredPath(String path);

  /// No description provided for @configured.
  ///
  /// In zh, this message translates to:
  /// **'已配置'**
  String get configured;

  /// No description provided for @notConfigured.
  ///
  /// In zh, this message translates to:
  /// **'未配置'**
  String get notConfigured;

  /// No description provided for @notSignedIn.
  ///
  /// In zh, this message translates to:
  /// **'未登录'**
  String get notSignedIn;

  /// No description provided for @localDirectory.
  ///
  /// In zh, this message translates to:
  /// **'本地目录'**
  String get localDirectory;

  /// No description provided for @baiduNetdisk.
  ///
  /// In zh, this message translates to:
  /// **'百度网盘'**
  String get baiduNetdisk;

  /// No description provided for @checkForUpdates.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get checkForUpdates;

  /// No description provided for @aboutUs.
  ///
  /// In zh, this message translates to:
  /// **'关于我们'**
  String get aboutUs;

  /// No description provided for @aboutUsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'查看应用简介和开源地址'**
  String get aboutUsSubtitle;

  /// No description provided for @charts.
  ///
  /// In zh, this message translates to:
  /// **'排行榜'**
  String get charts;

  /// No description provided for @songTitle.
  ///
  /// In zh, this message translates to:
  /// **'歌名'**
  String get songTitle;

  /// No description provided for @artist.
  ///
  /// In zh, this message translates to:
  /// **'歌星'**
  String get artist;

  /// No description provided for @local.
  ///
  /// In zh, this message translates to:
  /// **'本地'**
  String get local;

  /// No description provided for @favorites.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get favorites;

  /// No description provided for @frequent.
  ///
  /// In zh, this message translates to:
  /// **'常唱'**
  String get frequent;

  /// No description provided for @categories.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get categories;

  /// No description provided for @backToSongbook.
  ///
  /// In zh, this message translates to:
  /// **'返回点歌'**
  String get backToSongbook;

  /// No description provided for @pause.
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get pause;

  /// No description provided for @play.
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get play;

  /// No description provided for @replay.
  ///
  /// In zh, this message translates to:
  /// **'重唱'**
  String get replay;

  /// No description provided for @skip.
  ///
  /// In zh, this message translates to:
  /// **'切歌'**
  String get skip;

  /// No description provided for @originalVocal.
  ///
  /// In zh, this message translates to:
  /// **'原唱'**
  String get originalVocal;

  /// No description provided for @accompaniment.
  ///
  /// In zh, this message translates to:
  /// **'伴唱'**
  String get accompaniment;

  /// No description provided for @pitchDown.
  ///
  /// In zh, this message translates to:
  /// **'降调'**
  String get pitchDown;

  /// No description provided for @pitchUp.
  ///
  /// In zh, this message translates to:
  /// **'升调'**
  String get pitchUp;

  /// No description provided for @originalKey.
  ///
  /// In zh, this message translates to:
  /// **'原调'**
  String get originalKey;

  /// No description provided for @pitchShiftValue.
  ///
  /// In zh, this message translates to:
  /// **'{value}调'**
  String pitchShiftValue(String value);

  /// No description provided for @queuedCount.
  ///
  /// In zh, this message translates to:
  /// **'已点{count}'**
  String queuedCount(int count);

  /// No description provided for @previousPage.
  ///
  /// In zh, this message translates to:
  /// **'上一页'**
  String get previousPage;

  /// No description provided for @nextPage.
  ///
  /// In zh, this message translates to:
  /// **'下一页'**
  String get nextPage;

  /// No description provided for @searchQueueHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索已点歌曲 / 歌手'**
  String get searchQueueHint;

  /// No description provided for @searchArtistHint.
  ///
  /// In zh, this message translates to:
  /// **'输入歌手名称'**
  String get searchArtistHint;

  /// No description provided for @searchSongHint.
  ///
  /// In zh, this message translates to:
  /// **'输入歌名 / 中文 / 拼音首字母'**
  String get searchSongHint;

  /// No description provided for @noNextSong.
  ///
  /// In zh, this message translates to:
  /// **'暂无下一首'**
  String get noNextSong;

  /// No description provided for @addedToQueue.
  ///
  /// In zh, this message translates to:
  /// **'已加入已点'**
  String get addedToQueue;

  /// No description provided for @downloadResumed.
  ///
  /// In zh, this message translates to:
  /// **'已恢复下载'**
  String get downloadResumed;

  /// No description provided for @downloading.
  ///
  /// In zh, this message translates to:
  /// **'正在下载'**
  String get downloading;

  /// No description provided for @downloadedToLocalDirectory.
  ///
  /// In zh, this message translates to:
  /// **'已下载到本地目录：{fileName}'**
  String downloadedToLocalDirectory(String fileName);

  /// No description provided for @downloadedToAppDirectory.
  ///
  /// In zh, this message translates to:
  /// **'已下载到应用目录：{fileName}'**
  String downloadedToAppDirectory(String fileName);

  /// No description provided for @cancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消'**
  String get cancelled;

  /// No description provided for @paused.
  ///
  /// In zh, this message translates to:
  /// **'已暂停'**
  String get paused;

  /// No description provided for @downloadFailed.
  ///
  /// In zh, this message translates to:
  /// **'下载失败'**
  String get downloadFailed;

  /// No description provided for @allLanguages.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get allLanguages;

  /// No description provided for @mandarin.
  ///
  /// In zh, this message translates to:
  /// **'国语'**
  String get mandarin;

  /// No description provided for @cantonese.
  ///
  /// In zh, this message translates to:
  /// **'粤语'**
  String get cantonese;

  /// No description provided for @minNan.
  ///
  /// In zh, this message translates to:
  /// **'闽南语'**
  String get minNan;

  /// No description provided for @englishLanguage.
  ///
  /// In zh, this message translates to:
  /// **'英语'**
  String get englishLanguage;

  /// No description provided for @japanese.
  ///
  /// In zh, this message translates to:
  /// **'日语'**
  String get japanese;

  /// No description provided for @korean.
  ///
  /// In zh, this message translates to:
  /// **'韩语'**
  String get korean;

  /// No description provided for @otherLanguage.
  ///
  /// In zh, this message translates to:
  /// **'其它'**
  String get otherLanguage;

  /// No description provided for @currentPlayback.
  ///
  /// In zh, this message translates to:
  /// **'当前播放'**
  String get currentPlayback;

  /// No description provided for @queued.
  ///
  /// In zh, this message translates to:
  /// **'已点'**
  String get queued;

  /// No description provided for @back.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get back;

  /// No description provided for @queuePosition.
  ///
  /// In zh, this message translates to:
  /// **'队列 {position}'**
  String queuePosition(int position);

  /// No description provided for @waitingForDownload.
  ///
  /// In zh, this message translates to:
  /// **'等待下载'**
  String get waitingForDownload;

  /// No description provided for @downloadPaused.
  ///
  /// In zh, this message translates to:
  /// **'已暂停'**
  String get downloadPaused;

  /// No description provided for @downloadError.
  ///
  /// In zh, this message translates to:
  /// **'下载失败'**
  String get downloadError;

  /// No description provided for @noLocalDirectory.
  ///
  /// In zh, this message translates to:
  /// **'请先在设置里配置本地目录，扫描完成后这里会展示歌曲列表。'**
  String get noLocalDirectory;

  /// No description provided for @noDataSource.
  ///
  /// In zh, this message translates to:
  /// **'请先在设置里配置数据源，配置完成后这里会展示聚合曲库。'**
  String get noDataSource;

  /// No description provided for @scanningLocalSongs.
  ///
  /// In zh, this message translates to:
  /// **'正在扫描本地目录中的歌曲，请稍候。'**
  String get scanningLocalSongs;

  /// No description provided for @loadingArtists.
  ///
  /// In zh, this message translates to:
  /// **'正在加载歌手列表，请稍候。'**
  String get loadingArtists;

  /// No description provided for @loadingSongs.
  ///
  /// In zh, this message translates to:
  /// **'正在加载歌曲列表，请稍候。'**
  String get loadingSongs;

  /// No description provided for @noMatchingArtists.
  ///
  /// In zh, this message translates to:
  /// **'当前条件下没有可显示的歌手，试试切换语言或清空搜索关键字。'**
  String get noMatchingArtists;

  /// No description provided for @noFavorites.
  ///
  /// In zh, this message translates to:
  /// **'当前目录下还没有收藏歌曲，先去本地列表点亮爱心。'**
  String get noFavorites;

  /// No description provided for @noFrequentSongs.
  ///
  /// In zh, this message translates to:
  /// **'当前目录下还没有常唱记录，开始播放几首歌后会显示在这里。'**
  String get noFrequentSongs;

  /// No description provided for @noPlayableVideos.
  ///
  /// In zh, this message translates to:
  /// **'当前目录下没有扫描到可播放视频文件，请确认目录中包含常见视频格式媒体文件。'**
  String get noPlayableVideos;

  /// No description provided for @noArtistSongs.
  ///
  /// In zh, this message translates to:
  /// **'当前歌手下没有匹配的歌曲，试试切换语言或清空搜索关键字。'**
  String get noArtistSongs;

  /// No description provided for @emptyQueue.
  ///
  /// In zh, this message translates to:
  /// **'当前还没有已点歌曲，点歌后会在这里显示。'**
  String get emptyQueue;

  /// No description provided for @noQueueMatches.
  ///
  /// In zh, this message translates to:
  /// **'当前关键字下没有匹配的已点歌曲，试试清空搜索关键字。'**
  String get noQueueMatches;

  /// No description provided for @localFiles.
  ///
  /// In zh, this message translates to:
  /// **'本地文件'**
  String get localFiles;

  /// No description provided for @iosLocalFilesDescription.
  ///
  /// In zh, this message translates to:
  /// **'iPhone 和 iPad 不支持像桌面端那样直接挂载本地目录。请选择要导入到应用内的视频文件，导入后会在应用内建立本地歌库，再次导入会继续追加到当前歌库。'**
  String get iosLocalFilesDescription;

  /// No description provided for @localDirectoryDescription.
  ///
  /// In zh, this message translates to:
  /// **'配置本地目录后，点歌页会基于这个目录建立扫描范围。重新选择后会覆盖当前使用的本地目录。'**
  String get localDirectoryDescription;

  /// No description provided for @appLibraryDirectory.
  ///
  /// In zh, this message translates to:
  /// **'应用内歌库目录'**
  String get appLibraryDirectory;

  /// No description provided for @currentDirectory.
  ///
  /// In zh, this message translates to:
  /// **'当前目录'**
  String get currentDirectory;

  /// No description provided for @noImportedVideos.
  ///
  /// In zh, this message translates to:
  /// **'当前还没有导入本地视频文件。'**
  String get noImportedVideos;

  /// No description provided for @noConfiguredDirectory.
  ///
  /// In zh, this message translates to:
  /// **'当前还没有配置本地目录。'**
  String get noConfiguredDirectory;

  /// No description provided for @importing.
  ///
  /// In zh, this message translates to:
  /// **'导入中'**
  String get importing;

  /// No description provided for @selecting.
  ///
  /// In zh, this message translates to:
  /// **'选择中'**
  String get selecting;

  /// No description provided for @importFiles.
  ///
  /// In zh, this message translates to:
  /// **'导入文件'**
  String get importFiles;

  /// No description provided for @selectDirectory.
  ///
  /// In zh, this message translates to:
  /// **'选择目录'**
  String get selectDirectory;

  /// No description provided for @selectVideo.
  ///
  /// In zh, this message translates to:
  /// **'选择视频'**
  String get selectVideo;

  /// No description provided for @webDavDescription.
  ///
  /// In zh, this message translates to:
  /// **'连接支持 WebDAV 的网盘、NAS 或私有云。局域网地址可以使用 HTTP，公网地址必须使用 HTTPS。账号密码仅保存在系统安全存储中。'**
  String get webDavDescription;

  /// No description provided for @serverAddress.
  ///
  /// In zh, this message translates to:
  /// **'服务器地址'**
  String get serverAddress;

  /// No description provided for @username.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get username;

  /// No description provided for @password.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get password;

  /// No description provided for @passwordKeepHint.
  ///
  /// In zh, this message translates to:
  /// **'密码（留空则保持不变）'**
  String get passwordKeepHint;

  /// No description provided for @showPassword.
  ///
  /// In zh, this message translates to:
  /// **'显示密码'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In zh, this message translates to:
  /// **'隐藏密码'**
  String get hidePassword;

  /// No description provided for @songRootDirectory.
  ///
  /// In zh, this message translates to:
  /// **'歌曲根目录'**
  String get songRootDirectory;

  /// No description provided for @testing.
  ///
  /// In zh, this message translates to:
  /// **'测试中'**
  String get testing;

  /// No description provided for @testConnection.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get testConnection;

  /// No description provided for @saving.
  ///
  /// In zh, this message translates to:
  /// **'保存中'**
  String get saving;

  /// No description provided for @saveAndScan.
  ///
  /// In zh, this message translates to:
  /// **'保存并扫描'**
  String get saveAndScan;

  /// No description provided for @clearWebDavConfiguration.
  ///
  /// In zh, this message translates to:
  /// **'清空 WebDAV 配置'**
  String get clearWebDavConfiguration;

  /// No description provided for @pendingDownloadsTab.
  ///
  /// In zh, this message translates to:
  /// **'未完成 ({count})'**
  String pendingDownloadsTab(int count);

  /// No description provided for @downloadedTab.
  ///
  /// In zh, this message translates to:
  /// **'已下载 ({count})'**
  String downloadedTab(int count);

  /// No description provided for @noPendingDownloads.
  ///
  /// In zh, this message translates to:
  /// **'当前没有未完成的下载任务。'**
  String get noPendingDownloads;

  /// No description provided for @noDownloadedSongs.
  ///
  /// In zh, this message translates to:
  /// **'还没有已下载的歌曲。'**
  String get noDownloadedSongs;

  /// No description provided for @downloadComplete.
  ///
  /// In zh, this message translates to:
  /// **'下载完成'**
  String get downloadComplete;

  /// No description provided for @resumeDownload.
  ///
  /// In zh, this message translates to:
  /// **'继续下载'**
  String get resumeDownload;

  /// No description provided for @pauseDownload.
  ///
  /// In zh, this message translates to:
  /// **'暂停下载'**
  String get pauseDownload;

  /// No description provided for @cancelDownload.
  ///
  /// In zh, this message translates to:
  /// **'取消下载'**
  String get cancelDownload;

  /// No description provided for @deleteSourceFile.
  ///
  /// In zh, this message translates to:
  /// **'删除源文件'**
  String get deleteSourceFile;

  /// No description provided for @deleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get deleted;

  /// No description provided for @deleteDownloadedFile.
  ///
  /// In zh, this message translates to:
  /// **'删除已下载文件'**
  String get deleteDownloadedFile;

  /// No description provided for @deleteDownloadedFileMessage.
  ///
  /// In zh, this message translates to:
  /// **'将删除本地文件：{title}\n来源：{source}'**
  String deleteDownloadedFileMessage(String title, String source);

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @versionInformation.
  ///
  /// In zh, this message translates to:
  /// **'版本信息'**
  String get versionInformation;

  /// No description provided for @appIntroduction.
  ///
  /// In zh, this message translates to:
  /// **'应用介绍'**
  String get appIntroduction;

  /// No description provided for @appDescription.
  ///
  /// In zh, this message translates to:
  /// **'麦麦 KTV 是一个简洁的点歌与播放应用，方便在本地或云端曲库中快速找歌、点歌和播放。'**
  String get appDescription;

  /// No description provided for @sourceCodeAddress.
  ///
  /// In zh, this message translates to:
  /// **'开源地址'**
  String get sourceCodeAddress;

  /// No description provided for @viewReleasePage.
  ///
  /// In zh, this message translates to:
  /// **'查看发布页'**
  String get viewReleasePage;

  /// No description provided for @sourceCodeCopied.
  ///
  /// In zh, this message translates to:
  /// **'开源地址已复制'**
  String get sourceCodeCopied;

  /// No description provided for @copyAddress.
  ///
  /// In zh, this message translates to:
  /// **'复制地址'**
  String get copyAddress;

  /// No description provided for @reading.
  ///
  /// In zh, this message translates to:
  /// **'读取中'**
  String get reading;

  /// No description provided for @notChecked.
  ///
  /// In zh, this message translates to:
  /// **'未检查'**
  String get notChecked;

  /// No description provided for @unknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get unknown;

  /// No description provided for @versionSummary.
  ///
  /// In zh, this message translates to:
  /// **'当前版本：{currentVersion}\n最新版本：{latestVersion}\n最近检查：{lastCheckedAt}'**
  String versionSummary(
    String currentVersion,
    String latestVersion,
    String lastCheckedAt,
  );

  /// No description provided for @currentStatus.
  ///
  /// In zh, this message translates to:
  /// **'当前状态'**
  String get currentStatus;

  /// No description provided for @releaseNotes.
  ///
  /// In zh, this message translates to:
  /// **'更新说明'**
  String get releaseNotes;

  /// No description provided for @noReleaseNotes.
  ///
  /// In zh, this message translates to:
  /// **'暂无更新说明。'**
  String get noReleaseNotes;

  /// No description provided for @checking.
  ///
  /// In zh, this message translates to:
  /// **'检查中'**
  String get checking;

  /// No description provided for @updateNow.
  ///
  /// In zh, this message translates to:
  /// **'立即更新'**
  String get updateNow;

  /// No description provided for @updateStatusIdle.
  ///
  /// In zh, this message translates to:
  /// **'尚未检查'**
  String get updateStatusIdle;

  /// No description provided for @updateStatusUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'当前无法提供在线更新'**
  String get updateStatusUnavailable;

  /// No description provided for @updateStatusCurrent.
  ///
  /// In zh, this message translates to:
  /// **'已经是最新版本'**
  String get updateStatusCurrent;

  /// No description provided for @updateStatusAvailable.
  ///
  /// In zh, this message translates to:
  /// **'发现新版本'**
  String get updateStatusAvailable;

  /// No description provided for @updateStatusFailed.
  ///
  /// In zh, this message translates to:
  /// **'检查失败'**
  String get updateStatusFailed;

  /// No description provided for @updateInitialMessage.
  ///
  /// In zh, this message translates to:
  /// **'可先查看当前版本，再手动检查更新。'**
  String get updateInitialMessage;

  /// No description provided for @updateSummary.
  ///
  /// In zh, this message translates to:
  /// **'状态：{status}\n当前版本：{currentVersion}\n最新版本：{latestVersion}\n发布时间：{publishedAt}\n最近检查：{lastCheckedAt}\n说明：{message}'**
  String updateSummary(
    String status,
    String currentVersion,
    String latestVersion,
    String publishedAt,
    String lastCheckedAt,
    String message,
  );

  /// No description provided for @baiduDescription.
  ///
  /// In zh, this message translates to:
  /// **'百度网盘开放平台凭证已经内置到应用配置里。用户进入本页后，未登录时会自动拉起扫码登录二维码。登录后只需要配置歌曲根目录。'**
  String get baiduDescription;

  /// No description provided for @configuredSongRoot.
  ///
  /// In zh, this message translates to:
  /// **'已配置，歌曲根目录：{path}'**
  String configuredSongRoot(String path);

  /// No description provided for @savedRootNotSignedIn.
  ///
  /// In zh, this message translates to:
  /// **'未登录，已保存歌曲根目录：{path}'**
  String savedRootNotSignedIn(String path);

  /// No description provided for @baiduNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'未配置百度网盘数据源'**
  String get baiduNotConfigured;

  /// No description provided for @appAuthorizationConfiguration.
  ///
  /// In zh, this message translates to:
  /// **'应用授权配置'**
  String get appAuthorizationConfiguration;

  /// No description provided for @authorizationEmbedded.
  ///
  /// In zh, this message translates to:
  /// **'应用授权配置已内置'**
  String get authorizationEmbedded;

  /// No description provided for @authorizationMissing.
  ///
  /// In zh, this message translates to:
  /// **'应用授权配置缺失'**
  String get authorizationMissing;

  /// No description provided for @loginComplete.
  ///
  /// In zh, this message translates to:
  /// **'登录已完成'**
  String get loginComplete;

  /// No description provided for @scanToLogin.
  ///
  /// In zh, this message translates to:
  /// **'扫码登录'**
  String get scanToLogin;

  /// No description provided for @baiduAuthorizedDescription.
  ///
  /// In zh, this message translates to:
  /// **'当前百度网盘账号已登录，可以继续配置歌曲根目录并扫描指定文件夹。'**
  String get baiduAuthorizedDescription;

  /// No description provided for @baiduQrDescription.
  ///
  /// In zh, this message translates to:
  /// **'进入页面后已自动生成二维码。请直接使用百度 App 扫码授权，授权完成后会自动登录。'**
  String get baiduQrDescription;

  /// No description provided for @loginStatus.
  ///
  /// In zh, this message translates to:
  /// **'登录状态'**
  String get loginStatus;

  /// No description provided for @signedInDetails.
  ///
  /// In zh, this message translates to:
  /// **'已登录\n账号：{account}\n容量：{quota}\nToken 过期时间：{expiresAt}'**
  String signedInDetails(String account, String quota, String expiresAt);

  /// No description provided for @unknownAccount.
  ///
  /// In zh, this message translates to:
  /// **'未知账号'**
  String get unknownAccount;

  /// No description provided for @saveQrToPhone.
  ///
  /// In zh, this message translates to:
  /// **'保存二维码到手机'**
  String get saveQrToPhone;

  /// No description provided for @generating.
  ///
  /// In zh, this message translates to:
  /// **'生成中'**
  String get generating;

  /// No description provided for @refreshQrCode.
  ///
  /// In zh, this message translates to:
  /// **'刷新二维码'**
  String get refreshQrCode;

  /// No description provided for @signedOut.
  ///
  /// In zh, this message translates to:
  /// **'已退出登录'**
  String get signedOut;

  /// No description provided for @signOut.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get signOut;

  /// No description provided for @rootPathExample.
  ///
  /// In zh, this message translates to:
  /// **'例如 /KTV'**
  String get rootPathExample;

  /// No description provided for @directorySaved.
  ///
  /// In zh, this message translates to:
  /// **'目录已保存'**
  String get directorySaved;

  /// No description provided for @saveAndScanFolder.
  ///
  /// In zh, this message translates to:
  /// **'保存并扫描该文件夹'**
  String get saveAndScanFolder;

  /// No description provided for @saveDirectory.
  ///
  /// In zh, this message translates to:
  /// **'保存目录'**
  String get saveDirectory;

  /// No description provided for @clear.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get clear;

  /// No description provided for @loginQrCode.
  ///
  /// In zh, this message translates to:
  /// **'登录二维码'**
  String get loginQrCode;

  /// No description provided for @qrCodeLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'二维码加载失败'**
  String get qrCodeLoadFailed;

  /// No description provided for @qrCodeDetails.
  ///
  /// In zh, this message translates to:
  /// **'用户码：{userCode}\n验证页：{verificationUrl}'**
  String qrCodeDetails(String userCode, String verificationUrl);

  /// No description provided for @sourceLabel.
  ///
  /// In zh, this message translates to:
  /// **'来源：{source}'**
  String sourceLabel(String source);

  /// No description provided for @saved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get saved;

  /// No description provided for @saveQrFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存二维码失败：{error}'**
  String saveQrFailed(Object error);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
