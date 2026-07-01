import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cursor_pad/features/bookmarks/bookmark.dart';
import 'package:cursor_pad/features/bookmarks/bookmark_file_storage.dart';
import 'package:cursor_pad/features/bookmarks/bookmark_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late BookmarkFileStorage fileStorage;
  late BookmarkRepository repository;

  final sampleBookmark = Bookmark(
    id: '1',
    title: 'Example',
    url: 'https://example.com',
    createdAt: DateTime.utc(2026, 1, 1),
  );

  final olderBookmark = Bookmark(
    id: '2',
    title: 'Older',
    url: 'https://older.example.com',
    createdAt: DateTime.utc(2025, 12, 1),
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cursor_pad_bookmarks_test');
    fileStorage = BookmarkFileStorage(baseDirectory: tempDir);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repository = BookmarkRepository(prefs: prefs, fileStorage: fileStorage);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('BookmarkRepository', () {
    test('getAll returns empty list when no file and no prefs', () async {
      expect(await repository.getAll(), isEmpty);
    });

    test('add persists bookmark to file', () async {
      await repository.add(sampleBookmark);

      final bookmarks = await repository.getAll();
      expect(bookmarks, hasLength(1));
      expect(bookmarks.first.url, sampleBookmark.url);

      final file = File('${tempDir.path}/CursorPad/bookmarks.json');
      expect(await file.exists(), isTrue);
      final decoded = jsonDecode(await file.readAsString()) as List<dynamic>;
      expect(decoded, hasLength(1));
    });

    test('remove deletes bookmark from file', () async {
      await repository.add(sampleBookmark);
      await repository.remove(sampleBookmark.id);

      expect(await repository.getAll(), isEmpty);
    });

    test('containsUrl reflects stored bookmarks', () async {
      await repository.add(sampleBookmark);

      expect(await repository.containsUrl(sampleBookmark.url), isTrue);
      expect(await repository.containsUrl('https://missing.example.com'), isFalse);
    });

    test('add replaces bookmark with same url', () async {
      await repository.add(sampleBookmark);
      await repository.add(
        Bookmark(
          id: '3',
          title: 'Updated',
          url: sampleBookmark.url,
          createdAt: DateTime.utc(2026, 2, 1),
        ),
      );

      final bookmarks = await repository.getAll();
      expect(bookmarks, hasLength(1));
      expect(bookmarks.first.title, 'Updated');
    });

    test('getAll sorts by createdAt descending', () async {
      await repository.add(olderBookmark);
      await repository.add(sampleBookmark);

      final bookmarks = await repository.getAll();
      expect(bookmarks.first.id, sampleBookmark.id);
      expect(bookmarks.last.id, olderBookmark.id);
    });

    test('migrates legacy SharedPreferences data to file once', () async {
      final legacyData = jsonEncode([
        sampleBookmark.toJson(),
        olderBookmark.toJson(),
      ]);
      SharedPreferences.setMockInitialValues({
        'cursor_pad_bookmarks': legacyData,
      });
      final prefs = await SharedPreferences.getInstance();
      repository = BookmarkRepository(prefs: prefs, fileStorage: fileStorage);

      final bookmarks = await repository.getAll();
      expect(bookmarks, hasLength(2));
      expect(bookmarks.first.id, sampleBookmark.id);

      final file = File('${tempDir.path}/CursorPad/bookmarks.json');
      expect(await file.exists(), isTrue);
      expect(prefs.getString('cursor_pad_bookmarks'), isNull);

      SharedPreferences.setMockInitialValues({});
      final freshPrefs = await SharedPreferences.getInstance();
      final freshRepository = BookmarkRepository(
        prefs: freshPrefs,
        fileStorage: fileStorage,
      );
      final reloaded = await freshRepository.getAll();
      expect(reloaded, hasLength(2));
    });

    test('save clears legacy SharedPreferences key', () async {
      SharedPreferences.setMockInitialValues({
        'cursor_pad_bookmarks': jsonEncode([sampleBookmark.toJson()]),
      });
      final prefs = await SharedPreferences.getInstance();
      repository = BookmarkRepository(prefs: prefs, fileStorage: fileStorage);

      await repository.add(
        Bookmark(
          id: '4',
          title: 'New',
          url: 'https://new.example.com',
          createdAt: DateTime.utc(2026, 3, 1),
        ),
      );

      expect(prefs.getString('cursor_pad_bookmarks'), isNull);
    });
  });

  group('BookmarkFileStorage', () {
    test('readAll returns null when file does not exist', () async {
      expect(await fileStorage.readAll(), isNull);
    });

    test('writeAll uses atomic temp file rename', () async {
      await fileStorage.writeAll([sampleBookmark]);

      final file = File('${tempDir.path}/CursorPad/bookmarks.json');
      final tempFile = File('${file.path}.tmp');
      expect(await file.exists(), isTrue);
      expect(await tempFile.exists(), isFalse);
    });
  });
}
