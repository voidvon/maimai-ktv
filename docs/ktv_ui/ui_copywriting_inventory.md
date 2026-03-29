# KTV UI 文案清单

本清单只收录会直接进入 UI 的文案，不收录纯日志和不会显示给用户的内部字符串。

## 1. 顶层品牌与导航

### 1.1 App

- `KTV`
- `金调KTV`

来源：

- [app.dart](/Volumes/DATA/Space/ktv/lib/app.dart#L16)
- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L2162)

### 1.2 首页入口

- `排行榜`
- `歌名`
- `歌星`
- `本地`
- `收藏`
- `常唱`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L68)

### 1.3 Breadcrumb

- `‹ 主页`
- `‹ 主页 / 歌名`
- `‹ 主页 / 已点`
- `‹ 主页 / 歌星`
- `‹ 主页 / 歌星 / 歌曲`
- `‹ 主页 / 排行榜`
- `‹ 主页 / 本地`
- `‹ 主页 / 分类`
- `‹ 主页 / 收藏`
- `‹ 主页 / 常唱`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1719)

## 2. 顶部工具栏与按钮

### 2.1 首页工具栏

- `搜索`
- `已点{N}`
- `原唱`
- `伴唱`
- `切歌`
- `暂停`
- `播放`
- `设置`
- `退出`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L2099)

### 2.2 点歌页顶部按钮

- `已点{N}`
- `原唱`
- `伴唱`
- `切歌`
- `暂停`
- `播放`
- `重唱`
- `返回`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1597)
- [ktv_home_page_selection_widgets.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_selection_widgets.dart#L58)

### 2.3 全屏按钮

- `返回点歌`
- `伴唱`
- `切歌`
- `重唱`

来源：

- [ktv_home_page_preview_widgets.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_preview_widgets.dart#L389)

### 2.4 分页按钮

- `上一页`
- `下一页`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1827)

## 3. 搜索相关

### 3.1 Placeholder

- `输入歌名 / 中文 / 拼音首字母`
- `搜索已点歌曲 / 歌手`
- `搜索歌星名称`
- `搜索歌曲 / 文件名`
- `搜索排行榜歌曲 / 歌手`
- `搜索本地歌曲 / 文件名`
- `搜索歌曲 / 歌手 / 文件名`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1364)

### 3.2 搜索辅助

- `退格`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1325)

## 4. 语种筛选

- `全部`
- `国语`
- `粤语`
- `闽南语`
- `英语`
- `日语`
- `韩语`
- `其它`

来源：

- [ktv_home_page_selection_view_model.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_selection_view_model.dart#L4)

## 5. route 名称与描述

### 5.1 名称

- `点歌台`
- `歌名点歌`
- `已点列表`
- `歌星点歌`
- `歌手歌曲`
- `歌星歌曲`
- `排行榜`
- `本地`
- `本地歌曲`
- `分类`
- `收藏`
- `常唱`

来源：

- [ktv_home_page_selection_view_model.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_selection_view_model.dart#L53)
- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1448)

### 5.2 左列 route 说明

- `支持中文、拼音首字母和文件名搜索，虚拟键盘会直接写入输入框。`
- `这里只保留一个播放列表，第一条是当前播放，后面的按顺序待播，可直接搜索、置顶和移除。`
- `先按歌星聚合本地曲库，再进入该歌星的歌曲列表。`
- `当前展示选中歌星的全部歌曲，支持继续搜索和点唱。`
- `当前按本地媒体更新时间排序，后续可替换成真实热榜。`
- `直接浏览本地媒体文件，适合按目录资源快速点唱。`
- `分类点歌还没接入，先统一进同一套界面结构。`
- `收藏能力还没接入，后续会复用这套视觉壳。`
- `常唱能力还没接入，后续会复用这套视觉壳。`
- `从首页入口进入对应点歌功能。`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1461)

### 5.3 route meta

- `歌星 {N}`
- `本地聚合`
- `歌曲 {N}`
- `排行 {N}`
- `最近更新`
- `本地 {N}`
- `文件浏览`
- `敬请期待`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1474)

## 6. 首页和预览相关

- `等待点唱`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1247)
- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L2281)

## 7. 播放状态与弹窗

### 7.1 状态浮层

- `播放失败`
- `正在准备播放`
- `当前暂无画面输出`
- `正在等待画面`
- `正在解析媒体、切换音轨并等待首帧，请稍候。`
- `播放器还没有输出可用视频画面，请稍候。`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L623)

### 7.2 错误弹窗

- `播放失败`
- `《{歌曲名}》播放失败`
- `播放器返回了空错误信息。`
- `诊断信息`
- `知道了`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L564)

