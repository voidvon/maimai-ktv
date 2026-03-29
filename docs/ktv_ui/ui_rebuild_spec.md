# KTV UI 复刻规格文档

本文档基于当前仓库中的 Flutter UI 实现整理，目标是让另一个项目能够按规格重建同一套界面，而不是只做“风格接近”的二次设计。

默认单位均为逻辑像素 `dp/pt`。

适用代码基线：

- [app.dart](/Volumes/DATA/Space/ktv/lib/app.dart)
- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart)
- [ktv_home_page_selection_widgets.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_selection_widgets.dart)
- [ktv_home_page_queue_widgets.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_queue_widgets.dart)
- [ktv_home_page_preview_widgets.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_preview_widgets.dart)
- [settings_dialog.dart](/Volumes/DATA/Space/ktv/lib/widgets/settings_dialog.dart)

## 1. 设计基线

### 1.1 全局主题

- App 标题：`KTV`
- 全局字体：`SF Pro Display`
- `Material 3`：开启
- Scaffold 背景色：`#10071D`
- 主题种子色：`#6A36FF`
- 默认卡片圆角：`24`
- 默认卡片底色：`#120A1E`

来源：

- [app.dart](/Volumes/DATA/Space/ktv/lib/app.dart#L10)

### 1.2 主视觉方向

- 整体是“高饱和紫色 KTV 舞台”风格，不是纯黑播放器风格。
- 大面积背景使用紫色系多段渐变，叠加青色/粉色发光团和半透明圆环。
- 所有主要交互组件都采用高圆角 pill 或 soft card。
- 亮色文字主要偏白紫：`#FFF7FF`、`#FFF2FF`、`#F3DAFF`
- 强强调色主要有三组：
  - 主紫：`#6A36FF`
  - 玫粉：`#FF4D8D`
  - 金黄：`#FFD85E`

## 2. 布局模式

当前 UI 不是固定一套布局，而是 3 种模式：

### 2.1 沉浸横屏模式

触发条件：

- `constraints.maxWidth > constraints.maxHeight`

行为：

- 去掉四边 `MediaQuery` padding
- 页面内容居中显示
- 内容画布宽度：
  - `canvasWidth = min(screenWidth, screenHeight * 16 / 9)`
- 内容高度：
  - 等于屏幕高

这意味着横屏时内容会始终向 `16:9` 视觉比例收敛。

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L707)

### 2.2 普通宽屏模式

触发条件：

- 非沉浸模式
- 且 `maxWidth > maxHeight`

行为：

- 使用 `SafeArea`
- 外层容器有全屏背景渐变和环境光
- 主要内容 `maxWidth = 980`
- 页面本体保持 `852 / 393` 的固定宽高比

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L822)
- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L909)
- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1088)

### 2.3 紧凑竖屏模式

触发条件：

- 非沉浸模式
- 且 `maxWidth <= maxHeight`

行为：

- 仍保持 `maxWidth = 980`
- 取消固定 `852 / 393` 横向比例
- 首页和点歌页改为单列垂直结构

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L810)
- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L959)

## 3. 全局背景与环境装饰

### 3.1 普通页面背景

全屏背景渐变：

- `#23004F`
- `#6820D9`
- `#16012D`

方向：

- `topLeft -> bottomRight`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L745)

### 3.2 环境发光与圆环

普通模式下页面叠加 4 个背景装饰：

1. 左上紫色发光团
   - 位置：`top 76`, `left -120`
   - 尺寸：`380`
   - 颜色：`#B44DFF -> transparent`
   - 模糊：`12`
   - 透明度：`0.68`
2. 右上青色发光团
   - 位置：`top 48`, `right 88`
   - 尺寸：`330`
   - 颜色：`#2BD5FF -> transparent`
   - 模糊：`8`
   - 透明度：`0.64`
3. 右上白色圆环
   - 位置：`top -40`, `right 76`
   - 尺寸：`240`
   - 边框色：`white @ 7%`
