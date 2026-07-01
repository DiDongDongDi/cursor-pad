import 'package:flutter/material.dart';

import 'browser_tab.dart';
import 'tab_switcher_hit_tester.dart';

class BrowserTabSwitcher extends StatelessWidget {
  const BrowserTabSwitcher({
    super.key,
    required this.tabs,
    required this.activeIndex,
    required this.hitTester,
    required this.canCloseTab,
  });

  final List<BrowserTab> tabs;
  final int activeIndex;
  final TabSwitcherHitTester hitTester;
  final bool canCloseTab;

  @override
  Widget build(BuildContext context) {
    hitTester.pruneKeys(tabs.map((tab) => tab.id).toSet());
    final colorScheme = Theme.of(context).colorScheme;

    return IgnorePointer(
      child: Material(
        color: colorScheme.surfaceContainerHigh,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                itemCount: tabs.length,
                itemBuilder: (context, index) {
                  return _TabCard(
                    key: hitTester.tabKey(tabs[index].id),
                    tab: tabs[index],
                    selected: index == activeIndex,
                    showClose: canCloseTab,
                    closeKey: hitTester.closeKey(tabs[index].id),
                  );
                },
              ),
            ),
            Container(
              key: hitTester.newTabKey,
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '新建标签页',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabCard extends StatelessWidget {
  const _TabCard({
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
    final url = tab.controller.state.currentUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: selected
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.6)
              : colorScheme.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          if (tab.isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                Icons.language,
                size: 22,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tab.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                ),
                if (url.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _truncateUrl(url),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (showClose) ...[
            const SizedBox(width: 8),
            SizedBox(
              key: closeKey,
              width: 28,
              height: 28,
              child: Icon(
                Icons.close,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _truncateUrl(String url, {int maxLength = 40}) {
    if (url.length <= maxLength) {
      return url;
    }
    return '${url.substring(0, maxLength - 1)}…';
  }
}
