import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bookmarks/bookmark.dart';
import '../settings/browser_settings.dart';
import '../browser/browser_controller.dart';
import '../browser/browser_state.dart';
import '../browser/browser_tab.dart';
import '../browser/browser_tab_bar.dart';
import '../browser/browser_toolbar.dart';
import '../browser/desktop_webview.dart';
import '../browser/tab_bar_hit_tester.dart';
import '../browser/tab_manager.dart';
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

  late final TabManager _tabManager;
  late final TextEditingController _urlController;
  late final FocusNode _urlFocusNode;
  late final ToolbarVisibilityController _toolbarVisibility;
  late final ToolbarHitTester _toolbarHitTester;
  late final TabBarHitTester _tabBarHitTester;
  late final ValueNotifier<Offset> _cursorPosition;
  late final ValueNotifier<bool> _isBookmarked;
  late CursorState _cursorState;
  final GlobalKey _bodyStackKey = GlobalKey();
  final Map<String, VoidCallback> _tabStateListeners = {};

  Size _viewportSize = Size.zero;
  double _lastChromeHeight = -1;

  BrowserTab get _activeTab => _tabManager.activeTab;
  BrowserController get _activeController => _activeTab.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabManager = TabManager(settings: const BrowserSettings());
    _tabManager.addListener(_onTabManagerChanged);
    _urlController = TextEditingController(
      text: _activeController.settings.homeUrl,
    );
    _urlFocusNode = FocusNode();
    _urlFocusNode.addListener(_onUrlFocusChanged);
    _toolbarVisibility = ToolbarVisibilityController();
    _toolbarVisibility.addListener(_onToolbarVisibilityChanged);
    _toolbarHitTester = ToolbarHitTester();
    _tabBarHitTester = TabBarHitTester();
    _cursorState = _activeTab.cursorState;
    _cursorPosition = ValueNotifier(_cursorState.position);
    _isBookmarked = ValueNotifier(false);
    _bindTabCallbacks(_activeTab);
    unawaited(_prepareInitialContent());
  }

  Future<void> _prepareInitialContent() async {
    await _tabManager.prepareInitialContent();
    if (!mounted) {
      return;
    }
    for (final tab in _tabManager.tabs) {
      _bindTabCallbacks(tab);
    }
    setState(() {});
  }

  void _bindTabCallbacks(BrowserTab tab) {
    if (_tabStateListeners.containsKey(tab.id)) {
      return;
    }

    void onStateChanged(BrowserState state) {
      unawaited(_onBrowserStateChanged(tab, state));
    }

    void onPageReady() {
      if (_activeTab.id == tab.id) {
        unawaited(_syncCursorToPageImmediate());
      }
    }

    void onWebViewNeedsRecreate() {
      _recreateWebView(tab);
    }

    tab.controller.onStateChanged = onStateChanged;
    tab.controller.onPageReady = onPageReady;
    tab.controller.onWebViewNeedsRecreate = onWebViewNeedsRecreate;
    _tabStateListeners[tab.id] = () {
      tab.controller.onStateChanged = null;
      tab.controller.onPageReady = null;
      tab.controller.onWebViewNeedsRecreate = null;
    };
  }

  void _unbindTabCallbacks(BrowserTab tab) {
    _tabStateListeners.remove(tab.id)?.call();
  }

  void _onTabManagerChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      for (final tab in _tabManager.tabs) {
        _bindTabCallbacks(tab);
      }
    });
    _syncActiveTabUi();
  }

  void _syncActiveTabUi() {
    _cursorState = _activeTab.cursorState;
    _cursorPosition.value = _cursorState.position;
    final state = _activeController.state;
    _urlController.text = state.currentUrl.isNotEmpty
        ? state.currentUrl
        : _activeController.settings.homeUrl;
    unawaited(_refreshBookmarkState());
    unawaited(_syncCursorToPageImmediate());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncViewportFromLayout();
      }
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
    _isBookmarked.dispose();
    _urlController.dispose();
    for (final tab in _tabManager.tabs) {
      _unbindTabCallbacks(tab);
    }
    _tabManager.removeListener(_onTabManagerChanged);
    _tabManager.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _viewportSize != Size.zero) {
      _activeController.syncViewport(
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

  double _chromeHeight(BuildContext context) {
    if (!_toolbarVisibility.visible) {
      return 0;
    }
    return MediaQuery.paddingOf(context).top +
        BrowserTabBar.height +
        _toolbarContentHeight;
  }

  Size _cursorBounds(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final chromeHeight = _chromeHeight(context);
    return Size(
      screenSize.width,
      chromeHeight + _viewportSize.height,
    );
  }

  Offset _webViewCursorPosition(BuildContext context) {
    final chromeHeight = _chromeHeight(context);
    return Offset(
      _cursorState.position.dx,
      (_cursorState.position.dy - chromeHeight).clamp(0.0, _viewportSize.height),
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
    final chromeHeight = _chromeHeight(context);
    final screenSize = MediaQuery.sizeOf(context);
    final contentSize = Size(
      screenSize.width,
      (screenSize.height - chromeHeight).clamp(0, screenSize.height),
    );

    final oldChromeHeight = _lastChromeHeight;
    final cursorBounds = Size(
      screenSize.width,
      chromeHeight + contentSize.height,
    );

    if (contentSize == _viewportSize &&
        chromeHeight == _lastChromeHeight &&
        cursorBounds.height > 0) {
      return;
    }

    _lastChromeHeight = chromeHeight;
    _viewportSize = contentSize;

    if (_cursorState.position == Offset.zero && cursorBounds != Size.zero) {
      _cursorState.centerIn(cursorBounds);
    } else if (cursorBounds != Size.zero) {
      var pos = _cursorState.position;

      if (chromeHeight > oldChromeHeight && oldChromeHeight == 0) {
        pos = Offset(pos.dx, pos.dy + chromeHeight);
      } else if (chromeHeight == 0 && oldChromeHeight > 0) {
        if (pos.dy < oldChromeHeight) {
          pos = Offset(pos.dx, 0);
        } else {
          pos = Offset(pos.dx, pos.dy - oldChromeHeight);
        }
      }

      _cursorState.position = Offset(
        pos.dx.clamp(0.0, cursorBounds.width),
        pos.dy.clamp(0.0, cursorBounds.height),
      );
    }
    _activeTab.cursorState = _cursorState;
    _cursorPosition.value = _cursorState.position;

    _activeController.syncViewport(contentSize.width, contentSize.height);
    _syncCursorToPage();
  }

  Future<void> _refreshBookmarkState() async {
    final state = _activeController.state;
    final bookmarked = BrowserController.isBookmarksHomeUrl(state.currentUrl)
        ? false
        : await _activeController.bookmarkRepository.containsUrl(
            state.currentUrl,
          );
    if (mounted && _activeTab.id == _tabManager.activeTab.id) {
      _isBookmarked.value = bookmarked;
    }
  }

  Future<void> _onBrowserStateChanged(
    BrowserTab tab,
    BrowserState state,
  ) async {
    if (!mounted) {
      return;
    }

    if (tab.id != _activeTab.id) {
      setState(() {});
      return;
    }

    final chromeHeight = _chromeHeight(context);
    await _refreshBookmarkState();

    if (state.currentUrl.isNotEmpty &&
        _urlController.text != state.currentUrl) {
      _urlController.text = state.currentUrl;
    }

    if (state.isLoading) {
      _toolbarVisibility.forceShow();
    } else if (!_urlFocusNode.hasFocus) {
      _toolbarVisibility.onCursorMove(
        _cursorState.position.dy,
        chromeHeight: chromeHeight,
      );
    }
  }

  void _centerCursor() {
    final bounds = _cursorBounds(context);
    if (bounds == Size.zero) {
      return;
    }
    _cursorState.centerIn(bounds);
    _activeTab.cursorState = _cursorState;
    _cursorPosition.value = _cursorState.position;
    _syncCursorToPage();
  }

  Future<void> _syncCursorToPage() async {
    if (!_activeTab.webViewReady) {
      return;
    }
    final webViewPos = _webViewCursorPosition(context);
    await _activeController.moveCursor(webViewPos.dx, webViewPos.dy);
  }

  Future<void> _syncCursorToPageImmediate() async {
    if (!_activeTab.webViewReady) {
      return;
    }
    final webViewPos = _webViewCursorPosition(context);
    await _activeController.moveCursorImmediate(webViewPos.dx, webViewPos.dy);
  }

  void _onMove(Offset delta) {
    final bounds = _cursorBounds(context);
    if (bounds == Size.zero) {
      return;
    }
    _cursorState.moveBy(delta, bounds);
    _activeTab.cursorState = _cursorState;
    _cursorPosition.value = _cursorState.position;
    _toolbarVisibility.onCursorMove(
      _cursorState.position.dy,
      chromeHeight: _chromeHeight(context),
    );
    _syncCursorToPage();
  }

  bool _isCursorInChrome(BuildContext context) {
    if (!_toolbarVisibility.visible) {
      return false;
    }
    return _cursorState.position.dy < _chromeHeight(context);
  }

  Future<void> _handleTabBarTap(TabBarHitResult result) async {
    switch (result.target) {
      case TabBarHitTarget.newTab:
        if (!_tabManager.createTab()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('标签页数量已达上限')),
            );
          }
        }
      case TabBarHitTarget.tab:
        final index = result.tabIndex;
        if (index != null) {
          _tabManager.switchTab(index);
          _syncActiveTabUi();
        }
      case TabBarHitTarget.closeTab:
        final index = result.tabIndex;
        if (index != null &&
            index < _tabManager.tabs.length &&
            _tabManager.canCloseTab) {
          final removedTab = _tabManager.tabs[index];
          if (_tabManager.closeTab(index)) {
            _unbindTabCallbacks(removedTab);
            _syncActiveTabUi();
          }
        }
    }
  }

  Future<void> _handleToolbarTap() async {
    final globalPos = _cursorGlobalPosition();
    if (globalPos == null) {
      return;
    }

    final target = _toolbarHitTester.hitTest(globalPos);
    final state = _activeController.state;

    switch (target) {
      case ToolbarHitTarget.back:
        if (state.canGoBack) {
          await _activeController.goBack();
        }
      case ToolbarHitTarget.forward:
        if (state.canGoForward) {
          await _activeController.goForward();
        }
      case ToolbarHitTarget.reload:
        await _activeController.reload();
      case ToolbarHitTarget.home:
        await _activeController.loadUrl(BrowserSettings.bookmarksHomeUrl);
      case ToolbarHitTarget.bookmark:
        await _onBookmarkPressed();
      case ToolbarHitTarget.urlField:
        _urlFocusNode.requestFocus();
        SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      case null:
        break;
    }
  }

  Future<void> _handleChromeTap() async {
    final globalPos = _cursorGlobalPosition();
    if (globalPos == null) {
      return;
    }

    final tabHit = _tabBarHitTester.hitTest(
      globalPos,
      tabIds: _tabManager.tabs.map((tab) => tab.id).toList(),
      canCloseTab: _tabManager.canCloseTab,
    );
    if (tabHit != null) {
      await _handleTabBarTap(tabHit);
      return;
    }

    await _handleToolbarTap();
  }

  Future<void> _onTap() async {
    if (_isCursorInChrome(context)) {
      await _handleChromeTap();
      return;
    }

    await _syncCursorToPageImmediate();
    await _activeController.click();
  }

  Future<void> _onDoubleTap() async {
    if (_isCursorInChrome(context)) {
      return;
    }

    await _syncCursorToPageImmediate();
    await _activeController.doubleClick();
  }

  Future<void> _onLongPress() async {
    if (_isCursorInChrome(context)) {
      return;
    }

    await _syncCursorToPageImmediate();
    await _activeController.click(button: 2);
  }

  Future<void> _onScroll(Offset delta) async {
    await _activeController.scroll(delta.dx, delta.dy);
  }

  Future<void> _onPinch(double scaleFactor) async {
    await _activeController.zoomBy(scaleFactor);
  }

  Future<void> _onBookmarkPressed() async {
    final currentUrl = _activeController.state.currentUrl;
    if (currentUrl.isEmpty ||
        BrowserController.isBookmarksHomeUrl(currentUrl)) {
      return;
    }

    final title = await showDialog<String>(
      context: context,
      builder: (context) {
        return _BookmarkTitleDialog(
          initialTitle: _activeController.state.title.isNotEmpty
              ? _activeController.state.title
              : currentUrl,
        );
      },
    );

    if (title == null || !mounted) {
      return;
    }

    await _activeController.bookmarkRepository.add(
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
      _activeController.state.currentUrl,
    )) {
      await _activeController.loadBookmarksHome();
    }
  }

  void _recreateWebView(BrowserTab tab) {
    if (!mounted) {
      return;
    }
    _tabManager.recreateWebViewForTab(tab);
  }

  Future<void> _onUrlSubmitted(String url) async {
    _urlFocusNode.unfocus();
    await _activeController.loadUrl(url);
  }

  void _onWebViewCreated(BrowserTab tab) {
    tab.webViewReady = true;
    if (tab.id != _activeTab.id) {
      return;
    }
    _syncViewportFromLayout();
    _centerCursor();
  }

  void _onWebViewSizeChanged(BrowserTab tab, Size size) {
    if (tab.id != _activeTab.id || size == Size.zero) {
      return;
    }
    if (size == _viewportSize) {
      return;
    }
    _viewportSize = size;
    _lastChromeHeight =
        MediaQuery.sizeOf(context).height - size.height;

    final bounds = _cursorBounds(context);
    if (_cursorState.position == Offset.zero) {
      _cursorState.centerIn(bounds);
    } else {
      _cursorState.moveBy(Offset.zero, bounds);
    }
    _activeTab.cursorState = _cursorState;
    _cursorPosition.value = _cursorState.position;

    unawaited(_activeController.syncViewport(size.width, size.height));
    unawaited(_syncCursorToPage());
  }

  @override
  Widget build(BuildContext context) {
    final toolbarVisible = _toolbarVisibility.visible;

    return Scaffold(
      body: TouchpadDetector(
        sensitivity: _tabManager.settings.cursorSensitivity,
        scrollSensitivity: _tabManager.settings.scrollSensitivity,
        onMove: _onMove,
        onTap: _onTap,
        onDoubleTap: _onDoubleTap,
        onLongPress: _onLongPress,
        onScroll: _onScroll,
        onPinch: _onPinch,
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
                        return ListenableBuilder(
                          listenable: _tabManager,
                          builder: (context, _) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                BrowserTabBar(
                                  tabs: _tabManager.tabs,
                                  activeIndex: _tabManager.activeIndex,
                                  hitTester: _tabBarHitTester,
                                  canCloseTab: _tabManager.canCloseTab,
                                ),
                                ValueListenableBuilder<BrowserState>(
                                  valueListenable:
                                      _activeController.stateNotifier,
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
                                          onBack: _activeController.goBack,
                                          onForward: _activeController.goForward,
                                          onReload: _activeController.reload,
                                          onHome: () => _activeController.loadUrl(
                                            BrowserSettings.bookmarksHomeUrl,
                                          ),
                                          onBookmark: _onBookmarkPressed,
                                          isBookmarked: bookmarked,
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
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
                        child: _tabManager.initialHtmlReady ||
                                _tabManager.tabs.any((tab) => tab.webViewKey > 0)
                            ? ListenableBuilder(
                                listenable: _tabManager,
                                builder: (context, _) {
                                  return IndexedStack(
                                    index: _tabManager.activeIndex,
                                    sizing: StackFit.expand,
                                    children: [
                                      for (final tab in _tabManager.tabs)
                                        DesktopWebView(
                                          key: ValueKey(
                                            'tab-${tab.id}-${tab.webViewKey}',
                                          ),
                                          hostKey: tab.webViewKey,
                                          controller: tab.controller,
                                          initialHtml: tab.webViewKey == 0
                                              ? tab.initialBookmarksHtml
                                              : null,
                                          onCreated: () =>
                                              _onWebViewCreated(tab),
                                          onSizeChanged: (size) =>
                                              _onWebViewSizeChanged(tab, size),
                                          onCreateWindow: (url) {
                                            if (url == null || url.isEmpty) {
                                              return false;
                                            }
                                            return _tabManager.createTab(
                                              url: url,
                                            );
                                          },
                                        ),
                                    ],
                                  );
                                },
                              )
                            : const Center(
                                child: CircularProgressIndicator(),
                              ),
                      ),
                      ValueListenableBuilder<int>(
                        valueListenable: _activeController.progressNotifier,
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
                return CursorOverlay(
                  position: position,
                  visible: _activeTab.webViewReady,
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
