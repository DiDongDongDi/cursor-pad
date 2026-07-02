import 'package:cursor_pad/features/browser/selection_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
