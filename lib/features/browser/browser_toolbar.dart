import 'package:flutter/material.dart';

import 'browser_state.dart';

class BrowserToolbar extends StatelessWidget {
  const BrowserToolbar({
    super.key,
    required this.state,
    required this.urlController,
    required this.urlFocusNode,
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
  final ValueChanged<String> onSubmit;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onReload;
  final VoidCallback onHome;
  final VoidCallback onBookmark;
  final bool isBookmarked;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              IconButton(
                tooltip: '后退',
                onPressed: state.canGoBack ? onBack : null,
                icon: const Icon(Icons.arrow_back),
              ),
              IconButton(
                tooltip: '前进',
                onPressed: state.canGoForward ? onForward : null,
                icon: const Icon(Icons.arrow_forward),
              ),
              IconButton(
                tooltip: '刷新',
                onPressed: onReload,
                icon: state.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: '主页',
                onPressed: onHome,
                icon: const Icon(Icons.home),
              ),
              IconButton(
                tooltip: '收藏当前页面',
                onPressed: onBookmark,
                icon: Icon(isBookmarked ? Icons.star : Icons.star_border),
              ),
              Expanded(
                child: TextField(
                  controller: urlController,
                  focusNode: urlFocusNode,
                  textInputAction: TextInputAction.go,
                  decoration: InputDecoration(
                    hintText: '输入网址',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onSubmitted: onSubmit,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
