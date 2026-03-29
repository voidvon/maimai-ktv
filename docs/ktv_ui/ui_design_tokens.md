# KTV UI Design Tokens

本文件将当前 UI 中实际出现的视觉 token 抽成结构化表。用于在另一个项目中统一建立 `color / typography / radius / spacing / elevation / layout` 基础能力。

## 1. Color Tokens

### 1.1 Foundation

| Token | Value | 用途 |
|---|---|---|
| `canvas.base` | `#10071D` | 全局 scaffold 背景 |
| `brand.seed` | `#6A36FF` | 全局主题种子色 |
| `brand.title` | `#FFD85E` | 品牌标题“金调KTV” |
| `accent.pink` | `#FF4D8D` | 播放进度、全屏选中按钮 |
| `accent.pink.border` | `#FF9EBC` | 全屏选中按钮边框 |
| `accent.orange` | `#FF6E67` | 状态卡主操作按钮 |
| `surface.card.dark` | `#120A1E` | 主题卡片底色 |
| `surface.card.white` | `#FFFFFF` | 白底歌手网格与占位卡 |

### 1.2 Text

| Token | Value | 用途 |
|---|---|---|
| `text.primary.light` | `#FFF7FF` | 主亮文字 |
| `text.secondary.light` | `#F3DAFF` | 次级亮文字 |
| `text.light.soft` | `#FFF2FF` | 输入框 icon / 页码 / 次按钮 |
| `text.disabled.muted` | `#A99ABF` | 首页工具栏禁用 |
| `text.deep` | `#1D1230` | 白底卡片主标题 |
| `text.mid` | `#6B5D7C` | 白底卡片副文案 |
| `text.subtle` | `#8C819B` | 设置弹窗说明、hint |
| `text.error` | `#9C2F2F` | 红色错误卡文本 |
| `text.warning` | `#7A4A00` | Android 重授权提示 |

### 1.3 Background Gradients

| Token | Value |
|---|---|
| `bg.page.main` | `#23004F -> #6820D9 -> #16012D` |
| `bg.shell.wide` | `#23004F -> #4A0A99 -> #2B005A -> #30006B -> #6820D9 -> #461094 -> #16012D -> #3B1177 -> #25024A` |
| `bg.shell.compact` | `#23004F -> #5E1BC4 -> #1F033E` |
| `bg.overlay.video` | `black 5% -> black 28%` |
| `bg.overlay.previewMini` | `black 4% -> black 22%` |
| `bg.overlay.fullscreenChrome` | `black 34% -> black 8% -> black 52%` |

### 1.4 Ambient / Decoration

| Token | Value | 用途 |
|---|---|---|
| `glow.purple` | `#B44DFF` | 左上发光团 |
| `glow.cyan` | `#2BD5FF` | 右上发光团 |
| `ring.white.soft` | `white @ 7%` | 半透明白环 |
| `ring.blue.soft` | `#B98CFF @ 9%` | 右下紫环 |

### 1.5 Shortcut Gradients

| Shortcut | Gradient |
|---|---|
| 排行榜 | `#FF7C93, #FF5372, #FF9A7A` |
| 歌名 | `#FFD36A, #FFB245, #FF9566` |
| 歌星 | `#9CC9FF, #89B2FF, #9571FF` |
| 本地 | `#65D8FF, #2E9DFF` |
| 收藏 | `#F2AAFF, #C46BFF` |
| 常唱 | `#FFB8A8, #FF8B78` |

### 1.6 Artist Accent Palette

| Token | Value |
|---|---|
| `artist.1` | `#B554FF` |
| `artist.2` | `#FF7A59` |
| `artist.3` | `#00C2A8` |
| `artist.4` | `#FFC145` |
| `artist.5` | `#6D7CFF` |
| `artist.6` | `#E96BA8` |

来源：

