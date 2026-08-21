import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/localization/localization_extensions.dart';
import '../../../core/presentation/center_overlay_toast.dart';
import '../../ktv/application/download_manager_models.dart';
import '../../ktv/application/ktv_controller.dart';
import '../../media_library/data/baidu_pan/baidu_pan_models.dart';
import '../../media_library/data/cloud/cloud_playback_cache.dart';
import '../../update/application/update_controller.dart';
import '../../update/domain/update_check_result.dart';
import '../application/baidu_pan_settings_controller.dart';
import '../data/qr_image_save_data_source.dart';
import '../application/settings_controller.dart';
import '../application/webdav_settings_controller.dart';

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
    required this.webDavController,
    required this.ktvController,
    required this.updateController,
    required this.localeController,
  });

  final SettingsController controller;
  final BaiduPanSettingsController baiduPanController;
  final WebDavSettingsController webDavController;
  final KtvController ktvController;
  final UpdateController updateController;
  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0014),
      appBar: AppBar(
        title: Text(context.l10n.settings),
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
                  context.l10n.settingsDescription,
                  style: const TextStyle(height: 1.5),
                ),
                const SizedBox(height: 18),
                Text(
                  context.l10n.interfaceSection,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: localeController,
                  builder: (BuildContext context, _) {
                    return _SettingsEntryCard(
                      title: context.l10n.language,
                      subtitle: _localeLabel(context, localeController.locale),
                      icon: Icons.language_rounded,
                      onTap: () async {
                        await Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                _LanguageSettingsPage(
                                  controller: localeController,
                                ),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  context.l10n.dataSources,
                  style: const TextStyle(
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
                    webDavController,
                    ktvController,
                    updateController,
                  ]),
                  builder: (BuildContext context, _) {
                    final bool baiduPanReady =
                        baiduPanController.canRefreshRemoteFolder;
                    final bool webDavReady = webDavController.isConfigured;
                    final String? baiduPanRootPath =
                        baiduPanController.rootPath;
                    final int downloadingCount =
                        ktvController.downloadingSongs.length;
                    final int downloadedCount =
                        ktvController.downloadedSongs.length;
                    final UpdateController updateController =
                        this.updateController;
                    return Column(
                      children: <Widget>[
                        _SettingsEntryCard(
                          title: context.l10n.downloadManager,
                          subtitle: downloadingCount > 0
                              ? context.l10n.downloadSummary(
                                  downloadingCount,
                                  downloadedCount,
                                )
                              : downloadedCount > 0
                              ? context.l10n.downloadedSongsCount(
                                  downloadedCount,
                                )
                              : context.l10n.downloadManagerSubtitle,
                          icon: Icons.download_rounded,
                          onTap: () async {
                            await Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (BuildContext context) {
                                  return _DownloadManagerPage(
                                    controller: ktvController,
                                  );
                                },
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        _SettingsEntryCard(
                          title: 'WebDAV',
                          subtitle: webDavController.isLoading
                              ? context.l10n.loading
                              : webDavReady
                              ? context.l10n.configuredPath(
                                  webDavController.rootPath!,
                                )
                              : context.l10n.notConfigured,
                          icon: Icons.cloud_sync_rounded,
                          onTap: () async {
                            final SettingsPageResult? result =
                                await Navigator.of(
                                  context,
                                ).push<SettingsPageResult>(
                                  MaterialPageRoute<SettingsPageResult>(
                                    builder: (BuildContext context) {
                                      return _WebDavSettingsPage(
                                        controller: webDavController,
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
                          title: context.l10n.localDirectory,
                          subtitle: controller.currentDirectoryPath == null
                              ? context.l10n.notConfigured
                              : context.l10n.configured,
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
                          title: context.l10n.baiduNetdisk,
                          subtitle: baiduPanController.isLoading
                              ? context.l10n.loading
                              : baiduPanReady
                              ? context.l10n.configuredPath(baiduPanRootPath!)
                              : (baiduPanRootPath?.trim().isNotEmpty ?? false)
                              ? context.l10n.notSignedIn
                              : context.l10n.notConfigured,
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
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            context.l10n.other,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SettingsEntryCard(
                          title: context.l10n.checkForUpdates,
                          subtitle: updateController.summaryText,
                          icon: Icons.system_update_rounded,
                          onTap: () async {
                            await Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (BuildContext context) {
                                  return _UpdatePage(
                                    controller: updateController,
                                  );
                                },
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        _SettingsEntryCard(
                          title: context.l10n.aboutUs,
                          subtitle: context.l10n.aboutUsSubtitle,
                          icon: Icons.info_outline_rounded,
                          onTap: () async {
                            await Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (BuildContext context) {
                                  return _AboutPage(
                                    updateController: updateController,
                                  );
                                },
                              ),
                            );
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

String _localeLabel(BuildContext context, Locale? locale) {
  if (locale == null) {
    return context.l10n.followSystem;
  }
  if (locale == LocaleController.traditionalChinese) {
    return context.l10n.traditionalChinese;
  }
  if (locale == LocaleController.english) {
    return context.l10n.english;
  }
  return context.l10n.simplifiedChinese;
}

class _LanguageSettingsPage extends StatelessWidget {
  const _LanguageSettingsPage({required this.controller});

  final LocaleController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0014),
      appBar: AppBar(
        title: Text(context.l10n.language),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: AnimatedBuilder(
              animation: controller,
              builder: (BuildContext context, _) {
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: <Widget>[
                    Text(
                      context.l10n.languagePageDescription,
                      style: const TextStyle(height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    _LanguageOption(
                      label: context.l10n.followSystem,
                      selected: controller.followsSystem,
                      onTap: () => unawaited(controller.setLocale(null)),
                    ),
                    _LanguageOption(
                      label: context.l10n.simplifiedChinese,
                      selected:
                          controller.locale ==
                          LocaleController.simplifiedChinese,
                      onTap: () => unawaited(
                        controller.setLocale(
                          LocaleController.simplifiedChinese,
                        ),
                      ),
                    ),
                    _LanguageOption(
                      label: context.l10n.traditionalChinese,
                      selected:
                          controller.locale ==
                          LocaleController.traditionalChinese,
                      onTap: () => unawaited(
                        controller.setLocale(
                          LocaleController.traditionalChinese,
                        ),
                      ),
                    ),
                    _LanguageOption(
                      label: context.l10n.english,
                      selected: controller.locale == LocaleController.english,
                      onTap: () => unawaited(
                        controller.setLocale(LocaleController.english),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 56,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      title: Text(label),
      trailing: selected
          ? Icon(
              Icons.check_rounded,
              color: Theme.of(context).colorScheme.primary,
            )
          : const SizedBox(width: 24),
      onTap: onTap,
    );
  }
}

class _DownloadManagerPage extends StatelessWidget {
  const _DownloadManagerPage({required this.controller});

  final KtvController controller;

  String _buildDownloadTaskFooter(
    BuildContext context,
    DownloadingSongItem item,
  ) {
    final String statusLabel = switch (item.status) {
      DownloadTaskStatus.downloading => context.l10n.downloading,
      DownloadTaskStatus.paused => context.l10n.downloadPaused,
      DownloadTaskStatus.failed => context.l10n.downloadError,
    };
    final String errorSuffix = item.errorMessage?.trim().isNotEmpty ?? false
        ? ' · ${item.displayErrorMessage}'
        : '';
    return '$statusLabel · ${item.phaseLabel} · ${item.progressPercent}%$errorSuffix';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final List<DownloadingSongItem> downloadingSongs =
            controller.downloadingSongs;
        final List<DownloadedSongItem> downloadedSongs =
            controller.downloadedSongs;
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: const Color(0xFF0A0014),
            appBar: AppBar(
              title: Text(context.l10n.downloadManager),
              backgroundColor: Colors.transparent,
              bottom: TabBar(
                tabs: <Widget>[
                  Tab(
                    text: context.l10n.pendingDownloadsTab(
                      downloadingSongs.length,
                    ),
                  ),
                  Tab(text: context.l10n.downloadedTab(downloadedSongs.length)),
                ],
              ),
            ),
            body: TabBarView(
              children: <Widget>[
                _DownloadListView(
                  emptyMessage: context.l10n.noPendingDownloads,
                  children: downloadingSongs
                      .map(
                        (DownloadingSongItem item) => _DownloadListItem(
                          title: '${item.displayArtist}-${item.title}',
                          subtitle: '',
                          sourceLabel: item.sourceLabel,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (item.canResume)
                                IconButton(
                                  onPressed: () async {
                                    try {
                                      await controller.resumeDownload(
                                        sourceId: item.sourceId,
                                        sourceSongId: item.sourceSongId,
                                      );
                                      if (!context.mounted) {
                                        return;
                                      }
                                      CenterOverlayToast.showSuccess(
                                        context,
                                        message: context.l10n.downloadComplete,
                                      );
                                    } catch (error) {
                                      if (!context.mounted) {
                                        return;
                                      }
                                      if (error
                                              is CloudDownloadPausedException ||
                                          error
                                              is CloudDownloadCancelledException) {
                                        return;
                                      }
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            buildDownloadErrorSummary(
                                              error.toString(),
                                              fallback:
                                                  context.l10n.downloadFailed,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                  ),
                                  tooltip: context.l10n.resumeDownload,
                                ),
                              if (item.canPause)
                                IconButton(
                                  onPressed: () {
                                    controller.pauseDownload(
                                      sourceId: item.sourceId,
                                      sourceSongId: item.sourceSongId,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.pause_rounded,
                                    color: Colors.white,
                                  ),
                                  tooltip: context.l10n.pauseDownload,
                                ),
                              IconButton(
                                onPressed: () {
                                  controller.cancelDownload(
                                    sourceId: item.sourceId,
                                    sourceSongId: item.sourceSongId,
                                  );
                                },
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                ),
                                tooltip: context.l10n.cancelDownload,
                              ),
                            ],
                          ),
                          footer: _buildDownloadTaskFooter(context, item),
                          progress: item.progress,
                        ),
                      )
                      .toList(growable: false),
                ),
                _DownloadListView(
                  emptyMessage: context.l10n.noDownloadedSongs,
                  children: downloadedSongs
                      .map(
                        (DownloadedSongItem item) => _DownloadListItem(
                          title: '${item.displayArtist}-${item.displayTitle}',
                          subtitle: '',
                          sourceLabel: item.sourceLabel,
                          trailing: IconButton(
                            onPressed: () async {
                              final bool confirmed =
                                  await _confirmDeleteDownloadedSong(
                                    context,
                                    item,
                                  ) ??
                                  false;
                              if (!confirmed || !context.mounted) {
                                return;
                              }
                              await controller.deleteDownloadedSong(
                                sourceId: item.sourceId,
                                sourceSongId: item.sourceSongId,
                              );
                              if (!context.mounted) {
                                return;
                              }
                              CenterOverlayToast.showSuccess(
                                context,
                                message: context.l10n.deleted,
                              );
                            },
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Color(0xFFFF9B9B),
                            ),
                            tooltip: context.l10n.deleteSourceFile,
                          ),
                          footer: item.savedPath,
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool?> _confirmDeleteDownloadedSong(
    BuildContext context,
    DownloadedSongItem item,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF16081F),
          title: Text(
            context.l10n.deleteDownloadedFile,
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            context.l10n.deleteDownloadedFileMessage(
              item.displayTitle,
              item.sourceLabel,
            ),
            style: const TextStyle(color: Color(0xCCFFFFFF), height: 1.5),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF6E67),
              ),
              child: Text(context.l10n.delete),
            ),
          ],
        );
      },
    );
  }
}

class _AboutPage extends StatelessWidget {
  const _AboutPage({required this.updateController});

  static const String _opensourceUrl = 'https://github.com/voidvon/maimai-ktv';

  final UpdateController updateController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0014),
      appBar: AppBar(
        title: Text(context.l10n.aboutUs),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: <Widget>[
                AnimatedBuilder(
                  animation: updateController,
                  builder: (BuildContext context, _) {
                    return _InfoCard(
                      title: context.l10n.versionInformation,
                      content: _buildAboutVersionText(
                        context,
                        updateController,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                _InfoCard(
                  title: context.l10n.appIntroduction,
                  content: context.l10n.appDescription,
                ),
                const SizedBox(height: 14),
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
                        context.l10n.sourceCodeAddress,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const SelectableText(
                        _opensourceUrl,
                        style: TextStyle(color: Color(0xFFD8E5FF), height: 1.5),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await updateController.openReleasePage();
                                if (!context.mounted) {
                                  return;
                                }
                                final String? errorMessage =
                                    updateController.actionErrorMessage;
                                if (errorMessage == null) {
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(errorMessage)),
                                );
                              },
                              icon: const Icon(Icons.open_in_browser_rounded),
                              label: Text(context.l10n.viewReleasePage),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Color(0x33FFFFFF),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await Clipboard.setData(
                                  const ClipboardData(text: _opensourceUrl),
                                );
                                if (!context.mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      context.l10n.sourceCodeCopied,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy_rounded),
                              label: Text(context.l10n.copyAddress),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Color(0x33FFFFFF),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildAboutVersionText(
    BuildContext context,
    UpdateController controller,
  ) {
    final String currentVersion =
        controller.currentVersion?.fullValue ?? context.l10n.reading;
    final UpdateCheckResult? result = controller.lastResult;
    final String latestVersion =
        result?.updateInfo?.version.fullValue ?? context.l10n.notChecked;
    final String lastCheckedAt = controller.lastCheckedAt == null
        ? context.l10n.notChecked
        : _formatDateTime(controller.lastCheckedAt!);
    return context.l10n.versionSummary(
      currentVersion,
      latestVersion,
      lastCheckedAt,
    );
  }
}

class _UpdatePage extends StatelessWidget {
  const _UpdatePage({required this.controller});

  final UpdateController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final UpdateCheckResult? result = controller.lastResult;
        final String currentVersion =
            controller.currentVersion?.fullValue ?? context.l10n.reading;
        final String latestVersion =
            result?.updateInfo?.version.fullValue ?? context.l10n.notChecked;
        final String publishedAt = result?.updateInfo?.publishedAt == null
            ? context.l10n.unknown
            : _formatDateTime(result!.updateInfo!.publishedAt!);
        final List<String> notes =
            result?.updateInfo?.notes ?? const <String>[];
        return Scaffold(
          backgroundColor: const Color(0xFF0A0014),
          appBar: AppBar(
            title: Text(context.l10n.checkForUpdates),
            backgroundColor: Colors.transparent,
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: <Widget>[
                    _InfoCard(
                      title: context.l10n.currentStatus,
                      content: _buildUpdateSummary(
                        context: context,
                        controller: controller,
                        currentVersion: currentVersion,
                        latestVersion: latestVersion,
                        publishedAt: publishedAt,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _InfoCard(
                      title: context.l10n.releaseNotes,
                      content: notes.isEmpty
                          ? context.l10n.noReleaseNotes
                          : notes.join('\n'),
                    ),
                    if (controller.actionErrorMessage != null) ...<Widget>[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          controller.actionErrorMessage!,
                          style: const TextStyle(
                            color: Color(0xFF9C2F2F),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: controller.isBusy
                                ? null
                                : () async {
                                    await controller.checkForUpdates();
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6E67),
                            ),
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(
                              controller.isChecking
                                  ? context.l10n.checking
                                  : context.l10n.checkForUpdates,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: controller.isBusy
                                ? null
                                : () async {
                                    if (result?.isUpdateAvailable ?? false) {
                                      await controller.openUpdate();
                                    } else {
                                      await controller.openReleasePage();
                                    }
                                  },
                            icon: Icon(
                              result?.isUpdateAvailable ?? false
                                  ? Icons.system_update_alt_rounded
                                  : Icons.open_in_browser_rounded,
                            ),
                            label: Text(
                              result?.isUpdateAvailable ?? false
                                  ? context.l10n.updateNow
                                  : context.l10n.viewReleasePage,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _buildUpdateSummary({
    required BuildContext context,
    required UpdateController controller,
    required String currentVersion,
    required String latestVersion,
    required String publishedAt,
  }) {
    final UpdateCheckResult? result = controller.lastResult;
    final String statusLabel = switch (result?.state ?? UpdateCheckState.idle) {
      UpdateCheckState.idle => context.l10n.updateStatusIdle,
      UpdateCheckState.unavailable => context.l10n.updateStatusUnavailable,
      UpdateCheckState.upToDate => context.l10n.updateStatusCurrent,
      UpdateCheckState.updateAvailable => context.l10n.updateStatusAvailable,
      UpdateCheckState.failed => context.l10n.updateStatusFailed,
    };
    final String message = result?.message ?? context.l10n.updateInitialMessage;
    final String lastCheckedAt = controller.lastCheckedAt == null
        ? context.l10n.notChecked
        : _formatDateTime(controller.lastCheckedAt!);
    return context.l10n.updateSummary(
      statusLabel,
      currentVersion,
      latestVersion,
      publishedAt,
      lastCheckedAt,
      message,
    );
  }
}

String _formatDateTime(DateTime dateTime) {
  final DateTime localDateTime = dateTime.toLocal();
  final String month = localDateTime.month.toString().padLeft(2, '0');
  final String day = localDateTime.day.toString().padLeft(2, '0');
  final String hour = localDateTime.hour.toString().padLeft(2, '0');
  final String minute = localDateTime.minute.toString().padLeft(2, '0');
  return '${localDateTime.year}-$month-$day $hour:$minute';
}

class _LocalDirectorySettingsPage extends StatefulWidget {
  const _LocalDirectorySettingsPage({required this.controller});

  final SettingsController controller;

  @override
  State<_LocalDirectorySettingsPage> createState() =>
      _LocalDirectorySettingsPageState();
}

class _LocalDirectorySettingsPageState
    extends State<_LocalDirectorySettingsPage>
    with WidgetsBindingObserver {
  Timer? _selectionRecoveryTimer;
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  SettingsController get controller => widget.controller;

  bool get _usesImportedLocalLibrary =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _selectionRecoveryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final AppLifecycleState previousState = _appLifecycleState;
    _appLifecycleState = state;
    if (state != AppLifecycleState.resumed ||
        !_isBackgroundLifecycle(previousState) ||
        !_usesImportedLocalLibrary) {
      return;
    }
    _selectionRecoveryTimer?.cancel();
    _selectionRecoveryTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) {
        return;
      }
      controller.recoverStuckDirectorySelection();
    });
  }

  bool _isBackgroundLifecycle(AppLifecycleState state) {
    return state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, _) {
        final String pageTitle = _usesImportedLocalLibrary
            ? context.l10n.localFiles
            : context.l10n.localDirectory;
        final String introText = _usesImportedLocalLibrary
            ? context.l10n.iosLocalFilesDescription
            : context.l10n.localDirectoryDescription;
        final String currentPathTitle = _usesImportedLocalLibrary
            ? context.l10n.appLibraryDirectory
            : context.l10n.currentDirectory;
        final String emptyPathText = _usesImportedLocalLibrary
            ? context.l10n.noImportedVideos
            : context.l10n.noConfiguredDirectory;
        final IconData actionIcon = _usesImportedLocalLibrary
            ? Icons.file_upload_rounded
            : Icons.folder_open_rounded;
        final String actionLabel = controller.isImportingDirectory
            ? context.l10n.importing
            : controller.isSelectingDirectory
            ? context.l10n.selecting
            : (_usesImportedLocalLibrary
                  ? context.l10n.importFiles
                  : context.l10n.selectDirectory);
        return Scaffold(
          backgroundColor: const Color(0xFF0A0014),
          appBar: AppBar(
            title: Text(pageTitle),
            backgroundColor: Colors.transparent,
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: <Widget>[
                    Text(introText, style: const TextStyle(height: 1.5)),
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
                          Text(
                            currentPathTitle,
                            style: const TextStyle(
                              color: Color(0xFF1D1230),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            controller.currentDirectoryPath ?? emptyPathText,
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
                      icon: Icon(actionIcon),
                      label: Text(actionLabel),
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

class _WebDavSettingsPage extends StatefulWidget {
  const _WebDavSettingsPage({required this.controller});

  final WebDavSettingsController controller;

  @override
  State<_WebDavSettingsPage> createState() => _WebDavSettingsPageState();
}

class _WebDavSettingsPageState extends State<_WebDavSettingsPage> {
  late final TextEditingController _serverController = TextEditingController(
    text: widget.controller.serverUrl ?? '',
  );
  late final TextEditingController _usernameController = TextEditingController(
    text: widget.controller.username ?? '',
  );
  final TextEditingController _passwordController = TextEditingController();
  late final TextEditingController _rootController = TextEditingController(
    text: widget.controller.rootPath ?? '/',
  );
  bool _obscurePassword = true;

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _rootController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, _) {
        final bool busy =
            widget.controller.isLoading ||
            widget.controller.isSaving ||
            widget.controller.isTesting;
        return Scaffold(
          backgroundColor: const Color(0xFF0A0014),
          appBar: AppBar(
            title: const Text('WebDAV'),
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
                      context.l10n.webDavDescription,
                      style: const TextStyle(height: 1.5),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _serverController,
                      enabled: !busy,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: context.l10n.serverAddress,
                        hintText:
                            'https://dav.example.com/remote.php/dav/files/user',
                        prefixIcon: const Icon(Icons.dns_rounded),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _usernameController,
                      enabled: !busy,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: context.l10n.username,
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordController,
                      enabled: !busy,
                      obscureText: _obscurePassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: widget.controller.hasPassword
                            ? context.l10n.passwordKeepHint
                            : context.l10n.password,
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? context.l10n.showPassword
                              : context.l10n.hidePassword,
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _rootController,
                      enabled: !busy,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: context.l10n.songRootDirectory,
                        hintText: '/KTV',
                        prefixIcon: const Icon(Icons.folder_open_rounded),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: busy ? null : _testConnection,
                            icon: widget.controller.isTesting
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.cable_rounded),
                            label: Text(
                              widget.controller.isTesting
                                  ? context.l10n.testing
                                  : context.l10n.testConnection,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: busy ? null : _saveAndScan,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6E67),
                            ),
                            icon: const Icon(Icons.save_rounded),
                            label: Text(
                              widget.controller.isSaving
                                  ? context.l10n.saving
                                  : context.l10n.saveAndScan,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.controller.isConfigured) ...<Widget>[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: busy ? null : _clearSettings,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: Text(context.l10n.clearWebDavConfiguration),
                      ),
                    ],
                    if (widget.controller.successMessage != null) ...<Widget>[
                      const SizedBox(height: 14),
                      _WebDavStatusMessage(
                        message: widget.controller.successMessage!,
                        isError: false,
                      ),
                    ],
                    if (widget.controller.errorMessage != null) ...<Widget>[
                      const SizedBox(height: 14),
                      _WebDavStatusMessage(
                        message: widget.controller.errorMessage!,
                        isError: true,
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

  Future<void> _testConnection() async {
    await widget.controller.testConnection(
      serverUrl: _serverController.text,
      username: _usernameController.text,
      password: _passwordController.text,
      rootPath: _rootController.text,
    );
  }

  Future<void> _saveAndScan() async {
    final bool saved = await widget.controller.saveSettings(
      serverUrl: _serverController.text,
      username: _usernameController.text,
      password: _passwordController.text,
      rootPath: _rootController.text,
    );
    if (!saved || !mounted) {
      return;
    }
    Navigator.of(
      context,
    ).pop(const SettingsPageResult(refreshAggregatedSources: true));
  }

  Future<void> _clearSettings() async {
    await widget.controller.clearSettings();
    if (!mounted) {
      return;
    }
    _serverController.clear();
    _usernameController.clear();
    _passwordController.clear();
    _rootController.text = '/';
    Navigator.of(
      context,
    ).pop(const SettingsPageResult(refreshAggregatedSources: true));
  }
}

class _WebDavStatusMessage extends StatelessWidget {
  const _WebDavStatusMessage({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFF1F1) : const Color(0xFFEAF8F0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isError ? const Color(0xFF9C2F2F) : const Color(0xFF176B43),
          height: 1.5,
        ),
      ),
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
            title: Text(context.l10n.baiduNetdisk),
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
                      context.l10n.baiduDescription,
                      style: const TextStyle(height: 1.5),
                    ),
                    const SizedBox(height: 18),
                    _InfoCard(
                      title: context.l10n.currentStatus,
                      content: widget.controller.isLoading
                          ? context.l10n.loading
                          : canRefreshRemoteFolder
                          ? context.l10n.configuredSongRoot(rootPath!)
                          : (rootPath?.trim().isNotEmpty ?? false)
                          ? context.l10n.savedRootNotSignedIn(rootPath!)
                          : context.l10n.baiduNotConfigured,
                    ),
                    const SizedBox(height: 16),
                    _InfoCard(
                      title: context.l10n.appAuthorizationConfiguration,
                      content:
                          'AppID: ${widget.controller.appId}\n'
                          'Redirect URI: ${widget.controller.redirectUri}\n'
                          'Scope: ${widget.controller.scope}\n'
                          '${widget.controller.isAppConfigured ? context.l10n.authorizationEmbedded : context.l10n.authorizationMissing}',
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
                            widget.controller.isAuthorized
                                ? context.l10n.loginComplete
                                : context.l10n.scanToLogin,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.controller.isAuthorized
                                ? context.l10n.baiduAuthorizedDescription
                                : context.l10n.baiduQrDescription,
                            style: const TextStyle(
                              color: Color(0xCCFFFFFF),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _InfoCard(
                      title: context.l10n.loginStatus,
                      content: widget.controller.isAuthorized
                          ? context.l10n.signedInDetails(
                              widget.controller.accountDisplayName ??
                                  context.l10n.unknownAccount,
                              widget.controller.quotaSummary ??
                                  context.l10n.unknown,
                              widget.controller.tokenExpiresAt.toString(),
                            )
                          : context.l10n.notSignedIn,
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
                                  await _saveCurrentQrCode();
                                },
                          icon: Icon(
                            _isSavingQrImage
                                ? Icons.downloading_rounded
                                : Icons.download_rounded,
                          ),
                          label: Text(
                            _isSavingQrImage
                                ? context.l10n.saving
                                : context.l10n.saveQrToPhone,
                          ),
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
                              ? context.l10n.generating
                              : context.l10n.refreshQrCode,
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
                                CenterOverlayToast.showSuccess(
                                  context,
                                  message: context.l10n.signedOut,
                                );
                              },
                        icon: const Icon(Icons.logout_rounded),
                        label: Text(context.l10n.signOut),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _SettingsTextField(
                      controller: _rootPathController,
                      label: context.l10n.songRootDirectory,
                      hintText: context.l10n.rootPathExample,
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
                                    CenterOverlayToast.showSuccess(
                                      context,
                                      message: context.l10n.directorySaved,
                                    );
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6E67),
                            ),
                            icon: const Icon(Icons.save_rounded),
                            label: Text(
                              widget.controller.isSaving
                                  ? context.l10n.saving
                                  : widget.controller.canRefreshRemoteFolder
                                  ? context.l10n.saveAndScanFolder
                                  : context.l10n.saveDirectory,
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
                          label: Text(context.l10n.clear),
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

  Future<void> _saveCurrentQrCode() async {
    if (_isSavingQrImage) {
      return;
    }
    setState(() {
      _isSavingQrImage = true;
    });
    try {
      final String fileName =
          'baidu_pan_qr_${DateTime.now().millisecondsSinceEpoch}.png';
      final BaiduPanDeviceCodeSession? session =
          widget.controller.deviceCodeSession;
      if (session == null) {
        throw StateError('二维码会话不存在，请先刷新二维码');
      }
      final Uint8List bytes = await _readCurrentQrCodeBytes(session.qrcodeUrl);
      await _qrImageSaveDataSource.saveQrImageBytes(
        bytes: bytes,
        fileName: fileName,
      );
      if (!mounted) {
        return;
      }
      CenterOverlayToast.showSuccess(context, message: context.l10n.saved);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.saveQrFailed(error))));
    } finally {
      if (mounted) {
        setState(() {
          _isSavingQrImage = false;
        });
      }
    }
  }

  Future<Uint8List> _readCurrentQrCodeBytes(String imageUrl) async {
    final ImageConfiguration configuration = createLocalImageConfiguration(
      context,
    );
    final ImageStream stream = NetworkImage(imageUrl).resolve(configuration);
    final ui.Image image = await _waitForImage(stream);
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (byteData == null) {
      throw StateError('无法导出二维码图片');
    }
    return byteData.buffer.asUint8List();
  }

  Future<ui.Image> _waitForImage(ImageStream stream) {
    final Completer<ui.Image> completer = Completer<ui.Image>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        stream.removeListener(listener);
        completer.complete(info.image);
      },
      onError: (Object error, StackTrace? stackTrace) {
        stream.removeListener(listener);
        completer.completeError(error, stackTrace);
      },
    );
    stream.addListener(listener);
    return completer.future;
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
          Text(
            context.l10n.loginQrCode,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
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
                          return SizedBox(
                            width: 240,
                            height: 240,
                            child: Center(
                              child: Text(
                                context.l10n.qrCodeLoadFailed,
                                style: const TextStyle(color: Colors.black54),
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
              context.l10n.qrCodeDetails(
                session.userCode,
                session.verificationUrl,
              ),
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

class _DownloadListView extends StatelessWidget {
  const _DownloadListView({required this.emptyMessage, required this.children});

  final String emptyMessage;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyMessage,
            style: const TextStyle(color: Color(0xCCFFFFFF), height: 1.5),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: children.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: 14),
      itemBuilder: (BuildContext context, int index) => children[index],
    );
  }
}

class _DownloadListItem extends StatelessWidget {
  const _DownloadListItem({
    required this.title,
    required this.subtitle,
    required this.sourceLabel,
    required this.footer,
    required this.trailing,
    this.progress,
  });

  final String title;
  final String subtitle;
  final String sourceLabel;
  final String footer;
  final Widget trailing;
  final double? progress;

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x1A4D88FF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x334D88FF)),
                  ),
                  child: Text(
                    context.l10n.sourceLabel(sourceLabel),
                    style: const TextStyle(
                      color: Color(0xFFD8E5FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  footer,
                  style: const TextStyle(color: Color(0x99FFFFFF), height: 1.4),
                ),
                if (progress != null) ...<Widget>[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: const Color(0x1AFFFFFF),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF4D88FF),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Padding(padding: const EdgeInsets.only(top: 4), child: trailing),
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
