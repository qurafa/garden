import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/spotify_service.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2d5016), Color(0xFF1a1a1a)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pixel Art Style Title
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      border: Border.all(color: Colors.green, width: 3),
                    ),
                    child: const Text(
                      'PIXEL GARDEN',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Pixel flower icon representation
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      border: Border.all(color: Colors.green, width: 2),
                    ),
                    child: CustomPaint(
                      painter: PixelFlowerPainter(),
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  const Text(
                    'Connect your Spotify to grow\nyour musical garden',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 60),
                  
                  // Login Button
                  ElevatedButton(
                    onPressed: () {
                      final spotifyService = Provider.of<SpotifyService>(
                        context,
                        listen: false,
                      );
                      spotifyService.authenticateWithSpotify();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954), // Spotify green
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0), // Pixel style
                        side: const BorderSide(color: Colors.white, width: 2),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.music_note, size: 24),
                        SizedBox(width: 12),
                        Text(
                          'CONNECT SPOTIFY',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  const Text(
                    'Note: You\'ll need to set up your\nSpotify Developer credentials',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Simple pixel art flower painter
class PixelFlowerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final pixelSize = size.width / 10;
    
    // Draw a simple pixel flower
    // Petals
    paint.color = Colors.pink;
    canvas.drawRect(Rect.fromLTWH(pixelSize * 3, pixelSize * 2, pixelSize * 2, pixelSize * 2), paint);
    canvas.drawRect(Rect.fromLTWH(pixelSize * 5, pixelSize * 2, pixelSize * 2, pixelSize * 2), paint);
    canvas.drawRect(Rect.fromLTWH(pixelSize * 3, pixelSize * 4, pixelSize * 2, pixelSize * 2), paint);
    canvas.drawRect(Rect.fromLTWH(pixelSize * 5, pixelSize * 4, pixelSize * 2, pixelSize * 2), paint);
    
    // Center
    paint.color = Colors.yellow;
    canvas.drawRect(Rect.fromLTWH(pixelSize * 4, pixelSize * 3, pixelSize * 2, pixelSize * 2), paint);
    
    // Stem
    paint.color = Colors.green;
    canvas.drawRect(Rect.fromLTWH(pixelSize * 4.5, pixelSize * 5, pixelSize, pixelSize * 3), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}