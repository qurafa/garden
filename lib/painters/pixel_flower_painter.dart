import 'package:flutter/material.dart';
import 'dart:math';

class PixelFlowerPainter extends CustomPainter {
  final List<FlowerData> flowers;
  final FlowerData? selectedFlower;
  final String? playingFlowerUri;

  PixelFlowerPainter({
    required this.flowers,
    this.selectedFlower,
    this.playingFlowerUri
  });

  @override
  void paint(Canvas canvas, Size size) {
    // debugPrint('PixelFlowerPainter.paint() called - currently playing: '
    // '${flowers.where((f) => f.spotifyUri == playingFlowerUri).map((f) => f.trackName).join(", ")}');
    for (var flower in flowers) {
      final isSelected = selectedFlower?.position.trackIndex == flower.position.trackIndex;
      final isPlaying = flower.spotifyUri == playingFlowerUri;
      _drawFlower(canvas, flower, isSelected, isPlaying);
    }
  }

  void _drawFlower(Canvas canvas, FlowerData flower, bool isSelected, bool isPlaying) {
    final paint = Paint()..style = PaintingStyle.fill;
    final pixelSize = 4.0;
    final notePixelSize = 4.0;
    final x = flower.position.x;
    final y = flower.position.y;

    // Draw selection highlight
    if (isSelected) {
      paint.color = const Color.fromARGB(63, 255, 235, 59);
      canvas.drawCircle(Offset(x, y), 25, paint);
    }

    if (isPlaying) {
      paint.color = const Color.fromARGB(185, 94, 19, 246);
      _drawMusicNote(canvas, x + 30, y - 30, notePixelSize);
      _drawMusicNote(canvas, x - 30, y - 30, notePixelSize);
      _drawMusicNote(canvas, x + 20, y + 30, notePixelSize);
      _drawMusicNote(canvas, x - 30, y + 30, notePixelSize);
    }

    // Draw stem
    paint.color = Colors.green.shade700;
    canvas.drawRect(
      Rect.fromLTWH(x - pixelSize, y - pixelSize * 6, pixelSize * 2, pixelSize * 6),
      paint,
    );
    

    // Draw flower based on type
    switch (flower.position.flowerType) {
      case 0:
        _drawSimpleFlower(canvas, x, y, pixelSize, flower.position.colorVariant);
        break;
      case 1:
        _drawDaisyFlower(canvas, x, y, pixelSize, flower.position.colorVariant);
        break;
      case 2:
        _drawRoseFlower(canvas, x, y, pixelSize, flower.position.colorVariant);
        break;
      case 3:
        _drawTulipFlower(canvas, x, y, pixelSize, flower.position.colorVariant);
        break;
      case 4:
        _drawSunflower(canvas, x, y, pixelSize, flower.position.colorVariant);
        break;
    }

    // Draw leaves
    _drawLeaves(canvas, x, y, pixelSize);
  }

  void _drawMusicNote(Canvas canvas, double x, double y, double pixelSize) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = Colors.black;

    // Circle
    canvas.drawCircle(Offset(x, y), pixelSize, paint);

    // Bar
    canvas.drawRect(
      Rect.fromLTWH(x + (pixelSize / 2), y - (pixelSize * 6), pixelSize / 2, pixelSize * 6),
      paint);

    // drawing top bar
    canvas.drawRect(
      Rect.fromLTWH(x + (pixelSize / 2), y - (pixelSize * 6), pixelSize * 5, pixelSize / 2),
      paint);

    // Circle
    canvas.drawCircle(Offset(x + (pixelSize * 5), y), pixelSize, paint);

