class DemoArtist {
  const DemoArtist({
    required this.name,
    required this.songCount,
    required this.searchIndex,
  });

  final String name;
  final int songCount;
  final String searchIndex;

  String get avatarLabel {
    final String trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return '歌手';
    }
    return String.fromCharCodes(trimmedName.runes.take(3));
  }
}
