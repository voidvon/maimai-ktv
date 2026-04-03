import 'package:flutter_test/flutter_test.dart';
import 'package:ktv2_example/features/ktv/application/navigation_history.dart';
import 'package:ktv2_example/features/ktv/application/ktv_controller.dart';

void main() {
  test('navigation history tracks breadcrumb segments and back stack', () {
    final NavigationHistory history = NavigationHistory();

    expect(history.current.route, KtvRoute.home);
    expect(history.breadcrumbLabel, '‹ 主页');

    expect(history.enterSongBook(mode: SongBookMode.artists), isTrue);
    expect(history.selectArtist('周杰伦'), isTrue);
    expect(
      history.enterQueueList(
        songBookMode: history.current.songBookMode,
        libraryScope: history.current.libraryScope,
        selectedArtist: history.current.selectedArtist,
      ),
      isTrue,
    );

    expect(history.breadcrumbLabel, '‹ 主页 / 歌星 / 周杰伦 / 已点');

    final NavigationDestination? previous = history.navigateBack();
    expect(previous, isNotNull);
    expect(previous!.selectedArtist, '周杰伦');
    expect(previous.route, KtvRoute.songBook);
  });

  test('returnHome resets stack to a single home destination', () {
    final NavigationHistory history = NavigationHistory();

    history.enterSongBook();
    expect(history.returnHome(), isTrue);
    expect(history.current, const NavigationDestination.home());
    expect(history.canNavigateBack, isFalse);
    expect(history.returnHome(), isFalse);
  });
}
