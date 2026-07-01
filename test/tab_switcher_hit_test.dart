import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cursor_pad/features/browser/browser_tab.dart';
import 'package:cursor_pad/features/browser/browser_tab_switcher.dart';
import 'package:cursor_pad/features/browser/browser_controller.dart';
import 'package:cursor_pad/features/browser/tab_switcher_hit_tester.dart';

void main() {
  testWidgets('TabSwitcherHitTester detects tab, close, and new tab targets',
      (WidgetTester tester) async {
    final hitTester = TabSwitcherHitTester();
    final controllerA = BrowserController();
    final controllerB = BrowserController();
    addTearDown(controllerA.dispose);
    addTearDown(controllerB.dispose);

    final tabs = [
      BrowserTab(id: 'tab-a', controller: controllerA),
      BrowserTab(id: 'tab-b', controller: controllerB),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrowserTabSwitcher(
            tabs: tabs,
            activeIndex: 0,
            hitTester: hitTester,
            canCloseTab: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tabIds = tabs.map((tab) => tab.id).toList();

    final firstTabBox =
        hitTester.tabKey('tab-a').currentContext!.findRenderObject() as RenderBox;
    final firstTabCenter = firstTabBox.localToGlobal(
      firstTabBox.size.center(Offset.zero),
    );
    expect(
      hitTester.hitTest(
        firstTabCenter,
        tabIds: tabIds,
        canCloseTab: true,
      )?.target,
      TabSwitcherHitTarget.tab,
    );

    final closeBox =
        hitTester.closeKey('tab-a').currentContext!.findRenderObject() as RenderBox;
    final closeCenter = closeBox.localToGlobal(
      closeBox.size.center(Offset.zero),
    );
    expect(
      hitTester.hitTest(
        closeCenter,
        tabIds: tabIds,
        canCloseTab: true,
      )?.target,
      TabSwitcherHitTarget.closeTab,
    );

    final newTabBox =
        hitTester.newTabKey.currentContext!.findRenderObject() as RenderBox;
    final newTabCenter = newTabBox.localToGlobal(
      newTabBox.size.center(Offset.zero),
    );
    expect(
      hitTester.hitTest(
        newTabCenter,
        tabIds: tabIds,
        canCloseTab: true,
      )?.target,
      TabSwitcherHitTarget.newTab,
    );
  });
}
