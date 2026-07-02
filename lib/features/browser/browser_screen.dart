import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bookmarks/bookmark.dart';
import '../settings/browser_settings.dart';
import '../settings/browser_settings_repository.dart';
import '../settings/browser_settings_sheet.dart';
import '../browser/browser_controller.dart';
import '../browser/browser_state.dart';
import '../browser/browser_tab.dart';
import '../browser/browser_tab_switcher.dart';
import '../browser/browser_toolbar.dart';
import '../browser/desktop_webview.dart';
import '../browser/copy_mode_state.dart';
import '../browser/tab_manager.dart';
import '../browser/tab_switcher_hit_tester.dart';
import '../browser/text_selection_bar.dart';
import '../browser/toolbar_hit_tester.dart';
import '../browser/toolbar_visibility.dart';
import '../browser/url_field_selection.dart';
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
  late final BrowserSettingsRepository _settingsRepository;
  late final TextEditingController _urlController;
  late final FocusNode _urlFocusNode;
  late final ToolbarVisibilityController _toolbarVisibility;
  late final ToolbarHitTester _toolbarHitTester;
  late final TabSwitcherHitTester _tabSwitcherHitTester;
  late final ValueNotifier<Offset> _cursorPosition;
  late final ValueNotifier<bool> _isBookmarked;
  late CursorState _cursorState;
  final GlobalKey _bodyStackKey = GlobalKey();
  final Map<String, VoidCallback> _tabStateListeners = {};

  Size _viewportSize = Size.zero;
  double _lastChromeHeight = -1;
  bool _tabSwitcherOpen = false;
  final CopyModeState _copyMode = CopyModeState();
  final CopyModeState _urlCopyMode = CopyModeState();
  Offset? _selectionAnchor;
  int? _urlSelectionAnchor;
  Timer? _selectionPreviewTimer;
  String _selectedTextPreview = '';
  String _urlSelectedTextPreview = '';

  BrowserTab get _activeTab => _tabManager.activeTab;
  BrowserController get _activeController => _activeTab.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabManager = TabManager(settings: const BrowserSettings());
    _settingsRepository = BrowserSettingsRepository();
    _tabManager.addListener(_onTabManagerChanged);
    _urlController = TextEditingController(
      text: _activeController.settings.homeUrl,
    );
    _urlFocusNode = FocusNode();
    _urlFocusNode.addListener(_onUrlFocusChanged);
    _toolbarVisibility = ToolbarVisibilityController();
    _toolbarVisibility.addListener(_onToolbarVisibilityChanged);
    _toolbarHitTester = ToolbarHitTester();
    _tabSwitcherHitTester = TabSwitcherHitTester();
    _cursorState = _activeTab.cursorState;
    _cursorPosition = ValueNotifier(_cursorState.position);
    _isBookmarked = ValueNotifier(false);
    _bindTabCallbacks(_activeTab);
    unawaited(_prepareInitialContent());
  }

  Future<void> _prepareInitialContent() async {
    final settings = await _settingsRepository.load();
    _tabManager.updateSettings(settings);
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
    _selectionPreviewTimer?.cancel();
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
      _toolbarVisibility.forceShow();
    } else {
      if (_urlCopyMode.active) {
        unawaited(_exitUrlCopyMode());
      }
      _toolbarVisibility.onCursorMove(
        _cursorState.position.dy,
        chromeHeight: _chromeHeight(context),
      );
    }
  }

  void _selectAllUrlText() {
    selectAllUrlText(
      controller: _urlController,
      focusNode: _urlFocusNode,
      mounted: mounted,
    );
  }

  TextStyle _urlFieldTextStyle(BuildContext context) {
    return Theme.of(context).textTheme.bodyLarge ?? const TextStyle(fontSize: 16);
  }

  RenderBox? _urlFieldRenderBox() {
    return _toolbarHitTester.urlFieldKey.currentContext?.findRenderObject()
        as RenderBox?;
  }

  int? _urlOffsetAtCursor() {
    final globalPos = _cursorGlobalPosition();
    final box = _urlFieldRenderBox();
    if (globalPos == null || box == null || !box.hasSize) {
      return null;
    }
    return textOffsetAtGlobalX(
      text: _urlController.text,
      globalPoint: globalPos,
      fieldBox: box,
      style: _urlFieldTextStyle(context),
    );
  }

  bool _isAddressBarInteraction() {
    if (_urlCopyMode.active) {
      return true;
    }
    if (_urlFocusNode.hasFocus) {
      return true;
    }
    return _isCursorOverUrlField();
  }

  bool _isCursorOverUrlField() {
    final pos = _cursorGlobalPosition();
    if (pos == null) {
      return false;
    }
    return _toolbarHitTester.hitTest(pos) == ToolbarHitTarget.urlField;
  }

  void _focusUrlField({bool selectAll = false, bool showKeyboard = true}) {
    _urlFocusNode.requestFocus();
    if (selectAll) {
      _selectAllUrlText();
    }
    if (showKeyboard) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    }
  }

  Future<void> _handleUrlFieldSingleTap() async {
    if (_urlCopyMode.active) {
      return;
    }
    _focusUrlField(selectAll: true);
  }

  Future<void> _handleUrlFieldDoubleTap() async {
    if (_urlCopyMode.active) {
      return;
    }
    _focusUrlField(selectAll: false);
    final offset = _urlOffsetAtCursor() ?? 0;
    _urlController.selection =
        wordSelectionAt(_urlController.text, offset);
  }

  void _scheduleUrlSelectionPreviewUi() {
    _selectionPreviewTimer?.cancel();
    _selectionPreviewTimer = Timer(const Duration(milliseconds: 32), () {
      if (mounted && _urlCopyMode.active) {
        setState(() {});
      }
    });
  }

  void _updateUrlCopyModeSelection() {
    final anchor = _urlSelectionAnchor;
    if (anchor == null) {
      return;
    }
    final extent = _urlOffsetAtCursor();
    if (extent == null) {
      return;
    }
    final text = _urlController.text;
    _urlController.selection =
        selectionFromAnchor(anchor, extent, text.length);
    _urlSelectedTextPreview =
        selectedTextFromSelection(text, _urlController.selection);
    _scheduleUrlSelectionPreviewUi();
  }

  Future<void> _enterUrlCopyMode() async {
    if (!mounted) {
      return;
    }
    if (_copyMode.active) {
      await _exitCopyMode();
    }
    _focusUrlField(selectAll: false);
    final offset = _urlOffsetAtCursor() ?? 0;
    _urlSelectionAnchor = offset;
    final text = _urlController.text;
    _urlController.selection = wordSelectionAt(text, offset);
    _urlSelectedTextPreview =
        selectedTextFromSelection(text, _urlController.selection);
    _urlCopyMode.enter();
    setState(() {});
  }

  Future<void> _exitUrlCopyMode() async {
    _selectionPreviewTimer?.cancel();
    _urlCopyMode.exit();
    _urlSelectionAnchor = null;
    _urlSelectedTextPreview = '';
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _copyUrlSelectedText() async {
    final text =
        selectedTextFromSelection(_urlController.text, _urlController.selection);
    if (text.isEmpty) {
      return;
    }
    await TextSelectionBar.copyToClipboard(context, text);
    await _exitUrlCopyMode();
  }

  Future<void> _selectAllUrlForCopyBar() async {
    if (!mounted || !_urlCopyMode.active) {
      return;
    }
    _urlSelectionAnchor = 0;
    _selectAllUrlText();
    _urlSelectedTextPreview = _urlController.text;
    setState(() {});
  }

  void _onToolbarVisibilityChanged() {
    if (!_toolbarVisibility.visible && _tabSwitcherOpen) {
      _tabSwitcherOpen = false;
    }
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
    return MediaQuery.paddingOf(context).top + _toolbarContentHeight;
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

    _toolbarVisibility.onCursorMove(
      _cursorState.position.dy,
      chromeHeight: chromeHeight,
    );
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
    if (_copyMode.active) {
      await _activeController.moveCursor(webViewPos.dx, webViewPos.dy);
      await _updateCopyModeSelection(webViewPos);
      return;
    }
    await _activeController.moveCursor(webViewPos.dx, webViewPos.dy);
  }

  Future<void> _syncCursorToPageImmediate() async {
    if (!_activeTab.webViewReady) {
      return;
    }
    final webViewPos = _webViewCursorPosition(context);
    if (_copyMode.active) {
      await _activeController.moveCursorImmediate(webViewPos.dx, webViewPos.dy);
      await _updateCopyModeSelection(webViewPos);
      return;
    }
    await _activeController.moveCursorImmediate(webViewPos.dx, webViewPos.dy);
  }

  Future<void> _updateCopyModeSelection(Offset webViewPos) async {
    final anchor = _selectionAnchor;
    if (anchor == null) {
      return;
    }
    final info = await _activeController.setSelectionRange(
      anchor.dx,
      anchor.dy,
      webViewPos.dx,
      webViewPos.dy,
    );
    if (info != null && mounted) {
      _selectedTextPreview = info.text;
      _scheduleSelectionPreviewUi();
    }
  }

  void _scheduleSelectionPreviewUi() {
    _selectionPreviewTimer?.cancel();
    _selectionPreviewTimer = Timer(const Duration(milliseconds: 32), () {
      if (mounted && _copyMode.active) {
        setState(() {});
      }
    });
  }

  Future<void> _enterCopyMode() async {
    if (!mounted) {
      return;
    }
    if (_urlCopyMode.active) {
      await _exitUrlCopyMode();
    }
    final webViewPos = _webViewCursorPosition(context);
    await _syncCursorToPageImmediate();
    _selectionAnchor = webViewPos;
    _copyMode.enter();
    _activeController.selectionArmed = true;

    final info = await _activeController.selectWordAtPoint();
    if (info != null) {
      _selectedTextPreview = info.text;
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _exitCopyMode({bool clearPageSelection = true}) async {
    _selectionPreviewTimer?.cancel();
    _copyMode.exit();
    _selectionAnchor = null;
    _selectedTextPreview = '';
    _activeController.selectionArmed = false;
    if (clearPageSelection) {
      await _activeController.clearSelection();
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _dismissCopyMode() async {
    await _exitCopyMode();
  }

  Future<void> _copySelectedText() async {
    final text = _selectedTextPreview;
    if (text.isEmpty) {
      return;
    }
    await TextSelectionBar.copyToClipboard(context, text);
    await _exitCopyMode();
  }

  Future<void> _selectAllPageText() async {
    final info = await _activeController.selectAll();
    if (!mounted || !_copyMode.active) {
      return;
    }
    _selectedTextPreview = info?.text ?? '';
    setState(() {});
  }

  void _onMove(Offset delta) {
    final bounds = _cursorBounds(context);
    if (bounds == Size.zero) {
      return;
    }
    _cursorState.moveBy(delta, bounds);
    _activeTab.cursorState = _cursorState;
    _cursorPosition.value = _cursorState.position;

    if (_urlCopyMode.active) {
      if (_isCursorOverUrlField()) {
        _updateUrlCopyModeSelection();
        _toolbarVisibility.onCursorMove(
          _cursorState.position.dy,
          chromeHeight: _chromeHeight(context),
        );
        return;
      }
      unawaited(_exitUrlCopyMode());
    }

    if (_urlFocusNode.hasFocus && !_urlCopyMode.active) {
      final chromeHeight =
          MediaQuery.paddingOf(context).top + _toolbarContentHeight;
      if (_cursorState.position.dy >= chromeHeight) {
        _urlFocusNode.unfocus();
        _syncCursorToPage();
        return;
      }
    }

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

  bool _isCursorInTabSwitcher(BuildContext context) {
    if (!_tabSwitcherOpen || !_toolbarVisibility.visible) {
      return false;
    }
    return _cursorState.position.dy >= _chromeHeight(context);
  }

  Future<void> _handleTabSwitcherTap(TabSwitcherHitResult result) async {
    switch (result.target) {
      case TabSwitcherHitTarget.newTab:
        if (!_tabManager.createTab()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('标签页数量已达上限')),
            );
          }
        }
      case TabSwitcherHitTarget.tab:
        final index = result.tabIndex;
        if (index != null) {
          _tabManager.switchTab(index);
          _syncActiveTabUi();
          setState(() => _tabSwitcherOpen = false);
        }
      case TabSwitcherHitTarget.closeTab:
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
      case ToolbarHitTarget.zoomOut:
        await _activeController.zoomBy(1 / 1.2);
      case ToolbarHitTarget.zoomIn:
        await _activeController.zoomBy(1.2);
      case ToolbarHitTarget.tabsButton:
        setState(() => _tabSwitcherOpen = !_tabSwitcherOpen);
      case ToolbarHitTarget.settings:
        await _openSettings();
      case ToolbarHitTarget.urlField:
        await _handleUrlFieldSingleTap();
      case null:
        break;
    }
  }

  Future<void> _handleChromeTap() async {
    await _handleToolbarTap();
  }

  Future<void> _handleTabSwitcherAreaTap() async {
    final globalPos = _cursorGlobalPosition();
    if (globalPos == null) {
      return;
    }

    final hit = _tabSwitcherHitTester.hitTest(
      globalPos,
      tabIds: _tabManager.tabs.map((tab) => tab.id).toList(),
      canCloseTab: _tabManager.canCloseTab,
    );
    if (hit != null) {
      await _handleTabSwitcherTap(hit);
    }
  }

  Future<void> _onTap() async {
    if (_isCursorInChrome(context)) {
      await _handleChromeTap();
      return;
    }

    if (_isAddressBarInteraction()) {
      await _handleUrlFieldSingleTap();
      return;
    }

    if (_isCursorInTabSwitcher(context)) {
      await _handleTabSwitcherAreaTap();
      return;
    }

    if (_copyMode.active || _urlCopyMode.active) {
      return;
    }

    await _syncCursorToPageImmediate();
    await _activeController.click();
  }

  Future<void> _onDoubleTap() async {
    if (_isAddressBarInteraction()) {
      await _handleUrlFieldDoubleTap();
      return;
    }

    if (_isCursorInChrome(context) || _isCursorInTabSwitcher(context)) {
      return;
    }

    if (_copyMode.active || _urlCopyMode.active) {
      return;
    }

    await _syncCursorToPageImmediate();
    await _activeController.doubleClick();
  }

  Future<void> _onTripleTap() async {
    if (_isAddressBarInteraction()) {
      if (_urlCopyMode.active) {
        await _exitUrlCopyMode();
      }
      await _enterUrlCopyMode();
      return;
    }

    if (_isCursorInChrome(context) || _isCursorInTabSwitcher(context)) {
      return;
    }

    if (_copyMode.active) {
      await _exitCopyMode();
    }
    await _enterCopyMode();
  }

  Future<void> _onLongPress() async {
    if (_isCursorInChrome(context) || _isCursorInTabSwitcher(context)) {
      return;
    }

    if (_copyMode.active) {
      await _exitCopyMode();
    }

    await _syncCursorToPageImmediate();
    await _activeController.click(button: 2);
  }

  Future<void> _onScroll(Offset delta) async {
    if (_urlCopyMode.active) {
      await _exitUrlCopyMode();
    }
    if (_copyMode.active) {
      await _exitCopyMode();
    }
    await _activeController.scroll(delta.dx, delta.dy);
  }

  void _onMultiTouchStart() {
    if (_urlCopyMode.active) {
      unawaited(_exitUrlCopyMode());
    }
    if (_copyMode.active) {
      unawaited(_exitCopyMode());
    }
  }

  Future<void> _openSettings() async {
    final updated = await showModalBottomSheet<BrowserSettings>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return BrowserSettingsSheet(
          initialSettings: _tabManager.settings,
        );
      },
    );

    if (updated == null || !mounted) {
      return;
    }

    await _settingsRepository.save(updated);
    _tabManager.updateSettings(updated);
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

  Future<void> _handleSystemBack() async {
    if (_urlCopyMode.active) {
      await _exitUrlCopyMode();
      return;
    }

    if (_copyMode.active) {
      await _exitCopyMode();
      return;
    }

    if (_urlFocusNode.hasFocus) {
      _urlFocusNode.unfocus();
      return;
    }

    if (_tabSwitcherOpen) {
      setState(() => _tabSwitcherOpen = false);
      return;
    }

    if (await _activeController.webViewController?.canGoBack() ?? false) {
      await _activeController.goBack();
      return;
    }

    await SystemNavigator.pop();
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        unawaited(_handleSystemBack());
      },
      child: Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          TouchpadDetector(
        sensitivity: _tabManager.settings.cursorSensitivity,
        scrollSensitivity: _tabManager.settings.scrollSensitivity,
        onMove: _onMove,
        onTap: _onTap,
        onDoubleTap: _onDoubleTap,
        onTripleTap: _onTripleTap,
        onLongPress: _onLongPress,
        onScroll: _onScroll,
        onMultiTouchStart: _onMultiTouchStart,
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
                            return ValueListenableBuilder<BrowserState>(
                              valueListenable: _activeController.stateNotifier,
                              builder: (context, state, _) {
                                return ValueListenableBuilder<bool>(
                                  valueListenable: _isBookmarked,
                                  builder: (context, bookmarked, _) {
                                    return BrowserToolbar(
                                      state: state,
                                      urlController: _urlController,
                                      urlFocusNode: _urlFocusNode,
                                      hitTester: _toolbarHitTester,
                                      tabCount: _tabManager.tabs.length,
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
            if (_tabSwitcherOpen && toolbarVisible)
              Positioned(
                top: _chromeHeight(context),
                left: 0,
                right: 0,
                bottom: 0,
                child: ListenableBuilder(
                  listenable: _tabManager,
                  builder: (context, _) {
                    return BrowserTabSwitcher(
                      tabs: _tabManager.tabs,
                      activeIndex: _tabManager.activeIndex,
                      hitTester: _tabSwitcherHitTester,
                      canCloseTab: _tabManager.canCloseTab,
                    );
                  },
                ),
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
          if (_copyMode.active || _urlCopyMode.active)
            Positioned(
              left: 12,
              right: 12,
              bottom: MediaQuery.paddingOf(context).bottom + 12,
              child: TextSelectionBar(
                previewText: _copyMode.active
                    ? _selectedTextPreview
                    : _urlSelectedTextPreview,
                onCopy: _copyMode.active
                    ? _copySelectedText
                    : _copyUrlSelectedText,
                onSelectAll: _copyMode.active
                    ? _selectAllPageText
                    : _selectAllUrlForCopyBar,
                onDismiss: _copyMode.active
                    ? _dismissCopyMode
                    : _exitUrlCopyMode,
              ),
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
