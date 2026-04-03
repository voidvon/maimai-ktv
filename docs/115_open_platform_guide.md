# 115 开放平台开发文档整理

最后整理时间：2026-04-03

## 说明

这份文档是基于 115 官方开放平台入口、官方文档在公开索引中的可见信息，以及公开 SDK 文档交叉整理的本地版开发笔记。

- 官方文档入口：<https://www.yuque.com/115yun/open>
- 开放平台：<https://open.115.com>
- 由于语雀入口对抓取有访问限制，这里保留了官方页面链接，并把能确认的字段、流程和接口集中整理为本地 Markdown，方便后续查阅。

## 官方文档入口

官方开放文档目前至少包含下面两类入口页：

- 115 开放平台总入口：<https://www.yuque.com/115yun/open>
- 扫码授权相关文档：<https://www.yuque.com/115yun/open/shtpzfhewv5nag11>
- 授权码模式相关文档：<https://www.yuque.com/115yun/open/okr2cq0wywelscpe>

常用接口文档直达：

- 文件列表：<https://www.yuque.com/115yun/open/kz9ft9a7s57ep868>
- 文件夹详情：<https://www.yuque.com/115yun/open/rl8zrhe2nag21dfw>
- 搜索文件：<https://www.yuque.com/115yun/open/ft2yelxzopusus38>
- 复制文件：<https://www.yuque.com/115yun/open/lvas49ar94n47bbk>
- 移动文件：<https://www.yuque.com/115yun/open/vc6fhi2mrkenmav2>
- 下载地址：<https://www.yuque.com/115yun/open/um8whr91bxb5997o>
- 更新文件：<https://www.yuque.com/115yun/open/gyrpw5a0zc4sengm>
- 删除文件：<https://www.yuque.com/115yun/open/kt04fu8vcchd2fnb>
- 回收站列表：<https://www.yuque.com/115yun/open/bg7l4328t98fwgex>
- 回收站恢复：<https://www.yuque.com/115yun/open/gq293z80a3kmxbaq>
- 回收站彻底删除：<https://www.yuque.com/115yun/open/gwtof85nmboulrce>
- 上传令牌：<https://www.yuque.com/115yun/open/kzacvzl0g7aiyyn4>
- 初始化上传：<https://www.yuque.com/115yun/open/ul4mrauo5i2uza0q>
- 续传信息：<https://www.yuque.com/115yun/open/tzvi9sbcg59msddz>
- 用户信息：<https://www.yuque.com/115yun/open/ot1litggzxa1czww>

## 接入前置

### 1. 账号与应用

- 需要 115 账号。
- 需要在 <https://open.115.com> 创建应用。
- 如果要走授权码模式，需要提前在应用管理里配置 `redirect_uri` 对应域名。

### 2. 建议保管的密钥与令牌

- `client_id` / `AppID`
- `client_secret` / `AppSecret`
- `access_token`
- `refresh_token`

### 3. 主要接口域名

按公开 SDK 文档可确认的官方接口域名如下：

- `https://proapi.115.com`
- `https://passportapi.115.com`
- `https://qrcodeapi.115.com/get/status/`

补充说明：

- 一些第三方 SDK 文档把扫码授权接口写成 `qrcodeapi.115.com/open/...`。
- 官方 Go SDK 公布的常量仍以 `passportapi.115.com/open/...` 为主。
- 实际开发建议优先以官方语雀文档和你申请应用后的联调结果为准。

## 响应结构

普通开放接口在公开 SDK 中的通用返回结构如下：

```json
{
  "state": true,
  "code": 0,
  "message": "",
  "data": {}
}
```

令牌接口可确认的核心字段：

```json
{
  "access_token": "string",
  "refresh_token": "string",
  "expires_in": 0
}
```

## 授权方式

### 方式一：设备码扫码授权 + PKCE

这是最容易落地的接入方式，适合桌面端、CLI、服务端辅助授权页。

### 流程概览

1. 客户端生成 `code_verifier`
2. 根据 `code_verifier` 生成 `code_challenge`
3. 请求设备码和二维码
4. 用户使用 115 客户端扫码并确认
5. 轮询二维码状态
6. 用 `uid + code_verifier` 换取 `access_token` 和 `refresh_token`
7. 后续用 `refresh_token` 刷新令牌

### 1. 获取设备码

- 方法：`POST`
- 路径：`/open/authDeviceCode`
- 常见参数：
  - `client_id`
  - `code_challenge`
  - `code_challenge_method`

官方 Go SDK 可确认返回字段：

- `uid`
- `time`
- `qrcode`
- `sign`

其中：

- `qrcode` 可直接转成二维码图片给用户扫描。
- `uid/time/sign` 用于后续检查扫码状态。

### 2. 查询扫码状态

- 方法：`GET`
- 地址：`https://qrcodeapi.115.com/get/status/`
- 常见参数：
  - `uid`
  - `time`
  - `sign`

