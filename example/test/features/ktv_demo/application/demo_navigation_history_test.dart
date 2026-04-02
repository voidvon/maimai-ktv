import 'package:flutter_test/flutter_test.dart';
import 'package:ktv2_example/features/ktv_demo/application/demo_navigation_history.dart';
import 'package:ktv2_example/features/ktv_demo/application/ktv_demo_controller.dart';

void main() {
  test('navigation history tracks breadcrumb segments and back stack', () {
    final DemoNavigationHistory history = DemoNavigationHistory();

    expect(history.current.route, DemoRoute.home);
    expect(history.breadcrumbLabel, '‹ 主页');

    expect(history.enterSongBook(mode: DemoSongBookMode.artists), isTrue);
    expect(history.selectArtist('周杰伦'), isTrue);
    expect(
      history.enterQueueList(
        songBookMode: history.current.songBookMode,
        selectedArtist: history.current.selectedArtist,
      ),
      isTrue,
    );

    expect(history.breadcrumbLabel, '‹ 主页 / 歌星 / 周杰伦 / 已点');

    final DemoNavigationDestination? previous = history.navigateBack();
    expect(previous, isNotNull);
    expect(previous!.selectedArtist, '周杰伦');
    expect(previous.route, DemoRoute.songBook);
  });

  test('returnHome resets stack to a single home destination', () {
    final DemoNavigationHistory history = DemoNavigationHistory();

    history.enterSongBook();
    expect(history.returnHome(), isTrue);
    expect(history.current, const DemoNavigationDestination.home());
    expect(history.canNavigateBack, isFalse);
    expect(history.returnHome(), isFalse);
  });
}
