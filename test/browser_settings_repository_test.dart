import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cursor_pad/features/settings/browser_settings.dart';
import 'package:cursor_pad/features/settings/browser_settings_file_storage.dart';
import 'package:cursor_pad/features/settings/browser_settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late BrowserSettingsFileStorage fileStorage;
  late BrowserSettingsRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cursor_pad_settings_test');
    fileStorage = BrowserSettingsFileStorage(baseDirectory: tempDir);
    repository = BrowserSettingsRepository(fileStorage: fileStorage);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('BrowserSettingsRepository', () {
    test('load returns defaults when no file exists', () async {
      final settings = await repository.load();

      expect(settings.cursorSensitivity, BrowserSettings.defaultCursorSensitivity);
      expect(settings.scrollSensitivity, BrowserSettings.defaultScrollSensitivity);
    });

    test('save persists settings to file', () async {
      const settings = BrowserSettings(
        cursorSensitivity: 2.5,
        scrollSensitivity: 3.0,
      );

      await repository.save(settings);

      final file = File('${tempDir.path}/CursorPad/settings.json');
      expect(await file.exists(), isTrue);

      final decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      expect(decoded['cursorSensitivity'], 2.5);
      expect(decoded['scrollSensitivity'], 3.0);
    });

    test('load reads previously saved settings', () async {
      await repository.save(
        const BrowserSettings(
          cursorSensitivity: 1.0,
          scrollSensitivity: 2.25,
        ),
      );

      final freshRepository = BrowserSettingsRepository(fileStorage: fileStorage);
      final settings = await freshRepository.load();

      expect(settings.cursorSensitivity, 1.0);
      expect(settings.scrollSensitivity, 2.25);
    });

    test('fromJson clamps out-of-range values', () {
      final settings = BrowserSettings.fromJson({
        'cursorSensitivity': 99,
        'scrollSensitivity': -1,
      });

      expect(settings.cursorSensitivity, BrowserSettings.maxSensitivity);
      expect(settings.scrollSensitivity, BrowserSettings.minSensitivity);
    });
  });
}
