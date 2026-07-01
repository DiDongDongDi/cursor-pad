import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'bookmark.dart';
import 'bookmark_file_storage.dart';

class BookmarkRepository {
  BookmarkRepository({
    SharedPreferences? prefs,
    BookmarkFileStorage? fileStorage,
  })  : _prefs = prefs,
        _fileStorage = fileStorage ?? BookmarkFileStorage();

  static const _storageKey = 'cursor_pad_bookmarks';

  SharedPreferences? _prefs;
  final BookmarkFileStorage _fileStorage;

  Future<SharedPreferences> get _preferences async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<Bookmark>> getAll() async {
    final fromFile = await _fileStorage.readAll();
    if (fromFile != null) {
      return _sorted(fromFile);
    }

    final fromPrefs = await _readFromPreferences();
    if (fromPrefs.isEmpty) {
      return const [];
    }

    await _fileStorage.writeAll(fromPrefs);
    final prefs = await _preferences;
    await prefs.remove(_storageKey);
    return _sorted(fromPrefs);
  }

  Future<void> add(Bookmark bookmark) async {
    final bookmarks = await getAll();
    final filtered = bookmarks.where((item) => item.url != bookmark.url).toList();
    filtered.insert(0, bookmark);
    await _save(filtered);
  }

  Future<void> remove(String id) async {
    final bookmarks = await getAll();
    bookmarks.removeWhere((item) => item.id == id);
    await _save(bookmarks);
  }

  Future<bool> containsUrl(String url) async {
    final bookmarks = await getAll();
    return bookmarks.any((item) => item.url == url);
  }

  Future<List<Bookmark>> _readFromPreferences() async {
    final prefs = await _preferences;
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => Bookmark.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  List<Bookmark> _sorted(List<Bookmark> bookmarks) {
    return bookmarks.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> _save(List<Bookmark> bookmarks) async {
    await _fileStorage.writeAll(bookmarks);
    final prefs = await _preferences;
    await prefs.remove(_storageKey);
  }
}