## 8. 已点列表

- `当前还没有已点歌曲，点歌后会在这里显示。`
- `当前关键字下没有匹配的已点歌曲，试试清空搜索关键字。`
- `当前播放`
- `队列 {N}`
- `置顶`
- `移除`

来源：

- [ktv_home_page_queue_widgets.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_queue_widgets.dart#L26)

## 9. 空状态与占位

### 9.1 歌曲/歌手列表空态

- `当前筛选条件下没有匹配歌星，试试清空关键字后重新查找。`
- `当前筛选条件下没有歌曲，试试切换分类或清空搜索关键字。`
- `当前歌星下没有匹配歌曲，试试清空关键字或返回歌星列表重新选择。`
- `当前排行榜没有匹配歌曲，试试调整搜索关键字。`
- `当前本地列表没有匹配歌曲，试试调整搜索关键字。`
- `当前没有可展示的歌曲。`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1898)
- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1957)

### 9.2 功能占位页

- `分类点歌待接入`
- `下一阶段会先补目录分类、格式分类，再逐步扩展到语种和主题。`
- `收藏列表待接入`
- `需要先补歌曲收藏持久化，后续会把已收藏歌曲集中展示在这里。`
- `常唱列表待接入`
- `需要先记录点唱次数和播放次数，后续会按常唱频率生成列表。`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1790)

## 10. 设置与媒体库状态卡

- `正在读取本地媒体配置...`
- `稍后会按当前配置装载歌曲索引。`
- `请先设置 MV 路径`
- `当前只支持本地播放。先选择一个本地 MV 目录，后续的歌名点歌都会基于这个目录建立索引。`
- `设置本地 MV 路径`
- `正在扫描本地媒体库`
- `正在递归读取目录中的 MV 文件，并识别歌手、歌名与格式信息。`
- `媒体库扫描失败`
- `重新扫描`
- `目录下没有可识别的 MV 文件`
- `当前会优先识别本地 MV 文件。建议文件名采用“歌手 - 歌名.dat”或“歌手 - 歌名.mp4”这种格式。`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L2042)

## 11. 设置弹窗文案

- `媒体库设置`
- `当前项目只做本地播放。请先选择本地 MV 根目录，后续点歌页会基于这个目录建立歌曲索引，并支持读取 .dat 等常见 KTV 媒体格式。`
- `本地 MV 路径`
- `未设置目录`
- `当前 Android 媒体库路径是旧的文件路径，系统不会为它保留目录授权。请重新点击“选择目录”，选中同一个 MV 根目录并保存为系统授权的目录 URI。`
- `媒体处理引擎`
- `当前平台：{platformName}`
- `打包方式：{packagingModeLabel}`
- `运行状态：{runtimeStatusLabel}`
- `播放链路：{playbackPipeline}`
- `切换策略：{audioSwitchingStrategy}`
- `需要随包分发：{requiredArtifacts}`
- `启动时自动扫描`
- `后续会在应用启动时自动扫描目录并刷新歌曲索引。`
- `选择目录`
- `清空路径`
- `建议目录中的文件先采用“歌手 - 歌名.dat”或“歌手 - 歌名.mp4”这类命名方式，后续扫描时可以直接拆出歌手和歌名。`
- `关闭`
- `完成`

来源：

- [settings_dialog.dart](/Volumes/DATA/Space/ktv/lib/widgets/settings_dialog.dart#L154)

### 11.1 设置弹窗错误文案

- `打开目录选择器失败，请重启应用后重试。`

来源：

- [settings_dialog.dart](/Volumes/DATA/Space/ktv/lib/widgets/settings_dialog.dart#L38)

## 12. 运行时错误文案

这些字符串虽然来自业务/服务层，但会直达 UI。

- `当前 Android 媒体库路径是旧的文件路径。请打开“媒体库设置”，重新点击“选择目录”并选中 MV 根目录后重试。`
- `Android 扫描本地媒体库需要存储访问权限。请在系统设置中允许读取媒体或文件后重试。`
- `当前目录没有可用读取授权，请重新点击“选择目录”完成授权。`
- `Android 无法读取当前媒体库目录，请在“媒体库设置”中重新点击“选择目录”完成授权。`
- `媒体库目录不存在`
- `Web 版暂不支持按本地目录扫描媒体库。`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L219)
- [media_library_service_io.dart](/Volumes/DATA/Space/ktv/lib/services/media_library_service_io.dart#L29)
- [media_library_service_stub.dart](/Volumes/DATA/Space/ktv/lib/services/media_library_service_stub.dart#L18)

