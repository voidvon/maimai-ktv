part of 'ktv_demo_shell.dart';

class _SongBookPage extends StatelessWidget {
  const _SongBookPage({
    super.key,
    required this.controller,
    required this.searchController,
    required this.selectedLanguage,
    required this.songs,
    required this.hasConfiguredDirectory,
    required this.isScanningLibrary,
    required this.libraryScanErrorMessage,
    required this.queuedSongs,
    required this.onBackPressed,
    required this.onLanguageSelected,
    required this.onAppendSearchToken,
    required this.onRemoveSearchCharacter,
    required this.onClearSearch,
    required this.onPlaySong,
    required this.onSettingsPressed,
    required this.onToggleAudioMode,
    required this.onTogglePlayback,
    required this.onRestartPlayback,
  });

  final PlayerController controller;
  final TextEditingController searchController;
  final String selectedLanguage;
  final List<DemoSong> songs;
  final bool hasConfiguredDirectory;
  final bool isScanningLibrary;
  final String? libraryScanErrorMessage;
  final List<DemoSong> queuedSongs;
  final VoidCallback onBackPressed;
  final ValueChanged<String> onLanguageSelected;
  final ValueChanged<String> onAppendSearchToken;
  final VoidCallback onRemoveSearchCharacter;
  final VoidCallback onClearSearch;
  final ValueChanged<DemoSong> onPlaySong;
  final VoidCallback onSettingsPressed;
  final VoidCallback onToggleAudioMode;
  final VoidCallback onTogglePlayback;
  final VoidCallback onRestartPlayback;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 860;
        final bool showLetterKeyboard =
            MediaQuery.orientationOf(context) == Orientation.landscape;
        final Widget content = _GradientShell(
          padding: compact
              ? const EdgeInsets.all(18)
              : const EdgeInsets.fromLTRB(56, 22, 28, 18),
          compact: compact,
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _SongBookLeftColumn(
                      controller: controller,
                      searchController: searchController,
                      compact: true,
                      showLetterKeyboard: showLetterKeyboard,
                      onAppendSearchToken: onAppendSearchToken,
                      onRemoveSearchCharacter: onRemoveSearchCharacter,
                      onClearSearch: onClearSearch,
                    ),
                    const SizedBox(height: 20),
                    _SongBookRightColumn(
                      controller: controller,
                      compact: true,
                      selectedLanguage: selectedLanguage,
                      songs: songs,
                      hasConfiguredDirectory: hasConfiguredDirectory,
                      isScanningLibrary: isScanningLibrary,
                      libraryScanErrorMessage: libraryScanErrorMessage,
                      queuedSongs: queuedSongs,
                      onBackPressed: onBackPressed,
                      onLanguageSelected: onLanguageSelected,
                      onPlaySong: onPlaySong,
                      onSettingsPressed: onSettingsPressed,
                      onToggleAudioMode: onToggleAudioMode,
                      onTogglePlayback: onTogglePlayback,
                      onRestartPlayback: onRestartPlayback,
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      width: 304,
                      child: _SongBookLeftColumn(
                        controller: controller,
                        searchController: searchController,
                        showLetterKeyboard: showLetterKeyboard,
                        onAppendSearchToken: onAppendSearchToken,
                        onRemoveSearchCharacter: onRemoveSearchCharacter,
                        onClearSearch: onClearSearch,
                      ),
                    ),
                    const SizedBox(width: 28),
                    Expanded(
                      child: _SongBookRightColumn(
                        controller: controller,
                        selectedLanguage: selectedLanguage,
                        songs: songs,
                        hasConfiguredDirectory: hasConfiguredDirectory,
                        isScanningLibrary: isScanningLibrary,
                        libraryScanErrorMessage: libraryScanErrorMessage,
                        queuedSongs: queuedSongs,
                        onBackPressed: onBackPressed,
                        onLanguageSelected: onLanguageSelected,
                        onPlaySong: onPlaySong,
                        onSettingsPressed: onSettingsPressed,
                        onToggleAudioMode: onToggleAudioMode,
                        onTogglePlayback: onTogglePlayback,
                        onRestartPlayback: onRestartPlayback,
                      ),
                    ),
                  ],
                ),
        );

        if (compact) {
          return content;
        }

        return AspectRatio(aspectRatio: 852 / 393, child: content);
      },
    );
  }
}

class _SongBookLeftColumn extends StatelessWidget {
  const _SongBookLeftColumn({
    required this.controller,
    required this.searchController,
    required this.showLetterKeyboard,
    required this.onAppendSearchToken,
    required this.onRemoveSearchCharacter,
    required this.onClearSearch,
    this.compact = false,
  });

  final PlayerController controller;
  final TextEditingController searchController;
  final bool showLetterKeyboard;
  final ValueChanged<String> onAppendSearchToken;
  final VoidCallback onRemoveSearchCharacter;
  final VoidCallback onClearSearch;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(height: compact ? 6 : 10),
        _SongPreviewCard(controller: controller, compact: compact),
        SizedBox(height: compact ? 4 : 6),
        _SongBookSearchField(
          controller: searchController,
          enableSystemKeyboard: !showLetterKeyboard,
          onBackspacePressed: onRemoveSearchCharacter,
          onClearPressed: onClearSearch,
        ),
        if (showLetterKeyboard) ...<Widget>[
          SizedBox(height: compact ? 6 : 8),
          _LetterKeyboard(onKeyPressed: onAppendSearchToken),
        ],
      ],
    );
  }
}

