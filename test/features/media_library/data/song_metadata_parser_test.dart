import 'package:flutter_test/flutter_test.dart';
import 'package:ktv2_example/features/media_library/data/song_metadata_parser.dart';

void main() {
  const SongMetadataParser parser = SongMetadataParser();

  test('parseFileName extracts artist title language and tags', () {
    final ParsedSongMetadata metadata = parser.parseFileName(
      '周杰伦-青花瓷-国语-流行.mp4',
    );

    expect(metadata.artist, '周杰伦');
    expect(metadata.title, '青花瓷');
    expect(metadata.languages, <String>['国语']);
    expect(metadata.tags, <String>['流行']);
  });

  test('parseFileName keeps hyphenated artist aliases', () {
    final ParsedSongMetadata metadata = parser.parseFileName(
      'A-Lin-给我一个理由忘记-国语.mp4',
    );

    expect(metadata.artist, 'A-Lin');
    expect(metadata.title, '给我一个理由忘记');
    expect(metadata.languages, <String>['国语']);
  });

  test('parseFileName strips trailing copy noise from suffix keywords', () {
    final ParsedSongMetadata metadata = parser.parseFileName(
      'Beyond-海阔天空-国语-流行-副本(2).mp4',
    );

    expect(metadata.artist, 'Beyond');
    expect(metadata.title, '海阔天空');
    expect(metadata.languages, <String>['国语']);
    expect(metadata.tags, <String>['流行']);
  });
}
