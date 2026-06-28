import 'package:flutter/material.dart';

class CursorOverlay extends StatelessWidget {
  const CursorOverlay({
    super.key,
    required this.position,
    this.visible = true,
  });

  final Offset position;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: IgnorePointer(
        child: CustomPaint(
          size: const Size(24, 24),
          painter: _CursorPainter(),
        ),
      ),
    );
  }
}

class _CursorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, 18)
      ..lineTo(5, 14)
      ..lineTo(9, 22)
      ..lineTo(12, 21)
      ..lineTo(8, 13)
      ..lineTo(14, 13)
      ..close();

    canvas.drawShadow(path, Colors.black54, 2, false);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
