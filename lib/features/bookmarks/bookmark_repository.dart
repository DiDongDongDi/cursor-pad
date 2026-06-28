import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'bookmark.dart';

class BookmarkRepository {
  BookmarkRepository({SharedPreferences? prefs}) : _prefs = prefs;

  static const _storageKey = 'cursor_pad_bookmarks';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<Bookmark>> getAll() async {
    final prefs = await _preferences;
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => Bookmark.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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

  Future<void> _save(List<Bookmark> bookmarks) async {
    final prefs = await _preferences;
    final encoded = jsonEncode(bookmarks.map((item) => item.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}
