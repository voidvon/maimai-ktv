# KTV UI 状态矩阵

本文件补充 [ui_rebuild_spec.md](/Volumes/DATA/Space/ktv/docs/ui_rebuild_spec.md)，重点描述“同一界面在不同业务状态下显示什么”。

## 1. 页面级状态入口

页面有 2 个一级模式：

- 首页 `_SelectionRoute.home`
- 点歌工作区 `songList / queueList / artistList / artistSongs / rankingList / localList / placeholder routes`

切换来源：

- 首页快捷入口
- 首页工具栏“搜索/已点”
- 点歌工作区顶部按钮
- 歌手卡点击
- 返回按钮

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L405)

## 2. 首页状态矩阵

| 状态 | 预览区 | 快捷入口 | 工具栏 | 备注 |
|---|---|---|---|---|
| 无当前歌曲，无视频 | 显示 fallback 背景和“等待点唱”标签 | 正常显示 6 个入口 | 原唱/伴唱、切歌、播放/暂停禁用 | 默认首页态 |
| 有当前歌曲，准备播放中 | 显示播放状态覆盖层“正在准备播放” | 正常显示 | 播放/暂停可用，原唱/伴唱依赖 `isPreparingPlayback` 禁用 | 预览底部出现进度条 |
| 有当前歌曲，播放中但无视频输出 | 显示播放状态覆盖层“当前暂无画面输出” | 正常显示 | 正常显示 | 通常是音频文件或首帧未出 |
| 有当前歌曲，正常视频播放 | 显示视频画面和底部进度条 | 正常显示 | 正常显示 | 点击预览进入全屏 |
| 有当前歌曲，播放错误 | 显示“播放失败”覆盖层，并触发错误弹窗 | 正常显示 | 正常显示 | 弹窗去重，避免连续重复弹 |
| 有当前歌曲，播放完成 | 不显示状态覆盖层 | 正常显示 | 仍可重唱/切歌 | 若队列有下一首，将自动切歌 |

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L623)
- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L2220)
- [ktv_home_page_playback_view_model.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_playback_view_model.dart#L112)

## 3. 点歌工作区页面级状态矩阵

### 3.1 统一优先级

右列 route 内容区优先按以下顺序判断：

1. 正在读取设置
2. 未设置 MV 路径
3. 正在扫描且媒体库为空
4. 扫描报错
5. 媒体库为空
6. route 自身内容

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L2042)

### 3.2 状态卡矩阵

| 条件 | 展示卡片标题 | 描述 | 动作 |
|---|---|---|---|
| `_isLoadingSettings == true` | 正在读取本地媒体配置... | 稍后会按当前配置装载歌曲索引。 | 无 |
| `!_settings.hasMvLibraryPath` | 请先设置 MV 路径 | 当前只支持本地播放。先选择一个本地 MV 目录，后续的歌名点歌都会基于这个目录建立索引。 | 设置本地 MV 路径 |
| `_isScanningLibrary && _libraryItems.isEmpty` | 正在扫描本地媒体库 | 正在递归读取目录中的 MV 文件，并识别歌手、歌名与格式信息。 | 无 |
| `_scanError != null` | 媒体库扫描失败 | 直接显示错误内容 | 重新扫描 |
| `_libraryItems.isEmpty` | 目录下没有可识别的 MV 文件 | 建议用“歌手 - 歌名.dat / .mp4”命名 | 重新扫描 |

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L2042)

## 4. 左列状态矩阵

### 4.1 左列底部区域

| 当前 route | 左列底部显示 |
|---|---|
| `songList` | 字母/数字键盘 |
| `queueList` | 字母/数字键盘 |
| `artistList` | route 快速说明卡 |
| `artistSongs` | route 快速说明卡 |
| `rankingList` | route 快速说明卡 |
| `localList` | route 快速说明卡 |
| `categoryPlaceholder` | route 快速说明卡 |
| `favoritePlaceholder` | route 快速说明卡 |
| `frequentPlaceholder` | route 快速说明卡 |

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1162)

### 4.2 左列预览

| 条件 | 预览显示 |
|---|---|
| `_currentItem == null` | fallback 背景 + 等待点唱标签 |
| `_currentItem != null && !_hasVideoOutput` | fallback 背景；若有播放状态覆盖层则浮在上面 |
| `_currentItem != null && _hasVideoOutput` | 视频画面 |
| `_currentItem != null` | 预览区下方显示小进度条 |

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1183)

## 5. 右列 route 内容矩阵

| route | 主内容类型 | 上方辅助元素 |
|---|---|---|
| `songList` | 双列歌曲列表 + 分页器 | 语种 tab |
| `queueList` | 双列已点列表 + 分页器 | 无语种 tab |
| `artistList` | 歌手网格 + 分页器 | route meta chip |
| `artistSongs` | 双列歌曲列表 + 分页器 | route meta chip |
| `rankingList` | 双列歌曲列表 + 分页器 | route meta chip |
| `localList` | 双列歌曲列表 + 分页器 | route meta chip |
| `categoryPlaceholder` | 占位页 | route meta chip |
| `favoritePlaceholder` | 占位页 | route meta chip |
| `frequentPlaceholder` | 占位页 | route meta chip |

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1731)

## 6. 歌曲列表状态矩阵

### 6.1 单首歌曲 tile 状态

| 条件 | 背景 | 可点击 | 含义 |
|---|---|---|---|
| 当前播放 | 白色 16% | 否 | 当前项 |
| 已在队列中 | 白色 10% | 否 | 防止重复加入 |
| 普通可点 | 白色 10% | 是 | 点击加入队列 |