class _SongPreviewCard extends StatelessWidget {
  const _SongPreviewCard({required this.controller, required this.compact});

  final PlayerController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(compact ? 12 : 4),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0x87111111)),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x870A001E),
                            blurRadius: 18,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: KtvPlayerView(
                        controller: controller,
                        backgroundColor: const Color(0xFF090013),
                        placeholder: const _SongPreviewPlaceholder(),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0x1FFFFFFF),
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                        child: const Text(
                          '等待点唱',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),
            _PlayerProgressTrack(
              controller: controller,
              thickness: 6,
              barHeight: 8,
            ),
          ],
        );
      },
    );
  }
}

class _SongPreviewPlaceholder extends StatelessWidget {
  const _SongPreviewPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF1C0634), Color(0xFF120520)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.queue_music_rounded,
          size: 44,
          color: Color(0x99FFFFFF),
        ),
      ),
    );
  }
}

class _SongBookSearchField extends StatelessWidget {
  const _SongBookSearchField({
    required this.controller,
    required this.enableSystemKeyboard,
    required this.onBackspacePressed,
    required this.onClearPressed,
  });

  final TextEditingController controller;
  final bool enableSystemKeyboard;
  final VoidCallback onBackspacePressed;
  final VoidCallback onClearPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0x24FFFFFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(width: 10),
          const Icon(Icons.search_rounded, size: 14, color: Color(0xCCFFF2FF)),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: !enableSystemKeyboard,
              showCursor: enableSystemKeyboard,
              enableInteractiveSelection: enableSystemKeyboard,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFFF7FF),
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '输入歌名 / 中文 / 拼音首字母',
                hintStyle: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0x99F2DFFF),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onBackspacePressed,
            splashRadius: 14,
            iconSize: 14,
            color: const Color(0xCCFFF2FF),
            icon: const Icon(Icons.backspace_outlined),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Material(
              color: const Color(0x24FFFFFF),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onClearPressed,
                child: const SizedBox(
                  width: 16,
                  height: 16,
                  child: Icon(
                    Icons.close_rounded,
                    size: 10,
                    color: Color(0xCCFFF2FF),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LetterKeyboard extends StatelessWidget {
  const _LetterKeyboard({required this.onKeyPressed});

  final ValueChanged<String> onKeyPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _letterKeyboardRows
          .map((List<String> row) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: row == _letterKeyboardRows.last ? 0 : 6,
              ),
              child: Row(
                children: row
                    .map((String key) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: key == row.last ? 0 : 6,
                          ),
                          child: _KeyboardKey(
                            label: key,
                            onPressed: () => onKeyPressed(key.toLowerCase()),
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _KeyboardKey extends StatelessWidget {
  const _KeyboardKey({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Ink(
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0x24FFFFFF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: label == '123' ? 10 : 12,
                fontWeight: label == '123' ? FontWeight.w700 : FontWeight.w600,
                color: const Color(0xD9FFF6FF),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SongBookRightColumn extends StatelessWidget {
  const _SongBookRightColumn({
    required this.controller,
    required this.selectedLanguage,
    required this.songs,
    required this.hasConfiguredDirectory,
    required this.isScanningLibrary,
    required this.libraryScanErrorMessage,
    required this.queuedSongs,
    required this.onBackPressed,
    required this.onLanguageSelected,
    required this.onPlaySong,
    required this.onSettingsPressed,
    required this.onToggleAudioMode,
    required this.onTogglePlayback,
    required this.onRestartPlayback,
    this.compact = false,
  });

  final PlayerController controller;
  final String selectedLanguage;
  final List<DemoSong> songs;
  final bool hasConfiguredDirectory;
  final bool isScanningLibrary;
  final String? libraryScanErrorMessage;
  final List<DemoSong> queuedSongs;
  final VoidCallback onBackPressed;
  final ValueChanged<String> onLanguageSelected;
  final ValueChanged<DemoSong> onPlaySong;
  final VoidCallback onSettingsPressed;
  final VoidCallback onToggleAudioMode;
  final VoidCallback onTogglePlayback;
  final VoidCallback onRestartPlayback;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Widget libraryContent = !hasConfiguredDirectory
        ? const _EmptyContentCard(message: '请先在设置里选择扫描目录，扫描完成后这里会展示歌曲列表。')
        : isScanningLibrary
        ? const _EmptyContentCard(message: '正在扫描目录中的歌曲，请稍候。')
        : libraryScanErrorMessage != null
        ? _EmptyContentCard(message: libraryScanErrorMessage!)
        : songs.isEmpty
        ? const _EmptyContentCard(
            message: '当前目录下没有扫描到可播放歌曲，请确认目录中包含 mp4、dat 等媒体文件。',
          )
        : GridView.builder(
            shrinkWrap: compact,
            physics: compact
                ? const NeverScrollableScrollPhysics()
                : const ClampingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 6,
              crossAxisSpacing: 12,
              childAspectRatio: 2.86,
            ),
            itemCount: songs.length,
            itemBuilder: (BuildContext context, int index) {
              final DemoSong song = songs[index];
              final bool isCurrent =
                  queuedSongs.isNotEmpty && queuedSongs.first == song;
              return _SongTile(
                song: song,
                isCurrent: isCurrent,
                onTap: () => onPlaySong(song),
              );
            },
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SongBookActionRow(
          controller: controller,
          queueCount: queuedSongs.length,
          compact: compact,
          onSettingsPressed: onSettingsPressed,
          onToggleAudioMode: onToggleAudioMode,
          onTogglePlayback: onTogglePlayback,
          onRestartPlayback: onRestartPlayback,
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                '‹ 主页 / 歌名',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xEBFFF7FF),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _ActionPill(
              label: '返回',
              icon: Icons.chevron_right_rounded,
              onPressed: onBackPressed,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: _languageTabs
              .map((String language) {
                final bool selected = language == selectedLanguage;
                return Material(
                  color: selected
                      ? const Color(0x14FFFFFF)
                      : const Color(0x0AFFFFFF),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onLanguageSelected(language),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      child: Text(
                        language,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? const Color(0xFFFF625E)
                              : const Color(0xB8FFF0FF),
                        ),
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
        const SizedBox(height: 12),
        if (compact) ...<Widget>[
          libraryContent,
          const SizedBox(height: 12),
          const _PaginationBar(),
        ] else
          Expanded(
            child: Column(
              children: <Widget>[
                Expanded(child: libraryContent),
                const SizedBox(height: 12),
                const _PaginationBar(),
              ],
            ),
          ),
      ],
    );
  }
}

class _SongBookActionRow extends StatelessWidget {
  const _SongBookActionRow({
    required this.controller,
    required this.queueCount,
    required this.compact,
    required this.onSettingsPressed,
    required this.onToggleAudioMode,
    required this.onTogglePlayback,
    required this.onRestartPlayback,
  });

  final PlayerController controller;
  final int queueCount;
  final bool compact;
  final VoidCallback onSettingsPressed;
  final VoidCallback onToggleAudioMode;
  final VoidCallback onTogglePlayback;
  final VoidCallback onRestartPlayback;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        return Align(
          alignment: compact ? Alignment.centerLeft : Alignment.centerRight,
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.end,
            children: <Widget>[
              _ActionPill(
                label: '已点$queueCount',
                icon: Icons.queue_music_rounded,
              ),
              _ActionPill(
                label:
                    controller.audioOutputMode == AudioOutputMode.accompaniment
                    ? '原唱'
                    : '伴唱',
                icon: Icons.mic_rounded,
                onPressed: controller.hasMedia ? onToggleAudioMode : null,
              ),
              const _ActionPill(
                label: '切歌',
                icon: Icons.skip_next_rounded,
                enabled: false,
              ),
              _ActionPill(
                label: controller.isPlaying ? '暂停' : '播放',
                icon: controller.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                onPressed: controller.hasMedia ? onTogglePlayback : null,
              ),
              _ActionPill(
                label: '重唱',
                icon: Icons.replay_rounded,
                onPressed: controller.hasMedia ? onRestartPlayback : null,
              ),
              _ActionPill(
                label: '设置',
                icon: Icons.settings_rounded,
                onPressed: onSettingsPressed,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.icon,
    this.onPressed,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = enabled && onPressed != null;
    return Material(
      color: isEnabled ? const Color(0x1AFFFFFF) : const Color(0x0DFFFFFF),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isEnabled ? onPressed : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 12,
                color: isEnabled
                    ? const Color(0xCCFFF7FF)
                    : const Color(0x7AFFF7FF),
              ),
              const SizedBox(width: 4),
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

class _SongTile extends StatelessWidget {
  const _SongTile({required this.song, required this.isCurrent, this.onTap});

  final DemoSong song;
  final bool isCurrent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = isCurrent
        ? const Color(0x29FFFFFF)
        : const Color(0x1AFFFFFF);
    final Color subtitleColor = isCurrent
        ? const Color(0xCCF3DAFF)
        : const Color(0xB8F3DAFF);

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 5, 8, 5),
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
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        height: 1,
                        color: Color(0xEDFFF7FF),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${song.artist} · ${song.language}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w500,
                        height: 1,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isCurrent ? '当前播放' : '播放',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: isCurrent
                      ? const Color(0xFFFFD85E)
                      : const Color(0xB8FFF7FF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyContentCard extends StatelessWidget {
  const _EmptyContentCard({required this.message});

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

class _PaginationBar extends StatelessWidget {
  const _PaginationBar();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        children: const <Widget>[
          _PaginationButton(label: '上一页'),
          Text(
            '1/1',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xCCFFF2FF),
            ),
          ),
          _PaginationButton(label: '下一页'),
        ],
      ),
    );
  }
}

class _PaginationButton extends StatelessWidget {
  const _PaginationButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0x7AFFF2FF),
        ),
      ),
    );
  }
}