4. 右下蓝紫圆环
   - 位置：`right -14`, `bottom -82`
   - 尺寸：`360`
   - 边框色：`#B98CFF @ 9%`

点歌页普通模式和紧凑模式使用同类装饰，但位置与尺寸略有变化：

- 宽屏点歌页：
  - 左上 glow：`380`
  - 右上 glow：`330`
  - 右上 ring：`240`
  - 右下 ring：`360`
- 紧凑点歌页：
  - 左上 glow：`260`
  - 右上 glow：`220`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L761)
- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1026)
- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1097)
- [ktv_home_page_shell_widgets.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_shell_widgets.dart#L3)

## 4. 首页规格

## 4.1 外层容器

### 宽屏首页

- 外层内容容器圆角：`24`
- 内部主渐变共 9 个色阶：
  - `#23004F`
  - `#4A0A99`
  - `#2B005A`
  - `#30006B`
  - `#6820D9`
  - `#461094`
  - `#16012D`
  - `#3B1177`
  - `#25024A`
- 渐变方向：`topLeft -> bottomRight`
- 阴影：
  - 颜色 `#090012 @ 25%`
  - 模糊 `32`
  - Y 偏移 `20`

内边距：

- 普通宽屏：`left 18, top 12, right 18, bottom 16`
- 沉浸横屏：`left 0, top 0, right 0, bottom 4`

外层包裹：

- 普通宽屏外层 `AspectRatio = 852 / 393`
- 外层页面 padding：
  - 宽屏：`24, 20, 24, 24`
  - 紧凑：`16, 16, 16, 24`
  - 沉浸：`12, 6, 12, 8`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L842)
- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L815)

### 紧凑首页

- 圆角：`24`
- 渐变：`#23004F -> #5E1BC4 -> #1F033E`
- 阴影：
  - 颜色 `#090012 @ 25%`
  - 模糊 `28`
  - Y 偏移 `18`
- 内边距：`16`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L912)

## 4.2 首页结构

### 宽屏首页结构

纵向结构：

1. 顶部工具栏
2. 间距 `18`
3. 主体区域 `Expanded`

主体区域横向结构：

1. 左侧空白：`48`，仅普通宽屏存在
2. 预览区：`Expanded(flex: 384)`
3. 中间间距：
   - 普通宽屏 `12`
   - 沉浸横屏 `18`
4. 快捷入口区：`Expanded(flex: 324)`
5. 右侧空白：`48`，仅普通宽屏存在

这个布局不是 50/50，两栏比例约为 `384 : 324`，即约 `54.2% : 45.8%`。

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L876)

### 紧凑首页结构

纵向结构：

1. 顶部工具栏
2. 间距 `16`
3. 16:9 预览卡
4. 间距 `16`
5. 2 列快捷入口网格

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L929)

## 4.3 首页工具栏

### 工具栏外框

- 左右内边距：`12`
- 高度：
  - 宽屏：`40`
  - 紧凑：自适应
- 背景：白色 `8%`
- 圆角：`20`
- 阴影：
  - 颜色 `#120023 @ 40%`
  - 模糊 `20`
  - Y 偏移 `8`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L2141)

### 工具栏内容

品牌标题：

- 文案：`金调KTV`
- 字色：`#FFD85E`
- 字号：`18`
- 字重：`700`

紧凑模式内部布局：

- 垂直 padding：`10`
- 标题下间距：`10`
- 按钮区右对齐，`Wrap`

宽屏模式按钮排列：

- 使用水平 `Row`
- 按钮间距：`6`

工具栏按钮顺序：

1. 搜索
2. 已点N
3. 原唱/伴唱
4. 切歌
5. 暂停/播放
6. 设置
7. 退出

### 工具栏 pill

- 圆角：`16`
- 内边距：`horizontal 10, vertical 8`
- 字号：`10`
- 字重：`600`
- 启用背景：白色 `10%`
- 禁用背景：白色 `5%`
- 启用文字：`#FFF7FF`
- 禁用文字：`#A99ABF`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L2191)

