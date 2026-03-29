# KTV UI 资源说明

本文件描述当前 UI 里实际依赖的非代码视觉资源，以及图标/动态图形的使用策略。

## 1. 位图资源

### 1.1 首页 fallback 主图

资源路径：

- [generated-1774423872794.png](/Volumes/DATA/Space/ktv/images/generated-1774423872794.png)

当前用途：

- 首页预览区在“无当前歌曲且无视频输出”时，作为背景图显示
- 左列小预览在“无当前歌曲且无视频输出”时也复用此图
- 显示方式：`BoxFit.cover`

尺寸信息：

- 像素宽：`1376`
- 像素高：`768`
- 宽高比约：`1.7917`
- 接近 `16:9`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L65)

### 1.2 复刻建议

如果另一个项目无法直接复用同一张图，替代资源需要满足以下条件：

1. 画面方向必须为横向
2. 推荐比例仍为 `16:9`
3. 应适合铺满裁切，主体不要过度靠边
4. 颜色应与主界面兼容，优先紫蓝色系、夜店/KTV 舞台氛围
5. 图上不应有大段可读文字，否则在 `cover` 裁切后会很容易变形

## 2. 图标系统

当前项目没有自定义图标包，全部使用 `Material Icons`。

### 2.1 首页快捷入口图标

| 文案 | IconData |
|---|---|
| 排行榜 | `Icons.star_rounded` |
| 歌名 | `Icons.music_note_rounded` |
| 歌星 | `Icons.person_rounded` |
| 本地 | `Icons.music_note_rounded` |
| 收藏 | `Icons.favorite_border_rounded` |
| 常唱 | `Icons.mic_external_on_rounded` |

### 2.2 顶部与操作图标

| 场景 | IconData |
|---|---|
| 搜索框左侧 | `Icons.search_rounded` |
| 退格 | `Icons.keyboard_backspace_rounded` |
| 清空输入 | `Icons.close_rounded` |
| 返回 | `Icons.arrow_circle_left_rounded` |
| 已点 | `Icons.queue_music_rounded` |
| 原唱/伴唱 | `Icons.mic_rounded` |
| 切歌 | `Icons.skip_next_rounded` |
| 播放 | `Icons.play_circle_rounded` |
| 暂停 | `Icons.pause_circle_rounded` |
| 重唱 | `Icons.replay_rounded` |

### 2.3 播放状态图标

| 状态 | IconData |
|---|---|
| 错误 | `Icons.error_outline_rounded` |
| 加载中 | `Icons.hourglass_top_rounded` |
| 无视频输出 | `Icons.tv_off_rounded` |

### 2.4 状态卡与占位图标

| 场景 | IconData |
|---|---|
| 设置 MV 路径 | `Icons.folder_open_rounded` |
| 扫描中 | `Icons.sync_rounded` |
| 媒体库扫描失败 | `Icons.error_outline_rounded` |
| 空媒体库 | `Icons.library_music_rounded` |
| 功能占位 | `Icons.construction_rounded` |
| 歌手卡箭头 | `Icons.arrow_forward_rounded` |

### 2.5 设置弹窗图标

| 场景 | IconData |
|---|---|
| 选择目录 | `Icons.folder_open_rounded` |
| 清空路径 | `Icons.delete_outline_rounded` |

## 3. 环境装饰资源

当前页面里的 glow 和 ring 都不是图片资源，而是代码绘制：

- Glow：径向渐变圆 + 高斯模糊
- Ring：纯描边圆

优点：

- 可跨平台一致
- 不需要额外导出 PNG/SVG
- 可在不同页面复用并调整位置/尺寸/透明度

来源：

- [ktv_home_page_shell_widgets.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_shell_widgets.dart#L3)

## 4. 资源复刻建议

### 4.1 必须保留一致的资源

- 首页 fallback 主图的“横向舞台氛围”
- Material Icons 的圆角版本选择
- 环境 glow/ring 的位置关系

### 4.2 可以替换但要保持语义一致的资源

- 首页主图可以换，但色调和氛围不能偏离太多
- 若另一个项目有自己的图标系统，可以替换成语义等价图标，但必须保持“圆润、娱乐化、非商务后台”的视觉倾向

### 4.3 不建议替换的部分

- `等待点唱` 标签位置和胶囊样式
- 全屏层顶部按钮群的 pill 风格
- 歌手卡中的圆头像 + 首字母模式

