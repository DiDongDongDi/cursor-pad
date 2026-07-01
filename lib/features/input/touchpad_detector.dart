import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

typedef TouchpadTapCallback = void Function();
typedef TouchpadMoveCallback = void Function(Offset delta);
typedef TouchpadScrollCallback = void Function(Offset delta);

class TouchpadDetector extends StatefulWidget {
  const TouchpadDetector({
    super.key,
    required this.child,
    required this.onMove,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
    required this.onScroll,
    this.moveThreshold = 8,
    this.sensitivity = 1.0,
    this.scrollSensitivity = 1.0,
  });

  final Widget child;
  final TouchpadMoveCallback onMove;
  final TouchpadTapCallback onTap;
  final TouchpadTapCallback onDoubleTap;
  final TouchpadTapCallback onLongPress;
  final TouchpadScrollCallback onScroll;
  final double moveThreshold;
  final double sensitivity;
  final double scrollSensitivity;

  @override
  State<TouchpadDetector> createState() => _TouchpadDetectorState();
}

class _TouchpadDetectorState extends State<TouchpadDetector> {
  final Map<int, Offset> _pointers = {};
  Offset? _lastPanPosition;
  Offset? _lastMultiTouchCentroid;
  bool _moved = false;
  Timer? _longPressTimer;

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

  void _updateMultiTouchCentroid() {
    if (_pointers.length >= 2) {
      _lastMultiTouchCentroid = _computeCentroid();
    } else {
      _lastMultiTouchCentroid = null;
    }
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  void _cancelLongPress() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  void _scheduleLongPress() {
    _cancelLongPress();
    if (_pointers.length != 1) {
      return;
    }
    _longPressTimer = Timer(const Duration(milliseconds: 500), () {
      if (_pointers.length == 1 && !_moved) {
        widget.onLongPress();
      }
    });
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
          _scheduleLongPress();
        } else {
          _cancelLongPress();
          _updateMultiTouchCentroid();
        }
      },
      onPointerMove: (event) {
        _pointers[event.pointer] = event.position;

        if (_pointers.length >= 2) {
          _cancelLongPress();
          final centroid = _computeCentroid();
          if (_lastMultiTouchCentroid != null) {
            final delta =
                (centroid - _lastMultiTouchCentroid!) * widget.scrollSensitivity;
            if (delta != Offset.zero) {
              widget.onScroll(Offset(-delta.dx, -delta.dy));
            }
          }
          _lastMultiTouchCentroid = centroid;
          return;
        }

        if (_pointers.length == 1 && _lastPanPosition != null) {
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
        _cancelLongPress();
        _updateMultiTouchCentroid();

        if (wasSinglePointer && !_moved) {
          widget.onTap();
        }

        if (_pointers.isEmpty) {
          _lastPanPosition = null;
          _lastMultiTouchCentroid = null;
          _moved = false;
        }
      },
      onPointerCancel: (event) {
        _pointers.remove(event.pointer);
        _cancelLongPress();
        _updateMultiTouchCentroid();
        if (_pointers.isEmpty) {
          _lastPanPosition = null;
          _lastMultiTouchCentroid = null;
          _moved = false;
        }
      },
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          widget.onScroll(
            Offset(
              -event.scrollDelta.dx * widget.scrollSensitivity,
              -event.scrollDelta.dy * widget.scrollSensitivity,
            ),
          );
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onDoubleTap: widget.onDoubleTap,
        child: widget.child,
      ),
    );
  }
}
