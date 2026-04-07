# 百度网盘数据源接入准备文档

最后整理时间：2026-04-07

## 说明

这份文档用于给当前 KTV 项目后续接入“百度网盘数据源”做准备。

- 官方文档主入口以百度网盘开放平台为准。
- 本文优先整理能从百度官方入口、百度开发者中心公开页面中确认的授权流程、接口地址和接入约束。
- 对项目落地方式的描述，属于基于当前仓库结构做出的实现建议，不等同于百度官方承诺。

## 官方入口

- 百度网盘开放平台：<https://pan.baidu.com/union>
- 官方接入入口：<https://pan.baidu.com/union/document/entrance>
- 用户提供的官方文档链接：<https://pan.baidu.com/union/doc/Bl0eta7z8>
- 开放平台常见问题汇总：<https://developer.baidu.com/question/detail.html?id=224>

补充说明：

- 当前公开索引里，百度开发者中心有多篇“随手记 / FAQ”页面，内容与开放平台文档保持同一套接口体系，可用来交叉确认授权地址、Token 地址、文件接口和下载方式。
- 原始 `union/doc/Bl0eta7z8` 页面在公开抓取结果里可见度有限，因此本文把能确认的关键信息集中整理在本地，后续开发时仍应再对照线上原文复核一次。

## 接入前置

按官方入口和开发者中心示例，接入前至少需要准备：

- 百度账号
- 百度网盘开放平台应用
- `appId`
- `AppKey`，也就是 OAuth `client_id`
- `SecretKey`，也就是 OAuth `client_secret`
- `SignKey`
- 申请到的网盘相关权限

当前公开示例里，网盘相关授权 scope 使用：

- `basic,netdisk`

如果 scope 传错，开发者中心 FAQ 提到接口可能返回 `errno=-6`，因此后续代码里不应该把 scope 写成可选拼接字符串，建议直接常量化。

## 已确认的授权流程

### 1. 用户授权

百度开发者中心示例页给出的授权地址为：

`http://openapi.baidu.com/oauth/2.0/authorize`

常见参数：

- `response_type=code`
- `client_id=<AppKey>`
- `redirect_uri=oob`
- `scope=basic,netdisk`
- `display=tv`
- `qrcode=1`
- `force_login=1`

这说明桌面端可以优先考虑“二维码授权 + 授权码回填”的接入方式。

对当前项目的含义：

- macOS 桌面端不一定需要先做完整本地回调页。
- 第一版可以先走 `redirect_uri=oob`，让用户扫码后拿授权码，再换 Token。
- 如果后续希望体验更顺滑，再补本地回调页或内嵌 Web 授权流程。

### 2. 用授权码换取 Token

开发者中心公开示例页给出的地址为：

`https://openapi.baidu.com/oauth/2.0/token?grant_type=authorization_code`

常见参数：

- `code=<授权码>`
- `client_id=<AppKey>`
- `client_secret=<SecretKey>`
- `redirect_uri=oob`

应关注的返回字段：

- `access_token`
- `refresh_token`
- `expires_in`

### 3. 刷新 Token

开发者中心公开示例页给出的地址为：

`https://openapi.baidu.com/oauth/2.0/token?grant_type=refresh_token`

常见参数：

- `refresh_token=<refresh_token>`
- `client_id=<AppKey>`
- `client_secret=<SecretKey>`

实现建议：

- 本地必须同时持久化 `access_token`、`refresh_token` 和过期时间。
- 所有网盘 API 调用都需要统一走“自动刷新 Token”的封装层，避免业务代码散落处理 401 / 鉴权失败。
- `redirect_uri` 必须和应用配置一致。若后续改成网页回调模式，回调域名必须严格匹配。

## 已确认的核心接口

以下接口均可在百度开发者中心公开页面中看到示例。

### 1. 用户信息

- 接口：`https://pan.baidu.com/rest/2.0/xpan/nas?method=uinfo`
- 用途：校验授权是否成功，读取当前登录用户基础信息

建议用途：

- 在“连接百度网盘”成功页展示当前账号昵称 / uid
- 作为 Token 可用性的首个探活接口

### 2. 容量信息

- 接口：`https://pan.baidu.com/api/quota`
- 常见参数：
  - `access_token`
  - `checkfree=1`
  - `checkexpire=1`

建议用途：

