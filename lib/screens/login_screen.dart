import 'package:flutter/material.dart';
import 'package:pixel_garden/painters/single_pixel_flower_painter.dart';
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
                      borderRadius: BorderRadius.circular(12.5)
                    ),
                    child: const Text(
                      'GARDEN',
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
                      color: Colors.blueGrey,
                      border: Border.all(color: Colors.green, width: 2),
                    ),
                    child: CustomPaint(
                      painter: SinglePixelFlowerPainter(),
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  const Text(
                    'Connect your Spotify below...',
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
                        borderRadius: BorderRadius.circular(12.5), // Pixel style
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}