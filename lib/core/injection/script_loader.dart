import 'package:flutter/services.dart';

class ScriptLoader {
  ScriptLoader._();

  static Future<String> load(String assetPath) {
    return rootBundle.loadString(assetPath);
  }
}