来源：

- [ktv_home_page_selection_widgets.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_selection_widgets.dart#L172)

### 6.2 双列歌曲页空状态

| route | 空态文案 |
|---|---|
| `songList` | 当前筛选条件下没有歌曲，试试切换分类或清空搜索关键字。 |
| `artistSongs` | 当前歌星下没有匹配歌曲，试试清空关键字或返回歌星列表重新选择。 |
| `rankingList` | 当前排行榜没有匹配歌曲，试试调整搜索关键字。 |
| `localList` | 当前本地列表没有匹配歌曲，试试调整搜索关键字。 |
| 其他 | 当前没有可展示的歌曲。 |

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1957)

## 7. 已点列表状态矩阵

### 7.1 页面空状态

| 条件 | 空态文案 |
|---|---|
| `_requestedSongCount == 0` | 当前还没有已点歌曲，点歌后会在这里显示。 |
| `_requestedSongCount > 0` 但搜索后为空 | 当前关键字下没有匹配的已点歌曲，试试清空搜索关键字。 |

来源：

- [ktv_home_page_queue_widgets.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_queue_widgets.dart#L26)

### 7.2 单条已点状态

| 条目类型 | 副标题状态文案 | 右侧操作 |
|---|---|---|
| 当前播放 | 当前播放 | 无 |
| 队列第 1 条 | 队列 1 | 置顶禁用，移除可用 |
| 队列第 N 条 | 队列 N | 置顶可用，移除可用 |

来源：

- [ktv_home_page_queue_widgets.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_queue_widgets.dart#L58)

## 8. 歌手页状态矩阵

| 条件 | 显示 |
|---|---|
| 歌手结果为空 | 白底空状态卡：“当前筛选条件下没有匹配歌星，试试清空关键字后重新查找。” |
| 歌手结果非空且容器宽 < 520 | 单列歌手卡 |
| 歌手结果非空且容器宽 >= 520 | 双列歌手卡 |

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1849)

## 9. 播放状态矩阵

### 9.1 `_playbackStatusData` 生成规则

| 条件 | title | message | icon | isLoading |
|---|---|---|---|---|
| `playbackError != null && notEmpty` | 播放失败 | `playbackError` | `error_outline_rounded` | false |
| `isPreparingPlayback == true` | 正在准备播放 | 优先 `playbackDiagnostics`，否则“正在解析媒体、切换音轨并等待首帧，请稍候。” | `hourglass_top_rounded` | true |
| `!hasVideoOutput && !isPlaybackCompleted` | 当前暂无画面输出 或 正在等待画面 | 优先 `playbackDiagnostics`，否则“播放器还没有输出可用视频画面，请稍候。” | `tv_off_rounded` | false |
| 其他 | 不显示状态卡 | - | - | - |

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L623)

### 9.2 播放器错误弹窗

| 条件 | 行为 |
|---|---|
| `playbackError == null/empty` | 不弹 |
| 正在展示错误弹窗 | 不重复弹 |
| 与上次错误一致 | 不重复弹 |
| 有诊断信息且不等于错误正文 | 在弹窗内增加“诊断信息”区块 |

弹窗标题：

- 无当前歌曲：`播放失败`
- 有当前歌曲：`《歌曲名》播放失败`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L564)

## 10. 全屏层状态矩阵

| 条件 | 显示 |
|---|---|
| `persistentVideoView == null && _currentItem == null` | 不显示全屏层 |
| 全屏层已打开，`chromeVisible == false` | 只显示黑底 + 视频本身 + 可能存在的状态浮层 |
| 全屏层已打开，`chromeVisible == true` | 再叠加顶部渐变、顶部按钮组、标题歌手信息、底部进度条 |
| `statusData != null` | 无论 chrome 是否可见，都显示中间状态浮层 |

来源：

- [ktv_home_page_preview_widgets.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_preview_widgets.dart#L333)

## 11. 设置弹窗状态矩阵

| 条件 | 弹窗内表现 |
|---|---|
| 初始正常 | 显示说明、路径卡、引擎卡、开关、操作按钮 |
| Android 旧文件路径 | 路径卡下方额外显示重授权提示卡 |
| `_isBusy == true` | 目录选择、清空、关闭、完成、switch 等可交互项禁用 |
| `_errorMessage != null` | 显示红色错误提示卡 |
| 无 MV 路径 | 路径显示“未设置目录”；清空路径按钮禁用 |

来源：

- [settings_dialog.dart](/Volumes/DATA/Space/ktv/lib/widgets/settings_dialog.dart#L146)

## 12. 队列与自动切歌行为矩阵

| 条件 | 结果 |
|---|---|
| 当前无歌，队列为空，点一首歌 | 进入队列并立即开始播放 |
| 当前有歌在播，再点新歌 | 进入队列尾部 |
| 点的是当前播放中的同一首歌，且当前还未终止 | 忽略 |
| 当前歌曲播放完成/报错/接近结尾且队列非空 | 自动切到下一首 |
| 手动点击“切歌”且队列为空 | 无效果 |
| 手动点击“重唱”且当前无歌或正在准备播放 | 无效果 |

终止播放状态判定：

- 有播放错误
- 或 `isPlaybackCompleted == true`
- 或播放已接近尾声，剩余时长 `<= 1800ms`

来源：

- [ktv_home_page_playback_view_model.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_playback_view_model.dart#L83)

