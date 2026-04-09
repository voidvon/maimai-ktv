# 百度网盘数据源类设计草案

最后整理时间：2026-04-07

## 目标

这份设计稿用于指导当前项目把“百度网盘”接入为一个新的聚合媒体源，并尽量少改现有本地媒体库和播放器主链路。

目标拆分为三层：

1. 授权层：拿到并维护百度网盘 OAuth 凭证
2. 索引层：把百度网盘远端文件映射成项目内 `Song`
3. 播放层：点歌时把远端文件下载为本地缓存，再走现有播放器

## 当前仓库里的关键约束

根据现有代码，百度网盘接入不能绕开下面这些约束：

- [lib/features/media_library/data/aggregated_library_repository.dart](/Users/yytest/Documents/projects/ktv/lib/features/media_library/data/aggregated_library_repository.dart)
  统一的数据源扩展点是 `AggregatedSongSource`
- [lib/features/ktv/application/ktv_controller.dart](/Users/yytest/Documents/projects/ktv/lib/features/ktv/application/ktv_controller.dart)
  当前控制器只知道“请求歌曲”和“打开媒体”，还没有远端资源解析层
- [lib/features/ktv/application/playback_queue_manager.dart](/Users/yytest/Documents/projects/ktv/lib/features/ktv/application/playback_queue_manager.dart)
  现在直接把 `song.mediaPath` 传给播放器
