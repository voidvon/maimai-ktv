class DemoSong {
  const DemoSong({
    required this.title,
    required this.artist,
    required this.language,
    required this.searchIndex,
    required this.mediaPath,
  });

  final String title;
  final String artist;
  final String language;
  final String searchIndex;
  final String mediaPath;

  @override
  bool operator ==(Object other) {
    return other is DemoSong && other.mediaPath == mediaPath;
  }

  @override
  int get hashCode => mediaPath.hashCode;
}
