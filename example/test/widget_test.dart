import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ktv2_example/main.dart';

void main() {
  testWidgets('shows home shell before media library is selected', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const KtvDemoApp());

    expect(find.text('金调KTV'), findsOneWidget);
    expect(find.text('歌名'), findsOneWidget);
    expect(find.text('设置'), findsAtLeastNWidgets(1));
    expect(find.text('首页预览区'), findsNothing);
    expect(find.byType(Slider), findsOneWidget);
  });

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

  testWidgets('renders compact song book without layout exceptions', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 932);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const KtvDemoApp());

    await tester.tap(find.text('歌名'));
    await tester.pumpAndSettle();

    expect(find.text('请先在设置里选择扫描目录，扫描完成后这里会展示歌曲列表。'), findsOneWidget);
  });
}
