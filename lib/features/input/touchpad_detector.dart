import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

typedef TouchpadTapCallback = void Function();
typedef TouchpadMoveCallback = void Function(Offset delta);
typedef TouchpadScrollCallback = void Function(Offset delta);
typedef TouchpadMultiTouchCallback = void Function();

enum _TapPhase { idle, afterFirstTap, buttonHeld }

class TouchpadDetector extends StatefulWidget {
  const TouchpadDetector({
    super.key,
    required this.child,
    required this.onMove,
    required this.onTap,
    required this.onDoubleTap,
    required this.onButtonDown,
    required this.onButtonUp,
    required this.onButtonCancel,
    required this.onLongPress,
    required this.onScroll,
    this.onMultiTouchStart,
    this.moveThreshold = 8,
    this.sensitivity = 1.0,
    this.scrollSensitivity = 1.0,
  });

  final Widget child;
  final TouchpadMoveCallback onMove;
  final TouchpadTapCallback onTap;
  final TouchpadTapCallback onDoubleTap;
  final TouchpadTapCallback onButtonDown;
  final TouchpadTapCallback onButtonUp;
  final TouchpadTapCallback onButtonCancel;
  final TouchpadTapCallback onLongPress;
  final TouchpadScrollCallback onScroll;
  final TouchpadMultiTouchCallback? onMultiTouchStart;
  final double moveThreshold;
  final double sensitivity;
  final double scrollSensitivity;

  @override
  State<TouchpadDetector> createState() => _TouchpadDetectorState();
}

enum _ScrollAxisLock { none, vertical, horizontal }

class _TouchpadDetectorState extends State<TouchpadDetector> {
  static const _twoFingerSlop = 12.0;
  static const _multiTapWindow = Duration(milliseconds: 350);

  final Map<int, Offset> _pointers = {};
  final Map<int, Offset> _lastPointerPositions = {};
  Offset? _lastPanPosition;
  Offset? _lastMultiTouchCentroid;
  Offset? _secondPressOrigin;
  double _secondPressMaxTravel = 0;
  bool _moved = false;
  bool _multiTouchActive = false;
  bool _twoFingerScrollActive = false;
  double _accumulatedCentroidTravel = 0;
  Offset _accumulatedTwoFingerDelta = Offset.zero;
  _ScrollAxisLock _scrollAxisLock = _ScrollAxisLock.none;
  _TapPhase _tapPhase = _TapPhase.idle;
  Timer? _longPressTimer;
  Timer? _afterFirstTapTimer;

  Offset _computeCentroid() {
    if (_pointers.isEmpty) {
      return Offset.zero;
    }
    var sum = Offset.zero;
    for (final position in _pointers.values) {
      sum += position;
    }
    return sum / _pointers.length.toDouble();
  }

  void _resetTwoFingerGesture() {
    _twoFingerScrollActive = false;
    _accumulatedCentroidTravel = 0;
    _accumulatedTwoFingerDelta = Offset.zero;
    _scrollAxisLock = _ScrollAxisLock.none;
  }

  void _beginTwoFingerGesture() {
    _resetTwoFingerGesture();
    _lastMultiTouchCentroid = _computeCentroid();
    _lastPointerPositions
      ..clear()
      ..addAll(_pointers);
  }

  void _updateMultiTouchCentroid() {
    if (_pointers.length >= 2) {
      _lastMultiTouchCentroid = _computeCentroid();
      _lastPointerPositions
        ..clear()
        ..addAll(_pointers);
    } else {
      _lastMultiTouchCentroid = null;
      _lastPointerPositions.clear();
      _resetTwoFingerGesture();
    }
  }

  bool _handleTwoFingerGesture() {
    final centroid = _computeCentroid();

    if (_lastMultiTouchCentroid == null) {
      _lastMultiTouchCentroid = centroid;
      _lastPointerPositions
        ..clear()
        ..addAll(_pointers);
      return true;
    }

    final frameCentroidDelta = centroid - _lastMultiTouchCentroid!;
    _accumulatedCentroidTravel += frameCentroidDelta.distance;

    if (_twoFingerScrollActive ||
        _accumulatedCentroidTravel >= _twoFingerSlop) {
      _twoFingerScrollActive = true;
      if (frameCentroidDelta != Offset.zero) {
        _accumulatedTwoFingerDelta += frameCentroidDelta;

        if (_scrollAxisLock == _ScrollAxisLock.none &&
            _accumulatedCentroidTravel >= _twoFingerSlop) {
          if (_accumulatedTwoFingerDelta.dx.abs() >=
              _accumulatedTwoFingerDelta.dy.abs()) {
            _scrollAxisLock = _ScrollAxisLock.horizontal;
          } else {
            _scrollAxisLock = _ScrollAxisLock.vertical;
          }
        }

        var scrollDelta = frameCentroidDelta * widget.scrollSensitivity;
        scrollDelta = switch (_scrollAxisLock) {
          _ScrollAxisLock.vertical => Offset(0, scrollDelta.dy),
          _ScrollAxisLock.horizontal => Offset(scrollDelta.dx, 0),
          _ScrollAxisLock.none => scrollDelta,
        };

        if (scrollDelta != Offset.zero) {
          widget.onScroll(Offset(-scrollDelta.dx, -scrollDelta.dy));
        }
      }
    }

    _lastMultiTouchCentroid = centroid;
    _lastPointerPositions
      ..clear()
      ..addAll(_pointers);
    return true;
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _afterFirstTapTimer?.cancel();
    super.dispose();
  }

  void _resetTapPhase() {
    _tapPhase = _TapPhase.idle;
    _secondPressOrigin = null;
    _secondPressMaxTravel = 0;
    _afterFirstTapTimer?.cancel();
    _afterFirstTapTimer = null;
  }

