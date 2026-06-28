import 'package:flutter/material.dart';

import '../browser/browser_controller.dart';
import '../browser/browser_state.dart';
import '../browser/browser_toolbar.dart';
import '../browser/desktop_webview.dart';
import '../cursor/cursor_overlay.dart';
import '../cursor/cursor_state.dart';
import '../input/touchpad_detector.dart';
import '../settings/browser_settings.dart';

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen>
    with WidgetsBindingObserver {
  late final BrowserController _browserController;
  late final TextEditingController _urlController;
  late CursorState _cursorState;

  BrowserState _browserState = const BrowserState();
  Size _viewportSize = Size.zero;
  bool _webViewReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _browserController = BrowserController(settings: const BrowserSettings());
    _browserController.onStateChanged = _onBrowserStateChanged;
    _urlController = TextEditingController(
      text: _browserController.settings.homeUrl,
    );
    _cursorState = CursorState(position: Offset.zero);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _urlController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _viewportSize != Size.zero) {
      _browserController.syncBridgeSize(
        _viewportSize.width,
        _viewportSize.height,
      );
    }
  }

  void _onBrowserStateChanged(BrowserState state) {
    setState(() {
      _browserState = state;
      if (state.currentUrl.isNotEmpty &&
          _urlController.text != state.currentUrl) {
        _urlController.text = state.currentUrl;
      }
    });
  }

  void _centerCursor() {
    if (_viewportSize == Size.zero) {
      return;
    }
    setState(() {
      _cursorState.centerIn(_viewportSize);
    });
    _syncCursorToPage();
  }

  Future<void> _syncCursorToPage() async {
    if (!_webViewReady) {
      return;
    }
    await _browserController.moveCursor(
      _cursorState.position.dx,
      _cursorState.position.dy,
    );
  }

  void _onMove(Offset delta) {
    if (_viewportSize == Size.zero) {
      return;
    }
    setState(() {
      _cursorState.moveBy(delta, _viewportSize);
    });
    _syncCursorToPage();
  }

  Future<void> _onTap() async {
    await _syncCursorToPage();
    await _browserController.click();
  }

  Future<void> _onDoubleTap() async {
    await _syncCursorToPage();
    await _browserController.doubleClick();
  }

  Future<void> _onLongPress() async {
    await _syncCursorToPage();
    await _browserController.click(button: 2);
  }

  Future<void> _onScroll(Offset delta) async {
    await _browserController.scroll(delta.dx, delta.dy);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          BrowserToolbar(
            state: _browserState,
            urlController: _urlController,
            onSubmit: _browserController.loadUrl,
            onBack: _browserController.goBack,
            onForward: _browserController.goForward,
            onReload: _browserController.reload,
            onHome: () => _browserController.loadUrl(
              _browserController.settings.homeUrl,
            ),
          ),
          if (_browserState.isLoading && _browserState.progress < 100)
            LinearProgressIndicator(
              value: _browserState.progress / 100,
              minHeight: 2,
            ),
          Expanded(
            child: TouchpadDetector(
              sensitivity: _browserController.settings.cursorSensitivity,
              scrollSensitivity: _browserController.settings.scrollSensitivity,
              onMove: _onMove,
              onTap: _onTap,
              onDoubleTap: _onDoubleTap,
              onLongPress: _onLongPress,
              onScroll: _onScroll,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  DesktopWebView(
                    controller: _browserController,
                    onCreated: () {
                      setState(() {
                        _webViewReady = true;
                      });
                      _centerCursor();
                    },
                    onSizeChanged: (size) {
                      setState(() {
                        _viewportSize = size;
                        if (_cursorState.position == Offset.zero) {
                          _cursorState.centerIn(size);
                        } else {
                          _cursorState.moveBy(Offset.zero, size);
                        }
                      });
                      _browserController.syncBridgeSize(size.width, size.height);
                    },
                  ),
                  CursorOverlay(
                    position: _cursorState.position,
                    visible: _webViewReady,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
