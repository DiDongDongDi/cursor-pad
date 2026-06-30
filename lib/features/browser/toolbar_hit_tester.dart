import 'package:flutter/material.dart';

enum ToolbarHitTarget {
  back,
  forward,
  reload,
  home,
  bookmark,
  urlField,
}

class ToolbarHitTester {
  final GlobalKey backKey = GlobalKey();
  final GlobalKey forwardKey = GlobalKey();
  final GlobalKey reloadKey = GlobalKey();
  final GlobalKey homeKey = GlobalKey();
  final GlobalKey bookmarkKey = GlobalKey();
  final GlobalKey urlFieldKey = GlobalKey();

  ToolbarHitTarget? hitTest(Offset globalPosition) {
    for (final entry in _targets) {
      final box = entry.key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) {
        continue;
      }
      final topLeft = box.localToGlobal(Offset.zero);
      final rect = topLeft & box.size;
      if (rect.contains(globalPosition)) {
        return entry.target;
      }
    }
    return null;
  }

  List<({GlobalKey key, ToolbarHitTarget target})> get _targets => [
        (key: backKey, target: ToolbarHitTarget.back),
        (key: forwardKey, target: ToolbarHitTarget.forward),
        (key: reloadKey, target: ToolbarHitTarget.reload),
        (key: homeKey, target: ToolbarHitTarget.home),
        (key: bookmarkKey, target: ToolbarHitTarget.bookmark),
        (key: urlFieldKey, target: ToolbarHitTarget.urlField),
      ];
}
