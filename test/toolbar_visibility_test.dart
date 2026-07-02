import 'package:flutter_test/flutter_test.dart';

import 'package:cursor_pad/features/browser/toolbar_visibility.dart';

void main() {
  group('ToolbarVisibilityController', () {
    late ToolbarVisibilityController controller;

    setUp(() {
      controller = ToolbarVisibilityController(
        showDelay: const Duration(milliseconds: 400),
        hideDelay: const Duration(milliseconds: 800),
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('does not show when cursor is near top but not at edge', () {
      controller.onCursorMove(10, chromeHeight: 0);

      expect(controller.visible, isFalse);

      controller.onCursorMove(10, chromeHeight: 0);
      expect(controller.visible, isFalse);
    });

    test('shows after delay when cursor is at top edge', () async {
      controller.onCursorMove(0, chromeHeight: 0);

      expect(controller.visible, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(controller.visible, isTrue);
    });

    test('cancels pending show when cursor leaves top edge', () async {
      controller.onCursorMove(0, chromeHeight: 0);
      controller.onCursorMove(10, chromeHeight: 0);

      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(controller.visible, isFalse);
    });

    test('keeps visible while cursor stays in chrome area', () async {
      controller.forceShow();
      expect(controller.visible, isTrue);

      const chromeHeight = 76.0;
      controller.onCursorMove(50, chromeHeight: chromeHeight);

      await Future<void>.delayed(const Duration(milliseconds: 800));
      expect(controller.visible, isTrue);
    });

    test('hides after delay when cursor leaves chrome area', () async {
      controller.forceShow();
      expect(controller.visible, isTrue);

      const chromeHeight = 76.0;
      controller.onCursorMove(100, chromeHeight: chromeHeight);

      await Future<void>.delayed(const Duration(milliseconds: 800));
      expect(controller.visible, isFalse);
    });

    test('forceShow bypasses edge threshold', () {
      controller.onCursorMove(100, chromeHeight: 0);
      expect(controller.visible, isFalse);

      controller.forceShow();
      expect(controller.visible, isTrue);
    });
  });
}