## 4.4 首页视频预览卡

### 卡片基础

- 比例：`16 / 9`
- 圆角：`20`
- 边框：白色 `12%`
- 阴影：
  - 颜色 `#090012 @ 53%`
  - 模糊 `24`
  - Y 偏移 `10`
- 点击行为：有视频时点击进入全屏

内部层级：

1. 视频层或 fallback
2. 自上而下的黑色透明渐变遮罩
   - `0.05 -> 0.28`
3. 状态覆盖层
4. 无播放时的“等待点唱”标签
5. 有播放时底部进度条

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L2220)

### 等待点唱标签

- 位置：
  - 紧凑：`left 12, top 12`
  - 宽屏：`left 16, top 16`
- padding：`horizontal 10, vertical 6`
- 背景：白色 `12%`
- 圆角：`999`
- 文本：`等待点唱`
- 字色：`#FFF7FF`
- 字重：`700`

### 底部进度条

- 左右边距：
  - 紧凑：`12`
  - 宽屏：`16`
- 底部定位：`0`
- 顶部额外内边距：`4`
- 轨道高度：`6`
- 容器高度：
  - 首页紧凑：`6 + 22 + 2 = 30`
  - 首页宽屏：`6 + 26 + 2 = 34`
  - 其他非首页预览：`6 + 0 + 2 = 8`
- 轨道圆角：`999`
- 轨道底色：`white @ 20%`
- 进度色：`#FF4D8D`
- 支持点击 seek 与横向拖动 seek

来源：

- [ktv_home_page_preview_widgets.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_preview_widgets.dart#L151)
- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L2290)

### 播放状态覆盖层

显示条件：

- 当前有歌曲，且以下任一成立：
  - 播放错误
  - 正在准备播放
  - 正在播放但尚无视频输出且未播放完成

卡片规格：

- 最大宽度：
  - 普通预览：`360`
  - 全屏：`520`
- 外侧水平 margin：
  - 紧凑：`16`
  - 宽屏：`20`
  - 全屏：`24`
- 普通内边距：
  - 紧凑：`16 x 14`
  - 宽屏：`18 x 16`
- 全屏内边距：`24 x 20`
- 背景：黑色 `74%`
- 边框：白色 `12%`
- 圆角：
  - 普通：`20`
  - 全屏：`24`
- 阴影：
  - `#000000 @ 40%`
  - blur `18`
  - y `8`

图标区：

- 普通 icon `22`
- 全屏 icon `26`
- 图标容器尺寸 = `iconSize + 12`
- 图标容器背景：白色 `8%`

标题文字：

- 普通 `15/700`
- 全屏 `16/700`

说明文字：

- 普通 `12`
- 全屏 `13`
- 行高 `1.45`

来源：

- [ktv_home_page_preview_widgets.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_preview_widgets.dart#L17)

## 4.5 首页快捷入口网格

### 网格参数

- 列数：`2`
- 行间距：`12`
- 列间距：`12`
- 宽屏子项比例：`156 / 54 ≈ 2.8889`
- 紧凑子项比例：`2.25`
- 不可滚动，内容一次性展示

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L2319)

### 快捷卡样式

- 圆角：`18`
- 内边距：`horizontal 16, vertical 14`
- 渐变方向：`centerLeft -> centerRight`
- 阴影：
  - 颜色 `#1B024D @ 31%`
  - 模糊 `20`
  - Y 偏移 `10`

文本：

- 字色：`#FFF9FF`
- 字号：`14`
- 字重：`700`

图标：

- 尺寸：`24`
- 颜色：白色 `80%`

来源：

