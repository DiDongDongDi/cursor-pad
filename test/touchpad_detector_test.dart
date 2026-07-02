import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cursor_pad/features/input/touchpad_detector.dart';

void main() {
  Widget buildTouchpad({
    required void Function(Offset delta) onMove,
    required void Function(Offset delta) onScroll,
    double moveThreshold = 0,
  }) {
    return MaterialApp(
      home: TouchpadDetector(
        moveThreshold: moveThreshold,
        scrollSensitivity: 1.0,
        sensitivity: 1.0,
        onMove: onMove,
        onTap: () {},
        onDoubleTap: () {},
        onTripleTap: () {},
        onLongPress: () {},
        onScroll: onScroll,
        child: const SizedBox.expand(),
      ),
    );
  }

  void expectNoLargeMoveDeltas(
    List<Offset> moveDeltas, {
    double maxDistance = 8,
  }) {
    for (final delta in moveDeltas) {
      expect(
        delta.distance,
        lessThanOrEqualTo(maxDistance),
        reason: 'Unexpected cursor move delta $delta',
      );
    }
  }

  testWidgets('two-finger vertical drag triggers onScroll with dy', (tester) async {
    final scrollDeltas = <Offset>[];

    await tester.pumpWidget(
      buildTouchpad(
        onMove: (_) {},
        onScroll: scrollDeltas.add,
      ),
    );

    final finger1 = await tester.createGesture();
    final finger2 = await tester.createGesture();

    await finger1.down(const Offset(100, 100));
    await finger2.down(const Offset(200, 100));
    await tester.pump();

    await finger1.moveBy(const Offset(0, 40));
    await finger2.moveBy(const Offset(0, 40));
    await tester.pump();

    expect(scrollDeltas, isNotEmpty);
    expect(scrollDeltas.last.dy, isNonZero);
    expect(scrollDeltas.last.dx, 0);

    await finger1.up();
    await finger2.up();
    await tester.pumpAndSettle();
  });

  testWidgets('two-finger vertical drag ignores incidental horizontal movement', (
    tester,
  ) async {
    final scrollDeltas = <Offset>[];

    await tester.pumpWidget(
      buildTouchpad(
        onMove: (_) {},
        onScroll: scrollDeltas.add,
      ),
    );

    final finger1 = await tester.createGesture();
    final finger2 = await tester.createGesture();

    await finger1.down(const Offset(100, 100));
    await finger2.down(const Offset(200, 100));
    await tester.pump();

    await finger1.moveBy(const Offset(4, 40));
    await finger2.moveBy(const Offset(4, 40));
    await tester.pump();

    expect(scrollDeltas, isNotEmpty);
    expect(scrollDeltas.last.dy, isNonZero);
    expect(scrollDeltas.last.dx, 0);

    await finger1.up();
    await finger2.up();
    await tester.pumpAndSettle();
  });

  testWidgets('two-finger horizontal drag triggers onScroll with dx', (tester) async {
    final scrollDeltas = <Offset>[];

    await tester.pumpWidget(
      buildTouchpad(
        onMove: (_) {},
        onScroll: scrollDeltas.add,
      ),
    );

    final finger1 = await tester.createGesture();
    final finger2 = await tester.createGesture();

    await finger1.down(const Offset(100, 100));
    await finger2.down(const Offset(100, 200));
    await tester.pump();

    await finger1.moveBy(const Offset(40, 0));
    await finger2.moveBy(const Offset(40, 0));
    await tester.pump();

    expect(scrollDeltas, isNotEmpty);
    expect(scrollDeltas.last.dx, isNonZero);
    expect(scrollDeltas.last.dy, 0);

    await finger1.up();
    await finger2.up();
    await tester.pumpAndSettle();
  });

  testWidgets('single-finger drag triggers onMove not onScroll', (tester) async {
    final moveDeltas = <Offset>[];
    final scrollDeltas = <Offset>[];

    await tester.pumpWidget(
      buildTouchpad(
        moveThreshold: 0,
        onMove: moveDeltas.add,
        onScroll: scrollDeltas.add,
      ),
    );

    final finger = await tester.createGesture();
    await finger.down(const Offset(100, 100));
    await tester.pump();
    await finger.moveBy(const Offset(20, 30));
    await tester.pump();

    expect(moveDeltas, isNotEmpty);
    expect(scrollDeltas, isEmpty);

    await finger.up();
    await tester.pumpAndSettle();
  });

  testWidgets('two-finger scroll end does not trigger onMove jump', (tester) async {
    final moveDeltas = <Offset>[];
    final scrollDeltas = <Offset>[];

    await tester.pumpWidget(
      buildTouchpad(
        moveThreshold: 8,
        onMove: moveDeltas.add,
        onScroll: scrollDeltas.add,
      ),
    );

    final finger1 = await tester.createGesture();
    final finger2 = await tester.createGesture();

    await finger1.down(const Offset(100, 100));
    await finger2.down(const Offset(200, 100));
    await tester.pump();

    await finger1.moveBy(const Offset(0, 80));
    await finger2.moveBy(const Offset(0, 80));
    await tester.pump();

    expect(scrollDeltas, isNotEmpty);

    await finger2.up();
    await tester.pump();
    await finger1.moveBy(const Offset(0, 1));
    await tester.pump();
    await finger1.up();
    await tester.pumpAndSettle();

    expectNoLargeMoveDeltas(moveDeltas);
  });

  testWidgets('triple tap fires onTripleTap after three quick taps', (tester) async {
    var tripleTapCount = 0;
    var singleTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: TouchpadDetector(
          onMove: (_) {},
          onTap: () => singleTapCount++,
          onDoubleTap: () {},
          onTripleTap: () => tripleTapCount++,
          onLongPress: () {},
          onScroll: (_) {},
          child: const SizedBox.expand(),
        ),
      ),
    );

    final finger = await tester.createGesture();
    for (var i = 0; i < 3; i++) {
      await finger.down(const Offset(100, 100));
      await tester.pump();
      await finger.up();
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 400));

    expect(tripleTapCount, 1);
    expect(singleTapCount, 0);
  });
}
