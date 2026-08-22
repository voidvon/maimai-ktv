import 'song.dart';

class SongPage {
  const SongPage({
    required this.songs,
    required this.totalCount,
    required this.pageIndex,
    required this.pageSize,
  });

  final List<Song> songs;
  final int totalCount;
  final int pageIndex;
  final int pageSize;

  int get totalPages {
    if (pageSize <= 0 || totalCount <= 0) {
      return 1;
    }
    return (totalCount + pageSize - 1) ~/ pageSize;
  }
}
