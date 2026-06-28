import 'package:flutter/material.dart';

class CursorState {
  CursorState({
    required this.position,
    this.isVisible = true,
  });

  Offset position;
  bool isVisible;

  void moveBy(Offset delta, Size bounds) {
    position = Offset(
      (position.dx + delta.dx).clamp(0, bounds.width),
      (position.dy + delta.dy).clamp(0, bounds.height),
    );
  }

  void centerIn(Size bounds) {
    position = Offset(bounds.width / 2, bounds.height / 2);
  }

  CursorState copyWith({
    Offset? position,
    bool? isVisible,
  }) {
    return CursorState(
      position: position ?? this.position,
      isVisible: isVisible ?? this.isVisible,
    );
  }
}
