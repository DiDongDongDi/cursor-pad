import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'bookmark.dart';

class BookmarkFileStorage {
  BookmarkFileStorage({Directory? baseDirectory}) : _baseDirectory = baseDirectory;

  static const _subdir = 'CursorPad';
  static const _fileName = 'bookmarks.json';

  final Directory? _baseDirectory;
  Directory? _resolvedDirectory;

  Future<Directory> get _directory async {
    if (_resolvedDirectory != null) {
      return _resolvedDirectory!;
    }

    if (_baseDirectory != null) {
      _resolvedDirectory = Directory('${_baseDirectory.path}/$_subdir');
    } else {
      final base = await _resolveStorageBaseDirectory();
      _resolvedDirectory = Directory('${base.path}/$_subdir');
    }

    await _resolvedDirectory!.create(recursive: true);
    return _resolvedDirectory!;
  }

  Future<File> get _file async {
    final directory = await _directory;
    return File('${directory.path}/$_fileName');
  }

  Future<List<Bookmark>?> readAll() async {
    final file = await _file;
    if (!await file.exists()) {
      return null;
    }

    final raw = await file.readAsString();
    if (raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => Bookmark.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> writeAll(List<Bookmark> bookmarks) async {
    final file = await _file;
    final tempFile = File('${file.path}.tmp');
    final encoded = jsonEncode(bookmarks.map((item) => item.toJson()).toList());
    await tempFile.writeAsString(encoded);
    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
  }

  Future<Directory> _resolveStorageBaseDirectory() async {
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        return downloads;
      }
    } catch (_) {
      // Tests and some platforms may not expose Downloads.
    }

    return getApplicationDocumentsDirectory();
  }
}
