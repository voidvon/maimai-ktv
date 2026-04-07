import 'package:flutter/material.dart';

import '../../media_library/data/baidu_pan/baidu_pan_models.dart';
import '../application/baidu_pan_settings_controller.dart';
import '../data/qr_image_save_data_source.dart';
import '../application/settings_controller.dart';

class SettingsPageResult {
  const SettingsPageResult({
    this.localDirectory,
    this.refreshAggregatedSources = false,
  });

  final String? localDirectory;
  final bool refreshAggregatedSources;
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    required this.baiduPanController,
  });

  final SettingsController controller;
  final BaiduPanSettingsController baiduPanController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0014),
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: <Widget>[
                const Text(
                  '管理当前点歌库的数据来源。已配置的数据源会用于扫描、检索和展示歌曲列表。',
                  style: TextStyle(height: 1.5),
                ),
                const SizedBox(height: 18),
                const Text(
                  '数据源',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: Listenable.merge(<Listenable>[
                    controller,
                    baiduPanController,
                  ]),
                  builder: (BuildContext context, _) {
                    final bool baiduPanReady =
                        baiduPanController.canRefreshRemoteFolder;
                    final String? baiduPanRootPath =
                        baiduPanController.rootPath;
                    return Column(
                      children: <Widget>[
                        _SettingsEntryCard(
                          title: '本地目录',
                          subtitle: controller.currentDirectoryPath == null
                              ? '未配置'
                              : '已配置',
                          icon: Icons.folder_open_rounded,
                          onTap: () async {
                            final SettingsPageResult? result =
                                await Navigator.of(
                                  context,
                                ).push<SettingsPageResult>(
                                  MaterialPageRoute<SettingsPageResult>(
                                    builder: (BuildContext context) {
                                      return _LocalDirectorySettingsPage(
                                        controller: controller,
                                      );
                                    },
                                  ),
                                );
                            if (!context.mounted || result == null) {
                              return;
                            }
                            Navigator.of(context).pop(result);
                          },
                        ),
                        const SizedBox(height: 14),
                        _SettingsEntryCard(
                          title: '百度网盘',
                          subtitle: baiduPanController.isLoading
                              ? '加载中'
                              : baiduPanReady
                              ? '已配置 $baiduPanRootPath'
                              : (baiduPanRootPath?.trim().isNotEmpty ?? false)
                              ? '未登录'
                              : '未配置',
                          icon: Icons.cloud_rounded,
                          onTap: () async {
                            final SettingsPageResult? result =
                                await Navigator.of(
                                  context,
                                ).push<SettingsPageResult>(
                                  MaterialPageRoute<SettingsPageResult>(
                                    builder: (BuildContext context) {
                                      return _BaiduPanSettingsPage(
                                        controller: baiduPanController,
                                      );
                                    },
                                  ),
                                );
                            if (!context.mounted || result == null) {
                              return;
                            }
                            Navigator.of(context).pop(result);
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocalDirectorySettingsPage extends StatelessWidget {
  const _LocalDirectorySettingsPage({required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0A0014),
          appBar: AppBar(
            title: const Text('本地目录'),
            backgroundColor: Colors.transparent,
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: <Widget>[
                    const Text(
                      '配置本地目录后，点歌页会基于这个目录建立扫描范围。重新选择后会覆盖当前使用的本地目录。',
                      style: TextStyle(height: 1.5),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F2FF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            '当前目录',
                            style: TextStyle(
                              color: Color(0xFF1D1230),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            controller.currentDirectoryPath ?? '当前还没有配置本地目录。',
                            style: const TextStyle(
                              color: Color(0xFF6B5D7C),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: controller.isPickingDirectory
                          ? null
                          : () async {
                              final String? directory = await controller
                                  .pickDirectory();
                              if (!context.mounted || directory == null) {
                                return;
                              }
                              Navigator.of(context).pop(
                                SettingsPageResult(localDirectory: directory),
                              );
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6E67),
                      ),
                      icon: const Icon(Icons.folder_open_rounded),
                      label: Text(
                        controller.isPickingDirectory ? '选择中' : '选择目录',
                      ),
                    ),
                    if (controller.errorMessage != null) ...<Widget>[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          controller.errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFF9C2F2F),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BaiduPanSettingsPage extends StatefulWidget {
  const _BaiduPanSettingsPage({required this.controller});

  final BaiduPanSettingsController controller;

  @override
  State<_BaiduPanSettingsPage> createState() => _BaiduPanSettingsPageState();
}

class _BaiduPanSettingsPageState extends State<_BaiduPanSettingsPage> {
  late final TextEditingController _rootPathController = TextEditingController(
    text: widget.controller.rootPath ?? '',
  );
  final QrImageSaveDataSource _qrImageSaveDataSource =
      const QrImageSaveDataSource();
  bool _isSavingQrImage = false;

  @override
  void initState() {
    super.initState();
    if (!widget.controller.isAuthorized && widget.controller.supportsQrLogin) {
      Future<void>.microtask(() {
        return widget.controller.ensureDeviceLoginSession();
      });
    }
  }

  @override
  void dispose() {
    _rootPathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, _) {
        final bool supportsQrLogin = widget.controller.supportsQrLogin;
        final bool canSaveQrImage = _qrImageSaveDataSource.isSupported;
        final bool canRefreshRemoteFolder =
            widget.controller.canRefreshRemoteFolder;
        final String? rootPath = widget.controller.rootPath;
        return Scaffold(
          backgroundColor: const Color(0xFF0A0014),
          appBar: AppBar(
            title: const Text('百度网盘'),
            backgroundColor: Colors.transparent,
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: <Widget>[
                    Text(
                      '百度网盘开放平台凭证已经内置到应用配置里。用户进入本页后，未登录时会自动拉起扫码登录二维码。登录后只需要配置歌曲根目录。',
                      style: TextStyle(height: 1.5),
                    ),
                    const SizedBox(height: 18),
                    _InfoCard(
                      title: '当前状态',
                      content: widget.controller.isLoading
                          ? '加载中'
                          : canRefreshRemoteFolder
                          ? '已配置，歌曲根目录：$rootPath'
                          : (rootPath?.trim().isNotEmpty ?? false)
                          ? '未登录，已保存歌曲根目录：$rootPath'
                          : '未配置百度网盘数据源',
                    ),
                    const SizedBox(height: 16),
                    _InfoCard(
                      title: '应用授权配置',
                      content:
                          'AppID: ${widget.controller.appId}\n'
                          'Redirect URI: ${widget.controller.redirectUri}\n'
                          'Scope: ${widget.controller.scope}\n'
                          '应用授权配置${widget.controller.isAppConfigured ? '已内置' : '缺失'}',
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0x14FFFFFF),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0x26FFFFFF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.controller.isAuthorized ? '登录已完成' : '扫码登录',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.controller.isAuthorized
                                ? '当前百度网盘账号已登录，可以继续配置歌曲根目录并扫描指定文件夹。'
                                : '进入页面后已自动生成二维码。请直接使用百度 App 扫码授权，授权完成后会自动登录。',
                            style: TextStyle(
                              color: Color(0xCCFFFFFF),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _InfoCard(
                      title: '登录状态',
                      content: widget.controller.isAuthorized
                          ? '已登录\n'
                                '账号：${widget.controller.accountDisplayName ?? '未知账号'}\n'
                                '容量：${widget.controller.quotaSummary ?? '未知'}\n'
                                'Token 过期时间：${widget.controller.tokenExpiresAt}'
                          : '未登录',
                    ),
                    const SizedBox(height: 16),
                    if (!widget.controller.isAuthorized &&
                        supportsQrLogin) ...<Widget>[
                      _BaiduPanQrCard(controller: widget.controller),
                      if (canSaveQrImage &&
                          widget.controller.deviceCodeSession !=
                              null) ...<Widget>[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _isSavingQrImage
                              ? null
                              : () async {
                                  await _saveCurrentQrCode(
                                    widget.controller.deviceCodeSession!,
                                  );
                                },
                          icon: Icon(
                            _isSavingQrImage
                                ? Icons.downloading_rounded
                                : Icons.download_rounded,
                          ),
                          label: Text(_isSavingQrImage ? '保存中' : '保存二维码到手机'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed:
                            widget.controller.isPreparingDeviceLogin ||
                                widget.controller.isLoading
                            ? null
                            : () async {
                                await widget.controller
                                    .ensureDeviceLoginSession(
                                      forceRefresh: true,
                                    );
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF4D88FF),
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(
                          widget.controller.isPreparingDeviceLogin
                              ? '生成中'
                              : '刷新二维码',
                        ),
                      ),
                    ] else if (widget.controller.isAuthorized) ...<Widget>[
                      OutlinedButton.icon(
                        onPressed: widget.controller.isLoggingIn
                            ? null
                            : () async {
                                await widget.controller.logout();
                                if (!context.mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('百度网盘已退出登录')),
                                );
                              },
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('退出登录'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _SettingsTextField(
                      controller: _rootPathController,
                      label: '歌曲根目录',
                      hintText: '例如 /KTV',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: widget.controller.isSaving
                                ? null
                                : () async {
                                    final bool saved = await widget.controller
                                        .saveSettings(
                                          rootPath: _rootPathController.text,
                                        );
                                    if (!context.mounted || !saved) {
                                      return;
                                    }
                                    if (widget
                                        .controller
                                        .canRefreshRemoteFolder) {
                                      Navigator.of(context).pop(
                                        const SettingsPageResult(
                                          refreshAggregatedSources: true,
                                        ),
                                      );
                                      return;
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('百度网盘目录已保存，登录后可扫描'),
                                      ),
                                    );
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6E67),
                            ),
                            icon: const Icon(Icons.save_rounded),
                            label: Text(
                              widget.controller.isSaving
                                  ? '保存中'
                                  : widget.controller.canRefreshRemoteFolder
                                  ? '保存并扫描该文件夹'
                                  : '保存目录',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: widget.controller.isSaving
                              ? null
                              : () async {
                                  await widget.controller.clearSettings();
                                  if (!context.mounted) {
                                    return;
                                  }
                                  _rootPathController.clear();
                                  Navigator.of(context).pop(
                                    const SettingsPageResult(
                                      refreshAggregatedSources: true,
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('清空'),
                        ),
                      ],
                    ),
                    if (widget.controller.errorMessage != null) ...<Widget>[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          widget.controller.errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFF9C2F2F),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveCurrentQrCode(BaiduPanDeviceCodeSession session) async {
    if (_isSavingQrImage) {
      return;
    }
    setState(() {
      _isSavingQrImage = true;
    });
    try {
      final String fileName =
          'baidu_pan_qr_${DateTime.now().millisecondsSinceEpoch}.png';
      await _qrImageSaveDataSource.saveQrImage(
        imageUrl: session.qrcodeUrl,
        fileName: fileName,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('二维码已保存到手机')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存二维码失败：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSavingQrImage = false;
        });
      }
    }
  }
}

class _BaiduPanQrCard extends StatelessWidget {
  const _BaiduPanQrCard({required this.controller});

  final BaiduPanSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final BaiduPanDeviceCodeSession? session = controller.deviceCodeSession;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '登录二维码',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (controller.isPreparingDeviceLogin || session == null)
            const SizedBox(
              height: 280,
              child: Center(child: CircularProgressIndicator()),
            )
          else ...<Widget>[
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Image.network(
                    session.qrcodeUrl,
                    width: 240,
                    height: 240,
                    fit: BoxFit.contain,
                    errorBuilder:
                        (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) {
                          return const SizedBox(
                            width: 240,
                            height: 240,
                            child: Center(
                              child: Text(
                                '二维码加载失败',
                                style: TextStyle(color: Colors.black54),
                              ),
                            ),
                          );
                        },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SelectableText(
              '用户码：${session.userCode}\n验证页：${session.verificationUrl}',
              style: const TextStyle(color: Color(0xCCFFFFFF), height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(color: Color(0xCCFFFFFF), height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _SettingsTextField extends StatelessWidget {
  const _SettingsTextField({
    required this.controller,
    required this.label,
    required this.hintText,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: const Color(0x14FFFFFF),
        labelStyle: const TextStyle(color: Color(0xCCFFFFFF)),
        hintStyle: const TextStyle(color: Color(0x88FFFFFF)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0x26FFFFFF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0x26FFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0x66FFFFFF)),
        ),
      ),
    );
  }
}

class _SettingsEntryCard extends StatelessWidget {
  const _SettingsEntryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x14FFFFFF),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0x1AFFFFFF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xCCFFFFFF),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Color(0xCCFFFFFF)),
            ],
          ),
        ),
      ),
    );
  }
}
