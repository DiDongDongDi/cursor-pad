import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cursor_pad/features/browser/browser_state.dart';
import 'package:cursor_pad/features/browser/browser_toolbar.dart';
import 'package:cursor_pad/features/browser/toolbar_hit_tester.dart';

void main() {
  testWidgets('ToolbarHitTester detects url field and finger tap does not focus',
      (WidgetTester tester) async {
    final hitTester = ToolbarHitTester();
    final urlController = TextEditingController(text: 'https://example.com');
    final urlFocusNode = FocusNode();

    addTearDown(urlController.dispose);
    addTearDown(urlFocusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrowserToolbar(
            state: const BrowserState(currentUrl: 'https://example.com'),
            urlController: urlController,
            urlFocusNode: urlFocusNode,
            hitTester: hitTester,
            tabCount: 3,
            onSubmit: (_) {},
            onBack: () {},
            onForward: () {},
            onReload: () {},
            onHome: () {},
            onBookmark: () {},
            isBookmarked: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final urlBox = hitTester.urlFieldKey.currentContext!.findRenderObject()
        as RenderBox;
    final center = urlBox.localToGlobal(
      urlBox.size.center(Offset.zero),
    );
    expect(hitTester.hitTest(center), ToolbarHitTarget.urlField);

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(urlFocusNode.hasFocus, isFalse);

    urlFocusNode.requestFocus();
    await tester.pump();
    expect(urlFocusNode.hasFocus, isTrue);
  });

  testWidgets('ToolbarHitTester detects tabs button', (WidgetTester tester) async {
    final hitTester = ToolbarHitTester();
    final urlController = TextEditingController(text: 'https://example.com');
    final urlFocusNode = FocusNode();

    addTearDown(urlController.dispose);
    addTearDown(urlFocusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrowserToolbar(
            state: const BrowserState(currentUrl: 'https://example.com'),
            urlController: urlController,
            urlFocusNode: urlFocusNode,
            hitTester: hitTester,
            tabCount: 5,
            onSubmit: (_) {},
            onBack: () {},
            onForward: () {},
            onReload: () {},
            onHome: () {},
            onBookmark: () {},
            isBookmarked: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tabsBox = hitTester.tabsButtonKey.currentContext!.findRenderObject()
        as RenderBox;
    final center = tabsBox.localToGlobal(
      tabsBox.size.center(Offset.zero),
    );
    expect(hitTester.hitTest(center), ToolbarHitTarget.tabsButton);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('ToolbarHitTester detects zoom buttons', (WidgetTester tester) async {
    final hitTester = ToolbarHitTester();
    final urlController = TextEditingController(text: 'https://example.com');
    final urlFocusNode = FocusNode();

    addTearDown(urlController.dispose);
    addTearDown(urlFocusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrowserToolbar(
            state: const BrowserState(currentUrl: 'https://example.com'),
            urlController: urlController,
            urlFocusNode: urlFocusNode,
            hitTester: hitTester,
            tabCount: 1,
            onSubmit: (_) {},
            onBack: () {},
            onForward: () {},
            onReload: () {},
            onHome: () {},
            onBookmark: () {},
            isBookmarked: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final zoomOutBox = hitTester.zoomOutKey.currentContext!.findRenderObject()
        as RenderBox;
    final zoomOutCenter = zoomOutBox.localToGlobal(
      zoomOutBox.size.center(Offset.zero),
    );
    expect(hitTester.hitTest(zoomOutCenter), ToolbarHitTarget.zoomOut);

    final zoomInBox = hitTester.zoomInKey.currentContext!.findRenderObject()
        as RenderBox;
    final zoomInCenter = zoomInBox.localToGlobal(
      zoomInBox.size.center(Offset.zero),
    );
    expect(hitTester.hitTest(zoomInCenter), ToolbarHitTarget.zoomIn);
  });
}
