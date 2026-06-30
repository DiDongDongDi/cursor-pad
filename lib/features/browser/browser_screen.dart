import 'dart:async';

import 'package:flutter/material.dart';

import '../bookmarks/bookmark.dart';
import '../settings/browser_settings.dart';
import '../browser/browser_controller.dart';
import '../browser/browser_state.dart';
import '../browser/browser_toolbar.dart';
import '../browser/desktop_webview.dart';
import '../browser/toolbar_hit_tester.dart';
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
  static const double _toolbarContentHeight = 52;

  late final BrowserController _browserController;
  late final TextEditingController _urlController;
  late final FocusNode _urlFocusNode;
  late final ToolbarVisibilityController _toolbarVisibility;
  late final ToolbarHitTester _toolbarHitTester;
  late final ValueNotifier<Offset> _cursorPosition;
  late final ValueNotifier<bool> _webViewReady;
  late final ValueNotifier<bool> _isBookmarked;
  late CursorState _cursorState;
  final GlobalKey _bodyStackKey = GlobalKey();
  bool _initialHtmlReady = false;
  String? _initialBookmarksHtml;

  Size _viewportSize = Size.zero;
  double _lastToolbarHeight = -1;
  int _webViewKey = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _browserController = BrowserController(settings: const BrowserSettings());
    _browserController.onStateChanged = _onBrowserStateChanged;
    _browserController.onPageReady = _onPageReady;
    _browserController.onWebViewNeedsRecreate = _recreateWebView;
    _urlController = TextEditingController(
      text: _browserController.settings.homeUrl,
    );
    _urlFocusNode = FocusNode();
    _urlFocusNode.addListener(_onUrlFocusChanged);
    _toolbarVisibility = ToolbarVisibilityController();
    _toolbarVisibility.addListener(_onToolbarVisibilityChanged);
    _toolbarHitTester = ToolbarHitTester();
    _cursorState = CursorState(position: Offset.zero);
    _cursorPosition = ValueNotifier(Offset.zero);
    _webViewReady = ValueNotifier(false);
    _isBookmarked = ValueNotifier(false);
    unawaited(_prepareInitialContent());
  }

  Future<void> _prepareInitialContent() async {
    await _browserController.prepareInitialBookmarksHtml();
    if (!mounted) {
      return;
    }
    setState(() {
      _initialHtmlReady = true;
      _initialBookmarksHtml = _browserController.initialBookmarksHtml;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _urlFocusNode.removeListener(_onUrlFocusChanged);
    _urlFocusNode.dispose();
    _toolbarVisibility.removeListener(_onToolbarVisibilityChanged);
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncViewportFromLayout();
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
      if (mounted) {
        _syncViewportFromLayout();
      }
    });
  }

  double _toolbarHeight(BuildContext context) {
    if (!_toolbarVisibility.visible) {
      return 0;
    }
    return MediaQuery.paddingOf(context).top + _toolbarContentHeight;
  }

  Size _cursorBounds(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final toolbarHeight = _toolbarHeight(context);
    return Size(
      screenSize.width,
      toolbarHeight + _viewportSize.height,
    );
  }

  Offset _webViewCursorPosition(BuildContext context) {
    final toolbarHeight = _toolbarHeight(context);
    return Offset(
      _cursorState.position.dx,
      (_cursorState.position.dy - toolbarHeight).clamp(0.0, _viewportSize.height),
    );
  }

  Offset? _cursorGlobalPosition() {
    final stackContext = _bodyStackKey.currentContext;
    if (stackContext == null) {
      return null;
    }
    final box = stackContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return null;
    }
    return box.localToGlobal(_cursorState.position);
  }

  void _syncViewportFromLayout() {
    final toolbarHeight = _toolbarHeight(context);
    final screenSize = MediaQuery.sizeOf(context);
    final contentSize = Size(
      screenSize.width,
      (screenSize.height - toolbarHeight).clamp(0, screenSize.height),
    );

    final oldToolbarHeight = _lastToolbarHeight;
    final cursorBounds = Size(
      screenSize.width,
      toolbarHeight + contentSize.height,
    );

    if (contentSize == _viewportSize &&
        toolbarHeight == _lastToolbarHeight &&
        cursorBounds.height > 0) {
      return;
    }

    _lastToolbarHeight = toolbarHeight;
    _viewportSize = contentSize;

    if (_cursorState.position == Offset.zero && cursorBounds != Size.zero) {
      _cursorState.centerIn(cursorBounds);
    } else if (cursorBounds != Size.zero) {
      var pos = _cursorState.position;

      if (toolbarHeight > oldToolbarHeight && oldToolbarHeight == 0) {
        pos = Offset(pos.dx, pos.dy + toolbarHeight);
      } else if (toolbarHeight == 0 && oldToolbarHeight > 0) {
        if (pos.dy < oldToolbarHeight) {
          pos = Offset(pos.dx, 0);
        } else {
          pos = Offset(pos.dx, pos.dy - oldToolbarHeight);
        }
      }

      _cursorState.position = Offset(
        pos.dx.clamp(0.0, cursorBounds.width),
        pos.dy.clamp(0.0, cursorBounds.height),
      );
    }
    _cursorPosition.value = _cursorState.position;

    _browserController.syncViewport(contentSize.width, contentSize.height);
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
      _toolbarVisibility.onCursorMove(
        _cursorState.position.dy,
        toolbarHeight: _toolbarHeight(context),
      );
    }
  }

  void _centerCursor() {
    final bounds = _cursorBounds(context);
    if (bounds == Size.zero) {
      return;
    }
    _cursorState.centerIn(bounds);
    _cursorPosition.value = _cursorState.position;
    _syncCursorToPage();
  }

  Future<void> _syncCursorToPage() async {
    if (!_webViewReady.value) {
      return;
    }
    final webViewPos = _webViewCursorPosition(context);
    await _browserController.moveCursor(webViewPos.dx, webViewPos.dy);
  }

  Future<void> _syncCursorToPageImmediate() async {
    if (!_webViewReady.value) {
      return;
    }
    final webViewPos = _webViewCursorPosition(context);
    await _browserController.moveCursorImmediate(webViewPos.dx, webViewPos.dy);
  }

  void _onPageReady() {
    unawaited(_syncCursorToPageImmediate());
  }

  void _onMove(Offset delta) {
    final bounds = _cursorBounds(context);
    if (bounds == Size.zero) {
      return;
    }
    _cursorState.moveBy(delta, bounds);
    _cursorPosition.value = _cursorState.position;
    _toolbarVisibility.onCursorMove(
      _cursorState.position.dy,
      toolbarHeight: _toolbarHeight(context),
    );
    _syncCursorToPage();
  }

  bool _isCursorInToolbar(BuildContext context) {
    if (!_toolbarVisibility.visible) {
      return false;
    }
    return _cursorState.position.dy < _toolbarHeight(context);
  }

  Future<void> _handleToolbarTap() async {
    final globalPos = _cursorGlobalPosition();
    if (globalPos == null) {
      return;
    }

    final target = _toolbarHitTester.hitTest(globalPos);
    final state = _browserController.state;

    switch (target) {
      case ToolbarHitTarget.back:
        if (state.canGoBack) {
          await _browserController.goBack();
        }
      case ToolbarHitTarget.forward:
        if (state.canGoForward) {
          await _browserController.goForward();
        }
      case ToolbarHitTarget.reload:
        await _browserController.reload();
      case ToolbarHitTarget.home:
        await _browserController.loadUrl(BrowserSettings.bookmarksHomeUrl);
      case ToolbarHitTarget.bookmark:
        await _onBookmarkPressed();
      case ToolbarHitTarget.urlField:
        _urlFocusNode.requestFocus();
      case null:
        break;
    }
  }

  Future<void> _onTap() async {
    if (_isCursorInToolbar(context)) {
      await _handleToolbarTap();
      return;
    }

    await _syncCursorToPageImmediate();
    await _browserController.click();
  }

  Future<void> _onDoubleTap() async {
    if (_isCursorInToolbar(context)) {
      return;
    }

    await _syncCursorToPageImmediate();
    await _browserController.doubleClick();
  }

  Future<void> _onLongPress() async {
    if (_isCursorInToolbar(context)) {
      return;
    }

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

    final title = await showDialog<String>(
      context: context,
      builder: (context) {
        return _BookmarkTitleDialog(
          initialTitle: _browserController.state.title.isNotEmpty
              ? _browserController.state.title
              : currentUrl,
        );
      },
    );

    if (title == null || !mounted) {
      return;
    }

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

  void _recreateWebView() {
    if (!mounted) {
      return;
    }
    _webViewReady.value = false;
    setState(() => _webViewKey++);
  }

  Future<void> _onUrlSubmitted(String url) async {
    _urlFocusNode.unfocus();
    await _browserController.loadUrl(url);
  }

  void _onWebViewCreated() {
    _webViewReady.value = true;
    _syncViewportFromLayout();
    _centerCursor();
  }

  void _onWebViewSizeChanged(Size size) {
    if (size == _viewportSize || size == Size.zero) {
      return;
    }
    _viewportSize = size;
    _lastToolbarHeight = MediaQuery.sizeOf(context).height - size.height;

    final bounds = _cursorBounds(context);
    if (_cursorState.position == Offset.zero) {
      _cursorState.centerIn(bounds);
    } else {
      _cursorState.moveBy(Offset.zero, bounds);
    }
    _cursorPosition.value = _cursorState.position;

    unawaited(_browserController.syncViewport(size.width, size.height));
    unawaited(_syncCursorToPage());
  }

  @override
  Widget build(BuildContext context) {
    final toolbarVisible = _toolbarVisibility.visible;

    return Scaffold(
      body: TouchpadDetector(
        sensitivity: _browserController.settings.cursorSensitivity,
        scrollSensitivity: _browserController.settings.scrollSensitivity,
        onMove: _onMove,
        onTap: _onTap,
        onDoubleTap: _onDoubleTap,
        onLongPress: _onLongPress,
        onScroll: _onScroll,
        child: Stack(
          key: _bodyStackKey,
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: toolbarVisible ? 1 : 0,
                    child: ListenableBuilder(
                      listenable: _toolbarVisibility,
                      builder: (context, _) {
                        return ValueListenableBuilder<BrowserState>(
                          valueListenable: _browserController.stateNotifier,
                          builder: (context, state, _) {
                            return ValueListenableBuilder<bool>(
                              valueListenable: _isBookmarked,
                              builder: (context, bookmarked, _) {
                                return BrowserToolbar(
                                  state: state,
                                  urlController: _urlController,
                                  urlFocusNode: _urlFocusNode,
                                  hitTester: _toolbarHitTester,
                                  onSubmit: _onUrlSubmitted,
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
                        );
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        child: _initialHtmlReady || _webViewKey > 0
                            ? DesktopWebView(
                                key: ValueKey('desktop-webview-$_webViewKey'),
                                hostKey: _webViewKey,
                                controller: _browserController,
                                initialHtml: _webViewKey == 0
                                    ? _initialBookmarksHtml
                                    : null,
                                onCreated: _onWebViewCreated,
                                onSizeChanged: _onWebViewSizeChanged,
                              )
                            : const Center(
                                child: CircularProgressIndicator(),
                              ),
                      ),
                      ValueListenableBuilder<int>(
                        valueListenable: _browserController.progressNotifier,
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
                    ],
                  ),
                ),
              ],
            ),
            ValueListenableBuilder<Offset>(
              valueListenable: _cursorPosition,
              builder: (context, position, _) {
                return ValueListenableBuilder<bool>(
                  valueListenable: _webViewReady,
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

class _BookmarkTitleDialog extends StatefulWidget {
  const _BookmarkTitleDialog({required this.initialTitle});

  final String initialTitle;

  @override
  State<_BookmarkTitleDialog> createState() => _BookmarkTitleDialogState();
}

class _BookmarkTitleDialogState extends State<_BookmarkTitleDialog> {
  late final TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('收藏当前页面'),
      content: TextField(
        controller: _titleController,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: '名称',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_titleController.text.trim()),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
