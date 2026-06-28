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
  late final BrowserController _browserController;
  late final TextEditingController _urlController;
  late final FocusNode _urlFocusNode;
  late final ToolbarVisibilityController _toolbarVisibility;
  late CursorState _cursorState;

  BrowserState _browserState = const BrowserState();
  Size _viewportSize = Size.zero;
  bool _webViewReady = false;
  bool _isBookmarked = false;

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
    _toolbarVisibility.addListener(_onToolbarVisibilityChanged);
    _cursorState = CursorState(position: Offset.zero);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _urlFocusNode.removeListener(_onUrlFocusChanged);
    _urlFocusNode.dispose();
    _toolbarVisibility.removeListener(_onToolbarVisibilityChanged);
    _toolbarVisibility.dispose();
    _urlController.dispose();
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

  void _onToolbarVisibilityChanged() {
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncViewportAfterLayout();
    });
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

    setState(() {
      _browserState = state;
      _isBookmarked = bookmarked;
      if (state.currentUrl.isNotEmpty &&
          _urlController.text != state.currentUrl) {
        _urlController.text = state.currentUrl;
      }
    });

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

  void _syncViewportAfterLayout() {
    if (_viewportSize == Size.zero) {
      return;
    }
    _browserController.syncViewport(
      _viewportSize.width,
      _viewportSize.height,
    );
  }

  void _onMove(Offset delta) {
    if (_viewportSize == Size.zero) {
      return;
    }
    setState(() {
      _cursorState.moveBy(delta, _viewportSize);
    });
    _toolbarVisibility.onCursorMove(_cursorState.position.dy);
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

  Future<void> _onBookmarkPressed() async {
    final currentUrl = _browserState.currentUrl;
    if (currentUrl.isEmpty ||
        BrowserController.isBookmarksHomeUrl(currentUrl)) {
      return;
    }

    final titleController = TextEditingController(
      text: _browserState.title.isNotEmpty ? _browserState.title : currentUrl,
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

    setState(() {
      _isBookmarked = true;
    });

    if (BrowserController.isBookmarksHomeUrl(_browserState.currentUrl)) {
      await _browserController.loadBookmarksHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    final toolbarVisible = _toolbarVisibility.visible;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: TouchpadDetector(
              sensitivity: _browserController.settings.cursorSensitivity,
              scrollSensitivity: _browserController.settings.scrollSensitivity,
              onMove: _onMove,
              onTap: _onTap,
              onDoubleTap: _onDoubleTap,
              onLongPress: _onLongPress,
              onScroll: _onScroll,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DesktopWebView(
                      controller: _browserController,
                      onCreated: () async {
                        setState(() {
                          _webViewReady = true;
                        });
                        await _browserController.loadBookmarksHome();
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
                        _browserController.syncViewport(size.width, size.height);
                      },
                    ),
                  ),
                  if (_browserState.isLoading && _browserState.progress < 100)
                    const Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  CursorOverlay(
                    position: _cursorState.position,
                    visible: _webViewReady,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSlide(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            offset: toolbarVisible ? Offset.zero : const Offset(0, -1),
            child: BrowserToolbar(
              state: _browserState,
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
              isBookmarked: _isBookmarked,
            ),
          ),
        ],
      ),
    );
  }
}
