import 'dart:async';

import 'package:flutter/foundation.dart';

import '../settings/browser_settings.dart';
import 'browser_controller.dart';
import 'browser_tab.dart';

class TabManager extends ChangeNotifier {
  TabManager({
    BrowserSettings? settings,
    this.maxTabs = 20,
  }) : _settings = settings ?? const BrowserSettings() {
    _tabs.add(_createTabInstance(prepareInitialHtml: true));
  }

  final BrowserSettings _settings;
  final int maxTabs;
  final List<BrowserTab> _tabs = [];
  int _activeIndex = 0;
  bool _initialHtmlReady = false;
  String? _initialBookmarksHtml;

  List<BrowserTab> get tabs => List.unmodifiable(_tabs);
  int get activeIndex => _activeIndex;
  BrowserTab get activeTab => _tabs[_activeIndex];
  BrowserSettings get settings => _settings;
  bool get initialHtmlReady => _initialHtmlReady;
  String? get initialBookmarksHtml => _initialBookmarksHtml;
  bool get canCloseTab => _tabs.length > 1;

  Future<void> prepareInitialContent() async {
    if (_initialHtmlReady) {
      return;
    }
    await _tabs.first.controller.prepareInitialBookmarksHtml();
    _initialBookmarksHtml = _tabs.first.controller.initialBookmarksHtml;
    _tabs.first.initialBookmarksHtml = _initialBookmarksHtml;
    _initialHtmlReady = true;
    notifyListeners();
  }

  BrowserTab _createTabInstance({bool prepareInitialHtml = false}) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    return BrowserTab(
      id: id,
      controller: BrowserController(settings: _settings),
      initialBookmarksHtml: prepareInitialHtml ? _initialBookmarksHtml : null,
    );
  }

  bool createTab({String? url}) {
    if (_tabs.length >= maxTabs) {
      return false;
    }

    final tab = _createTabInstance();
    _tabs.add(tab);
    _activeIndex = _tabs.length - 1;
    notifyListeners();

    final targetUrl = url ?? BrowserSettings.bookmarksHomeUrl;
    unawaited(tab.controller.loadUrl(targetUrl));
    return true;
  }

  bool closeTab(int index) {
    if (_tabs.length <= 1 || index < 0 || index >= _tabs.length) {
      return false;
    }

    final tab = _tabs.removeAt(index);
    tab.controller.dispose();

    if (_activeIndex >= _tabs.length) {
      _activeIndex = _tabs.length - 1;
    } else if (index < _activeIndex) {
      _activeIndex--;
    }

    notifyListeners();
    return true;
  }

  void switchTab(int index) {
    if (index < 0 || index >= _tabs.length || index == _activeIndex) {
      return;
    }
    _activeIndex = index;
    notifyListeners();
  }

  void recreateWebViewForTab(BrowserTab tab) {
    tab.webViewReady = false;
    tab.webViewKey++;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final tab in _tabs) {
      tab.controller.dispose();
    }
    _tabs.clear();
    super.dispose();
  }
}
