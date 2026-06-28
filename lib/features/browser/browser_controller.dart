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

  void Function(BrowserState state)? onStateChanged;
  InAppWebViewController? get webViewController => _webViewController;

  static bool isBookmarksHomeUrl(String url) {
    return url == BrowserSettings.bookmarksHomeUrl;
  }

  void attach(InAppWebViewController controller) {
    _webViewController = controller;
  }

  void _emit(BrowserState next) {
    state = next;
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

    _emit(state.copyWith(currentUrl: normalized, isLoading: true));
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
      ),
    );

    await controller.loadData(
      data: html,
      baseUrl: WebUri(BrowserSettings.bookmarksHomeUrl),
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
    final nextUrl = url?.toString() ?? state.currentUrl;
    if (isBookmarksHomeUrl(nextUrl)) {
      _emit(
        state.copyWith(
          currentUrl: BrowserSettings.bookmarksHomeUrl,
          title: '收藏夹',
          isLoading: true,
          progress: 0,
        ),
      );
      return;
    }

    _emit(
      state.copyWith(
        currentUrl: nextUrl,
        isLoading: true,
        progress: 0,
      ),
    );
  }

  Future<void> onLoadStop(WebUri? url) async {
    await updateNavigationState();
    _emit(state.copyWith(isLoading: false, progress: 100));
    await syncViewport(_lastViewportWidth, _lastViewportHeight);
  }

  void onProgressChanged(int progress) {
    _emit(state.copyWith(progress: progress, isLoading: progress < 100));
  }

  double _lastViewportWidth = 0;
  double _lastViewportHeight = 0;

  Future<void> syncViewport(double width, double height) async {
    if (width <= 0 || height <= 0) {
      return;
    }

    _lastViewportWidth = width;
    _lastViewportHeight = height;

    await _webViewController?.evaluateJavascript(
      source:
          'window.__cursorPad && window.__cursorPad.setNativeSize($width, $height);',
    );
    await _webViewController?.evaluateJavascript(
      source:
          'window.__cursorPadDesktop && window.__cursorPadDesktop.setViewportWidth(${settings.viewportWidth}, $width);',
    );
  }

  Future<void> syncBridgeSize(double width, double height) async {
    await syncViewport(width, height);
  }

  Future<void> moveCursor(double x, double y) async {
    await _webViewController?.evaluateJavascript(
      source: 'window.__cursorPad && window.__cursorPad.moveTo($x, $y);',
    );
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
