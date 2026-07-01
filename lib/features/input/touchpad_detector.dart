import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

typedef TouchpadTapCallback = void Function();
typedef TouchpadMoveCallback = void Function(Offset delta);
typedef TouchpadScrollCallback = void Function(Offset delta);
typedef TouchpadPinchCallback = void Function(double scaleFactor);

enum _TwoFingerMode { undecided, scroll, pinch }

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
  static const _twoFingerSlop = 12.0;
  static const _pinchDistanceRate = 0.07;
  static const _spreadParallelRatio = 1.2;
  static const _pinchSpreadSlop = 18.0;

  final Map<int, Offset> _pointers = {};
  final Map<int, Offset> _lastPointerPositions = {};
  Offset? _lastPanPosition;
  Offset? _lastMultiTouchCentroid;
  double? _lastPinchDistance;
  bool _moved = false;
  bool _multiTouchActive = false;
  Timer? _longPressTimer;

  _TwoFingerMode _twoFingerMode = _TwoFingerMode.undecided;
  Offset? _gestureStartCentroid;
  double? _gestureStartDistance;
  double _accumulatedCentroidTravel = 0;
  double _accumulatedSpread = 0;
  double _accumulatedParallel = 0;

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

  void _resetTwoFingerGesture() {
    _twoFingerMode = _TwoFingerMode.undecided;
    _gestureStartCentroid = null;
    _gestureStartDistance = null;
    _accumulatedCentroidTravel = 0;
    _accumulatedSpread = 0;
    _accumulatedParallel = 0;
  }

  void _beginTwoFingerGesture() {
    _resetTwoFingerGesture();
    _gestureStartCentroid = _computeCentroid();
    _gestureStartDistance = _pointerDistance();
    _lastMultiTouchCentroid = _gestureStartCentroid;
    _lastPinchDistance = _gestureStartDistance;
    _lastPointerPositions
      ..clear()
      ..addAll(_pointers);
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
      _resetTwoFingerGesture();
    }
  }

  ({double spread, double parallel}) _computeFrameSpreadParallel(
    Offset deltaFirst,
    Offset deltaSecond,
    Offset axis,
  ) {
    final axisLength = axis.distance;
    if (axisLength <= 10 ||
        (deltaFirst == Offset.zero && deltaSecond == Offset.zero)) {
      return (spread: 0, parallel: 0);
    }

    final axisUnit = axis / axisLength;
    if (deltaFirst != Offset.zero && deltaSecond != Offset.zero) {
      final spreadFirst =
          deltaFirst.dx * axisUnit.dx + deltaFirst.dy * axisUnit.dy;
      final spreadSecond = -(deltaSecond.dx * axisUnit.dx +
          deltaSecond.dy * axisUnit.dy);
      return (
        spread: (spreadFirst + spreadSecond).abs(),
        parallel: (deltaFirst - deltaSecond).distance,
      );
    }

    final activeDelta = deltaFirst != Offset.zero ? deltaFirst : deltaSecond;
    final alongAxis =
        (activeDelta.dx * axisUnit.dx + activeDelta.dy * axisUnit.dy).abs();
    final acrossAxis =
        (activeDelta.dx * -axisUnit.dy + activeDelta.dy * axisUnit.dx).abs();
    return (spread: alongAxis, parallel: acrossAxis);
  }

  void _tryLockTwoFingerMode(double distance) {
    if (_twoFingerMode != _TwoFingerMode.undecided ||
        _gestureStartDistance == null ||
        _gestureStartDistance! <= 10) {
      return;
    }

    final distanceChangeRate = (distance - _gestureStartDistance!).abs() /
        _gestureStartDistance!;

    final readyToDecide = _accumulatedCentroidTravel >= _twoFingerSlop ||
        _accumulatedSpread >= _twoFingerSlop ||
        distanceChangeRate >= _pinchDistanceRate;

    if (!readyToDecide) {
      return;
    }

    if (_accumulatedCentroidTravel >= _twoFingerSlop &&
        _accumulatedCentroidTravel > _accumulatedSpread * 1.2) {
      _twoFingerMode = _TwoFingerMode.scroll;
      return;
    }

    final lockScroll = _accumulatedCentroidTravel >= _twoFingerSlop &&
        (distanceChangeRate < _pinchDistanceRate ||
            _accumulatedParallel > _accumulatedSpread * _spreadParallelRatio);

    final lockPinch = distanceChangeRate >= _pinchDistanceRate &&
        _accumulatedSpread > _accumulatedParallel * _spreadParallelRatio &&
        _accumulatedSpread >= _pinchSpreadSlop &&
        _accumulatedCentroidTravel < _accumulatedSpread;

    if (lockPinch && !lockScroll) {
      _twoFingerMode = _TwoFingerMode.pinch;
    } else if (lockScroll) {
      _twoFingerMode = _TwoFingerMode.scroll;
    } else if (lockPinch) {
      _twoFingerMode = _TwoFingerMode.pinch;
    }
  }

  bool _handleTwoFingerGesture() {
    final distance = _pointerDistance();
    final centroid = _computeCentroid();

    if (_gestureStartCentroid == null ||
        _gestureStartDistance == null ||
        _lastPinchDistance == null ||
        _lastMultiTouchCentroid == null ||
        _gestureStartDistance! <= 10) {
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

    final frameMetrics = _computeFrameSpreadParallel(
      deltaFirst,
      deltaSecond,
      axis,
    );
    final frameCentroidDelta = centroid - _lastMultiTouchCentroid!;

    _accumulatedCentroidTravel += frameCentroidDelta.distance;
    _accumulatedSpread += frameMetrics.spread;
    _accumulatedParallel += frameMetrics.parallel;

    _tryLockTwoFingerMode(distance);

    if (_twoFingerMode == _TwoFingerMode.scroll) {
      if (frameCentroidDelta != Offset.zero) {
        final scrollDelta = frameCentroidDelta * widget.scrollSensitivity;
        widget.onScroll(Offset(-scrollDelta.dx, -scrollDelta.dy));
      }
    } else if (_twoFingerMode == _TwoFingerMode.pinch) {
      final scaleFactor = distance / _lastPinchDistance!;
      final scaleDelta = (scaleFactor - 1.0).abs();
      if (scaleDelta > 0.01) {
        widget.onPinch(scaleFactor);
      }
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

  void _enterMultiTouch() {
    _multiTouchActive = true;
    _lastPanPosition = null;
    _moved = true;
    _cancelLongPress();
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
      _lastPinchDistance = null;
      _lastPointerPositions.clear();
      _resetTwoFingerGesture();
      _moved = false;
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
          _scheduleLongPress();
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

        _onMultiTouchPointerRemoved();
      },
      onPointerCancel: (event) {
        _pointers.remove(event.pointer);
        _lastPointerPositions.remove(event.pointer);
        _cancelLongPress();
        _updateMultiTouchCentroid();
        _onMultiTouchPointerRemoved();
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