- [app.dart](/Volumes/DATA/Space/ktv/lib/app.dart#L10)
- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L745)
- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L842)
- [ktv_home_page_selection_view_model.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_selection_view_model.dart#L410)

## 2. Typography Tokens

### 2.1 Font Family

| Token | Value |
|---|---|
| `font.family.primary` | `SF Pro Display` |

### 2.2 Font Size Scale

| Token | Size | 常见用途 |
|---|---|---|
| `text.7` | `7` | 列表副标题 |
| `text.8` | `8` | 已点列表小按钮 |
| `text.9` | `9` | 语种 tab / meta chip |
| `text.10` | `10` | 工具栏 pill / 小标签 / 搜索提示 |
| `text.11` | `11` | 搜索框输入 / 页码 / 说明文 |
| `text.12` | `12` | 全屏按钮 / 状态层说明 |
| `text.13` | `13` | 面包屑 / 全屏歌手名 |
| `text.14` | `14` | 首页快捷卡标签 |
| `text.15` | `15` | 状态卡标题 / 歌手卡标题 / 浮层标题 |
| `text.16` | `16` | 全屏状态浮层标题 / 歌手头像字母 |
| `text.18` | `18` | 顶部品牌 / 全屏标题 |

### 2.3 Weight Tokens

| Token | Value | 用途 |
|---|---|---|
| `weight.medium` | `500` | 副标题、页码 |
| `weight.semibold` | `600` | 大多数按钮和列表标题 |
| `weight.bold` | `700` | 品牌、快捷卡、状态浮层标题 |
| `weight.extrabold` | `800` | 状态卡标题、歌手卡标题 |

## 3. Radius Tokens

| Token | Value | 用途 |
|---|---|---|
| `radius.4` | `4` | 左列宽屏小预览 |
| `radius.8` | `8` | 列表项、小操作按钮 |
| `radius.10` | `10` | 分页按钮、tab |
| `radius.12` | `12` | 搜索框、小状态 icon 容器、action pill |
| `radius.16` | `16` | toolbar pill、歌手卡、状态卡 |
| `radius.18` | `18` | 首页快捷卡、设置卡 |
| `radius.20` | `20` | 首页工具栏、首页预览状态浮层 |
| `radius.22` | `22` | 白底歌手面板 |
| `radius.24` | `24` | 页面主壳、全屏状态浮层 |
| `radius.26` | `26` | 占位页图标容器 |
| `radius.pill` | `999` | 全部胶囊按钮、hint chip、标签 |

## 4. Spacing Tokens

### 4.1 Micro

| Token | Value |
|---|---|
| `space.2` | `2` |
| `space.4` | `4` |
| `space.6` | `6` |
| `space.8` | `8` |
| `space.10` | `10` |
| `space.12` | `12` |
| `space.14` | `14` |
| `space.16` | `16` |
| `space.18` | `18` |
| `space.20` | `20` |
| `space.22` | `22` |
| `space.24` | `24` |
| `space.28` | `28` |
| `space.32` | `32` |
| `space.48` | `48` |

### 4.2 High-value Layout Spacing

| Token | Value | 用途 |
|---|---|---|
| `layout.page.maxWidth` | `980` | 非沉浸内容最大宽 |
| `layout.home.aspect` | `852 / 393` | 首页壳体比例 |
| `layout.workspace.aspect` | `852 / 393` | 点歌页壳体比例 |
| `layout.preview.aspect` | `16 / 9` | 视频预览比例 |
| `layout.leftColumn.fixed` | `304` | 宽屏左列 |
| `layout.leftColumn.immersiveMax` | `340` | 沉浸左列上限 |
| `layout.home.sideInset` | `48` | 首页宽屏预览左右留白 |

## 5. Elevation / Shadow Tokens

| Token | Value |
|---|---|
| `shadow.shell` | `#090012 @ 25%, blur 32, y 20` |
| `shadow.shell.compact` | `#090012 @ 25%, blur 28, y 18` |
| `shadow.toolbar` | `#120023 @ 40%, blur 20, y 8` |
| `shadow.preview.home` | `#090012 @ 53%, blur 24, y 10` |
| `shadow.preview.left` | `#0A001E @ 53%, blur 18, y 10` |
| `shadow.shortcut` | `#1B024D @ 31%, blur 20, y 10` |
| `shadow.statusOverlay` | `#000000 @ 40%, blur 18, y 8` |

## 6. Component Tokens

### 6.1 Toolbar Pill

| Token | Value |
|---|---|
| `toolbar.pill.padding` | `10 x 8` |
| `toolbar.pill.radius` | `16` |
| `toolbar.pill.bg.enabled` | `white @ 10%` |
| `toolbar.pill.bg.disabled` | `white @ 5%` |

### 6.2 Top Action Pill

| Token | Value |
|---|---|
| `action.pill.padding` | `8 x 5` |
| `action.pill.radius` | `12` |
| `action.pill.icon` | `12` |
| `action.pill.text` | `10 / 600` |

### 6.3 List Tile

| Token | Value |
|---|---|
| `list.tile.song.height` | `34` |
| `list.tile.queue.height` | `48` |
| `list.tile.padding` | `10,5,8,5` |
| `list.tile.radius` | `8` |
| `list.tile.gap.columns` | `12` |
| `list.tile.gap.rows` | `6` |

### 6.4 Search Field

| Token | Value |
|---|---|
| `search.height` | `32` |
| `search.radius` | `12` |
| `search.icon` | `14` |
| `search.close.circle` | `16` |
| `search.close.icon` | `10` |

### 6.5 Keyboard Key

| Token | Value |
|---|---|
| `keyboard.key.height` | `22` |
| `keyboard.key.radius` | `12` |
| `keyboard.key.gap` | `6` |

### 6.6 Progress

| Token | Value |
|---|---|
| `progress.track.height` | `6` |
| `progress.track.radius` | `999` |
| `progress.track.bg` | `white @ 20%` |
| `progress.track.fg` | `#FF4D8D` |

## 7. Layout Ratios

| Token | Value | 说明 |
|---|---|---|
| `home.columns.ratio` | `384 : 324` | 首页预览区与快捷区 |
| `artist.grid.ratio.single` | `2.5` | 单列歌手卡 |
| `artist.grid.ratio.double` | `1.48` | 双列歌手卡 |
| `shortcut.grid.ratio.wide` | `156 / 54` | 首页宽屏快捷卡 |
| `shortcut.grid.ratio.compact` | `2.25` | 首页紧凑快捷卡 |

