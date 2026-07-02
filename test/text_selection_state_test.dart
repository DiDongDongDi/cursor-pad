import 'package:cursor_pad/features/browser/selection_info.dart';
import 'package:cursor_pad/features/browser/text_selection_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextSelectionState', () {
    test('idle tap begins selection', () {
      final state = TextSelectionState();
      expect(state.onTap(), TextSelectionTapAction.beginSelection);
    });

    test('armed without drag resolves to click on second tap', () {
      final state = TextSelectionState()..onBeginSelection();
      expect(state.onTap(), TextSelectionTapAction.clickWithoutSelection);
    });

    test('armed with drag ends selection on second tap', () {
      final state = TextSelectionState()
        ..onBeginSelection()
        ..onDrag();
      expect(state.onTap(), TextSelectionTapAction.endSelection);
    });

    test('drag cancels pending auto click', () {
      final state = TextSelectionState()..onBeginSelection();
      expect(state.shouldAutoClick, isTrue);
      state.onDrag();
      expect(state.shouldAutoClick, isFalse);
      expect(state.dragged, isTrue);
    });

    test('cancel resets armed state', () {
      final state = TextSelectionState()
        ..onBeginSelection()
        ..onDrag();
      state.onCancel();
      expect(state.armed, isFalse);
      expect(state.dragged, isFalse);
      expect(state.onTap(), TextSelectionTapAction.beginSelection);
    });

    test('commit clears armed state', () {
      final state = TextSelectionState()
        ..onBeginSelection()
        ..onDrag();
      state.onSelectionCommitted();
      expect(state.armed, isFalse);
      expect(state.dragged, isFalse);
    });
  });

  group('SelectionInfo', () {
    test('parses json payload', () {
      final info = SelectionInfo.fromJson({
        'text': 'hello',
        'isCollapsed': false,
        'length': 5,
      });
      expect(info.text, 'hello');
      expect(info.hasText, isTrue);
      expect(info.length, 5);
    });

    test('tryParse returns null for invalid payload', () {
      expect(SelectionInfo.tryParse('not-json'), isNull);
    });
  });
}
