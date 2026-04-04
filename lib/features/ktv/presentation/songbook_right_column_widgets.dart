import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ktv2/ktv2.dart';

import '../../../core/models/artist.dart';
import '../../../core/models/song.dart';

class SongBookActionRow extends StatelessWidget {
  const SongBookActionRow({
    super.key,
    required this.controller,
    required this.queueCount,
    required this.compact,
    required this.onQueuePressed,
    required this.onSettingsPressed,
    required this.onToggleAudioMode,
    required this.onTogglePlayback,
    required this.onRestartPlayback,
    required this.onSkipSong,
  });

  final PlayerController controller;
  final int queueCount;
  final bool compact;
  final VoidCallback? onQueuePressed;
  final VoidCallback onSettingsPressed;
  final VoidCallback onToggleAudioMode;
  final VoidCallback onTogglePlayback;
  final VoidCallback onRestartPlayback;
  final VoidCallback onSkipSong;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        return Align(
          alignment: compact ? Alignment.centerLeft : Alignment.centerRight,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ActionPill(
                  label: '已点$queueCount',
                  icon: Icons.queue_music_rounded,
                  onPressed: onQueuePressed,
                ),
                const SizedBox(width: 4),
                ActionPill(
                  label:
                      controller.audioOutputMode ==
                          AudioOutputMode.accompaniment
                      ? '原唱'
                      : '伴唱',
                  icon: Icons.mic_rounded,
                  onPressed: controller.hasMedia ? onToggleAudioMode : null,
                ),
                const SizedBox(width: 4),
                ActionPill(
                  label: '切歌',
                  icon: Icons.skip_next_rounded,
                  onPressed: controller.hasMedia || queueCount > 0
                      ? onSkipSong
                      : null,
                ),
                const SizedBox(width: 4),
                ActionPill(
                  label: controller.isPlaying ? '暂停' : '播放',
                  icon: controller.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  onPressed: controller.hasMedia ? onTogglePlayback : null,
                ),
                const SizedBox(width: 4),
                ActionPill(
                  label: '重唱',
                  icon: Icons.replay_rounded,
                  onPressed: controller.hasMedia ? onRestartPlayback : null,
                ),
                const SizedBox(width: 4),
                ActionPill(
                  label: '设置',
                  icon: Icons.settings_rounded,
                  onPressed: onSettingsPressed,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ActionPill extends StatelessWidget {
  const ActionPill({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null;
    return Material(
      color: isEnabled ? const Color(0x1AFFFFFF) : const Color(0x0DFFFFFF),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isEnabled ? onPressed : null,
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(
                  icon,
                  size: 12,
                  color: isEnabled
                      ? const Color(0xCCFFF7FF)
                      : const Color(0x7AFFF7FF),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isEnabled
                      ? const Color(0xCCFFF7FF)
                      : const Color(0x7AFFF7FF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.isCurrent,
    required this.isQueued,
    required this.isFavorite,
    this.onToggleFavorite,
    this.onTap,
  });

  final Song song;
  final bool isCurrent;
  final bool isQueued;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = isCurrent
        ? const Color(0x29FFFFFF)
        : isQueued
        ? const Color(0x12FFFFFF)
        : const Color(0x1AFFFFFF);
    final Color subtitleColor = isCurrent
        ? const Color(0xCCF3DAFF)
        : isQueued
        ? const Color(0x80F3DAFF)
        : const Color(0xB8F3DAFF);

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool useCompactLayout = constraints.maxHeight < 42;
            final double horizontalPadding = useCompactLayout ? 10 : 12;
            final double verticalPadding = useCompactLayout ? 4 : 6;
            final double titleFontSize = useCompactLayout ? 11 : 12;
            final double subtitleFontSize = useCompactLayout ? 8 : 9;
            final double textGap = useCompactLayout ? 2 : 4;
            final double trailingGap = useCompactLayout ? 6 : 8;
            final double actionSize = useCompactLayout ? 24 : 28;
            final double actionIconSize = useCompactLayout ? 14 : 16;

            return Container(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                verticalPadding,
                useCompactLayout ? 8 : 10,
                verticalPadding,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x1AFFFFFF)),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                            color: isQueued
                                ? const Color(0xA6FFF7FF)
                                : const Color(0xEDFFF7FF),
                          ),
                        ),
                        SizedBox(height: textGap),
                        Text(
                          isCurrent
                              ? '${song.artist} · ${song.language} · 当前播放'
                              : isQueued
                              ? '${song.artist} · ${song.language} · 已点'
                              : '${song.artist} · ${song.language}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: subtitleFontSize,
                            fontWeight: FontWeight.w500,
                            height: 1.1,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: trailingGap),
                  Material(
                    color: const Color(0x12FFFFFF),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onToggleFavorite,
                      child: SizedBox(
                        width: actionSize,
                        height: actionSize,
                        child: Icon(
                          isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: actionIconSize,
                          color: isFavorite
                              ? const Color(0xFFFF7AA2)
                              : const Color(0xB8F3DAFF),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class ArtistTile extends StatelessWidget {
  const ArtistTile({super.key, required this.artist, this.onTap});

  final Artist artist;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final String badgeLabel = artist.songCount.toString();
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool useCompactLayout =
                constraints.maxHeight < 88 || constraints.maxWidth < 128;
            final double horizontalPadding = useCompactLayout ? 2 : 6;
            final double verticalPadding = useCompactLayout ? 1 : 4;
            final double availableWidth = math.max(
              0,
              constraints.maxWidth - (horizontalPadding * 2),
            );
            final double nameFontSize = useCompactLayout ? 12 : 13;
            final double nameGap = useCompactLayout ? 6 : 10;
            final double nameHeight = nameFontSize * 1.12;
            final double availableAvatarHeight = math.max(
              0,
              constraints.maxHeight -
                  (verticalPadding * 2) -
                  nameGap -
                  nameHeight,
            );
            final double avatarSize = math.min(
              (availableWidth * 0.66).clamp(
                useCompactLayout ? 24.0 : 30.0,
                useCompactLayout ? 42.0 : 52.0,
              ),
              (availableAvatarHeight * 0.72).clamp(
                useCompactLayout ? 24.0 : 30.0,
                useCompactLayout ? 42.0 : 52.0,
              ),
            );
            final double avatarLabelFontSize = (avatarSize * 0.32).clamp(
              useCompactLayout ? 8.5 : 10.5,
              useCompactLayout ? 10.5 : 13,
            );
            final double badgeFontSize = (avatarSize * 0.24).clamp(
              useCompactLayout ? 7.5 : 8.5,
              useCompactLayout ? 9.0 : 10.5,
            );
            final double badgeHorizontalPadding = (avatarSize * 0.14).clamp(
              4.0,
              6.0,
            );
            final double badgeVerticalPadding = (avatarSize * 0.05).clamp(
              1.5,
              2.5,
            );
            final Widget avatar = Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[Color(0xFF8BC4FF), Color(0xFF7562FF)],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    artist.avatarLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: avatarLabelFontSize,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                Positioned(
                  right: useCompactLayout ? -6 : -4,
                  bottom: useCompactLayout ? -4 : -2,
                  child: Container(
                    constraints: BoxConstraints(
                      minWidth: badgeFontSize + (badgeHorizontalPadding * 2),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: badgeHorizontalPadding,
                      vertical: badgeVerticalPadding,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8A63),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xCCFFF7FF),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      badgeLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: badgeFontSize,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ],
            );

            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  avatar,
                  SizedBox(height: nameGap),
                  Text(
                    artist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: nameFontSize,
                      fontWeight: FontWeight.w700,
                      height: 1.05,
                      color: const Color(0xEDFFF7FF),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class EmptyContentCard extends StatelessWidget {
  const EmptyContentCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xCCF3DAFF), height: 1.5),
      ),
    );
  }
}

class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    this.onPrevious,
    this.onNext,
  });

  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: <Widget>[
          _PaginationButton(label: '上一页', onPressed: onPrevious),
          Text(
            '$currentPage/$totalPages',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xCCFFF2FF),
            ),
          ),
          _PaginationButton(label: '下一页', onPressed: onNext),
        ],
      ),
    );
  }
}

class _PaginationButton extends StatelessWidget {
  const _PaginationButton({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return Material(
      color: enabled ? const Color(0x16FFFFFF) : const Color(0x0DFFFFFF),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: enabled
                  ? const Color(0xCCFFF2FF)
                  : const Color(0x7AFFF2FF),
            ),
          ),
        ),
      ),
    );
  }
}
