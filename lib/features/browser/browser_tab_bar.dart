import 'package:flutter/material.dart';

import 'browser_tab.dart';
import 'tab_bar_hit_tester.dart';

class BrowserTabBar extends StatelessWidget {
  const BrowserTabBar({
    super.key,
    required this.tabs,
    required this.activeIndex,
    required this.hitTester,
    required this.canCloseTab,
  });

  final List<BrowserTab> tabs;
  final int activeIndex;
  final TabBarHitTester hitTester;
  final bool canCloseTab;

  static const double height = 36;

  @override
  Widget build(BuildContext context) {
    hitTester.pruneKeys(tabs.map((tab) => tab.id).toSet());
    final colorScheme = Theme.of(context).colorScheme;

    return IgnorePointer(
      child: Material(
        color: colorScheme.surfaceContainerHigh,
        child: SizedBox(
          height: height,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  _TabChip(
                    key: hitTester.tabKey(tabs[i].id),
                    tab: tabs[i],
                    selected: i == activeIndex,
                    showClose: canCloseTab,
                    closeKey: hitTester.closeKey(tabs[i].id),
                  ),
                Container(
                  key: hitTester.newTabKey,
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(left: 2),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Icon(
                    Icons.add,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    super.key,
    required this.tab,
    required this.selected,
    required this.showClose,
    required this.closeKey,
  });

  final BrowserTab tab;
  final bool selected;
  final bool showClose;
  final GlobalKey closeKey;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(right: 4),
      constraints: const BoxConstraints(maxWidth: 180, minWidth: 80),
      decoration: BoxDecoration(
        color: selected
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.5)
              : colorScheme.outlineVariant,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tab.isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              ),
            ),
          Flexible(
            child: Text(
              tab.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (showClose) ...[
            const SizedBox(width: 4),
            SizedBox(
              key: closeKey,
              width: 20,
              height: 20,
              child: Icon(
                Icons.close,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