- 在数据源设置页展示总容量、已用容量、剩余容量
- 作为下载缓存前的空间提示依据

### 3. 文件列表

- 接口：`https://pan.baidu.com/rest/2.0/xpan/file?method=list`
- 用途：列出指定目录下的文件

这适合做：

- 指定目录浏览
- 远端目录选择器
- 手动选择“歌曲根目录”

### 4. 递归文件列表

- 接口：`https://pan.baidu.com/rest/2.0/xpan/multimedia?method=listall`
- 常见参数：
  - `access_token`
  - `path=<目录>`

这对当前项目尤其重要，因为 KTV 场景更需要：

- 从某个根目录递归扫描视频文件
- 一次性建立远端歌曲索引

第一版实现建议优先验证这个接口是否足够覆盖“递归拉平目录并筛选媒体文件”的需求。

### 5. 搜索文件

- 接口：`https://pan.baidu.com/rest/2.0/xpan/file?method=search`
- 常见参数：
  - `access_token`
  - `key=<关键字>`

建议用途：

- 远端关键字搜索
- 与本地聚合搜索统一到同一搜索框

### 6. 文件详情 / 下载地址

- 接口：`https://pan.baidu.com/rest/2.0/xpan/multimedia?method=filemetas`
- 常见参数：
  - `access_token`
  - `fsids=[<文件id>]`
  - `dlink=1`

开发者中心示例明确说明：

- `dlink` 是下载链接

但这里有一个关键风险：

- FAQ 明确提到“接口返回 dlink 后，浏览器可以下载，但使用 httpClient 访问可能返回 403”。

对当前项目的含义：

- 不要假设 `dlink` 拿到后就能稳定被通用 HTTP 客户端直接消费。
- 下载模块需要单独做联调验证，至少确认 macOS / Android 上的请求头、跳转、鉴权和大文件下载行为。

### 7. 视频列表

- 接口：`https://pan.baidu.com/rest/2.0/xpan/file?method=videolist`

如果该接口返回的视频集合足够稳定，它可能比通用递归扫描更适合做 KTV 首版接入。但这一点需要后续拿真实账号验证，因为公开页面只展示了接口存在，没有给出足够细的筛选语义。

## 上传相关约束

虽然当前项目第一阶段主要是“读网盘并播放”，但官方公开示例已经给出了上传链路，后面如果要做“从本地导入到百度网盘”可以直接参考。

已确认的上传相关接口包括：

- `POST /rest/2.0/xpan/file?method=precreate`
- `POST https://d.pcs.baidu.com/rest/2.0/pcs/superfile2?method=upload&type=tmpfile`
- `POST /rest/2.0/xpan/file?method=create`

已确认的路径约束：

- 上传目录只能在 `/apps/<应用名称>/` 下

这意味着：

- 读取用户整个网盘内容，与写入应用私有目录，是两套不同约束。
- 如果未来要把 KTV 本地媒体库反向上传到网盘，默认目标目录应该落在 `/apps/<应用名>/...`，而不是用户任意目录。

## 对当前项目的直接影响

### 1. 当前播放器更适合“先下载缓存，再播放”

当前播放器模型里，`MediaSource.path` 就是一个直接喂给播放器的路径字符串，现有实现主要围绕本地文件路径展开。

结合仓库现状和百度网盘下载链路风险，第一版更合理的策略是：

1. 先把百度网盘文件作为“远端歌曲元数据”接入媒体库
2. 用户点播时再通过 `filemetas(dlink=1)` 获取下载地址
3. 下载到本地缓存目录
4. `resolvePlayableMediaPath()` 返回缓存后的本地文件路径
5. 复用现有本地播放链路

不要在第一版里直接把远端 `dlink` 当播放器路径。

### 2. 现有聚合数据模型可以直接承接百度网盘数据源

当前仓库已经有 `AggregatedSongSource` 和聚合媒体库索引，百度网盘接入可以复用这套结构。

建议映射如下：

- `sourceId`: `baidu_pan`
- `sourceSongId`: 使用百度网盘文件唯一标识，优先 `fsid`
- `songId`: 继续复用当前聚合逻辑，按 `title + artist` 生成聚合 ID
- `mediaPath`: 第一阶段写本地缓存路径；未缓存时可先置空字符串或占位值，再通过播放前解析补全

