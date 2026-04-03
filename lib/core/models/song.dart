class Song {
  const Song({
    required this.songId,
    required this.sourceId,
    required this.sourceSongId,
    required this.title,
    required this.artist,
    required this.languages,
    this.tags = const <String>[],
    required this.searchIndex,
    required this.mediaPath,
  });

  final String songId;
  final String sourceId;
  final String sourceSongId;
  final String title;
  final String artist;
  final List<String> languages;
  final List<String> tags;
  final String searchIndex;
  final String mediaPath;

  String get language => languages.join('/');

  String get tagsLabel => tags.join('/');

  @override
  bool operator ==(Object other) {
    return other is Song &&
        other.songId == songId &&
        other.sourceId == sourceId &&
        other.sourceSongId == sourceSongId;
  }

  @override
  int get hashCode => Object.hash(songId, sourceId, sourceSongId);
}
