import 'dart:ui';

import 'package:flutter/material.dart';

class PathPainter extends CustomPainter {
  final List<Offset> positions;
  PathPainter({required this.positions});

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.isEmpty) return;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final path = Path();
    Offset getPixelPos(Offset relPos) =>
        Offset(relPos.dx * size.width, relPos.dy + 30);
    path.moveTo(getPixelPos(positions[0]).dx, getPixelPos(positions[0]).dy);
    for (int i = 0; i < positions.length - 1; i++) {
      final p1 = getPixelPos(positions[i]);
      final p2 = getPixelPos(positions[i + 1]);
      path.cubicTo(
        p1.dx,
        (p1.dy + p2.dy) / 2,
        p2.dx,
        (p1.dy + p2.dy) / 2,
        p2.dx,
        p2.dy,
      );
    }
    _drawDashedPath(canvas, path, paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final PathMetric pathMetric = path.computeMetrics().first;
    final double dashWidth = 10.0;
    final double dashSpace = 10.0;
    double distance = 0.0;
    while (distance < pathMetric.length) {
      canvas.drawPath(
        pathMetric.extractPath(distance, distance + dashWidth),
        paint,
      );
      distance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}