- [ktv_home_page_shell_widgets.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_shell_widgets.dart#L53)

### 六个首页入口配置

1. 排行榜
   - 图标：`star_rounded`
   - 渐变：`#FF7C93`, `#FF5372`, `#FF9A7A`
2. 歌名
   - 图标：`music_note_rounded`
   - 渐变：`#FFD36A`, `#FFB245`, `#FF9566`
3. 歌星
   - 图标：`person_rounded`
   - 渐变：`#9CC9FF`, `#89B2FF`, `#9571FF`
4. 本地
   - 图标：`music_note_rounded`
   - 渐变：`#65D8FF`, `#2E9DFF`
5. 收藏
   - 图标：`favorite_border_rounded`
   - 渐变：`#F2AAFF`, `#C46BFF`
6. 常唱
   - 图标：`mic_external_on_rounded`
   - 渐变：`#FFB8A8`, `#FF8B78`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L68)

## 5. 点歌工作区规格

点歌工作区覆盖这些 route：

- 歌名点歌
- 已点列表
- 歌星点歌
- 歌星歌曲
- 排行榜
- 本地
- 各类占位页

## 5.1 外层壳体

### 宽屏

- 与首页共用同一组 9 段渐变壳体
- 圆角：`24`
- 阴影：blur `32`, y `20`
- 普通宽屏整体比例：`852 / 393`

内部布局：

- 普通宽屏：
  - 左内边距 `56`
  - 上内边距 `22`
  - 右内边距 `28`
  - 下内边距 `18`
  - 左列固定宽 `304`
  - 中间间距 `28`
  - 右列 `Expanded`
- 沉浸横屏：
  - 外层 padding `16,14,16,16`
  - 内部顶部额外 padding `0,4,0,8`
  - 左列宽：`min(340, screenWidth * 0.25)`
  - 中间间距 `18`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L991)

### 紧凑

- 使用同一壳体背景
- 内边距：`18`
- 垂直结构
- 左列和右列上下排列
- 中间垂直间距：`20`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1091)

## 5.2 左列

纵向结构：

1. 顶部空白：
   - 紧凑 `6`
   - 宽屏 `10`
2. 预览区
3. 间距：
   - 紧凑 `4`
   - 宽屏 `6`
4. 搜索框
5. 间距：
   - 紧凑 `6`
   - 宽屏 `8`
6. 字母键盘或 route 快速信息面板

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1162)

### 左列预览区

区别于首页预览卡：

- 比例同样是 `16 / 9`
- 宽屏圆角只有 `4`
- 紧凑圆角 `12`
- 边框：`#111111 @ 53%`
- 阴影：
  - `#0A001E @ 53%`
  - blur `18`
  - y `10`

无播放标签：

- 定位：`left 10, top 10`
- padding：`8 x 4`
- 字体：`10/700`

若有播放：

- 预览区下方追加一个 8 高的独立进度条条带
- 与视频区间距 `2`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1183)

### 搜索框

- 高度：`32`
- 背景：白色 `14%`
- 圆角：`12`

内部顺序：

1. 左 padding `10`
2. 搜索 icon
   - 尺寸 `14`
   - 色 `#FFF2FF @ 80%`
3. 间距 `6`
4. 输入框 `Expanded`
5. 退格按钮 `IconButton`
   - splash 半径 `14`
   - 图标尺寸 `14`
6. 右侧关闭按钮外层 padding `right 6`
7. 关闭按钮圆形容器
   - 宽高 `16`
   - 图标尺寸 `10`

文字：

- 输入内容：`11/600`, `#FFF7FF`
- placeholder：`10/600`, `#F2DFFF @ 60%`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1285)

### 快速信息面板

用于非“歌名点歌/已点列表”路由的左列底部说明卡。

- 宽度：`100%`
- padding：
  - 紧凑 `12`
  - 宽屏 `14`
- 背景：白色 `10%`
- 边框：白色 `10%`
- 圆角：`16`

顶部 route pill：

- padding `8 x 5`
- 背景：白色 `12%`
- 圆角：`999`
- 文字：`10/700`, `#FFF7FF`

说明文字：