需要注意：

- 百度网盘原始元数据更像“文件系统对象”，不是 KTV 语义化歌曲对象。
- 标题、歌手、语言、标签，大概率仍需要沿用当前文件名解析规则做二次归一化。

### 3. Token 和账号信息不应该混进歌曲资料表

当前仓库的 `SongProfileDatabase` 更偏向歌曲画像，不适合直接存 OAuth 凭证。

建议新增单独存储：

- `BaiduPanAuthStore`
- 保存 `accessToken`、`refreshToken`、`expiresAt`
- 可选保存 `appId`、`clientId`、最近登录账号标识

如果后续要兼顾安全性，优先考虑：

- macOS 使用 Keychain
- Android 使用 Keystore / 加密存储

### 4. 需要增加“远端文件到歌曲对象”的映射层

建议后续不要把百度网盘 API 返回值直接塞进 UI 或 Repository。

可以拆成几层：

- `BaiduPanApiClient`：只负责 HTTP、鉴权、刷新 Token、接口出参与错误码
- `BaiduPanRemoteDataSource`：负责目录扫描、搜索、详情读取、下载
- `BaiduPanSongMapper`：把远端文件对象映射成项目内 `Song`
- `BaiduPanSongSource`：实现 `AggregatedSongSource`
- `BaiduPanPlaybackCache`：负责下载、命名、校验、本地缓存淘汰

## 建议的最小落地顺序

### 阶段 1：打通授权和探活

目标：

- 能完成二维码授权
- 能保存和刷新 Token
- 能调用 `uinfo`
- 能调用 `quota`

完成标准：

- 设置页能看到“已连接百度网盘”
- 能显示当前账号和容量信息

### 阶段 2：打通远端目录扫描

目标：

- 选择一个百度网盘目录作为歌曲根目录
- 调用 `listall` 或 `videolist`
- 过滤出当前项目支持的视频扩展名
- 写入本地聚合索引

完成标准：

- 歌曲列表页能看到百度网盘来源的曲目
- 搜索、歌手页、语言筛选能工作

### 阶段 3：打通播放前缓存

目标：

- 点歌时根据 `fsid` 获取 `dlink`
- 下载到本地缓存
- 下载完成后走现有播放器链路

完成标准：

- macOS 和 Android 都能从百度网盘来源点歌并成功播放
- 已下载文件可重复播放，避免每次重新拉取

### 阶段 4：补缓存策略和容错

目标：

- 处理 Token 过期自动刷新
- 处理下载失败重试
- 处理缓存清理
- 处理远端文件被删除或重命名后的索引修复

## 建议优先确认的联调问题

真正开工前，建议优先验证下面几件事：

1. `listall` 是否足够稳定地返回大目录递归结果
2. `videolist` 是否能直接覆盖 KTV 场景，减少自定义递归扫描
3. `filemetas(dlink=1)` 返回的 `dlink` 能否被当前 Flutter 下载实现稳定消费
4. Android 上下载后的本地缓存文件，是否需要继续复用现有 `content://` 到缓存文件的播放保护逻辑
5. 百度网盘文件名是否足够稳定，能否沿用当前本地文件名解析策略识别歌手和歌曲名

## 建议新增的文档后续项

等真正开始开发后，可以继续补三份更细的文档：

- `docs/baidu_pan_data_source_design.md`
- `docs/baidu_pan_auth_flow.md`
- `docs/baidu_pan_remote_indexing.md`
- `docs/baidu_pan_playback_cache.md`

## 参考链接

- 官方开放平台：<https://pan.baidu.com/union>
- 官方接入入口：<https://pan.baidu.com/union/document/entrance>
- 官方文档链接：<https://pan.baidu.com/union/doc/Bl0eta7z8>
- 接口调用前准备：<https://developer.baidu.com/question/detail.html?id=177>
- 用户 / 容量 / 文件列表示例：<https://developer.baidu.com/question/detail.html?id=178>
- 文件管理 / 上传 / 下载示例：<https://developer.baidu.com/question/detail.html?id=179>
- 常见问题 FAQ：<https://developer.baidu.com/question/detail.html?id=224>
- dlink 403 问题页：<https://developer.baidu.com/question/detail.html?id=141>
- 开放平台升级公告：<https://developer.baidu.com/article/detail.html?id=295516>
