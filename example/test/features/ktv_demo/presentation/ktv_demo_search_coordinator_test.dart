import 'package:flutter_test/flutter_test.dart';
import 'package:ktv2_example/features/ktv_demo/presentation/ktv_demo_search_coordinator.dart';

void main() {
  testWidgets('syncFromQuery updates text without re-emitting query changes', (
    WidgetTester tester,
  ) async {
    final List<String> emittedQueries = <String>[];
    final KtvDemoSearchCoordinator coordinator = KtvDemoSearchCoordinator(
      onQueryChanged: emittedQueries.add,
    );
    addTearDown(coordinator.dispose);

    coordinator.syncFromQuery('周杰伦');

    expect(coordinator.controller.text, '周杰伦');
    expect(emittedQueries, isEmpty);
  });

  testWidgets('append remove and clear forward query changes', (
    WidgetTester tester,
  ) async {
    final List<String> emittedQueries = <String>[];
    final KtvDemoSearchCoordinator coordinator = KtvDemoSearchCoordinator(
      onQueryChanged: emittedQueries.add,
    );
    addTearDown(coordinator.dispose);

    coordinator.appendToken('A');
    coordinator.appendToken('B');
    coordinator.removeLastCharacter();
    coordinator.clear();

    expect(emittedQueries, <String>['A', 'AB', 'A', '']);
    expect(coordinator.controller.text, isEmpty);
  });
}
