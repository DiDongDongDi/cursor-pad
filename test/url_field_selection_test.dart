import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors [_BrowserScreenState._selectAllUrlText] in browser_screen.dart.
void selectAllUrlText({
  required TextEditingController controller,
  required FocusNode focusNode,
  required bool mounted,
}) {
  final length = controller.text.length;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || !focusNode.hasFocus) {
      return;
    }
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: length,
    );
  });
}

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
}
