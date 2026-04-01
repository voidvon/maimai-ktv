import 'demo_song.dart';

class DemoSongPage {
  const DemoSongPage({
    required this.songs,
    required this.totalCount,
    required this.pageIndex,
    required this.pageSize,
  });

  final List<DemoSong> songs;
  final int totalCount;
  final int pageIndex;
  final int pageSize;

  int get totalPages {
    if (pageSize <= 0 || totalCount <= 0) {
      return 1;
    }
    return ((totalCount + pageSize - 1) / pageSize).ceil();
  }
}
