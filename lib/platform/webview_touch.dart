import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android-only native touch injection into the WebView platform view.
/// Produces trusted touch events that work on sites ignoring synthetic JS clicks.
class WebViewTouchSimulator {
  static const MethodChannel _channel =
      MethodChannel('com.cursorpad.cursor_pad/webview_touch');

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> clickAt(double x, double y) async {
    if (!_isAndroid) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('clickAt', {
        'x': x,
        'y': y,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> dragDown(double x, double y) async {
    if (!_isAndroid) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('dragDown', {
        'x': x,
        'y': y,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> dragMove(double x, double y) async {
    if (!_isAndroid) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('dragMove', {
        'x': x,
        'y': y,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> dragUp(double x, double y) async {
    if (!_isAndroid) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('dragUp', {
        'x': x,
        'y': y,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Trusted mouse drag for chart box-select / zoom (SOURCE_MOUSE).
  static Future<bool> mouseDragDown(double x, double y) async {
    if (!_isAndroid) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('mouseDragDown', {
        'x': x,
        'y': y,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> mouseDragMove(double x, double y) async {
    if (!_isAndroid) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('mouseDragMove', {
        'x': x,
        'y': y,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> mouseDragUp(double x, double y) async {
    if (!_isAndroid) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('mouseDragUp', {
        'x': x,
        'y': y,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> showIme() async {
    if (!_isAndroid) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('showIme');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hideIme() async {
    if (!_isAndroid) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('hideIme');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
