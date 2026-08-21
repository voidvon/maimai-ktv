// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '麦麦KTV';

  @override
  String get settings => '设置';

  @override
  String get home => '主页';

  @override
  String get interfaceSection => '界面';

  @override
  String get language => '语言';

  @override
  String get languageSubtitle => '选择应用显示语言';

  @override
  String get languagePageDescription => '默认跟随系统语言。手动选择后，应用会记住你的设置。';

  @override
  String get followSystem => '跟随系统';

  @override
  String get simplifiedChinese => '简体中文';

  @override
  String get traditionalChinese => '繁體中文';

  @override
  String get english => 'English';

  @override
  String get dataSources => '数据源';

  @override
  String get settingsDescription => '管理当前点歌库的数据来源。已配置的数据源会用于扫描、检索和展示歌曲列表。';

  @override
  String get other => '其他';

  @override
  String get downloadManager => '下载管理';

  @override
  String downloadSummary(int pendingCount, int downloadedCount) {
    return '未完成 $pendingCount 首，已下载 $downloadedCount 首';
  }

  @override
  String downloadedSongsCount(int count) {
    return '已下载 $count 首歌曲';
  }

  @override
  String get downloadManagerSubtitle => '查看下载中和已下载的歌曲列表';

  @override
  String get loading => '加载中';

  @override
  String configuredPath(String path) {
    return '已配置 $path';
  }

  @override
  String get configured => '已配置';

  @override
  String get notConfigured => '未配置';

  @override
  String get notSignedIn => '未登录';

  @override
  String get localDirectory => '本地目录';

  @override
  String get baiduNetdisk => '百度网盘';

  @override
  String get checkForUpdates => '检查更新';

  @override
  String get aboutUs => '关于我们';

  @override
  String get aboutUsSubtitle => '查看应用简介和开源地址';

  @override
  String get charts => '排行榜';

  @override
  String get songTitle => '歌名';

  @override
  String get artist => '歌星';

  @override
  String get local => '本地';

  @override
  String get favorites => '收藏';

  @override
  String get frequent => '常唱';

  @override
  String get categories => '分类';

  @override
  String get backToSongbook => '返回点歌';

  @override
  String get pause => '暂停';

  @override
  String get play => '播放';

  @override
  String get replay => '重唱';

  @override
  String get skip => '切歌';

  @override
  String get originalVocal => '原唱';

  @override
  String get accompaniment => '伴唱';

  @override
  String queuedCount(int count) {
    return '已点$count';
  }

  @override
  String get previousPage => '上一页';

  @override
  String get nextPage => '下一页';

  @override
  String get searchQueueHint => '搜索已点歌曲 / 歌手';

  @override
  String get searchArtistHint => '输入歌手名称';

  @override
  String get searchSongHint => '输入歌名 / 中文 / 拼音首字母';

  @override
  String get noNextSong => '暂无下一首';

  @override
  String get addedToQueue => '已加入已点';

  @override
  String get downloadResumed => '已恢复下载';

  @override
  String get downloading => '正在下载';

  @override
  String downloadedToLocalDirectory(String fileName) {
    return '已下载到本地目录：$fileName';
  }

  @override
  String downloadedToAppDirectory(String fileName) {
    return '已下载到应用目录：$fileName';
  }

  @override
  String get cancelled => '已取消';

  @override
  String get paused => '已暂停';

  @override
  String get downloadFailed => '下载失败';

  @override
  String get allLanguages => '全部';

  @override
  String get mandarin => '国语';

  @override
  String get cantonese => '粤语';

  @override
  String get minNan => '闽南语';

  @override
  String get englishLanguage => '英语';

  @override
  String get japanese => '日语';

  @override
  String get korean => '韩语';

  @override
  String get otherLanguage => '其它';

  @override
  String get currentPlayback => '当前播放';

  @override
  String get queued => '已点';

  @override
  String get back => '返回';

  @override
  String queuePosition(int position) {
    return '队列 $position';
  }

  @override
  String get waitingForDownload => '等待下载';

  @override
  String get downloadPaused => '已暂停';

  @override
  String get downloadError => '下载失败';

  @override
  String get noLocalDirectory => '请先在设置里配置本地目录，扫描完成后这里会展示歌曲列表。';

  @override
  String get noDataSource => '请先在设置里配置数据源，配置完成后这里会展示聚合曲库。';

  @override
  String get scanningLocalSongs => '正在扫描本地目录中的歌曲，请稍候。';

  @override
  String get loadingArtists => '正在加载歌手列表，请稍候。';

  @override
  String get loadingSongs => '正在加载歌曲列表，请稍候。';

  @override
  String get noMatchingArtists => '当前条件下没有可显示的歌手，试试切换语言或清空搜索关键字。';

  @override
  String get noFavorites => '当前目录下还没有收藏歌曲，先去本地列表点亮爱心。';

  @override
  String get noFrequentSongs => '当前目录下还没有常唱记录，开始播放几首歌后会显示在这里。';

  @override
  String get noPlayableVideos => '当前目录下没有扫描到可播放视频文件，请确认目录中包含常见视频格式媒体文件。';

  @override
  String get noArtistSongs => '当前歌手下没有匹配的歌曲，试试切换语言或清空搜索关键字。';

  @override
  String get emptyQueue => '当前还没有已点歌曲，点歌后会在这里显示。';

  @override
  String get noQueueMatches => '当前关键字下没有匹配的已点歌曲，试试清空搜索关键字。';

  @override
  String get localFiles => '本地文件';

  @override
  String get iosLocalFilesDescription =>
      'iPhone 和 iPad 不支持像桌面端那样直接挂载本地目录。请选择要导入到应用内的视频文件，导入后会在应用内建立本地歌库，再次导入会继续追加到当前歌库。';

  @override
  String get localDirectoryDescription =>
      '配置本地目录后，点歌页会基于这个目录建立扫描范围。重新选择后会覆盖当前使用的本地目录。';

  @override
  String get appLibraryDirectory => '应用内歌库目录';

  @override
  String get currentDirectory => '当前目录';

  @override
  String get noImportedVideos => '当前还没有导入本地视频文件。';

  @override
  String get noConfiguredDirectory => '当前还没有配置本地目录。';

  @override
  String get importing => '导入中';

  @override
  String get selecting => '选择中';

  @override
  String get importFiles => '导入文件';

  @override
  String get selectDirectory => '选择目录';

  @override
  String get selectVideo => '选择视频';

  @override
  String get webDavDescription =>
      '连接支持 WebDAV 的网盘、NAS 或私有云。局域网地址可以使用 HTTP，公网地址必须使用 HTTPS。账号密码仅保存在系统安全存储中。';

  @override
  String get serverAddress => '服务器地址';

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get passwordKeepHint => '密码（留空则保持不变）';

  @override
  String get showPassword => '显示密码';

  @override
  String get hidePassword => '隐藏密码';

  @override
  String get songRootDirectory => '歌曲根目录';

  @override
  String get testing => '测试中';

  @override
  String get testConnection => '测试连接';

  @override
  String get saving => '保存中';

  @override
  String get saveAndScan => '保存并扫描';

  @override
  String get clearWebDavConfiguration => '清空 WebDAV 配置';

  @override
  String pendingDownloadsTab(int count) {
    return '未完成 ($count)';
  }

  @override
  String downloadedTab(int count) {
    return '已下载 ($count)';
  }

  @override
  String get noPendingDownloads => '当前没有未完成的下载任务。';

  @override
  String get noDownloadedSongs => '还没有已下载的歌曲。';

  @override
  String get downloadComplete => '下载完成';

  @override
  String get resumeDownload => '继续下载';

  @override
  String get pauseDownload => '暂停下载';

  @override
  String get cancelDownload => '取消下载';

  @override
  String get deleteSourceFile => '删除源文件';

  @override
  String get deleted => '已删除';

  @override
  String get deleteDownloadedFile => '删除已下载文件';

  @override
  String deleteDownloadedFileMessage(String title, String source) {
    return '将删除本地文件：$title\n来源：$source';
  }

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get versionInformation => '版本信息';

  @override
  String get appIntroduction => '应用介绍';

  @override
  String get appDescription => '麦麦 KTV 是一个简洁的点歌与播放应用，方便在本地或云端曲库中快速找歌、点歌和播放。';

  @override
  String get sourceCodeAddress => '开源地址';

  @override
  String get viewReleasePage => '查看发布页';

  @override
  String get sourceCodeCopied => '开源地址已复制';

  @override
  String get copyAddress => '复制地址';

  @override
  String get reading => '读取中';

  @override
  String get notChecked => '未检查';

  @override
  String get unknown => '未知';

  @override
  String versionSummary(
    String currentVersion,
    String latestVersion,
    String lastCheckedAt,
  ) {
    return '当前版本：$currentVersion\n最新版本：$latestVersion\n最近检查：$lastCheckedAt';
  }

  @override
  String get currentStatus => '当前状态';

  @override
  String get releaseNotes => '更新说明';

  @override
  String get noReleaseNotes => '暂无更新说明。';

  @override
  String get checking => '检查中';

  @override
  String get updateNow => '立即更新';

  @override
  String get updateStatusIdle => '尚未检查';

  @override
  String get updateStatusUnavailable => '当前无法提供在线更新';

  @override
  String get updateStatusCurrent => '已经是最新版本';

  @override
  String get updateStatusAvailable => '发现新版本';

  @override
  String get updateStatusFailed => '检查失败';

  @override
  String get updateInitialMessage => '可先查看当前版本，再手动检查更新。';

  @override
  String updateSummary(
    String status,
    String currentVersion,
    String latestVersion,
    String publishedAt,
    String lastCheckedAt,
    String message,
  ) {
    return '状态：$status\n当前版本：$currentVersion\n最新版本：$latestVersion\n发布时间：$publishedAt\n最近检查：$lastCheckedAt\n说明：$message';
  }

  @override
  String get baiduDescription =>
      '百度网盘开放平台凭证已经内置到应用配置里。用户进入本页后，未登录时会自动拉起扫码登录二维码。登录后只需要配置歌曲根目录。';

  @override
  String configuredSongRoot(String path) {
    return '已配置，歌曲根目录：$path';
  }

  @override
  String savedRootNotSignedIn(String path) {
    return '未登录，已保存歌曲根目录：$path';
  }

  @override
  String get baiduNotConfigured => '未配置百度网盘数据源';

  @override
  String get appAuthorizationConfiguration => '应用授权配置';

  @override
  String get authorizationEmbedded => '应用授权配置已内置';

  @override
  String get authorizationMissing => '应用授权配置缺失';

  @override
  String get loginComplete => '登录已完成';

  @override
  String get scanToLogin => '扫码登录';

  @override
  String get baiduAuthorizedDescription => '当前百度网盘账号已登录，可以继续配置歌曲根目录并扫描指定文件夹。';

  @override
  String get baiduQrDescription => '进入页面后已自动生成二维码。请直接使用百度 App 扫码授权，授权完成后会自动登录。';

  @override
  String get loginStatus => '登录状态';

  @override
  String signedInDetails(String account, String quota, String expiresAt) {
    return '已登录\n账号：$account\n容量：$quota\nToken 过期时间：$expiresAt';
  }

  @override
  String get unknownAccount => '未知账号';

  @override
  String get saveQrToPhone => '保存二维码到手机';

  @override
  String get generating => '生成中';

  @override
  String get refreshQrCode => '刷新二维码';

  @override
  String get signedOut => '已退出登录';

  @override
  String get signOut => '退出登录';

  @override
  String get rootPathExample => '例如 /KTV';

  @override
  String get directorySaved => '目录已保存';

  @override
  String get saveAndScanFolder => '保存并扫描该文件夹';

  @override
  String get saveDirectory => '保存目录';

  @override
  String get clear => '清空';

  @override
  String get loginQrCode => '登录二维码';

  @override
  String get qrCodeLoadFailed => '二维码加载失败';

  @override
  String qrCodeDetails(String userCode, String verificationUrl) {
    return '用户码：$userCode\n验证页：$verificationUrl';
  }

  @override
  String sourceLabel(String source) {
    return '来源：$source';
  }

  @override
  String get saved => '已保存';

  @override
  String saveQrFailed(Object error) {
    return '保存二维码失败：$error';
  }
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get appName => '麥麥KTV';

  @override
  String get settings => '設定';

  @override
  String get home => '主頁';

  @override
  String get interfaceSection => '介面';

  @override
  String get language => '語言';

  @override
  String get languageSubtitle => '選擇應用程式顯示語言';

  @override
  String get languagePageDescription => '預設跟隨系統語言。手動選擇後，應用程式會記住你的設定。';

  @override
  String get followSystem => '跟隨系統';

  @override
  String get simplifiedChinese => '简体中文';

  @override
  String get traditionalChinese => '繁體中文';

  @override
  String get english => 'English';

  @override
  String get dataSources => '資料來源';

  @override
  String get settingsDescription => '管理目前點歌庫的資料來源。已設定的資料來源會用於掃描、搜尋和顯示歌曲清單。';

  @override
  String get other => '其他';

  @override
  String get downloadManager => '下載管理';

  @override
  String downloadSummary(int pendingCount, int downloadedCount) {
    return '未完成 $pendingCount 首，已下載 $downloadedCount 首';
  }

  @override
  String downloadedSongsCount(int count) {
    return '已下載 $count 首歌曲';
  }

  @override
  String get downloadManagerSubtitle => '查看下載中和已下載的歌曲清單';

  @override
  String get loading => '載入中';

  @override
  String configuredPath(String path) {
    return '已設定 $path';
  }

  @override
  String get configured => '已設定';

  @override
  String get notConfigured => '未設定';

  @override
  String get notSignedIn => '未登入';

  @override
  String get localDirectory => '本機目錄';

  @override
  String get baiduNetdisk => '百度網盤';

  @override
  String get checkForUpdates => '檢查更新';

  @override
  String get aboutUs => '關於我們';

  @override
  String get aboutUsSubtitle => '查看應用程式簡介和開源地址';

  @override
  String get charts => '排行榜';

  @override
  String get songTitle => '歌名';

  @override
  String get artist => '歌星';

  @override
  String get local => '本機';

  @override
  String get favorites => '收藏';

  @override
  String get frequent => '常唱';

  @override
  String get categories => '分類';

  @override
  String get backToSongbook => '返回點歌';

  @override
  String get pause => '暫停';

  @override
  String get play => '播放';

  @override
  String get replay => '重唱';

  @override
  String get skip => '切歌';

  @override
  String get originalVocal => '原唱';

  @override
  String get accompaniment => '伴唱';

  @override
  String queuedCount(int count) {
    return '已點$count';
  }

  @override
  String get previousPage => '上一頁';

  @override
  String get nextPage => '下一頁';

  @override
  String get searchQueueHint => '搜尋已點歌曲 / 歌手';

  @override
  String get searchArtistHint => '輸入歌手名稱';

  @override
  String get searchSongHint => '輸入歌名 / 中文 / 拼音首字母';

  @override
  String get noNextSong => '暫無下一首';

  @override
  String get addedToQueue => '已加入已點';

  @override
  String get downloadResumed => '已恢復下載';

  @override
  String get downloading => '正在下載';

  @override
  String downloadedToLocalDirectory(String fileName) {
    return '已下載到本機目錄：$fileName';
  }

  @override
  String downloadedToAppDirectory(String fileName) {
    return '已下載到應用程式目錄：$fileName';
  }

  @override
  String get cancelled => '已取消';

  @override
  String get paused => '已暫停';

  @override
  String get downloadFailed => '下載失敗';

  @override
  String get allLanguages => '全部';

  @override
  String get mandarin => '國語';

  @override
  String get cantonese => '粵語';

  @override
  String get minNan => '閩南語';

  @override
  String get englishLanguage => '英語';

  @override
  String get japanese => '日語';

  @override
  String get korean => '韓語';

  @override
  String get otherLanguage => '其它';

  @override
  String get currentPlayback => '目前播放';

  @override
  String get queued => '已點';

  @override
  String get back => '返回';

  @override
  String queuePosition(int position) {
    return '佇列 $position';
  }

  @override
  String get waitingForDownload => '等待下載';

  @override
  String get downloadPaused => '已暫停';

  @override
  String get downloadError => '下載失敗';

  @override
  String get noLocalDirectory => '請先在設定中配置本機目錄，掃描完成後這裡會顯示歌曲清單。';

  @override
  String get noDataSource => '請先在設定中配置資料來源，配置完成後這裡會顯示聚合曲庫。';

  @override
  String get scanningLocalSongs => '正在掃描本機目錄中的歌曲，請稍候。';

  @override
  String get loadingArtists => '正在載入歌手清單，請稍候。';

  @override
  String get loadingSongs => '正在載入歌曲清單，請稍候。';

  @override
  String get noMatchingArtists => '目前條件下沒有可顯示的歌手，請嘗試切換語言或清除搜尋關鍵字。';

  @override
  String get noFavorites => '目前目錄下還沒有收藏歌曲，先去本機清單點亮愛心。';

  @override
  String get noFrequentSongs => '目前目錄下還沒有常唱記錄，開始播放幾首歌後會顯示在這裡。';

  @override
  String get noPlayableVideos => '目前目錄下沒有掃描到可播放的影片檔案，請確認目錄中包含常見影片格式媒體檔案。';

  @override
  String get noArtistSongs => '目前歌手下沒有符合的歌曲，請嘗試切換語言或清除搜尋關鍵字。';

  @override
  String get emptyQueue => '目前還沒有已點歌曲，點歌後會顯示在這裡。';

  @override
  String get noQueueMatches => '目前關鍵字下沒有符合的已點歌曲，請嘗試清除搜尋關鍵字。';

  @override
  String get localFiles => '本機檔案';

  @override
  String get iosLocalFilesDescription =>
      'iPhone 和 iPad 不支援像桌面端一樣直接掛載本機目錄。請選擇要匯入應用程式的影片檔案，匯入後會在應用程式內建立本機歌庫，再次匯入會繼續加入目前歌庫。';

  @override
  String get localDirectoryDescription =>
      '設定本機目錄後，點歌頁會以此目錄建立掃描範圍。重新選擇後會取代目前使用的本機目錄。';

  @override
  String get appLibraryDirectory => '應用程式內歌庫目錄';

  @override
  String get currentDirectory => '目前目錄';

  @override
  String get noImportedVideos => '目前還沒有匯入本機影片檔案。';

  @override
  String get noConfiguredDirectory => '目前還沒有設定本機目錄。';

  @override
  String get importing => '匯入中';

  @override
  String get selecting => '選擇中';

  @override
  String get importFiles => '匯入檔案';

  @override
  String get selectDirectory => '選擇目錄';

  @override
  String get selectVideo => '選擇影片';

  @override
  String get webDavDescription =>
      '連接支援 WebDAV 的網盤、NAS 或私有雲。區域網路地址可以使用 HTTP，公網地址必須使用 HTTPS。帳號密碼只會保存在系統安全儲存空間中。';

  @override
  String get serverAddress => '伺服器地址';

  @override
  String get username => '使用者名稱';

  @override
  String get password => '密碼';

  @override
  String get passwordKeepHint => '密碼（留空則保持不變）';

  @override
  String get showPassword => '顯示密碼';

  @override
  String get hidePassword => '隱藏密碼';

  @override
  String get songRootDirectory => '歌曲根目錄';

  @override
  String get testing => '測試中';

  @override
  String get testConnection => '測試連線';

  @override
  String get saving => '儲存中';

  @override
  String get saveAndScan => '儲存並掃描';

  @override
  String get clearWebDavConfiguration => '清除 WebDAV 設定';

  @override
  String pendingDownloadsTab(int count) {
    return '未完成 ($count)';
  }

  @override
  String downloadedTab(int count) {
    return '已下載 ($count)';
  }

  @override
  String get noPendingDownloads => '目前沒有未完成的下載工作。';

  @override
  String get noDownloadedSongs => '還沒有已下載的歌曲。';

  @override
  String get downloadComplete => '下載完成';

  @override
  String get resumeDownload => '繼續下載';

  @override
  String get pauseDownload => '暫停下載';

  @override
  String get cancelDownload => '取消下載';

  @override
  String get deleteSourceFile => '刪除來源檔案';

  @override
  String get deleted => '已刪除';

  @override
  String get deleteDownloadedFile => '刪除已下載檔案';

  @override
  String deleteDownloadedFileMessage(String title, String source) {
    return '將刪除本機檔案：$title\n來源：$source';
  }

  @override
  String get cancel => '取消';

  @override
  String get delete => '刪除';

  @override
  String get versionInformation => '版本資訊';

  @override
  String get appIntroduction => '應用程式介紹';

  @override
  String get appDescription => '麥麥 KTV 是一個簡潔的點歌與播放應用程式，方便在本機或雲端曲庫中快速找歌、點歌和播放。';

  @override
  String get sourceCodeAddress => '開源地址';

  @override
  String get viewReleasePage => '查看發佈頁';

  @override
  String get sourceCodeCopied => '開源地址已複製';

  @override
  String get copyAddress => '複製地址';

  @override
  String get reading => '讀取中';

  @override
  String get notChecked => '未檢查';

  @override
  String get unknown => '未知';

  @override
  String versionSummary(
    String currentVersion,
    String latestVersion,
    String lastCheckedAt,
  ) {
    return '目前版本：$currentVersion\n最新版本：$latestVersion\n最近檢查：$lastCheckedAt';
  }

  @override
  String get currentStatus => '目前狀態';

  @override
  String get releaseNotes => '更新說明';

  @override
  String get noReleaseNotes => '暫無更新說明。';

  @override
  String get checking => '檢查中';

  @override
  String get updateNow => '立即更新';

  @override
  String get updateStatusIdle => '尚未檢查';

  @override
  String get updateStatusUnavailable => '目前無法提供線上更新';

  @override
  String get updateStatusCurrent => '已經是最新版本';

  @override
  String get updateStatusAvailable => '發現新版本';

  @override
  String get updateStatusFailed => '檢查失敗';

  @override
  String get updateInitialMessage => '可先查看目前版本，再手動檢查更新。';

  @override
  String updateSummary(
    String status,
    String currentVersion,
    String latestVersion,
    String publishedAt,
    String lastCheckedAt,
    String message,
  ) {
    return '狀態：$status\n目前版本：$currentVersion\n最新版本：$latestVersion\n發佈時間：$publishedAt\n最近檢查：$lastCheckedAt\n說明：$message';
  }

  @override
  String get baiduDescription =>
      '百度網盤開放平台憑證已內置於應用程式設定中。進入本頁後，未登入時會自動顯示掃碼登入 QR Code。登入後只需設定歌曲根目錄。';

  @override
  String configuredSongRoot(String path) {
    return '已設定，歌曲根目錄：$path';
  }

  @override
  String savedRootNotSignedIn(String path) {
    return '未登入，已儲存歌曲根目錄：$path';
  }

  @override
  String get baiduNotConfigured => '未設定百度網盤資料來源';

  @override
  String get appAuthorizationConfiguration => '應用程式授權設定';

  @override
  String get authorizationEmbedded => '應用程式授權設定已內置';

  @override
  String get authorizationMissing => '應用程式授權設定缺失';

  @override
  String get loginComplete => '登入已完成';

  @override
  String get scanToLogin => '掃碼登入';

  @override
  String get baiduAuthorizedDescription => '目前百度網盤帳號已登入，可以繼續設定歌曲根目錄並掃描指定資料夾。';

  @override
  String get baiduQrDescription =>
      '進入頁面後已自動產生 QR Code。請直接使用百度 App 掃碼授權，授權完成後會自動登入。';

  @override
  String get loginStatus => '登入狀態';

  @override
  String signedInDetails(String account, String quota, String expiresAt) {
    return '已登入\n帳號：$account\n容量：$quota\nToken 過期時間：$expiresAt';
  }

  @override
  String get unknownAccount => '未知帳號';

  @override
  String get saveQrToPhone => '儲存 QR Code 到手機';

  @override
  String get generating => '產生中';

  @override
  String get refreshQrCode => '重新整理 QR Code';

  @override
  String get signedOut => '已登出';

  @override
  String get signOut => '登出';

  @override
  String get rootPathExample => '例如 /KTV';

  @override
  String get directorySaved => '目錄已儲存';

  @override
  String get saveAndScanFolder => '儲存並掃描此資料夾';

  @override
  String get saveDirectory => '儲存目錄';

  @override
  String get clear => '清除';

  @override
  String get loginQrCode => '登入 QR Code';

  @override
  String get qrCodeLoadFailed => 'QR Code 載入失敗';

  @override
  String qrCodeDetails(String userCode, String verificationUrl) {
    return '使用者碼：$userCode\n驗證頁：$verificationUrl';
  }

  @override
  String sourceLabel(String source) {
    return '來源：$source';
  }

  @override
  String get saved => '已儲存';

  @override
  String saveQrFailed(Object error) {
    return '儲存 QR Code 失敗：$error';
  }
}
