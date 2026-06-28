import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../bookmarks/bookmark_repository.dart';
import '../bookmarks/bookmarks_html.dart';
import '../../features/settings/browser_settings.dart';
import 'browser_state.dart';

class BrowserController {
  BrowserController({
    BrowserSettings? settings,
    BookmarkRepository? bookmarkRepository,
  })  : settings = settings ?? const BrowserSettings(),
        bookmarkRepository = bookmarkRepository ?? BookmarkRepository();

  final BrowserSettings settings;
  final BookmarkRepository bookmarkRepository;
  InAppWebViewController? _webViewController;

  BrowserState state = const BrowserState();

  final ValueNotifier<int> progressNotifier = ValueNotifier(0);
  final ValueNotifier<BrowserState> stateNotifier =
      ValueNotifier(const BrowserState());

  bool _pendingInitialBookmarksLoad = true;
  Timer? _cursorSyncTimer;
  double? _pendingCursorX;
  double? _pendingCursorY;
  double _lastSyncedWidth = 0;
  double _lastSyncedHeight = 0;

  void Function(BrowserState state)? onStateChanged;
  InAppWebViewController? get webViewController => _webViewController;

  static bool isBookmarksHomeUrl(String url) {
    return url == BrowserSettings.bookmarksHomeUrl;
  }

  static bool _isAboutBlank(String url) {
    return url.isEmpty || url.startsWith('about:blank');
  }

  static bool _isBookmarksPageUrl(String url) {
    return isBookmarksHomeUrl(url) || url.contains('localhost/bookmarks');
  }

  void attach(InAppWebViewController controller) {
    _webViewController = controller;
    unawaited(_loadInitialBookmarksIfNeeded());
  }

  Future<void> _loadInitialBookmarksIfNeeded() async {
    if (!_pendingInitialBookmarksLoad || _webViewController == null) {
      return;
    }

    final url = (await _webViewController?.getUrl())?.toString() ?? '';
    if (!_isAboutBlank(url)) {
      return;
    }

    _pendingInitialBookmarksLoad = false;
    await loadBookmarksHome();
  }

  void _emit(BrowserState next) {
    state = next;
    if (stateNotifier.value != next) {
      stateNotifier.value = next;
    }
    onStateChanged?.call(next);
  }

  Future<void> loadUrl(String url) async {
    final normalized = _normalizeUrl(url);
    if (isBookmarksHomeUrl(normalized)) {
      await loadBookmarksHome();
      return;
    }

    final controller = _webViewController;
    if (controller == null) {
      return;
    }

    _emit(
      state.copyWith(
        currentUrl: normalized,
        isLoading: true,
        progress: 0,
      ),
    );
    progressNotifier.value = 0;

    await controller.loadUrl(
      urlRequest: URLRequest(url: WebUri(normalized)),
    );
  }

  Future<void> loadBookmarksHome() async {
    final controller = _webViewController;
    if (controller == null) {
      return;
    }

    final bookmarks = await bookmarkRepository.getAll();
    final html = BookmarksHtml.generate(bookmarks);

    _emit(
      state.copyWith(
        currentUrl: BrowserSettings.bookmarksHomeUrl,
        title: '收藏夹',
        isLoading: true,
        progress: 0,
      ),
    );
    progressNotifier.value = 0;

    await controller.loadData(
      data: html,
      baseUrl: WebUri('https://localhost/bookmarks'),
      mimeType: 'text/html',
      encoding: 'utf-8',
    );
  }

  Future<void> reload() async {
    if (isBookmarksHomeUrl(state.currentUrl)) {
      await loadBookmarksHome();
      return;
    }
    await _webViewController?.reload();
  }

  Future<void> goBack() async {
    if (await _webViewController?.canGoBack() ?? false) {
      await _webViewController?.goBack();
    }
  }

  Future<void> goForward() async {
    if (await _webViewController?.canGoForward() ?? false) {
      await _webViewController?.goForward();
    }
  }

  Future<void> updateNavigationState() async {
    final controller = _webViewController;
    if (controller == null) {
      return;
    }

    if (isBookmarksHomeUrl(state.currentUrl)) {
      _emit(
        state.copyWith(
          title: '收藏夹',
          canGoBack: await controller.canGoBack(),
          canGoForward: await controller.canGoForward(),
        ),
      );
      return;
    }

    final url = (await controller.getUrl())?.toString() ?? state.currentUrl;
    if (_isBookmarksPageUrl(url)) {
      return;
    }

    final title = await controller.getTitle() ?? state.title;
    final canGoBack = await controller.canGoBack();
    final canGoForward = await controller.canGoForward();

    _emit(
      state.copyWith(
        currentUrl: url,
        title: title,
        canGoBack: canGoBack,
        canGoForward: canGoForward,
      ),
    );
  }