公开 SDK 可确认返回字段：

- `msg`
- `status`
- `version`

### 3. 设备码换 Token

- 方法：`POST`
- 路径：`/open/deviceCodeToToken`
- 常见参数：
  - `uid`
  - `code_verifier`

返回核心字段：

- `access_token`
- `refresh_token`
- `expires_in`

### 4. 刷新 Token

- 方法：`POST`
- 路径：`/open/refreshToken`
- 常见参数：
  - `refresh_token`

关键注意点：

- 刷新后通常会返回新的 `access_token` 和新的 `refresh_token`。
- 老的 `refresh_token` 失效，必须立刻覆盖本地存储。
- 公开社区资料和第三方 SDK 都提到刷新过于频繁会被限制。

### PKCE 备注

第三方 SDK 文档和公开社区讨论能确认这些约束：

- `code_verifier` 长度应在 `43` 到 `128` 之间。
- `code_challenge_method` 支持 `md5`、`sha1`、`sha256`。
- 实际接入建议优先使用 `sha256`。

示例：

```text
code_verifier -> SHA-256 -> base64 编码 -> code_challenge
```

### 方式二：授权码模式

如果你的应用有明确的回调地址，并且要按照标准 Web OAuth 流程接入，可以使用授权码模式。

### 1. 请求授权

- 方法：`GET`
- 路径：`/open/authorize`
- 常见参数：
  - `client_id`
  - `redirect_uri`
  - `response_type=code`
  - `state`

授权成功后，115 会重定向到你的 `redirect_uri`，并附带 `code`。

### 2. 用授权码换 Token

- 方法：`POST`
- 路径：`/open/authCodeToToken`
- 常见参数：
  - `client_id`
  - `client_secret`
  - `code`
  - `redirect_uri`
  - `grant_type=authorization_code`

### 3. 刷新 Token

与设备码模式一致，继续调用：

- `POST /open/refreshToken`

## 用户接口

### 获取用户信息

- 方法：`GET`
- 路径：`/open/user/info`

公开 SDK 可确认返回字段包括：

- `user_id`
- `user_name`
- `user_face_s`
- `user_face_m`
- `user_face_l`
- `rt_space_info`

其中 `rt_space_info` 下至少包含：

- `all_total`
- `all_remain`
- `all_use`

## 文件与目录接口

以下接口均来自官方 Go SDK 暴露出的常量与类型信息。

### 1. 创建目录

- 方法：`POST`
- 路径：`/open/folder/add`
- 常见参数：
  - `pid`
  - `filename`

响应中可确认字段：

- `file_name`
- `file_id`

### 2. 获取文件列表

- 方法：`GET`
- 路径：`/open/ufile/files`

可确认请求字段：

- `cid`
- `type`
- `limit`
- `offset`
- `suffix`
- `asc`
- `o`
- `custom_order`
- `stdir`
- `star`
- `cur`
- `show_dir`

字段含义摘录整理：

- `cid`: 目录 ID
- `limit` / `offset`: 分页参数
- `suffix`: 按后缀筛选
- `o`: 排序字段，可见值有 `file_name`、`file_size`、`user_utime`、`file_type`
- `stdir`: 筛选文件时是否显示文件夹
- `show_dir`: 是否展示目录

可确认响应信息：

- `count`
- `sys_count`
- `offset`
- `limit`
- `aid`
- `cid`

列表项中常见字段：

- `fid`: 文件 ID
- `pid`: 父目录 ID
- `fc`: `0` 文件夹，`1` 文件
- `fn`: 文件名
- `pc`: 提取码
- `sha1`
- `fs`: 文件大小
- `ico`: 后缀
- `thumb`: 缩略图
- `play_long`

### 3. 获取文件夹详情

- 方法：`GET`
- 路径：`/open/folder/get_info`
- 常见参数：
  - `file_id`

可确认响应字段：

- `count`
- `size`
- `folder_count`
- `ptime`
- `utime`
- `file_name`
- `pick_code`
- `sha1`
- `file_id`
- `file_category`
- `paths`

### 4. 搜索文件

- 方法：`GET`
- 路径：`/open/ufile/search`

可确认请求字段：

- `search_value`
- `limit`
- `offset`
- `file_label`
- `cid`
- `gte_day`
- `lte_day`
- `fc`

补充：

- `search_value` 是关键字。
- `gte_day` / `lte_day` 使用 `YYYY-MM-DD`。
- `fc=1` 只文件夹，`fc=2` 只文件。

### 5. 复制文件

- 方法：`POST`
- 路径：`/open/ufile/copy`

可确认请求字段：

- `pid`: 目标目录
- `file_id`: 多个文件或目录 ID 可用逗号分隔
- `no_dupli`: 目标目录是否允许重名

### 6. 移动文件

- 方法：`POST`
- 路径：`/open/ufile/move`

可确认请求字段：