  void _enterAfterFirstTap() {
    _tapPhase = _TapPhase.afterFirstTap;
    _afterFirstTapTimer?.cancel();
    _afterFirstTapTimer = Timer(_multiTapWindow, _resetTapPhase);
  }

  void _onFirstTapUp() {
    widget.onTap();
    _enterAfterFirstTap();
  }

  void _enterSecondPressDown(Offset position) {
    _secondPressOrigin = position;
    _secondPressMaxTravel = 0;
    _afterFirstTapTimer?.cancel();
    _afterFirstTapTimer = null;
    _cancelLongPress();
    _enterButtonHeld();
  }

  void _enterButtonHeld() {
    if (_tapPhase == _TapPhase.buttonHeld) {
      return;
    }
    _tapPhase = _TapPhase.buttonHeld;
    widget.onButtonDown();
  }

  void _onSecondPressUp() {
    if (_tapPhase != _TapPhase.buttonHeld) {
      _resetTapPhase();
      return;
    }
    if (_secondPressMaxTravel >= widget.moveThreshold) {
      widget.onButtonUp();
    } else {
      widget.onButtonCancel();
      widget.onDoubleTap();
    }
    _resetTapPhase();
  }

  void _trackSecondPressMove(Offset position) {
    if (_tapPhase != _TapPhase.buttonHeld) {
      return;
    }
    final origin = _secondPressOrigin;
    if (origin == null) {
      return;
    }
    final travel = (position - origin).distance;
    if (travel > _secondPressMaxTravel) {
      _secondPressMaxTravel = travel;
    }
  }

  void _cancelLongPress() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  void _scheduleLongPress() {
    _cancelLongPress();
    if (_pointers.length != 1 ||
        _tapPhase == _TapPhase.buttonHeld) {
      return;
    }
    _longPressTimer = Timer(const Duration(milliseconds: 500), () {
      if (_pointers.length == 1 &&
          !_moved &&
          _tapPhase != _TapPhase.buttonHeld) {
        widget.onLongPress();
      }
    });
  }

  void _enterMultiTouch() {
    _multiTouchActive = true;
    _lastPanPosition = null;
    _moved = true;
    _cancelLongPress();
    _resetTapPhase();
    widget.onMultiTouchStart?.call();
  }

  void _onMultiTouchPointerRemoved() {
    if (_pointers.length == 1 && _multiTouchActive) {
      _lastPanPosition = _pointers.values.first;
      _moved = true;
      return;
    }

    if (_pointers.isEmpty) {
      _multiTouchActive = false;
      _lastPanPosition = null;
      _lastMultiTouchCentroid = null;
      _lastPointerPositions.clear();
      _resetTwoFingerGesture();
      _moved = false;
    }
  }

  void _handleSinglePointerUp() {
    switch (_tapPhase) {
      case _TapPhase.buttonHeld:
        _onSecondPressUp();
      case _TapPhase.idle:
        if (!_moved) {
          _onFirstTapUp();
        }
      case _TapPhase.afterFirstTap:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _pointers[event.pointer] = event.position;
        if (_pointers.length == 1) {
          _lastPanPosition = event.position;
          _lastMultiTouchCentroid = null;
          _moved = false;
          if (_tapPhase == _TapPhase.afterFirstTap) {
            _enterSecondPressDown(event.position);
          } else {
            _scheduleLongPress();
          }
        } else {
          if (_pointers.length == 2) {
            _enterMultiTouch();
            _beginTwoFingerGesture();
          } else {
            _cancelLongPress();
            _updateMultiTouchCentroid();
          }
        }
      },
      onPointerMove: (event) {
        _pointers[event.pointer] = event.position;

        if (_pointers.length >= 2) {
          _cancelLongPress();
          if (_handleTwoFingerGesture()) {
            return;
          }
        }

        if (_pointers.length == 1 && _lastPanPosition != null) {
          if (_tapPhase == _TapPhase.buttonHeld) {
            _trackSecondPressMove(event.position);
          }
          final delta = (event.position - _lastPanPosition!) * widget.sensitivity;
          if (delta.distance >= widget.moveThreshold || _moved) {
            _moved = true;
            _cancelLongPress();
            widget.onMove(delta);
            _lastPanPosition = event.position;
          }
        }
      },
      onPointerUp: (event) {
        final wasSinglePointer = _pointers.length == 1;
        _pointers.remove(event.pointer);
        _lastPointerPositions.remove(event.pointer);
        _cancelLongPress();
        _updateMultiTouchCentroid();

        if (wasSinglePointer) {
          _handleSinglePointerUp();
        }

        _onMultiTouchPointerRemoved();
      },
      onPointerCancel: (event) {
        final wasButtonHeld = _tapPhase == _TapPhase.buttonHeld;
        _pointers.remove(event.pointer);
        _lastPointerPositions.remove(event.pointer);
        _cancelLongPress();
        _updateMultiTouchCentroid();
        if (wasButtonHeld) {
          widget.onButtonCancel();
          _resetTapPhase();
        }
        _onMultiTouchPointerRemoved();
      },
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          final rawDelta = Offset(
            -event.scrollDelta.dx * widget.scrollSensitivity,
            -event.scrollDelta.dy * widget.scrollSensitivity,
          );
          final absX = rawDelta.dx.abs();
          final absY = rawDelta.dy.abs();
          if (absX == 0 && absY == 0) {
            return;
          }

          final lockedDelta = absY >= absX
              ? Offset(0, rawDelta.dy)
              : Offset(rawDelta.dx, 0);
          widget.onScroll(lockedDelta);
        }
      },
      child: widget.child,
    );
  }
}
