import 'package:flutter/material.dart';
import '../models/avatar_model.dart';
import 'dart:math' as dart_math;

class AvatarPainter extends CustomPainter {
  final Avatar avatar;
  final double size;

  AvatarPainter({required this.avatar, this.size = 40});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final radius = size / 2;
    final pixelSize = size / 10;

    // Draw face (circle made of pixels)
    paint.color = avatar.faceColor;
    _drawPixelCircle(canvas, center, radius, pixelSize, paint);

    // Draw eyes
    _drawEyes(canvas, center, radius, pixelSize, avatar.eyeStyle);

    // Draw mouth
    _drawMouth(canvas, center, radius, pixelSize, avatar.mouthStyle);

    // Draw outline
    paint.color = Colors.black;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;
    _drawPixelCircleOutline(canvas, center, radius, pixelSize, paint);
  }

  void _drawPixelCircle(Canvas canvas, Offset center, double radius, double pixelSize, Paint paint) {
    // Draw a circle using pixel blocks
    for (double x = -radius; x <= radius; x += pixelSize) {
      for (double y = -radius; y <= radius; y += pixelSize) {
        if (x * x + y * y <= radius * radius) {
          canvas.drawRect(
            Rect.fromLTWH(
              center.dx + x,
              center.dy + y,
              pixelSize,
              pixelSize,
            ),
            paint,
          );
        }
      }
    }
  }

  void _drawPixelCircleOutline(Canvas canvas, Offset center, double radius, double pixelSize, Paint paint) {
    // Draw outline pixels
    for (double angle = 0; angle < 360; angle += 10) {
      final radians = angle * 3.14159 / 180;
      final x = center.dx + radius * Math.cos(radians);
      final y = center.dy + radius * Math.sin(radians);
      
      canvas.drawRect(
        Rect.fromLTWH(x - pixelSize / 2, y - pixelSize / 2, pixelSize, pixelSize),
        paint,
      );
    }
  }

  void _drawEyes(Canvas canvas, Offset center, double radius, double pixelSize, int style) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final leftEyeX = center.dx - radius * 0.3;
    final rightEyeX = center.dx + radius * 0.3;
    final eyeY = center.dy - radius * 0.2;

    switch (style) {
      case 0: // Dots
        canvas.drawRect(
          Rect.fromLTWH(leftEyeX - pixelSize, eyeY - pixelSize, pixelSize * 2, pixelSize * 2),
          paint,
        );
        canvas.drawRect(
          Rect.fromLTWH(rightEyeX - pixelSize, eyeY - pixelSize, pixelSize * 2, pixelSize * 2),
          paint,
        );
        break;
      case 1: // Wide eyes
        canvas.drawRect(
          Rect.fromLTWH(leftEyeX - pixelSize * 1.5, eyeY - pixelSize, pixelSize * 3, pixelSize * 2),
          paint,
        );
        canvas.drawRect(
          Rect.fromLTWH(rightEyeX - pixelSize * 1.5, eyeY - pixelSize, pixelSize * 3, pixelSize * 2),
          paint,
        );
        break;
      case 2: // Closed/Happy
        canvas.drawRect(
          Rect.fromLTWH(leftEyeX - pixelSize * 1.5, eyeY, pixelSize * 3, pixelSize),
          paint,
        );
        canvas.drawRect(
          Rect.fromLTWH(rightEyeX - pixelSize * 1.5, eyeY, pixelSize * 3, pixelSize),
          paint,
        );
        break;
      case 3: // Wink (left closed, right open)
        canvas.drawRect(
          Rect.fromLTWH(leftEyeX - pixelSize * 1.5, eyeY, pixelSize * 3, pixelSize),
          paint,
        );
        canvas.drawRect(
          Rect.fromLTWH(rightEyeX - pixelSize, eyeY - pixelSize, pixelSize * 2, pixelSize * 2),
          paint,
        );
        break;
      case 4: // Star eyes
        _drawPixelStar(canvas, Offset(leftEyeX, eyeY), pixelSize * 2, paint);
        _drawPixelStar(canvas, Offset(rightEyeX, eyeY), pixelSize * 2, paint);
        break;
    }
  }

  void _drawMouth(Canvas canvas, Offset center, double radius, double pixelSize, int style) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final mouthY = center.dy + radius * 0.3;

    switch (style) {
      case 0: // Smile
        for (int i = -2; i <= 2; i++) {
          canvas.drawRect(
            Rect.fromLTWH(
              center.dx + i * pixelSize * 1.5,
              mouthY + (i.abs() * pixelSize * 0.5),
              pixelSize,
              pixelSize,
            ),
            paint,
          );
        }
        break;
      case 1: // Big smile
        for (int i = -3; i <= 3; i++) {
          canvas.drawRect(
            Rect.fromLTWH(
              center.dx + i * pixelSize * 1.2,
              mouthY + (i.abs() * pixelSize * 0.3),
              pixelSize,
              pixelSize,
            ),
            paint,
          );
        }
        break;
      case 2: // Neutral line
        canvas.drawRect(
          Rect.fromLTWH(center.dx - pixelSize * 2, mouthY, pixelSize * 4, pixelSize),
          paint,
        );
        break;
      case 3: // Open mouth
        canvas.drawRect(
          Rect.fromLTWH(center.dx - pixelSize * 1.5, mouthY, pixelSize * 3, pixelSize * 2),
          paint,
        );
        break;
      case 4: // Sad
        for (int i = -2; i <= 2; i++) {
          canvas.drawRect(
            Rect.fromLTWH(
              center.dx + i * pixelSize * 1.5,
              mouthY - (i.abs() * pixelSize * 0.5),
              pixelSize,
              pixelSize,
            ),
            paint,
          );
        }
        break;
    }
  }

  void _drawPixelStar(Canvas canvas, Offset center, double size, Paint paint) {
    // Simple pixel star (5 pixels in X pattern)
    final p = size / 3;
    canvas.drawRect(Rect.fromLTWH(center.dx - p, center.dy - p, p, p), paint);
    canvas.drawRect(Rect.fromLTWH(center.dx, center.dy, p, p), paint);
    canvas.drawRect(Rect.fromLTWH(center.dx + p, center.dy + p, p, p), paint);
    canvas.drawRect(Rect.fromLTWH(center.dx + p, center.dy - p, p, p), paint);
    canvas.drawRect(Rect.fromLTWH(center.dx - p, center.dy + p, p, p), paint);
  }

  @override
  bool shouldRepaint(AvatarPainter oldDelegate) {
    return oldDelegate.avatar != avatar || oldDelegate.size != size;
  }
}

class Math {
  static double cos(double radians) => radians.cos();
  static double sin(double radians) => radians.sin();
}

extension on double {
  double cos() {
    return dart_math.cos(this);
  }
  
  double sin() {
    return dart_math.sin(this);
  }
}