- [ktv-player/lib/models/media_source.dart](https://github.com/voidvon/ktv-player/blob/main/lib/models/media_source.dart)
  播放器输入是简单的本地路径字符串模型
- [lib/features/media_library/data/media_index_store.dart](/Users/yytest/Documents/projects/ktv/lib/features/media_library/data/media_index_store.dart)
  已经具备“来源曲目表 + 聚合曲目表 + 来源同步状态表”的结构，适合承接远端数据源
- [lib/features/settings/application/settings_controller.dart](/Users/yytest/Documents/projects/ktv/lib/features/settings/application/settings_controller.dart)
  目前设置页只处理本地目录选择，没有远端账号或数据源配置入口

这意味着第一版最稳妥的路线不是“直接在线播放”，而是：

- 百度网盘只负责提供远端文件元数据和下载能力
- 播放前统一解析为本地缓存文件路径

## 建议新增的目录结构

建议把百度网盘实现集中放在 `lib/features/media_library/data/baidu_pan/` 下：

```text
lib/features/media_library/data/baidu_pan/
  baidu_pan_api_client.dart
  baidu_pan_auth_store.dart
  baidu_pan_auth_repository.dart
  baidu_pan_models.dart
  baidu_pan_remote_data_source.dart
  baidu_pan_song_mapper.dart
  baidu_pan_song_source.dart
  baidu_pan_playback_cache.dart
  baidu_pan_source_config_store.dart
```

如果后续设置页和连接流程变复杂，再补一层：

```text
lib/features/settings/application/baidu_pan_settings_controller.dart
lib/features/settings/presentation/baidu_pan_source_section.dart
```

## 建议新增的核心模型

### 1. OAuth 凭证

```dart
class BaiduPanAuthToken {
  const BaiduPanAuthToken({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAtMillis,
    this.scope,
    this.sessionKey,
    this.sessionSecret,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresAtMillis;
  final String? scope;
  final String? sessionKey;
  final String? sessionSecret;

  bool get isExpired;
  bool willExpireWithin(Duration duration);
}
```

说明：

- `sessionKey` / `sessionSecret` 是否长期需要，取决于联调结果；第一版可先允许为空。
- `expiresAtMillis` 应在拿到 `expires_in` 时立即换算成绝对时间，避免业务层自己算。

### 2. 数据源配置

```dart
class BaiduPanSourceConfig {
  const BaiduPanSourceConfig({
    required this.sourceRootId,
    required this.rootPath,
    required this.displayName,
    this.syncToken,
    this.lastSyncedAtMillis,
  });

  final String sourceRootId;
  final String rootPath;
  final String displayName;
  final String? syncToken;
  final int? lastSyncedAtMillis;
}
```

建议：

- `sourceRootId` 统一使用 `baidu_pan:<path>` 形式
- `rootPath` 是用户选中的百度网盘根目录
- `displayName` 用于 UI 展示，例如“百度网盘 / KTV”

### 3. 远端文件对象

```dart
class BaiduPanRemoteFile {
  const BaiduPanRemoteFile({
    required this.fsid,
    required this.path,
    required this.serverFilename,
    required this.isDirectory,
    required this.size,
    required this.modifiedAtMillis,
    this.md5,
    this.category,
    this.dlink,
    this.rawPayload,
  });

  final String fsid;
  final String path;
  final String serverFilename;
  final bool isDirectory;
  final int size;
  final int modifiedAtMillis;
  final String? md5;
  final int? category;
  final String? dlink;
  final Map<String, Object?>? rawPayload;
}
```

说明：

- 模型字段以“当前项目真正会用到的字段”为主
- 全量原始返回可序列化后放到 `rawPayload`

### 4. 播放解析结果

```dart
class PlayableMediaResolution {
  const PlayableMediaResolution({
    required this.song,
    required this.localPath,
    required this.displayName,
    this.cacheHit = false,
  });

  final Song song;
  final String localPath;
  final String displayName;
  final bool cacheHit;
}
```

这个模型不是百度网盘专属，但第一版很适合作为“远端歌曲转本地播放路径”的统一结果。

## 建议新增的核心类

### 1. `BaiduPanAuthStore`

职责：

- 持久化保存 Token
- 读取当前已登录状态
- 清除登录状态

建议接口：

```dart
abstract class BaiduPanAuthStore {
  Future<BaiduPanAuthToken?> readToken();
  Future<void> writeToken(BaiduPanAuthToken token);
  Future<void> clearToken();
}
```

落地建议：

- 第一版可以先用 `SharedPreferences` 或本地 sqlite
- 真正上线前应迁移到系统安全存储

### 2. `BaiduPanAuthRepository`

职责：

- 生成授权 URL
- 用授权码换 Token
- 统一刷新 Token
- 对外暴露“拿一个可用 access token”

建议接口：

```dart
class BaiduPanAuthRepository {
  Future<Uri> buildAuthorizeUri();
  Future<void> loginWithAuthorizationCode(String code);
  Future<void> logout();
  Future<String> getValidAccessToken();
  Future<bool> hasValidSession();
}
```

关键点：

- `getValidAccessToken()` 应内部处理“快过期时自动刷新”
- 刷新成功后必须立刻覆盖本地 token

### 3. `BaiduPanApiClient`

职责：

- 封装所有 HTTP 调用
- 自动带上 `access_token`
- 统一解析百度网盘接口错误码

建议接口：

```dart
class BaiduPanApiClient {
  Future<Map<String, Object?>> getUserInfo();
  Future<Map<String, Object?>> getQuota();
  Future<List<BaiduPanRemoteFile>> listDirectory({
    required String path,
    int start = 0,
    int limit = 1000,
  });
  Future<List<BaiduPanRemoteFile>> listAll({
    required String path,
    int start = 0,
    int limit = 1000,
  });
  Future<List<BaiduPanRemoteFile>> search({
    required String key,
    String? path,
    int page = 1,
    int num = 100,
  });
  Future<BaiduPanRemoteFile> getFileMeta({
    required String fsid,
    bool withDlink = false,
  });
}
```

关键约束：

- 不要在这里做歌曲名解析
- 不要在这里做缓存下载
- 这里应该只关心 HTTP 协议和 DTO 解析

### 4. `BaiduPanRemoteDataSource`

职责：

- 组合多个 API 调用，形成“远端目录扫描 / 远端搜索 / 文件详情 / 下载地址获取”

建议接口：

```dart
class BaiduPanRemoteDataSource {
  Future<List<BaiduPanRemoteFile>> scanRoot(String rootPath);
  Future<List<BaiduPanRemoteFile>> searchFiles({
    required String keyword,
    String? rootPath,
  });
  Future<BaiduPanRemoteFile> getPlayableFileMeta(String fsid);
}
```

这个类是“协议层”和“业务层”之间的薄封装，避免 `SongSource` 直接拼接口参数。

### 5. `BaiduPanSongMapper`

职责：

- 把 `BaiduPanRemoteFile` 转成项目内 `Song`
- 复用当前本地文件名解析规则

建议接口：

```dart
class BaiduPanSongMapper {
  Song mapRemoteFileToSong(BaiduPanRemoteFile file);
}
```

建议实现：

- 提取现有 `MediaLibraryDataSource` 中文件名解析逻辑为可复用工具
- 本地目录扫描和百度网盘扫描都走同一套标题 / 歌手 / 语言 / 标签解析

如果不抽公共解析器，后续本地和网盘数据源会产生不一致的歌手拆分结果。

### 6. `BaiduPanSongSource`

职责：

- 实现 `AggregatedSongSource`
- 负责把百度网盘根目录扫描结果写入聚合索引
- 对外提供按 ID 查歌能力

建议接口轮廓：

```dart
class BaiduPanSongSource implements AggregatedSongSource {
  @override
  String get sourceId => 'baidu_pan';

  @override
  bool isAvailable({String? localDirectory});

  @override
  bool supportsScope(LibraryScope scope);

  @override
  Future<void> refresh({String? localDirectory});

  @override
  Future<List<Song>> loadAllSongs({String? localDirectory});

  @override
  Future<List<Song>> getSongsByIds({
    required List<String> songIds,
    String? localDirectory,
  });

  @override
  Future<Song?> getSongById({
    required String songId,
    String? localDirectory,
  });

  @override
  int compareSongs(Song left, Song right);
}
```

落地重点：

- `refresh()` 内部应扫描当前已配置的百度网盘根目录
- 扫描结果应写入 `MediaIndexStore.sourceSongItemsTable`
- `sourceRootId` 应使用百度网盘目录 ID 或标准化 path

### 7. `BaiduPanPlaybackCache`

职责：

- 根据 `fsid` 获取下载地址
- 下载到本地缓存目录
- 命中缓存时直接返回本地路径

建议接口：

```dart
class BaiduPanPlaybackCache {
  Future<String> resolveLocalPlayablePath({
    required Song song,
    required String sourceSongId,
  });

  Future<void> clearExpiredCache();
}
```

缓存命名建议：

- 目录：`<appSupport>/baidu_pan_cache/`
- 文件名：`<sourceSongId>_<sanitizedName>.<ext>`

缓存命中判断建议同时考虑：

- 文件是否存在
- 文件大小是否大于 0
- 如拿得到远端 `md5`，可选做一致性校验

## 建议新增的通用播放解析层

当前最值得改的一点不是播放器本身，而是点歌到打开媒体之间缺一个解析步骤。

建议新增一个通用接口：

```dart
abstract class PlayableSongResolver {
  Future<PlayableMediaResolution> resolve(Song song);
}
```

第一版实现可以叫：

```dart
class DefaultPlayableSongResolver implements PlayableSongResolver
```

行为建议：

- `sourceId == 'local'` 时直接返回 `song.mediaPath`
- `sourceId == 'baidu_pan'` 时调用 `BaiduPanPlaybackCache`

## 需要改动的现有类

### 1. `PlaybackQueueManager`

当前问题：

- 直接 `openMedia(MediaSource(path: song.mediaPath, ...))`
- 这会把远端歌曲和本地歌曲强耦合到同一个字段上

建议改成注入 `PlayableSongResolver`：

```dart
class PlaybackQueueManager {
  const PlaybackQueueManager({
    required this.playerController,
    required this.playableSongResolver,
  });

  final PlayerController playerController;
  final PlayableSongResolver playableSongResolver;
}
```

然后在 `requestSong()` 和 `skipCurrentSong()` 里先解析：

```dart
final PlayableMediaResolution media = await playableSongResolver.resolve(song);
await playerController.openMedia(
  MediaSource(path: media.localPath, displayName: media.displayName),
);
```

### 2. `KtvController`

建议改动：

- 构造时注入 `PlayableSongResolver`
- 创建 `PlaybackQueueManager` 时传下去

这样百度网盘接入不会污染 UI 层。

### 3. `createKtvController()`

建议在 [lib/app/ktv_dependencies.dart](/Users/yytest/Documents/projects/ktv/lib/app/ktv_dependencies.dart) 里统一组装：

- `MediaLibraryRepository`
- `BaiduPanAuthRepository`
- `BaiduPanSongSource`
- `DefaultAggregatedLibraryRepository`
- `DefaultPlayableSongResolver`

让依赖关系都收口在应用装配层。

### 4. `MediaLibraryDataSource`

建议把文件名解析逻辑抽成独立工具，例如：

```text
lib/features/media_library/data/song_metadata_parser.dart
```

原因：

- 百度网盘远端文件也需要同一套歌名 / 歌手 / 标签解析
- 不应该让 `BaiduPanSongMapper` 直接依赖本地扫描类

## 索引写入建议

当前 `MediaIndexStore` 已有通用结构，百度网盘第一版不需要另开歌曲索引库。

建议写入规则如下：

- `source_type`: `baidu_pan`
- `source_song_id`: `fsid`
- `source_root_id`: `baidu_pan:<rootPath>`
- `media_locator`: 远端 path，例如 `/KTV/周杰伦-稻香.mp4`
- `file_fingerprint`: 优先 `md5`，没有就用 `meta::<path>::<size>::<mtime>`
- `availability_status`:
  - 已索引可播放：`ready`
  - 远端存在但未缓存：第一版仍可写 `ready`
  - 远端失效：`missing`
- `raw_payload_json`: 存百度原始文件对象 JSON

这样做的好处：

- 查询歌曲列表时不需要区分本地 / 网盘
- 聚合逻辑继续复用当前 `title + artist` 对齐策略

## 同步策略建议

### 第一版

- 每次手动触发“刷新百度网盘歌曲目录”时，全量扫描并全量覆盖该 `source_root_id`

优点：

- 实现简单
- 与当前本地目录扫描的思路一致

缺点：

- 大目录性能一般

### 第二版

- 利用 `source_sync_states.sync_token`
- 增量记录上次同步时间或接口游标
- 对比远端变更后做增量写入

这个阶段可以等第一版跑通再做。

## 设置页建议

第一版设置页至少需要加 3 个操作：

1. 连接百度网盘
2. 选择歌曲根目录
3. 手动刷新百度网盘索引

建议新增状态控制器：

```dart
class BaiduPanSettingsController extends ChangeNotifier
```

最小状态字段：

- `isAuthorized`
- `accountDisplayName`
- `selectedRootPath`
- `isRefreshing`
- `errorMessage`

## 点歌播放时序建议

### 1. 首次播放百度网盘歌曲

```text
UI 点歌
-> KtvController.requestSong(song)
-> PlaybackQueueManager.requestSong(song)
-> PlayableSongResolver.resolve(song)
-> BaiduPanPlaybackCache.resolveLocalPlayablePath(song)
-> BaiduPanRemoteDataSource.getPlayableFileMeta(fsid)
-> BaiduPanApiClient.getFileMeta(dlink=1)
-> 下载文件到本地缓存
-> playerController.openMedia(localPath)
```

### 2. 再次播放同一首歌

```text
UI 点歌
-> PlayableSongResolver.resolve(song)
-> BaiduPanPlaybackCache 命中缓存
-> playerController.openMedia(localPath)
```

## 异常处理建议

第一版至少要统一处理这些错误：

- 未授权
- Token 过期且刷新失败
- 选中的百度网盘根目录不存在
- `dlink` 获取成功但实际下载返回 403
- 下载中断或缓存文件损坏

建议定义一组明确异常：

```dart
class BaiduPanUnauthorizedException implements Exception {}
class BaiduPanTokenExpiredException implements Exception {}
class BaiduPanFileNotFoundException implements Exception {}
class BaiduPanDownloadForbiddenException implements Exception {}
```

不要在上层全用字符串错误代替结构化异常。

## 最小实施顺序

### 第一步

- 抽出 `song_metadata_parser.dart`
- 新增 `PlayableSongResolver`
- 改造 `PlaybackQueueManager`

这一步做完后，远端数据源的播放接入点就准备好了。

### 第二步

- 新增 `BaiduPanAuthStore`
- 新增 `BaiduPanAuthRepository`
- 新增 `BaiduPanApiClient`

这一步做完后，可以在不接 UI 的情况下单独联调授权和接口。

### 第三步

- 新增 `BaiduPanRemoteDataSource`
- 新增 `BaiduPanSongMapper`
- 新增 `BaiduPanSongSource`
- 把百度网盘歌曲写进 `MediaIndexStore`

这一步做完后，歌曲列表应该能显示百度网盘来源曲目。

### 第四步

- 新增 `BaiduPanPlaybackCache`
- 在 `DefaultPlayableSongResolver` 里接入百度网盘播放解析

这一步做完后，点歌到播放链路才算真正打通。

## 建议的后续文档

等开始写代码后，建议同步补这两份文档：

- `docs/baidu_pan_api_error_notes.md`
- `docs/baidu_pan_cache_strategy.md`
