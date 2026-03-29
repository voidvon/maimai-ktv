import 'package:flutter_test/flutter_test.dart';
import 'package:ktv2_example/main.dart';

void main() {
  testWidgets(
    'shows home shell and persistent player before media is selected',
    (WidgetTester tester) async {
      await tester.pumpWidget(const KtvDemoApp());

      expect(find.text('金调KTV'), findsOneWidget);
      expect(find.text('歌名'), findsOneWidget);
      expect(find.text('设置'), findsAtLeastNWidgets(1));
      expect(find.text('选择本地视频'), findsOneWidget);
    },
  );

  testWidgets('opens scan directory settings dialog from top actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const KtvDemoApp());

    await tester.tap(find.text('设置').first);
    await tester.pumpAndSettle();

    expect(find.text('媒体库设置'), findsOneWidget);
    expect(find.text('扫描目录'), findsOneWidget);
    expect(find.text('选择目录'), findsOneWidget);
  });
}
