import 'package:flutter/material.dart';

import '../bookmarks/bookmark.dart';
import '../settings/browser_settings.dart';
import '../browser/browser_controller.dart';
import '../browser/browser_state.dart';
import '../browser/browser_toolbar.dart';
import '../browser/desktop_webview.dart';
import '../browser/toolbar_visibility.dart';
import '../cursor/cursor_overlay.dart';
import '../cursor/cursor_state.dart';
import '../input/touchpad_detector.dart';

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen>
    with WidgetsBindingObserver {
  final GlobalKey<_BrowserWebViewLayerState> _webViewLayerKey =
      GlobalKey<_BrowserWebViewLayerState>();

  late final BrowserController _browserController;
  late final TextEditingController _urlController;
  late final FocusNode _urlFocusNode;
  late final ToolbarVisibilityController _toolbarVisibility;
  late final ValueNotifier<Offset> _cursorPosition;
  late final ValueNotifier<bool> _webViewReady;
  late final ValueNotifier<bool> _isBookmarked;
  late CursorState _cursorState;

  Size _viewportSize = Size.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _browserController = BrowserController(settings: const BrowserSettings());
    _browserController.onStateChanged = _onBrowserStateChanged;
    _urlController = TextEditingController(
      text: _browserController.settings.homeUrl,
    );
    _urlFocusNode = FocusNode();
    _urlFocusNode.addListener(_onUrlFocusChanged);
    _toolbarVisibility = ToolbarVisibilityController();
    _cursorState = CursorState(position: Offset.zero);
    _cursorPosition = ValueNotifier(Offset.zero);
    _webViewReady = ValueNotifier(false);
    _isBookmarked = ValueNotifier(false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _urlFocusNode.removeListener(_onUrlFocusChanged);
    _urlFocusNode.dispose();
    _toolbarVisibility.dispose();
    _cursorPosition.dispose();
    _webViewReady.dispose();
    _isBookmarked.dispose();
    _urlController.dispose();
    _browserController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _viewportSize != Size.zero) {
      _browserController.syncViewport(
        _viewportSize.width,
        _viewportSize.height,
      );
    }
  }

  void _onUrlFocusChanged() {
    if (_urlFocusNode.hasFocus) {
      _toolbarVisibility.pin();
    } else {
      _toolbarVisibility.unpin();
    }
  }

  void _handleViewportSizeChanged(Size size) {
    if (_viewportSize == size) {
      return;
    }
    _viewportSize = size;

    if (_cursorState.position == Offset.zero && size != Size.zero) {
      _cursorState.centerIn(size);
    } else if (size != Size.zero) {
      _cursorState.moveBy(Offset.zero, size);
    }
    _cursorPosition.value = _cursorState.position;

    _browserController.syncViewport(size.width, size.height);
    _syncCursorToPage();
  }

  Future<void> _onBrowserStateChanged(BrowserState state) async {
    final bookmarked = BrowserController.isBookmarksHomeUrl(state.currentUrl)
        ? false
        : await _browserController.bookmarkRepository.containsUrl(
            state.currentUrl,
          );

    if (!mounted) {
      return;
    }

    _isBookmarked.value = bookmarked;
    if (state.currentUrl.isNotEmpty &&
        _urlController.text != state.currentUrl) {
      _urlController.text = state.currentUrl;
    }

    if (state.isLoading) {
      _toolbarVisibility.forceShow();
    } else if (!_urlFocusNode.hasFocus) {
      _toolbarVisibility.onCursorMove(_cursorState.position.dy);
    }
  }

  void _centerCursor() {
    if (_viewportSize == Size.zero) {
      return;
    }
    _cursorState.centerIn(_viewportSize);
    _cursorPosition.value = _cursorState.position;
    _syncCursorToPage();
  }

  Future<void> _syncCursorToPage() async {
    if (!_webViewReady.value) {
      return;
    }
    await _browserController.moveCursor(
      _cursorState.position.dx,
      _cursorState.position.dy,
    );
  }

  Future<void> _syncCursorToPageImmediate() async {
    if (!_webViewReady.value) {
      return;
    }
    await _browserController.moveCursorImmediate(
      _cursorState.position.dx,
      _cursorState.position.dy,
    );
  }

  void _onMove(Offset delta) {
    if (_viewportSize == Size.zero) {
      return;
    }
    _cursorState.moveBy(delta, _viewportSize);
    _cursorPosition.value = _cursorState.position;
    _toolbarVisibility.onCursorMove(_cursorState.position.dy);
    _syncCursorToPage();
  }

  Future<void> _onTap() async {
    await _syncCursorToPageImmediate();
    await _browserController.click();
  }

  Future<void> _onDoubleTap() async {
    await _syncCursorToPageImmediate();
    await _browserController.doubleClick();
  }

  Future<void> _onLongPress() async {
    await _syncCursorToPageImmediate();
    await _browserController.click(button: 2);
  }

  Future<void> _onScroll(Offset delta) async {
    await _browserController.scroll(delta.dx, delta.dy);
  }

  Future<void> _onBookmarkPressed() async {
    final currentUrl = _browserController.state.currentUrl;
    if (currentUrl.isEmpty ||
        BrowserController.isBookmarksHomeUrl(currentUrl)) {
      return;
    }

    final titleController = TextEditingController(
      text: _browserController.state.title.isNotEmpty
          ? _browserController.state.title
          : currentUrl,
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('收藏当前页面'),
          content: TextField(
            controller: titleController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '名称',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (saved != true || !mounted) {
      titleController.dispose();
      return;
    }

    final title = titleController.text.trim();
    titleController.dispose();

    await _browserController.bookmarkRepository.add(
      Bookmark(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title.isEmpty ? currentUrl : title,
        url: currentUrl,
        createdAt: DateTime.now(),
      ),
    );

    if (!mounted) {
      return;
    }

    _isBookmarked.value = true;

    if (BrowserController.isBookmarksHomeUrl(
      _browserController.state.currentUrl,
    )) {
      await _browserController.loadBookmarksHome();
    }
  }

  void _onWebViewCreated() {
    _webViewReady.value = true;
    _centerCursor();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _BrowserWebViewLayer(
            key: _webViewLayerKey,
            browserController: _browserController,
            cursorPosition: _cursorPosition,
            webViewReady: _webViewReady,
            onCreated: _onWebViewCreated,
            onSizeChanged: _handleViewportSizeChanged,
            onMove: _onMove,
            onTap: _onTap,
            onDoubleTap: _onDoubleTap,
            onLongPress: _onLongPress,
            onScroll: _onScroll,
          ),
          ListenableBuilder(
            listenable: _toolbarVisibility,
            builder: (context, _) {
              final toolbarVisible = _toolbarVisibility.visible;
              return AnimatedSlide(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                offset: toolbarVisible ? Offset.zero : const Offset(0, -1),
                child: ValueListenableBuilder<BrowserState>(
                  valueListenable: _browserController.stateNotifier,
                  builder: (context, state, _) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: _isBookmarked,
                      builder: (context, bookmarked, _) {
                        return BrowserToolbar(
                          state: state,
                          urlController: _urlController,
                          urlFocusNode: _urlFocusNode,
                          onSubmit: _browserController.loadUrl,
                          onBack: _browserController.goBack,
                          onForward: _browserController.goForward,
                          onReload: _browserController.reload,
                          onHome: () => _browserController.loadUrl(
                            BrowserSettings.bookmarksHomeUrl,
                          ),
                          onBookmark: _onBookmarkPressed,
                          isBookmarked: bookmarked,
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BrowserWebViewLayer extends StatefulWidget {
  const _BrowserWebViewLayer({
    super.key,
    required this.browserController,
    required this.cursorPosition,
    required this.webViewReady,
    required this.onCreated,
    required this.onSizeChanged,
    required this.onMove,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
    required this.onScroll,
  });

  final BrowserController browserController;
  final ValueNotifier<Offset> cursorPosition;
  final ValueNotifier<bool> webViewReady;
  final VoidCallback onCreated;
  final ValueChanged<Size> onSizeChanged;
  final ValueChanged<Offset> onMove;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;
  final ValueChanged<Offset> onScroll;

  @override
  State<_BrowserWebViewLayer> createState() => _BrowserWebViewLayerState();
}

class _BrowserWebViewLayerState extends State<_BrowserWebViewLayer> {
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: TouchpadDetector(
        sensitivity: widget.browserController.settings.cursorSensitivity,
        scrollSensitivity: widget.browserController.settings.scrollSensitivity,
        onMove: widget.onMove,
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onLongPress: widget.onLongPress,
        onScroll: widget.onScroll,
        child: Stack(
          children: [
            Positioned.fill(
              child: DesktopWebView(
                key: const ValueKey('desktop-webview'),
                controller: widget.browserController,
                onCreated: widget.onCreated,
                onSizeChanged: widget.onSizeChanged,
              ),
            ),
            ValueListenableBuilder<int>(
              valueListenable: widget.browserController.progressNotifier,
              builder: (context, progress, _) {
                if (progress >= 100 || progress <= 0) {
                  return const SizedBox.shrink();
                }
                return const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: LinearProgressIndicator(minHeight: 2),
                );
              },
            ),
            ValueListenableBuilder<Offset>(
              valueListenable: widget.cursorPosition,
              builder: (context, position, _) {
                return ValueListenableBuilder<bool>(
                  valueListenable: widget.webViewReady,
                  builder: (context, ready, _) {
                    return CursorOverlay(
                      position: position,
                      visible: ready,
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
