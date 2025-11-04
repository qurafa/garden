import 'package:flutter/material.dart';

// Simple pixel art flower painter
class SinglePixelFlowerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final pixelSize = size.width / 10;
    
    // Draw a simple pixel flower
    // Stem
    paint.color = Colors.green;
    canvas.drawRect(Rect.fromLTWH(pixelSize * 4.5, pixelSize * 5, pixelSize, pixelSize * 4.5), paint);

    // Petals
    paint.color = Colors.pink;
    canvas.drawRect(Rect.fromLTWH(pixelSize * 3, pixelSize * 2, pixelSize * 2, pixelSize * 2), paint);
    canvas.drawRect(Rect.fromLTWH(pixelSize * 5, pixelSize * 2, pixelSize * 2, pixelSize * 2), paint);
    canvas.drawRect(Rect.fromLTWH(pixelSize * 3, pixelSize * 4, pixelSize * 3, pixelSize * 2), paint);
    canvas.drawRect(Rect.fromLTWH(pixelSize * 5, pixelSize * 4, pixelSize * 2, pixelSize * 2), paint);
    
    // Center
    paint.color = Colors.yellow;
    canvas.drawRect(Rect.fromLTWH(pixelSize * 4.25, pixelSize * 2.75, pixelSize * 1.5, pixelSize), paint);

    // Vase
    paint.color = Colors.white38;
    canvas.drawRect(Rect.fromLTWH(pixelSize * 4, pixelSize * 7, pixelSize * 2, pixelSize * 1.5), paint);
    canvas.drawRect(Rect.fromLTWH(pixelSize * 3.5, pixelSize * 8.5, pixelSize * 3, pixelSize * 1.5), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}