- `file_ids`: 需要移动的文件或目录 ID
- `to_cid`: 目标目录 ID，根目录一般为 `0`

### 7. 获取下载地址

- 方法：`POST`
- 路径：`/open/ufile/downurl`

公开 SDK 暴露的调用参数：

- `pick_code`
- `ua`

返回数据中能确认的信息：

- `file_name`
- `file_size`
- `pick_code`
- `sha1`
- `url.url`

### 8. 更新文件信息

- 方法：`POST`
- 路径：`/open/ufile/update`

可确认请求字段：

- `file_id`
- `file_name`
- `star`

可用于：

- 重命名文件或目录
- 设置或取消星标

### 9. 删除文件

- 方法：`POST`
- 路径：`/open/ufile/delete`

可确认请求字段：

- `file_ids`
- `parent_id`

## 回收站接口

### 1. 回收站列表

- 方法：`GET`
- 路径：`/open/rb/list`
- 常见参数：
  - `limit`
  - `offset`

可确认返回字段：

- `offset`
- `limit`
- `count`
- `rb_pass`

列表项中常见字段：

- `id`
- `file_name`
- `file_size`
- `dtime`
- `thumb_url`
- `cid`
- `parent_name`
- `pick_code`
- `sha1`

### 2. 恢复回收站文件

- 方法：`POST`
- 路径：`/open/rb/revert`
- 常见参数：
  - `tid`

### 3. 彻底删除回收站文件

- 方法：`POST`
- 路径：`/open/rb/del`
- 常见参数：
  - `tid`

## 上传接口

公开 SDK 显示 115 开放平台上传流程至少拆成 3 步。

### 1. 获取上传凭证

- 方法：`GET`
- 路径：`/open/upload/get_token`

可确认返回字段：

- `endpoint`
- `AccessKeyId`
- `AccessKeySecret`
- `SecurityToken`
- `expiration`

这一步通常用于拿临时云存储凭证。

### 2. 初始化上传

- 方法：`POST`
- 路径：`/open/upload/init`

可确认请求字段：

- `file_name`
- `file_size`
- `target`
- `fileid`
- `preid`
- `pick_code`
- `topupload`
- `sign_key`
- `sign_val`

字段说明整理：

- `fileid`: 文件整体 `SHA1`
- `preid`: 文件前 `128KB` 的 `SHA1`
- `target`: 目标目录或目标定位串

可确认响应字段：

- `pick_code`
- `status`
- `sign_key`
- `sign_check`
- `file_id`
- `target`
- `bucket`
- `object`
- `callback`

补充：

- 第三方上传工具文档提到，如果响应里包含 `reuse=true`，通常表示秒传成功。
- 这一点来自第三方封装，不是当前文档能直接从官方页面抓到的原文。

### 3. 获取续传信息

- 方法：`POST`
- 路径：`/open/upload/resume`

可确认请求字段：

- `file_size`
- `target`
- `fileid`
- `pick_code`

可确认响应字段：

- `pick_code`
- `target`
- `version`
- `bucket`
- `object`
- `callback`

## 建议的接入顺序

如果你要自己实现一个最小可用客户端，建议按下面顺序联调：

1. 在 `open.115.com` 创建应用并确认 `client_id`
2. 先打通设备码扫码授权
3. 保存 `refresh_token`，并实现刷新后覆盖旧值
4. 验证 `GET /open/user/info`
5. 验证 `GET /open/ufile/files`
6. 验证 `POST /open/ufile/downurl`
7. 最后再接上传相关接口

## 实战注意点

- `refresh_token` 看起来是轮换式的，不要继续使用旧值。
- 下载接口依赖 `pick_code`，文件列表里需要把它缓存下来。
- 上传链路依赖 `SHA1` 和前 `128KB` 的 `SHA1`，实现前先封装本地哈希计算。
- 授权码模式对 `redirect_uri` 校验更严格，域名通常需要与应用配置一致。
- 如果应用出现鉴权失败，先检查：
  - `code_verifier` 是否和第一次生成 `code_challenge` 时严格一致
  - `refresh_token` 是否已经被刷新轮换
  - `redirect_uri` 是否和换 token 时完全一致

## 参考来源

官方来源：

- 115 官方开放文档入口：<https://www.yuque.com/115yun/open>
- 115 开放平台：<https://open.115.com>
- 官方文档对应的公开 Go SDK 索引页：<https://pkg.go.dev/github.com/xhofe/115-sdk-go>

辅助来源：

- p115client 客户端文档：<https://p115client.readthedocs.io/en/latest/reference/module/client.html>
- p115client 上传工具文档：<https://p115client.readthedocs.io/en/latest/reference/tool/upload.html>

## 后续可选补充

如果后面你要继续在这个仓库里落地调用代码，可以再补下面几项：

- 一份 115 Open 的 Dart 接口封装约定
- 一份扫码授权时序图
- 一份错误码对照表
- 一份最小可跑的 `curl` / Dart 示例
