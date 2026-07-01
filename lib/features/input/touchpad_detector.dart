import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

typedef TouchpadTapCallback = void Function();
typedef TouchpadMoveCallback = void Function(Offset delta);
typedef TouchpadScrollCallback = void Function(Offset delta);
typedef TouchpadPinchCallback = void Function(double scaleFactor);

class TouchpadDetector extends StatefulWidget {
  const TouchpadDetector({
    super.key,
    required this.child,
    required this.onMove,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
    required this.onScroll,
    required this.onPinch,
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
  final TouchpadPinchCallback onPinch;
  final double moveThreshold;
  final double sensitivity;
  final double scrollSensitivity;

  @override
  State<TouchpadDetector> createState() => _TouchpadDetectorState();
}

class _TouchpadDetectorState extends State<TouchpadDetector> {
  final Map<int, Offset> _pointers = {};
  final Map<int, Offset> _lastPointerPositions = {};
  Offset? _lastPanPosition;
  Offset? _lastMultiTouchCentroid;
  double? _lastPinchDistance;
  bool _moved = false;
  Timer? _longPressTimer;

  double _pointerDistance() {
    if (_pointers.length < 2) {
      return 0;
    }
    final positions = _pointers.values.toList(growable: false);
    return (positions[0] - positions[1]).distance;
  }

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
      _lastPinchDistance = _pointerDistance();
      _lastPointerPositions
        ..clear()
        ..addAll(_pointers);
    } else {
      _lastMultiTouchCentroid = null;
      _lastPinchDistance = null;
      _lastPointerPositions.clear();
    }
  }

  bool _handleTwoFingerGesture() {
    final distance = _pointerDistance();
    final centroid = _computeCentroid();
    if (_lastPinchDistance == null ||
        _lastMultiTouchCentroid == null ||
        _lastPinchDistance! <= 10) {
      _lastPinchDistance = distance;
      _lastMultiTouchCentroid = centroid;
      _lastPointerPositions
        ..clear()
        ..addAll(_pointers);
      return true;
    }

    final ids = _pointers.keys.toList(growable: false);
    if (ids.length < 2) {
      return true;
    }

    final first = _pointers[ids[0]]!;
    final second = _pointers[ids[1]]!;
    final prevFirst = _lastPointerPositions[ids[0]] ?? first;
    final prevSecond = _lastPointerPositions[ids[1]] ?? second;
    final deltaFirst = first - prevFirst;
    final deltaSecond = second - prevSecond;
    final axis = second - first;
    final axisLength = axis.distance;

    if (axisLength > 10) {
      final axisUnit = axis / axisLength;
      final scaleFactor = distance / _lastPinchDistance!;
      final scaleDelta = (scaleFactor - 1.0).abs();
      final hasFirstDelta = deltaFirst != Offset.zero;
      final hasSecondDelta = deltaSecond != Offset.zero;

      if (hasFirstDelta || hasSecondDelta) {
        var isPinch = false;

        if (hasFirstDelta && hasSecondDelta) {
          final spreadFirst =
              deltaFirst.dx * axisUnit.dx + deltaFirst.dy * axisUnit.dy;
          final spreadSecond = -(deltaSecond.dx * axisUnit.dx +
              deltaSecond.dy * axisUnit.dy);
          final pinchDelta = spreadFirst + spreadSecond;
          final parallelDelta = (deltaFirst - deltaSecond).distance;
          isPinch =
              pinchDelta.abs() > 2 && pinchDelta.abs() > parallelDelta * 0.35;
        } else {
          final activeDelta = hasFirstDelta ? deltaFirst : deltaSecond;
          final alongAxis =
              (activeDelta.dx * axisUnit.dx + activeDelta.dy * axisUnit.dy)
                  .abs();
          final acrossAxis =
              (activeDelta.dx * -axisUnit.dy + activeDelta.dy * axisUnit.dx)
                  .abs();
          isPinch = scaleDelta > 0.02 && alongAxis > acrossAxis;
        }

        if (isPinch && scaleDelta > 0.005) {
          widget.onPinch(scaleFactor);
          _lastPinchDistance = distance;
          _lastMultiTouchCentroid = centroid;
          _lastPointerPositions
            ..clear()
            ..addAll(_pointers);
          return true;
        }
      }
    }

    final scrollDelta =
        (centroid - _lastMultiTouchCentroid!) * widget.scrollSensitivity;
    if (scrollDelta != Offset.zero) {
      widget.onScroll(Offset(-scrollDelta.dx, -scrollDelta.dy));
    }

    _lastPinchDistance = distance;
    _lastMultiTouchCentroid = centroid;
    _lastPointerPositions
      ..clear()
      ..addAll(_pointers);
    return true;
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
          if (_handleTwoFingerGesture()) {
            return;
          }
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
        _lastPointerPositions.remove(event.pointer);
        _cancelLongPress();
        _updateMultiTouchCentroid();

        if (wasSinglePointer && !_moved) {
          widget.onTap();
        }

        if (_pointers.isEmpty) {
          _lastPanPosition = null;
          _lastMultiTouchCentroid = null;
          _lastPinchDistance = null;
          _lastPointerPositions.clear();
          _moved = false;
        }
      },
      onPointerCancel: (event) {
        _pointers.remove(event.pointer);
        _lastPointerPositions.remove(event.pointer);
        _cancelLongPress();
        _updateMultiTouchCentroid();
        if (_pointers.isEmpty) {
          _lastPanPosition = null;
          _lastMultiTouchCentroid = null;
          _lastPinchDistance = null;
          _lastPointerPositions.clear();
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
