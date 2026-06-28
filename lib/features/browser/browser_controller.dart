import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../features/settings/browser_settings.dart';
import 'browser_state.dart';

class BrowserController {
  BrowserController({BrowserSettings? settings})
      : settings = settings ?? const BrowserSettings();

  final BrowserSettings settings;
  InAppWebViewController? _webViewController;

  BrowserState state = const BrowserState();

  void Function(BrowserState state)? onStateChanged;

  InAppWebViewController? get webViewController => _webViewController;

  void attach(InAppWebViewController controller) {
    _webViewController = controller;
  }

  void _emit(BrowserState next) {
    state = next;
    onStateChanged?.call(next);
  }

  Future<void> loadUrl(String url) async {
    final controller = _webViewController;
    if (controller == null) {
      return;
    }

    final normalized = _normalizeUrl(url);
    _emit(state.copyWith(currentUrl: normalized, isLoading: true));
    await controller.loadUrl(
      urlRequest: URLRequest(url: WebUri(normalized)),
    );
  }

  Future<void> reload() async {
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
    _emit(
      state.copyWith(
        currentUrl: url?.toString() ?? state.currentUrl,
        isLoading: true,
        progress: 0,
      ),
    );
  }

  Future<void> onLoadStop(WebUri? url) async {
    await updateNavigationState();
    _emit(state.copyWith(isLoading: false, progress: 100));
    await _applyViewportWidth();
  }

  void onProgressChanged(int progress) {
    _emit(state.copyWith(progress: progress, isLoading: progress < 100));
  }

  Future<void> syncBridgeSize(double width, double height) async {
    await _webViewController?.evaluateJavascript(
      source:
          'window.__cursorPad && window.__cursorPad.setNativeSize($width, $height);',
    );
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

  Future<void> _applyViewportWidth() async {
    await _webViewController?.evaluateJavascript(
      source:
          'window.__cursorPadDesktop && window.__cursorPadDesktop.setViewportWidth(${settings.viewportWidth});',
    );
  }

  String _normalizeUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return settings.homeUrl;
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'https://$trimmed';
  }
}
