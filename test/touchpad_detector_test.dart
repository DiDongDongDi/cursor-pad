import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cursor_pad/features/input/touchpad_detector.dart';

void main() {
  Widget buildTouchpad({
    required void Function(Offset delta) onMove,
    required void Function(Offset delta) onScroll,
    double moveThreshold = 0,
    void Function()? onTap,
    void Function()? onDoubleTap,
    void Function()? onButtonDown,
    void Function()? onButtonUp,
  }) {
    return MaterialApp(
      home: TouchpadDetector(
        moveThreshold: moveThreshold,
        scrollSensitivity: 1.0,
        sensitivity: 1.0,
        onMove: onMove,
        onTap: onTap ?? () {},
        onDoubleTap: onDoubleTap ?? () {},
        onButtonDown: onButtonDown ?? () {},
        onButtonUp: onButtonUp ?? () {},
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

  testWidgets('first tap fires onTap immediately', (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      buildTouchpad(
        onMove: (_) {},
        onScroll: (_) {},
        onTap: () => tapCount++,
      ),
    );

    final finger = await tester.createGesture();
    await finger.down(const Offset(100, 100));
    await tester.pump();
    await finger.up();
    await tester.pump();

    expect(tapCount, 1);
  });

  testWidgets('quick second tap without move fires onDoubleTap', (tester) async {
    var tapCount = 0;
    var doubleTapCount = 0;
    var buttonDownCount = 0;

    await tester.pumpWidget(
      buildTouchpad(
        onMove: (_) {},
        onScroll: (_) {},
        onTap: () => tapCount++,
        onDoubleTap: () => doubleTapCount++,
        onButtonDown: () => buttonDownCount++,
      ),
    );

    final finger = await tester.createGesture();
    await finger.down(const Offset(100, 100));
    await tester.pump();
    await finger.up();
    await tester.pump();
    await finger.down(const Offset(100, 100));
    await tester.pump();
    await finger.up();
    await tester.pump();

    expect(tapCount, 1);
    expect(doubleTapCount, 1);
    expect(buttonDownCount, 0);
  });

  testWidgets('second press move enters button held and up releases', (tester) async {
    var tapCount = 0;
    var doubleTapCount = 0;
    var buttonDownCount = 0;
    var buttonUpCount = 0;

    await tester.pumpWidget(
      buildTouchpad(
        moveThreshold: 8,
        onMove: (_) {},
        onScroll: (_) {},
        onTap: () => tapCount++,
        onDoubleTap: () => doubleTapCount++,
        onButtonDown: () => buttonDownCount++,
        onButtonUp: () => buttonUpCount++,
      ),
    );

    final finger = await tester.createGesture();
    await finger.down(const Offset(100, 100));
    await tester.pump();
    await finger.up();
    await tester.pump();
    await finger.down(const Offset(100, 100));
    await tester.pump();
    await finger.moveBy(const Offset(20, 0));
    await tester.pump();
    await finger.up();
    await tester.pump();

    expect(tapCount, 1);
    expect(doubleTapCount, 0);
    expect(buttonDownCount, 1);
    expect(buttonUpCount, 1);
  });

  testWidgets('second press long hold without move enters button held', (tester) async {
    var buttonDownCount = 0;
    var buttonUpCount = 0;
    var doubleTapCount = 0;

    await tester.pumpWidget(
      buildTouchpad(
        moveThreshold: 8,
        onMove: (_) {},
        onScroll: (_) {},
        onDoubleTap: () => doubleTapCount++,
        onButtonDown: () => buttonDownCount++,
        onButtonUp: () => buttonUpCount++,
      ),
    );

    final finger = await tester.createGesture();
    await finger.down(const Offset(100, 100));
    await tester.pump();
    await finger.up();
    await tester.pump();
    await finger.down(const Offset(100, 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(buttonDownCount, 1);
    expect(doubleTapCount, 0);
    await finger.up();
    await tester.pump();
    expect(buttonUpCount, 1);
  });
}