- `11`
- 行高 `1.5`
- 颜色 `#F3DAFF @ 80%`

meta chip：

- 间距 `6`
- padding `8 x 5`
- 背景：白色 `8%`
- 圆角 `999`
- 字体 `9/600`
- 文字色 `#FFF7FF @ 92%`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1373)

### 字母/数字键盘

#### 字母模式

- 4 行
- 每行 7 个按钮
- 横向间距：`6`
- 纵向间距：`6`
- 最后一项 `123` 为数字键盘切换按钮

#### 数字模式

- 前 3 行：
  - `1 2 3`
  - `4 5 6`
  - `7 8 9`
- 最后一行：
  - 空
  - `0`
  - `ABC`
- 横向间距：`6`
- 纵向间距：`6`

#### 单个键帽

- 高度：`22`
- 圆角：`12`
- 选中背景：白色 `14%`
- 未选中背景：透明
- 字体：
  - 普通字母：`12/600`
  - `123`：`10/700`
- 文字色：`#FFF6FF @ 85%`

来源：

- [ktv_home_page_selection_widgets.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_selection_widgets.dart#L113)
- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1487)

## 5.3 右列

纵向结构：

1. 顶部操作 pill 组，右对齐
2. 间距 `8`
3. 面包屑 + 返回按钮
4. 间距 `8`
5. 若为歌名点歌，显示语种筛选 tab
6. 若非歌名点歌且有 meta，显示 hint chip
7. route 内容区

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1597)

### 顶部操作 pill

按钮顺序：

1. 已点N
2. 原唱/伴唱
3. 切歌
4. 播放/暂停
5. 重唱

排列方式：

- `Wrap`
- 水平间距 `4`
- 垂直间距 `4`
- 右对齐

单个 pill：

- 圆角：`12`
- padding：`horizontal 8, vertical 5`
- icon：`12`
- icon 与文字间距：`4`
- 字号：`10`
- 字重：`600`
- 启用背景：白色 `10%`
- 禁用背景：白色 `5%`
- 启用色：`#FFF7FF @ 80%`
- 禁用色：`#FFF7FF @ 48%`

来源：

- [ktv_home_page_selection_widgets.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_selection_widgets.dart#L3)
- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1603)

### 面包屑

- 文本字号：`13`
- 字重：`700`
- 文本色：`#FFF7FF @ 92%`
- 文本与返回按钮间距：`10`

返回按钮复用顶部 action pill 样式。

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1648)

### 语种筛选 pill

仅歌名点歌显示，选项顺序：

- 全部
- 国语
- 粤语
- 闽南语
- 英语
- 日语
- 韩语
- 其它

单个 tab：

- 圆角：`10`
- padding：`horizontal 10, vertical 3`
- 选中背景：白色 `8%`
- 未选中背景：白色 `4%`
- 字号：`9`
- 选中权重：`700`
- 未选中权重：`500`
- 选中颜色：`#FF625E`
- 未选中颜色：`#FFF0FF @ 72%`
- tab 间距：`4`

来源：

