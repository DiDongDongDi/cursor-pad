import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cursor_pad/features/input/touchpad_detector.dart';

void main() {
  Widget buildTouchpad({
    required void Function(Offset delta) onMove,
    required void Function(Offset delta) onScroll,
    void Function(double scaleFactor)? onPinch,
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
        onLongPress: () {},
        onScroll: onScroll,
        onPinch: onPinch ?? (_) {},
        child: const SizedBox.expand(),
      ),
    );
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

  testWidgets('two-finger pinch triggers onPinch', (tester) async {
    final pinchFactors = <double>[];

    await tester.pumpWidget(
      buildTouchpad(
        onMove: (_) {},
        onScroll: (_) {},
        onPinch: pinchFactors.add,
      ),
    );

    final finger1 = await tester.createGesture();
    final finger2 = await tester.createGesture();

    await finger1.down(const Offset(100, 200));
    await finger2.down(const Offset(200, 200));
    await tester.pump();

    await finger1.moveBy(const Offset(-40, 0));
    await finger2.moveBy(const Offset(40, 0));
    await tester.pump();

    expect(pinchFactors, isNotEmpty);
    expect(pinchFactors.last, greaterThan(1));

    await finger1.up();
    await finger2.up();
    await tester.pumpAndSettle();
  });

  testWidgets('two-finger drag with spacing jitter does not trigger onPinch',
      (tester) async {
    final scrollDeltas = <Offset>[];
    final pinchFactors = <double>[];

    await tester.pumpWidget(
      buildTouchpad(
        onMove: (_) {},
        onScroll: scrollDeltas.add,
        onPinch: pinchFactors.add,
      ),
    );

    final finger1 = await tester.createGesture();
    final finger2 = await tester.createGesture();

    await finger1.down(const Offset(100, 100));
    await finger2.down(const Offset(200, 100));
    await tester.pump();

    await finger1.moveBy(const Offset(-3, 40));
    await finger2.moveBy(const Offset(3, 40));
    await tester.pump();

    expect(scrollDeltas, isNotEmpty);
    expect(pinchFactors, isEmpty);

    await finger1.up();
    await finger2.up();
    await tester.pumpAndSettle();
  });

  testWidgets('small spread during slop phase does not trigger onPinch',
      (tester) async {
    final pinchFactors = <double>[];

    await tester.pumpWidget(
      buildTouchpad(
        onMove: (_) {},
        onScroll: (_) {},
        onPinch: pinchFactors.add,
      ),
    );

    final finger1 = await tester.createGesture();
    final finger2 = await tester.createGesture();

    await finger1.down(const Offset(100, 200));
    await finger2.down(const Offset(200, 200));
    await tester.pump();

    await finger1.moveBy(const Offset(-5, 0));
    await finger2.moveBy(const Offset(5, 0));
    await tester.pump();

    expect(pinchFactors, isEmpty);

    await finger1.up();
    await finger2.up();
    await tester.pumpAndSettle();
  });
}
