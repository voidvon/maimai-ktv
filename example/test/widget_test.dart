import 'package:flutter_test/flutter_test.dart';
import 'package:ktv2_example/main.dart';

void main() {
  testWidgets('shows empty player placeholder before media is selected', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const KtvPlayerExampleApp());

    expect(find.text('选择一个本地视频开始播放'), findsOneWidget);
  });
}
