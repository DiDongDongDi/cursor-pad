import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../bookmarks/bookmark_repository.dart';
import '../bookmarks/bookmarks_html.dart';
import '../../features/settings/browser_settings.dart';
import '../../platform/webview_touch.dart';
import 'browser_state.dart';
import 'selection_info.dart';

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
  String? _pendingNavigationUrl;
  String? _initialBookmarksHtml;
  int _recreateCount = 0;
  DateTime? _lastRecreateAt;
  Timer? _cursorSyncTimer;
  double? _pendingCursorX;
  double? _pendingCursorY;
  double _lastSyncedWidth = 0;
  double _lastSyncedHeight = 0;
  bool selectionArmed = false;

  void Function(BrowserState state)? onStateChanged;
  VoidCallback? onPageReady;
  VoidCallback? onWebViewNeedsRecreate;
  InAppWebViewController? get webViewController => _webViewController;
  String? get initialBookmarksHtml => _initialBookmarksHtml;

  Future<void> prepareInitialBookmarksHtml() async {
    if (_initialBookmarksHtml != null) {
      return;
    }
    final bookmarks = await bookmarkRepository.getAll();
    _initialBookmarksHtml = BookmarksHtml.generate(bookmarks);
  }

  static bool isBookmarksHomeUrl(String url) {
    return url == BrowserSettings.bookmarksHomeUrl;
  }

  static bool _isAboutBlank(String url) {
    return url.isEmpty || url.startsWith('about:blank');
  }

  static bool _isBookmarksPageUrl(String url) {
    return isBookmarksHomeUrl(url) || url.contains('localhost/bookmarks');
  }

  void attach(InAppWebViewController controller, {bool skipInitialLoad = false}) {
    _webViewController = controller;

    final pending = _pendingNavigationUrl;
    if (pending != null) {
      _pendingNavigationUrl = null;
      if (isBookmarksHomeUrl(pending) || _isAboutBlank(pending)) {
        unawaited(loadBookmarksHome());
      } else {
        unawaited(loadUrl(pending));
      }
      return;
    }

    if (!skipInitialLoad) {
      unawaited(_loadInitialBookmarksIfNeeded());
      return;
    }

    _emit(
      state.copyWith(
        currentUrl: BrowserSettings.bookmarksHomeUrl,
        title: '收藏夹',
        isLoading: true,
        progress: 0,
      ),
    );
    progressNotifier.value = 0;
  }

  void detachWebView() {
    _webViewController = null;
  }

  Future<void> _loadInitialBookmarksIfNeeded() async {
    if (!_pendingInitialBookmarksLoad || _webViewController == null) {
      return;
    }

    final url = (await _webViewController?.getUrl())?.toString() ?? '';
    if (_isBookmarksPageUrl(url)) {
      _pendingInitialBookmarksLoad = false;
      progressNotifier.value = 100;
      _emit(
        state.copyWith(
          currentUrl: BrowserSettings.bookmarksHomeUrl,
          title: '收藏夹',
          isLoading: false,
          progress: 100,
        ),
      );
      return;
    }
    if (!_isAboutBlank(url)) {
      return;
    }

    _pendingInitialBookmarksLoad = false;
    await loadBookmarksHome();
  }

  void handleRenderProcessGone() {
    final now = DateTime.now();
    if (_lastRecreateAt != null &&
        now.difference(_lastRecreateAt!) < const Duration(seconds: 2)) {
      _recreateCount++;
    } else {
      _recreateCount = 1;
    }
    _lastRecreateAt = now;

    if (_recreateCount > 5) {
      if (kDebugMode) {
        debugPrint('WebView recreate throttled after repeated crashes');
      }
      return;
    }

    final url = state.currentUrl;
    if (isBookmarksHomeUrl(url) || _isAboutBlank(url)) {
      _pendingNavigationUrl = BrowserSettings.bookmarksHomeUrl;
    } else {
      _pendingNavigationUrl = url;
    }

    detachWebView();
    onWebViewNeedsRecreate?.call();
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

    _pendingInitialBookmarksLoad = false;

    _emit(
      state.copyWith(
        currentUrl: normalized,
        isLoading: true,
        progress: 0,
      ),
    );
    progressNotifier.value = 0;

    final controller = _webViewController;
    if (controller == null) {
      _pendingNavigationUrl = normalized;
      return;
    }

    try {
      await controller.loadUrl(
        urlRequest: URLRequest(url: WebUri(normalized)),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('loadUrl failed: $e');
      }
    }
  }

  Future<void> loadBookmarksHome() async {
    _emit(
      state.copyWith(
        currentUrl: BrowserSettings.bookmarksHomeUrl,
        title: '收藏夹',
        isLoading: true,
        progress: 0,
      ),
    );
    progressNotifier.value = 0;

    final controller = _webViewController;
    if (controller == null) {
      _pendingNavigationUrl = BrowserSettings.bookmarksHomeUrl;
      return;
    }

    final bookmarks = await bookmarkRepository.getAll();
    final html = BookmarksHtml.generate(bookmarks);

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
      if (_pendingInitialBookmarksLoad &&
          _webViewController != null &&
          _pendingNavigationUrl == null &&
          (state.currentUrl.isEmpty ||
              isBookmarksHomeUrl(state.currentUrl) ||
              _isAboutBlank(state.currentUrl))) {
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
      await syncViewport(_lastViewportWidth, _lastViewportHeight, force: true);
      await applyDefaultZoom();
      onPageReady?.call();
      return;
    }

    await updateNavigationState();
    progressNotifier.value = 100;
    _emit(state.copyWith(isLoading: false, progress: 100));
    await syncViewport(_lastViewportWidth, _lastViewportHeight, force: true);
    await applyDefaultZoom();
    onPageReady?.call();
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

  Future<void> syncViewport(
    double width,
    double height, {
    bool force = false,
  }) async {
    if (width <= 0 || height <= 0 || _webViewController == null) {
      return;
    }
    if (!force &&
        width == _lastSyncedWidth &&
        height == _lastSyncedHeight) {
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
            'window.__cursorPadDesktop && window.__cursorPadDesktop.setViewportWidth(${settings.viewportWidth}, $width, $height);',
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

  bool _parseActivateAtNeedsIme(dynamic raw) {
    if (raw == null) {
      return false;
    }
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is Map && decoded['needsIme'] == true) {
        return true;
      }
    } catch (_) {
      // Malformed JS return value.
    }
    return false;
  }

  Future<void> blurWebInput() async {
    try {
      await _webViewController?.evaluateJavascript(
        source: 'window.__cursorPad && window.__cursorPad.blurFocusedInput();',
      );
    } catch (_) {
      // WebView may be reloading.
    }
  }

  Future<void> dismissWebKeyboard() async {
    await blurWebInput();
    await WebViewTouchSimulator.hideIme();
  }

  _LinkInfo? _parseLinkInfo(dynamic raw) {
    if (raw == null) {
      return null;
    }
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map) {
        return null;
      }
      final href = decoded['href']?.toString();
      final newTab = decoded['newTab'] == true;
      if (!newTab || href == null || href.isEmpty) {
        return null;
      }
      return _LinkInfo(href: href, newTab: newTab);
    } catch (_) {
      return null;
    }
  }

  Future<void> click({int button = 0, bool skipNativeTouch = false}) async {
    final px = _pendingCursorX;
    final py = _pendingCursorY;
    final xArg = px ?? 'null';
    final yArg = py ?? 'null';

    if (button == 0 &&
        !skipNativeTouch &&
        !selectionArmed &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        px != null &&
        py != null) {
      final linkRaw = await _webViewController?.evaluateJavascript(
        source:
            'JSON.stringify(window.__cursorPad && window.__cursorPad.linkInfoAt($xArg, $yArg));',
      );
      final linkInfo = _parseLinkInfo(linkRaw);
      if (linkInfo != null) {
        final escapedUrl = jsonEncode(linkInfo.href);
        await _webViewController?.evaluateJavascript(
          source:
              'window.__cursorPad && window.__cursorPad.openLinkViaHost($escapedUrl, true);',
        );
        return;
      }

      await WebViewTouchSimulator.clickAt(px, py);
      // activateAt only detects IME need; native touch already activated the target.
      final raw = await _webViewController?.evaluateJavascript(
        source:
            'JSON.stringify(window.__cursorPad && window.__cursorPad.activateAt($xArg, $yArg) || {needsIme:false});',
      );
      if (_parseActivateAtNeedsIme(raw)) {
        await WebViewTouchSimulator.showIme();
      } else {
        await dismissWebKeyboard();
      }
      return;
    }

    await _webViewController?.evaluateJavascript(
      source:
          'window.__cursorPad && window.__cursorPad.click($button, $xArg, $yArg);',
    );
  }

  Future<void> doubleClick({bool firstClickAlreadySent = false}) async {
    final px = _pendingCursorX;
    final py = _pendingCursorY;
    final xArg = px ?? 'null';
    final yArg = py ?? 'null';
    final skipFirstArg = firstClickAlreadySent ? 'true' : 'false';

    if (!selectionArmed &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        px != null &&
        py != null) {
      if (!firstClickAlreadySent) {
        await WebViewTouchSimulator.clickAt(px, py);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await WebViewTouchSimulator.clickAt(px, py);
    }

    await _webViewController?.evaluateJavascript(
      source:
          'window.__cursorPad && window.__cursorPad.doubleClick($xArg, $yArg, $skipFirstArg);',
    );
  }

  Future<void> scroll(double deltaX, double deltaY) async {
    await _webViewController?.evaluateJavascript(
      source:
          'window.__cursorPad && window.__cursorPad.scroll($deltaX, $deltaY);',
    );
  }

  Future<SelectionInfo?> _parseSelectionResult(dynamic raw) async {
    if (raw == null) {
      return null;
    }
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is Map) {
        return SelectionInfo.tryParse(decoded.cast<String, dynamic>());
      }
    } catch (_) {
      // Malformed JS return value.
    }
    return null;
  }

  Future<SelectionInfo?> _evaluateSelection(String source) async {
    try {
      final raw = await _webViewController?.evaluateJavascript(source: source);
      return _parseSelectionResult(raw);
    } catch (_) {
      return null;
    }
  }

  String _cursorArgs() {
    final px = _pendingCursorX;
    final py = _pendingCursorY;
    final xArg = px ?? 'null';
    final yArg = py ?? 'null';
    return '$xArg, $yArg';
  }

  Future<void> beginSelection() async {
    final px = _pendingCursorX;
    final py = _pendingCursorY;
    final args = _cursorArgs();
    final useNativeDrag = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        px != null &&
        py != null;
    if (useNativeDrag) {
      await WebViewTouchSimulator.dragDown(px, py);
    }
    final skipSynthetic = useNativeDrag ? 'true' : 'false';
    await _webViewController?.evaluateJavascript(
      source:
          'window.__cursorPad && window.__cursorPad.beginSelection($args, $skipSynthetic);',
    );
  }

  Future<void> updateSelectionAt(double x, double y) async {
    _pendingCursorX = x;
    _pendingCursorY = y;
    final useNativeDrag =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (useNativeDrag) {
      await WebViewTouchSimulator.dragMove(x, y);
    }
    await _webViewController?.evaluateJavascript(
      source:
          'window.__cursorPad && window.__cursorPad.updateSelection($x, $y);',
    );
  }

  Future<void> updateSelection() async {
    final px = _pendingCursorX;
    final py = _pendingCursorY;
    if (px == null || py == null) {
      return;
    }
    await updateSelectionAt(px, py);
  }

  Future<SelectionInfo?> endSelection() async {
    final px = _pendingCursorX;
    final py = _pendingCursorY;
    final useNativeDrag = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        px != null &&
        py != null;
    if (useNativeDrag) {
      await WebViewTouchSimulator.dragUp(px, py);
    }
    final args = _cursorArgs();
    return _evaluateSelection(
      'JSON.stringify(window.__cursorPad && window.__cursorPad.endSelection($args) || {text:"",isCollapsed:true,length:0});',
    );
  }

  Future<SelectionInfo?> cancelSelection() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final px = _pendingCursorX;
      final py = _pendingCursorY;
      if (px != null && py != null) {
        await WebViewTouchSimulator.dragUp(px, py);
      }
      await _webViewController?.evaluateJavascript(
        source: 'window.__cursorPad && window.__cursorPad.cancelSelection();',
      );
      return getSelectedText();
    }
    return _evaluateSelection(
      'JSON.stringify(window.__cursorPad && window.__cursorPad.cancelSelection() || {text:"",isCollapsed:true,length:0});',
    );
  }

  Future<SelectionInfo?> selectWordAtPoint() {
    final args = _cursorArgs();
    return _evaluateSelection(
      'JSON.stringify(window.__cursorPad && window.__cursorPad.selectWordAt($args) || {text:"",isCollapsed:true,length:0});',
    );
  }

  Future<SelectionInfo?> setSelectionRange(
    double x1,
    double y1,
    double x2,
    double y2,
  ) {
    return _evaluateSelection(
      'JSON.stringify(window.__cursorPad && window.__cursorPad.setSelectionRange($x1, $y1, $x2, $y2) || {text:"",isCollapsed:true,length:0});',
    );
  }

  Future<SelectionInfo?> getSelectedText() {
    return _evaluateSelection(
      'JSON.stringify(window.__cursorPad && window.__cursorPad.getSelectedText() || {text:"",isCollapsed:true,length:0});',
    );
  }

  Future<SelectionInfo?> clearSelection() {
    return _evaluateSelection(
      'JSON.stringify(window.__cursorPad && window.__cursorPad.clearSelection() || {text:"",isCollapsed:true,length:0});',
    );
  }

  Future<SelectionInfo?> selectAll() {
    return _evaluateSelection(
      'JSON.stringify(window.__cursorPad && window.__cursorPad.selectAll() || {text:"",isCollapsed:true,length:0});',
    );
  }

  Future<void> zoomBy(double scaleFactor) async {
    if (scaleFactor <= 0 || scaleFactor == 1) {
      return;
    }
    await _webViewController?.evaluateJavascript(
      source:
          'window.__cursorPadDesktop && window.__cursorPadDesktop.zoomBy($scaleFactor);',
    );
  }

  Future<void> applyDefaultZoom() async {
    await _webViewController?.evaluateJavascript(
      source:
          'window.__cursorPadDesktop && window.__cursorPadDesktop.applyDefaultZoom();',
    );
  }

  Future<void> resetZoom() async {
    await applyDefaultZoom();
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

class _LinkInfo {
  const _LinkInfo({required this.href, required this.newTab});

  final String href;
  final bool newTab;
}
