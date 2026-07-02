import 'dart:async';

import 'package:flutter/foundation.dart';

class ToolbarVisibilityController extends ChangeNotifier {
  ToolbarVisibilityController({
    this.showEdgeThreshold = 0,
    this.keepEdgeThreshold = 16,
    this.showDelay = const Duration(milliseconds: 400),
    this.hideDelay = const Duration(milliseconds: 800),
  });

  final double showEdgeThreshold;
  final double keepEdgeThreshold;
  final Duration showDelay;
  final Duration hideDelay;

  bool _visible = false;
  bool _pinned = false;
  Timer? _showTimer;
  Timer? _hideTimer;

  bool get visible => _visible || _pinned;

  void pin() {
    _pinned = true;
    _cancelTimers();
    if (!_visible) {
      _visible = true;
      notifyListeners();
    }
  }

  void unpin() {
    if (!_pinned) {
      return;
    }
    _pinned = false;
    notifyListeners();
    _scheduleHide();
  }

  void forceShow() {
    _cancelTimers();
    if (!_visible) {
      _visible = true;
      notifyListeners();
    }
  }

  void onCursorMove(double globalY, {required double chromeHeight}) {
    if (_pinned) {
      return;
    }

    if (_visible) {
      if (globalY < chromeHeight + keepEdgeThreshold) {
        _hideTimer?.cancel();
      } else {
        _scheduleHide();
      }
      return;
    }

    if (globalY <= showEdgeThreshold) {
      _hideTimer?.cancel();
      if (_showTimer != null) {
        return;
      }
      _showTimer = Timer(showDelay, () {
        _showTimer = null;
        _visible = true;
        notifyListeners();
      });
      return;
    }

    _showTimer?.cancel();
    _showTimer = null;
  }

  void _scheduleHide() {
    if (_pinned) {
      return;
    }
    _hideTimer?.cancel();
    _hideTimer = Timer(hideDelay, () {
      _hideTimer = null;
      if (_pinned) {
        return;
      }
      _visible = false;
      notifyListeners();
    });
  }

  void _cancelTimers() {
    _showTimer?.cancel();
    _showTimer = null;
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }
}
