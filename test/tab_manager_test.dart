import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cursor_pad/features/bookmarks/bookmark_file_storage.dart';
import 'package:cursor_pad/features/bookmarks/bookmark_repository.dart';
import 'package:cursor_pad/features/browser/tab_manager.dart';
import 'package:cursor_pad/features/settings/browser_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cursor_pad_tab_manager_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<TabManager> createManager() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return TabManager(
      bookmarkRepository: BookmarkRepository(
        prefs: prefs,
        fileStorage: BookmarkFileStorage(baseDirectory: tempDir),
      ),
    );
  }

  group('TabManager', () {
    test('starts with one tab', () {
      final manager = TabManager();
      addTearDown(manager.dispose);

      expect(manager.tabs, hasLength(1));
      expect(manager.activeIndex, 0);
      expect(manager.canCloseTab, isFalse);
    });

    test('createTab adds tab and switches active index', () {
      final manager = TabManager();
      addTearDown(manager.dispose);

      expect(manager.createTab(), isTrue);

      expect(manager.tabs, hasLength(2));
      expect(manager.activeIndex, 1);
      expect(manager.canCloseTab, isTrue);
    });

    test('createTab respects maxTabs', () {
      final manager = TabManager(maxTabs: 2);
      addTearDown(manager.dispose);

      expect(manager.createTab(), isTrue);
      expect(manager.createTab(), isFalse);
      expect(manager.tabs, hasLength(2));
    });

    test('createTab with url sets pending navigation', () {
      final manager = TabManager();
      addTearDown(manager.dispose);

      manager.createTab(url: 'https://example.com');

      expect(
        manager.activeTab.controller.state.currentUrl,
        'https://example.com',
      );
    });

    test('switchTab changes active index', () {
      final manager = TabManager();
      addTearDown(manager.dispose);

      manager.createTab();
      manager.switchTab(0);

      expect(manager.activeIndex, 0);
    });

    test('closeTab removes tab and keeps at least one', () {
      final manager = TabManager();
      addTearDown(manager.dispose);

      manager.createTab();
      manager.createTab();

      expect(manager.closeTab(2), isTrue);
      expect(manager.tabs, hasLength(2));
      expect(manager.activeIndex, 1);

      expect(manager.closeTab(0), isTrue);
      expect(manager.tabs, hasLength(1));
      expect(manager.activeIndex, 0);

      expect(manager.closeTab(0), isFalse);
      expect(manager.tabs, hasLength(1));
    });

    test('closeTab adjusts active index when closing active tab', () {
      final manager = TabManager();
      addTearDown(manager.dispose);

      manager.createTab();
      manager.createTab();
      expect(manager.activeIndex, 2);

      expect(manager.closeTab(2), isTrue);
      expect(manager.activeIndex, 1);
    });

    test('prepareInitialContent marks html ready', () async {
      final manager = await createManager();
      addTearDown(manager.dispose);

      expect(manager.initialHtmlReady, isFalse);
      await manager.prepareInitialContent();

      expect(manager.initialHtmlReady, isTrue);
      expect(manager.initialBookmarksHtml, isNotNull);
      expect(manager.tabs.first.initialBookmarksHtml, isNotNull);
    });

    test('new tab defaults to bookmarks home url', () {
      final manager = TabManager();
      addTearDown(manager.dispose);

      manager.createTab();

      expect(
        manager.activeTab.controller.state.currentUrl,
        BrowserSettings.bookmarksHomeUrl,
      );
    });
  });
}
