import 'browser_settings.dart';
import 'browser_settings_file_storage.dart';

class BrowserSettingsRepository {
  BrowserSettingsRepository({
    BrowserSettingsFileStorage? fileStorage,
  }) : _fileStorage = fileStorage ?? BrowserSettingsFileStorage();

  final BrowserSettingsFileStorage _fileStorage;

  Future<BrowserSettings> load() async {
    final stored = await _fileStorage.read();
    return stored ?? const BrowserSettings();
  }

  Future<void> save(BrowserSettings settings) async {
    await _fileStorage.write(settings);
  }
}