    // Bar
    canvas.drawRect(
      Rect.fromLTWH(x + (pixelSize / 2) + (pixelSize * 5), y - (pixelSize * 6), pixelSize / 2, pixelSize * 6),
      paint);
  }

  void _drawSimpleFlower(Canvas canvas, double x, double y, double pixelSize, int colorVariant) {
    final paint = Paint()..style = PaintingStyle.fill;
    final petalColor = _getColorVariant(colorVariant);

    // Center
    paint.color = Colors.yellow.shade600;
    canvas.drawRect(
      Rect.fromLTWH(x - pixelSize, y - pixelSize * 8, pixelSize * 2, pixelSize * 2),
      paint,
    );

    // Petals (4 directions)
    paint.color = petalColor;
    // Top
    canvas.drawRect(
      Rect.fromLTWH(x - pixelSize, y - pixelSize * 10, pixelSize * 2, pixelSize * 2),
      paint,
    );
    // Bottom
    canvas.drawRect(
      Rect.fromLTWH(x - pixelSize, y - pixelSize * 6, pixelSize * 2, pixelSize * 2),
      paint,
    );
    // Left
    canvas.drawRect(
      Rect.fromLTWH(x - pixelSize * 3, y - pixelSize * 8, pixelSize * 2, pixelSize * 2),
      paint,
    );
    // Right
    canvas.drawRect(
      Rect.fromLTWH(x + pixelSize, y - pixelSize * 8, pixelSize * 2, pixelSize * 2),
      paint,
    );
  }

  void _drawDaisyFlower(Canvas canvas, double x, double y, double pixelSize, int colorVariant) {
    final paint = Paint()..style = PaintingStyle.fill;
    final petalColor = _getColorVariant(colorVariant);

    // Center
    paint.color = Colors.yellow.shade700;
    canvas.drawRect(
      Rect.fromLTWH(x - pixelSize * 1.5, y - pixelSize * 8.5, pixelSize * 3, pixelSize * 3),
      paint,
    );

    // 8 petals around center
    paint.color = petalColor;
    final petalPositions = [
      const Offset(0, -1), const Offset(1, -1), const Offset(1, 0), const Offset(1, 1),
      const Offset(0, 1), const Offset(-1, 1), const Offset(-1, 0), const Offset(-1, -1),
    ];

    for (var pos in petalPositions) {
      canvas.drawRect(
        Rect.fromLTWH(
          x + pos.dx * pixelSize * 3 - pixelSize,
          y - pixelSize * 7 + pos.dy * pixelSize * 3 - pixelSize,
          pixelSize * 2,
          pixelSize * 2,
        ),
        paint,
      );
    }
  }

  void _drawRoseFlower(Canvas canvas, double x, double y, double pixelSize, int colorVariant) {
    final paint = Paint()..style = PaintingStyle.fill;
    final petalColor = _getColorVariant(colorVariant);

    // Layered petals for depth
    paint.color = petalColor.withOpacity(0.7);
    canvas.drawRect(
      Rect.fromLTWH(x - pixelSize * 3, y - pixelSize * 9, pixelSize * 6, pixelSize * 4),
      paint,
    );

    paint.color = petalColor;
    canvas.drawRect(
      Rect.fromLTWH(x - pixelSize * 2, y - pixelSize * 8, pixelSize * 4, pixelSize * 3),
      paint,
    );

    // Center bud
    paint.color = petalColor.withOpacity(0.9);
    canvas.drawRect(
      Rect.fromLTWH(x - pixelSize, y - pixelSize * 7.5, pixelSize * 2, pixelSize * 2),
      paint,
    );
  }

  void _drawTulipFlower(Canvas canvas, double x, double y, double pixelSize, int colorVariant) {
    final paint = Paint()..style = PaintingStyle.fill;
    final petalColor = _getColorVariant(colorVariant);

    paint.color = petalColor;
    // Cup shape
    canvas.drawRect(
      Rect.fromLTWH(x - pixelSize * 2, y - pixelSize * 9, pixelSize * 4, pixelSize * 4),
      paint,
    );
    
    // Top petals
    canvas.drawRect(
      Rect.fromLTWH(x - pixelSize * 3, y - pixelSize * 10, pixelSize * 2, pixelSize * 2),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(x + pixelSize, y - pixelSize * 10, pixelSize * 2, pixelSize * 2),
      paint,
    );
  }

  void _drawSunflower(Canvas canvas, double x, double y, double pixelSize, int colorVariant) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Large center
    paint.color = Colors.brown.shade700;
    canvas.drawRect(
      Rect.fromLTWH(x - pixelSize * 2, y - pixelSize * 9, pixelSize * 4, pixelSize * 4),
      paint,
    );

    // Yellow petals all around
    paint.color = Colors.yellow.shade600;
    final petalOffsets = [
      const Offset(-3, -2), const Offset(-3, 0), const Offset(-3, 2),
      const Offset(3, -2), const Offset(3, 0), const Offset(3, 2),
      const Offset(-2, -3), const Offset(0, -3), const Offset(2, -3),
      const Offset(-2, 3), const Offset(0, 3), const Offset(2, 3),
    ];

    for (var offset in petalOffsets) {
      canvas.drawRect(
        Rect.fromLTWH(
          x + offset.dx * pixelSize - pixelSize,
          y - pixelSize * 7 + offset.dy * pixelSize - pixelSize,
          pixelSize * 2,
          pixelSize * 2,
        ),
        paint,
      );
    }
  }

  void _drawLeaves(Canvas canvas, double x, double y, double pixelSize) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.green.shade600;

    // Left leaf
    canvas.drawRect(
      Rect.fromLTWH(x - pixelSize * 3, y - pixelSize * 4, pixelSize * 2, pixelSize * 2),
      paint,
    );

    // Right leaf
    canvas.drawRect(
      Rect.fromLTWH(x + pixelSize, y - pixelSize * 3, pixelSize * 2, pixelSize * 2),
      paint,
    );
  }

  Color _getColorVariant(int variant) {
    switch (variant) {
      case 0:
        return Colors.pink.shade400;
      case 1:
        return Colors.red.shade400;
      case 2:
        return Colors.purple.shade300;
      case 3:
        return Colors.orange.shade400;
      default:
        return Colors.pink.shade400;
    }
  }

  @override
  bool shouldRepaint(PixelFlowerPainter oldDelegate) {
    if (oldDelegate.selectedFlower != selectedFlower){
      return true;
    }

    if(oldDelegate.playingFlowerUri != playingFlowerUri) {
      return true;
    }

    return false;
  }
}

class FlowerData {
  final dynamic position; // FlowerPosition from garden_model
  final String trackName;
  final String artistName;
  final String? albumArt;
  final String? spotifyUri;

  FlowerData({
    required this.position,
    required this.trackName,
    required this.artistName,
    this.albumArt,
    this.spotifyUri,
  });
}