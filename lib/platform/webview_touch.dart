import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android-only native touch injection into the WebView platform view.
/// Produces trusted touch events that work on sites ignoring synthetic JS clicks.
class WebViewTouchSimulator {
  static const MethodChannel _channel =
      MethodChannel('com.cursorpad.cursor_pad/webview_touch');

  static Future<bool> clickAt(double x, double y) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
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

  static Future<bool> touchDownAt(double x, double y) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('touchDownAt', {
        'x': x,
        'y': y,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> touchMoveTo(double x, double y) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('touchMoveTo', {
        'x': x,
        'y': y,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> touchUpAt(double x, double y) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('touchUpAt', {
        'x': x,
        'y': y,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> showIme() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('showIme');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