  void onLoadStart(WebUri? url) {
    final nextUrl = url?.toString() ?? '';
    if (_isAboutBlank(nextUrl)) {
      return;
    }

    if (_isBookmarksPageUrl(nextUrl)) {
      _emit(
        state.copyWith(
          currentUrl: BrowserSettings.bookmarksHomeUrl,
          title: '收藏夹',
          isLoading: true,
          progress: 0,
        ),
      );
      progressNotifier.value = 0;
      return;
    }

    _emit(
      state.copyWith(
        currentUrl: nextUrl,
        isLoading: true,
        progress: 0,
      ),
    );
    progressNotifier.value = 0;
  }

  Future<void> onLoadStop(WebUri? url) async {
    final urlString = url?.toString() ?? '';

    if (_isAboutBlank(urlString)) {
      if (_pendingInitialBookmarksLoad && _webViewController != null) {
        _pendingInitialBookmarksLoad = false;
        await loadBookmarksHome();
      }
      return;
    }

    if (_isBookmarksPageUrl(urlString)) {
      progressNotifier.value = 100;
      _emit(
        state.copyWith(
          currentUrl: BrowserSettings.bookmarksHomeUrl,
          title: '收藏夹',
          isLoading: false,
          progress: 100,
        ),
      );
      await syncViewport(_lastViewportWidth, _lastViewportHeight);
      return;
    }

    await updateNavigationState();
    progressNotifier.value = 100;
    _emit(state.copyWith(isLoading: false, progress: 100));
    await syncViewport(_lastViewportWidth, _lastViewportHeight);
  }

  void onProgressChanged(int progress) {
    if (progressNotifier.value != progress) {
      progressNotifier.value = progress;
    }
    final loading = progress < 100;
    if (state.isLoading == loading) {
      return;
    }
    _emit(state.copyWith(isLoading: loading, progress: progress));
  }

  double _lastViewportWidth = 0;
  double _lastViewportHeight = 0;

  Future<void> syncViewport(double width, double height) async {
    if (width <= 0 || height <= 0 || _webViewController == null) {
      return;
    }
    if (width == _lastSyncedWidth && height == _lastSyncedHeight) {
      return;
    }

    _lastViewportWidth = width;
    _lastViewportHeight = height;
    _lastSyncedWidth = width;
    _lastSyncedHeight = height;

    try {
      await _webViewController?.evaluateJavascript(
        source:
            'window.__cursorPad && window.__cursorPad.setNativeSize($width, $height);',
      );
      await _webViewController?.evaluateJavascript(
        source:
            'window.__cursorPadDesktop && window.__cursorPadDesktop.setViewportWidth(${settings.viewportWidth}, $width);',
      );
    } catch (_) {
      // WebView may not be ready yet during platform view init.
    }
  }

  Future<void> syncBridgeSize(double width, double height) async {
    await syncViewport(width, height);
  }

  Future<void> moveCursor(double x, double y) async {
    _pendingCursorX = x;
    _pendingCursorY = y;
    if (_cursorSyncTimer != null) {
      return;
    }
    _cursorSyncTimer = Timer(const Duration(milliseconds: 16), () async {
      _cursorSyncTimer = null;
      await _flushPendingCursor();
    });
  }

  Future<void> moveCursorImmediate(double x, double y) async {
    _pendingCursorX = x;
    _pendingCursorY = y;
    _cursorSyncTimer?.cancel();
    _cursorSyncTimer = null;
    await _flushPendingCursor();
  }

  Future<void> _flushPendingCursor() async {
    final px = _pendingCursorX;
    final py = _pendingCursorY;
    if (px == null || py == null || _webViewController == null) {
      return;
    }
    try {
      await _webViewController?.evaluateJavascript(
        source: 'window.__cursorPad && window.__cursorPad.moveTo($px, $py);',
      );
    } catch (_) {
      // WebView may be reloading.
    }
  }

  void dispose() {
    _cursorSyncTimer?.cancel();
    progressNotifier.dispose();
    stateNotifier.dispose();
  }

  Future<void> click({int button = 0}) async {
    await _webViewController?.evaluateJavascript(
      source: 'window.__cursorPad && window.__cursorPad.click($button);',
    );
  }

  Future<void> doubleClick() async {
    await _webViewController?.evaluateJavascript(
      source: 'window.__cursorPad && window.__cursorPad.doubleClick();',
    );
  }

  Future<void> scroll(double deltaX, double deltaY) async {
    await _webViewController?.evaluateJavascript(
      source:
          'window.__cursorPad && window.__cursorPad.scroll($deltaX, $deltaY);',
    );
  }

  Future<void> handleDeleteBookmark(String id) async {
    await bookmarkRepository.remove(id);
    if (isBookmarksHomeUrl(state.currentUrl)) {
      await loadBookmarksHome();
    }
  }

  String _normalizeUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return settings.homeUrl;
    }
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        isBookmarksHomeUrl(trimmed)) {
      return trimmed;
    }
    return 'https://$trimmed';
  }
}
