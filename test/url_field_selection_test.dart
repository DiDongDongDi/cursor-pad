import 'package:cursor_pad/features/browser/url_field_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selectAllUrlText selects entire url on focus', (tester) async {
    const url = 'https://example.com';
    final controller = TextEditingController(text: url);
    final focusNode = FocusNode();
    var mounted = true;

    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        selectAllUrlText(
          controller: controller,
          focusNode: focusNode,
          mounted: mounted,
        );
      }
    });

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: EditableText(
          controller: controller,
          focusNode: focusNode,
          style: const TextStyle(fontSize: 14),
          cursorColor: const Color(0xFF000000),
          backgroundCursorColor: const Color(0xFF000000),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();
    await tester.pump();

    expect(
      controller.selection,
      TextSelection(baseOffset: 0, extentOffset: url.length),
    );
  });

  testWidgets('selectAllUrlText re-selects when invoked while already focused',
      (tester) async {
    const url = 'https://example.com/page';
    final controller = TextEditingController(text: url);
    final focusNode = FocusNode();
    const mounted = true;

    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: EditableText(
          controller: controller,
          focusNode: focusNode,
          style: const TextStyle(fontSize: 14),
          cursorColor: const Color(0xFF000000),
          backgroundCursorColor: const Color(0xFF000000),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();
    await tester.pump();

    controller.selection = const TextSelection.collapsed(offset: 4);
    selectAllUrlText(
      controller: controller,
      focusNode: focusNode,
      mounted: mounted,
    );
    await tester.pump();

    expect(
      controller.selection,
      TextSelection(baseOffset: 0, extentOffset: url.length),
    );
  });

  test('wordSelectionAt selects word at offset', () {
    const url = 'https://example.com/path';
    final exampleStart = url.indexOf('example');
    final selection = wordSelectionAt(url, exampleStart + 3);

    expect(selection.start, exampleStart);
    expect(selection.end, exampleStart + 'example'.length);
    expect(
      selectedTextFromSelection(url, selection),
      'example',
    );
  });

  test('selectionFromAnchor builds range between anchor and extent', () {
    const text = 'https://example.com';
    final selection = selectionFromAnchor(8, 15, text.length);

    expect(selection.start, 8);
    expect(selection.end, 15);
    expect(selectedTextFromSelection(text, selection), 'example');
  });

  testWidgets('textOffsetAtGlobalX maps horizontal position to text offset',
      (tester) async {
    const url = 'https://example.com';
    const style = TextStyle(fontSize: 16);
    final fieldKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              key: fieldKey,
              width: 280,
              height: urlFieldHeight,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fieldBox = fieldKey.currentContext!.findRenderObject() as RenderBox;

    final startGlobal = fieldBox.localToGlobal(
      Offset(urlFieldContentPadding.left, urlFieldHeight / 2),
    );
    final startOffset = textOffsetAtGlobalX(
      text: url,
      globalPoint: startGlobal,
      fieldBox: fieldBox,
      style: style,
    );

    final endGlobal = fieldBox.localToGlobal(
      Offset(
        fieldBox.size.width - urlFieldContentPadding.right,
        urlFieldHeight / 2,
      ),
    );
    final endOffset = textOffsetAtGlobalX(
      text: url,
      globalPoint: endGlobal,
      fieldBox: fieldBox,
      style: style,
    );

    expect(startOffset, 0);
    expect(endOffset, url.length);
  });
}