- [ktv_home_page_selection_widgets.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_selection_widgets.dart#L73)
- [ktv_home_page_selection_view_model.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_selection_view_model.dart#L4)

## 6. 内容区组件规格

## 6.1 双列歌曲列表

适用于：

- 歌名点歌
- 歌星歌曲
- 排行榜
- 本地
- 已点列表

布局规则：

- 固定两列
- 列间距：`12`
- 行间距：`6`

空状态卡：

- 宽度：`100%`
- padding：`vertical 28, horizontal 18`
- 背景：白色 `8%`
- 边框：白色 `8%`
- 圆角：`16`
- 文本居中
- 字色：`#F3DAFF @ 80%`
- 行高：`1.5`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1979)

### 歌曲列表项

- 高度：`34`
- 外框圆角：`8`
- padding：`left 10, top 5, right 8, bottom 5`
- 边框：白色 `10%`
- 当前播放背景：白色 `16%`
- 普通背景：白色 `10%`

主标题：

- 字号 `10`
- 字重 `600`
- 行高 `1`

副标题：

- 字号 `7`
- 字重 `500`
- 行高 `1`
- 标题与副标题间距 `1`

颜色：

- 当前播放标题：`#FFF7FF`
- 普通标题：`#FFF7FF @ 93%`
- 当前播放副标题：`#F3DAFF @ 80%`
- 普通副标题：`#F3DAFF @ 72%`

交互：

- 当前播放项不可点击
- 已在队列中的项不可点击
- 只有未播放且未在队列中的项可点击加入队列

来源：

- [ktv_home_page_selection_widgets.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_selection_widgets.dart#L159)

### 已点列表项

- 复用 `_SelectionListTileFrame`
- 高度：`48`
- 标题字号：`10`
- 副标题字号：`7`
- 副标题间距：`3`
- 右侧操作区仅当前播放外显示

状态文本：

- 当前播放：`当前播放`
- 队列项：`队列 {index + 1}`

右侧按钮：

- `置顶`
- `移除`

按钮规格：

- 圆角：`8`
- padding：`horizontal 6, vertical 5`
- 按钮间距：`4`
- 字号：`8`
- 字重：`600`
- 启用背景：白色 `10%`
- 禁用背景：白色 `5%`

来源：

- [ktv_home_page_queue_widgets.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_queue_widgets.dart#L47)

## 6.2 分页器

- 对齐：
  - 紧凑模式居中
  - 宽屏靠右
- 结构：
  - 上一页按钮
  - 间距 `12`
  - 页码文字
  - 间距 `12`
  - 下一页按钮

页码文字：

- 字号：`11`
- 字重：`500`
- 颜色：`#FFF2FF @ 80%`

分页按钮：

- 圆角：`10`
- padding：`horizontal 12, vertical 5`
- 字号：`11`
- 字重：`600`
- 启用背景：白色 `11%`
- 禁用背景：白色 `5%`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1815)
- [ktv_home_page_selection_widgets.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_selection_widgets.dart#L283)

## 6.3 歌手网格

### 网格规则

- padding：`12`
- 行间距：`10`
- 列间距：`10`
- `constraints.maxWidth < 520` 时为 1 列，否则 2 列
- 单列时 `childAspectRatio = 2.5`
- 双列时 `childAspectRatio = 1.48`
- 宽屏非 bounded 状态下整体高度固定 `520`

容器底色：

- 纯白 `#FFFFFF`
- 圆角：`22`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1844)

### 歌手卡

- 圆角：`16`
- 内边距：`12`
- 背景为基于歌手 accent 色的弱渐变：
  - `accent @ 18%`
  - `accent @ 6%`

头像：

- `CircleAvatar radius 22`
- 背景 = accent 色
- 首字母文字：`16/800`, 白色

底部信息：

- 歌手名：
  - 字号 `15`
  - 字重 `800`
  - 颜色 `#1D1230`
- 歌曲数：
  - 字号 `11`
  - 字重 `600`
  - 颜色 `#6B5D7C`
- 右箭头：
  - 尺寸 `16`
  - 颜色 = accent 色

accent 调色板：

- `#B554FF`
- `#FF7A59`
- `#00C2A8`
- `#FFC145`
- `#6D7CFF`
- `#E96BA8`

选择规则：

- `artistName` 的 Unicode code point 求和，再对调色板长度取模

来源：

- [ktv_home_page_preview_widgets.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_preview_widgets.dart#L474)
- [ktv_home_page_selection_view_model.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_selection_view_model.dart#L410)

## 6.4 状态卡

适用于：

- 未设置 MV 路径
- 扫描中
- 扫描失败
- 空媒体库

样式：

- 宽度：`100%`
- padding：`14`
- 背景：白色 `10%`
- 边框：白色 `10%`
- 圆角：`16`

图标容器：

- `34 x 34`
- 圆角：`12`
- 背景：白色 `12%`
- 图标尺寸：`18`
- 图标色：`#FFF2FF`

标题：

- `15/800`
- `#FFF7FF`

描述：

- `11`
- 行高 `1.5`
- `#F3DAFF @ 80%`

主操作按钮：

- 上边距 `12`
- 使用 FilledButton
- 背景色 `#FF6E67`

footer：

- 上边距 `16`

来源：

- [ktv_home_page_selection_widgets.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_selection_widgets.dart#L318)

## 6.5 Hint Chip

- padding：`horizontal 10, vertical 6`
- 背景：`#F2EAFF`
- 圆角：`999`
- 字色：`#6A36FF`
- 字体：`11/700`

来源：

- [ktv_home_page_preview_widgets.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_preview_widgets.dart#L551)

## 6.6 占位页

- 白底
- 圆角：`22`
- 中心布局
- 内边距：`32`

图标容器：

- `84 x 84`
- 圆角：`26`
- 底色：`#F2EAFF`
- 图标：
  - `construction_rounded`
  - 尺寸 `38`
  - 颜色 `#6A36FF`

标题：

- 使用 `headlineSmall`
- 字重 `800`
- 颜色 `#1D1230`

说明：

- 上间距 `10`
- 颜色 `#6B5D7C`
- 行高 `1.6`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L2340)

## 7. 全屏播放层规格

显示条件：

- 用户点击预览视频卡，且当前有可复用视频视图

容器：

- 全屏 `Positioned.fill`
- 背景纯黑
- 点击空白区域切换 chrome 显隐

来源：

- [ktv_home_page_preview_widgets.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_preview_widgets.dart#L333)

### 顶部渐变罩

仅在 chrome 可见时显示：

- 渐变颜色：
  - `black @ 34%`
  - `black @ 8%`
  - `black @ 52%`
- 停靠点：`0.0, 0.4, 1.0`

### 顶部工具区

- 定位：`left 16, right 16, top 16`
- 按钮区使用 `Wrap`
- 按钮间距：`8`

按钮：

1. 返回点歌
2. 伴唱
3. 切歌
4. 重唱

按钮规格：

- 圆角：`999`
- padding：`horizontal 14, vertical 9`
- 字体：`12/700`
- 默认背景：
  - 启用 `white @ 14%`
  - 禁用 `white @ 8%`
- 默认边框：
  - 启用 `white @ 18%`
  - 禁用 `white @ 8%`
- 选中背景：`#FF4D8D`
- 选中边框：`#FF9EBC`

歌曲信息：

- 按钮下间距：`12`
- 标题：
  - `18/700`
  - 白色
- 歌手：
  - 间距 `4`
  - `13/500`
  - 白色 `80%`

### 底部进度条

- 定位：`left 20, right 20, bottom 18`
- 复用同一套 `_PreviewOverlayBar`
- 额外 bottom padding：`0`

来源：

- [ktv_home_page_preview_widgets.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page_preview_widgets.dart#L377)

## 8. 设置弹窗规格

触发入口：

- 首页工具栏“设置”
- 状态卡动作按钮“设置本地 MV 路径”

### 弹窗基础

- 类型：`AlertDialog`
- inset：`horizontal 24, vertical 24`
- 支持滚动
- 标题：`媒体库设置`
- content 最大宽：
  - 屏幕宽 `> 560` 时固定 `520`
  - 否则 `screenWidth - 48`
- content 最大高：`screenHeight * 0.6`

来源：

- [settings_dialog.dart](/Volumes/DATA/Space/ktv/lib/widgets/settings_dialog.dart#L146)

### 内容区结构

1. 顶部说明文字
2. 间距 `18`
3. 本地 MV 路径卡
4. 如需要，Android 重授权提示卡
5. 间距 `16`
6. 媒体处理引擎信息卡
7. 间距 `16`
8. 自动扫描开关
9. 间距 `12`
10. 操作按钮组
11. 如有错误，错误提示卡
12. 间距 `16`
13. 底部命名建议说明

### 路径卡

- padding：`16`
- 背景：`#F7F2FF`
- 圆角：`18`

标题：

- `本地 MV 路径`
- 深色 `#1D1230`
- `700`

路径文本：

- 上间距 `8`
- `SelectableText`
- 色 `#6B5D7C`
- 行高 `1.5`

### Android 目录重授权提示卡

- 上间距 `12`
- padding `14`
- 背景：`#FFF5E6`
- 圆角：`16`
- 文字色：`#7A4A00`
- 行高：`1.5`

### 媒体引擎信息卡

- padding：`16`
- 背景：`#F3F5FF`
- 圆角：`18`
- 标题色：`#1D1230`
- 内容主色：`#6B5D7C`
- 摘要色：`#4B3E5F`
- packaging hint 色：`#8C819B`

### 错误卡

- 上间距 `16`
- padding `14`
- 背景：`#FFF1F1`
- 圆角：`14`
- 文本色：`#9C2F2F`
- 行高：`1.5`

### 按钮区

- `Wrap`
- 间距 `10`
- 按钮：
  - FilledButton.icon：选择目录
  - OutlinedButton.icon：清空路径

### 弹窗底部 actions

- `关闭`
- `完成`

来源：

- [settings_dialog.dart](/Volumes/DATA/Space/ktv/lib/widgets/settings_dialog.dart#L154)

## 9. 页面文案与状态语义

复刻时不要随意改这些文案，因为当前 UI 视觉和空间分配已经围绕这些文案长度建立。

关键固定文本：

- 品牌：`金调KTV`
- 首页空态：`等待点唱`
- 顶部按钮：`搜索 / 已点N / 原唱/伴唱 / 切歌 / 暂停/播放 / 设置 / 退出`
- 点歌页 breadcrumb：
  - `‹ 主页 / 歌名`
  - `‹ 主页 / 已点`
  - `‹ 主页 / 歌星`
  - `‹ 主页 / 歌星 / 歌曲`
  - `‹ 主页 / 排行榜`
  - `‹ 主页 / 本地`
- 全屏按钮：`返回点歌 / 伴唱 / 切歌 / 重唱`

来源：

- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L2100)
- [ktv_home_page.dart](/Volumes/DATA/Space/ktv/lib/pages/ktv_home_page.dart#L1714)

## 10. 实现约束

为保证另一个项目能最大程度重现当前 UI，建议按以下约束实现：

1. 首页和点歌页的主内容壳在非紧凑模式下必须保持 `852 / 393`。
2. 页面最大内容宽度必须保持 `980`。
3. 横屏沉浸时，内容宽度必须使用 `min(screenWidth, screenHeight * 16 / 9)`。
4. 首页宽屏左右主栏必须保持 `384 : 324` 的 flex 比。
5. 点歌页普通宽屏左栏应固定 `304`，沉浸横屏左栏应使用 `min(340, screenWidth * 0.25)`。
6. 所有小按钮必须保持高圆角和低对比白色半透明底，不要改成实体按钮风格。
7. 歌曲列表必须维持两列，每页逻辑由分页器控制，不做滚动长列表。
8. 歌手页必须保留“白底卡片”风格，不要改成深色卡，否则层级会变乱。
9. 全屏模式必须支持点击空白切换 chrome 显隐。
10. 搜索页左栏小预览在宽屏时圆角只能是 `4`，这是当前视觉上刻意做出的“监视器”感，不要统一改成大圆角。

## 11. 未纳入本文档的内容

以下内容不属于 UI 规格本身，但实现时需要有占位能力：

- 原生播放器真正的视频渲染层
- 媒体库扫描逻辑
- 队列与播放状态逻辑
- 搜索、拼音、语种识别算法

另一个项目如果只做 UI 复刻，可以先用 mock 数据和占位播放器完成界面重建。
