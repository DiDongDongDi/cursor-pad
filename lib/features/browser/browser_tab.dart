import 'package:flutter/material.dart';

import '../cursor/cursor_state.dart';
import 'browser_controller.dart';

class BrowserTab {
  BrowserTab({
    required this.id,
    required this.controller,
    CursorState? cursorState,
    this.webViewKey = 0,
    this.webViewReady = false,
    this.initialBookmarksHtml,
  }) : cursorState = cursorState ?? CursorState(position: Offset.zero);

  final String id;
  final BrowserController controller;
  CursorState cursorState;
  int webViewKey;
  bool webViewReady;
  String? initialBookmarksHtml;

  String get displayTitle {
    final title = controller.state.title.trim();
    if (title.isNotEmpty) {
      return title;
    }
    final url = controller.state.currentUrl;
    if (url.isEmpty) {
      return '新标签页';
    }
    return _truncateUrl(url);
  }

  bool get isLoading => controller.state.isLoading;

  static String _truncateUrl(String url, {int maxLength = 24}) {
    if (url.length <= maxLength) {
      return url;
    }
    return '${url.substring(0, maxLength - 1)}…';
  }
}
