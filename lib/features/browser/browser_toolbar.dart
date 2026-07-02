import 'package:flutter/material.dart';

import 'browser_state.dart';
import 'toolbar_hit_tester.dart';

class BrowserToolbar extends StatelessWidget {
  const BrowserToolbar({
    super.key,
    required this.state,
    required this.urlController,
    required this.urlFocusNode,
    required this.hitTester,
    required this.tabCount,
    required this.onSubmit,
    required this.onBack,
    required this.onForward,
    required this.onReload,
    required this.onHome,
    required this.onBookmark,
    required this.isBookmarked,
  });

  final BrowserState state;
  final TextEditingController urlController;
  final FocusNode urlFocusNode;
  final ToolbarHitTester hitTester;
  final int tabCount;
  final ValueChanged<String> onSubmit;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onReload;
  final VoidCallback onHome;
  final VoidCallback onBookmark;
  final bool isBookmarked;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IgnorePointer(
      child: Material(
        elevation: 2,
        color: colorScheme.surfaceContainerHighest,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                IconButton(
                  key: hitTester.backKey,
                  tooltip: '后退',
                  onPressed: state.canGoBack ? () {} : null,
                  icon: const Icon(Icons.arrow_back),
                ),
                IconButton(
                  key: hitTester.forwardKey,
                  tooltip: '前进',
                  onPressed: state.canGoForward ? () {} : null,
                  icon: const Icon(Icons.arrow_forward),
                ),
                IconButton(
                  key: hitTester.reloadKey,
                  tooltip: '刷新',
                  onPressed: () {},
                  icon: state.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
                IconButton(
                  key: hitTester.homeKey,
                  tooltip: '主页',
                  onPressed: () {},
                  icon: const Icon(Icons.home),
                ),
                IconButton(
                  key: hitTester.bookmarkKey,
                  tooltip: '收藏当前页面',
                  onPressed: () {},
                  icon: Icon(isBookmarked ? Icons.star : Icons.star_border),
                ),
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colorScheme.outline),
                    ),
                    child: TextField(
                      key: hitTester.urlFieldKey,
                      controller: urlController,
                      focusNode: urlFocusNode,
                      textInputAction: TextInputAction.go,
                      decoration: const InputDecoration(
                        hintText: '输入网址',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      onSubmitted: onSubmit,
                    ),
                  ),
                ),
                IconButton(
                  key: hitTester.zoomOutKey,
                  tooltip: '缩小',
                  visualDensity: VisualDensity.compact,
                  iconSize: 20,
                  onPressed: () {},
                  icon: const Icon(Icons.zoom_out),
                ),
                IconButton(
                  key: hitTester.zoomInKey,
                  tooltip: '放大',
                  visualDensity: VisualDensity.compact,
                  iconSize: 20,
                  onPressed: () {},
                  icon: const Icon(Icons.zoom_in),
                ),
                const SizedBox(width: 12),
                _TabCountButton(
                  key: hitTester.tabsButtonKey,
                  count: tabCount,
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabCountButton extends StatelessWidget {
  const _TabCountButton({
    super.key,
    required this.count,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: colorScheme.onSurface,
          width: 1.5,
        ),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 11,
              height: 1,
            ),
      ),
    );
  }
}
