import 'package:flutter/material.dart';

enum TabSwitcherHitTarget {
  tab,
  closeTab,
  newTab,
}

class TabSwitcherHitResult {
  const TabSwitcherHitResult({
    required this.target,
    this.tabIndex,
  });

  final TabSwitcherHitTarget target;
  final int? tabIndex;
}

class TabSwitcherHitTester {
  final GlobalKey newTabKey = GlobalKey();
  final Map<String, GlobalKey> _tabKeys = {};
  final Map<String, GlobalKey> _closeKeys = {};

  GlobalKey tabKey(String tabId) =>
      _tabKeys.putIfAbsent(tabId, GlobalKey.new);

  GlobalKey closeKey(String tabId) =>
      _closeKeys.putIfAbsent(tabId, GlobalKey.new);

  void pruneKeys(Set<String> activeTabIds) {
    _tabKeys.removeWhere((id, _) => !activeTabIds.contains(id));
    _closeKeys.removeWhere((id, _) => !activeTabIds.contains(id));
  }

  TabSwitcherHitResult? hitTest(
    Offset globalPosition, {
    required List<String> tabIds,
    required bool canCloseTab,
  }) {
    if (canCloseTab) {
      for (var i = 0; i < tabIds.length; i++) {
        final closeKey = _closeKeys[tabIds[i]];
        if (closeKey != null && _contains(closeKey, globalPosition)) {
          return TabSwitcherHitResult(
            target: TabSwitcherHitTarget.closeTab,
            tabIndex: i,
          );
        }
      }
    }

    for (var i = 0; i < tabIds.length; i++) {
      final tabKey = _tabKeys[tabIds[i]];
      if (tabKey != null && _contains(tabKey, globalPosition)) {
        return TabSwitcherHitResult(
          target: TabSwitcherHitTarget.tab,
          tabIndex: i,
        );
      }
    }

    if (_contains(newTabKey, globalPosition)) {
      return const TabSwitcherHitResult(target: TabSwitcherHitTarget.newTab);
    }

    return null;
  }

  bool _contains(GlobalKey key, Offset globalPosition) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return false;
    }
    final topLeft = box.localToGlobal(Offset.zero);
    final rect = topLeft & box.size;
    return rect.contains(globalPosition);
  }
}
