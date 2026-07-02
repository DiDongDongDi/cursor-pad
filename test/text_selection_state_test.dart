import 'package:cursor_pad/features/browser/copy_mode_state.dart';
import 'package:cursor_pad/features/browser/selection_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CopyModeState', () {
    test('starts inactive', () {
      final mode = CopyModeState();
      expect(mode.active, isFalse);
    });

    test('enter and exit toggle active flag', () {
      final mode = CopyModeState();
      mode.enter();
      expect(mode.active, isTrue);
      mode.exit();
      expect(mode.active, isFalse);
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
