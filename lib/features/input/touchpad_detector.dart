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
  bool _moved = false;
  Timer? _longPressTimer;

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
          _moved = false;
          _scheduleLongPress();
        } else {
          _cancelLongPress();
        }
      },
      onPointerMove: (event) {
        _pointers[event.pointer] = event.position;

        if (_pointers.length >= 2) {
          _cancelLongPress();
          widget.onScroll(
            Offset(0, -event.delta.dy * widget.scrollSensitivity),
          );
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

        if (wasSinglePointer && !_moved) {
          widget.onTap();
        }

        if (_pointers.isEmpty) {
          _lastPanPosition = null;
          _moved = false;
        }
      },
      onPointerCancel: (event) {
        _pointers.remove(event.pointer);
        _cancelLongPress();
        if (_pointers.isEmpty) {
          _lastPanPosition = null;
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
