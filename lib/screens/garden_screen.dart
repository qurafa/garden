import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spotify/spotify.dart' as spotify_sdk;
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import '../services/spotify_service.dart';
import '../services/garden_service.dart';
import '../models/garden_model.dart';
import '../painters/pixel_flower_painter.dart';

class GardenScreen extends StatefulWidget {
  final String playlistId;
  final String gardenId;

  const GardenScreen({
    Key? key,
    required this.playlistId,
    required this.gardenId,
  }) : super(key: key);

  @override
  State<GardenScreen> createState() => _GardenScreenState();
}

class _GardenScreenState extends State<GardenScreen> {
  List<spotify_sdk.Track>? _tracks;
  Garden? _garden;
  bool _isLoading = true;
  List<FlowerData>? _flowerData;
  FlowerData? _selectedFlower;
  FlowerData? _playingFlower;
  final TransformationController _transformationController = TransformationController();
  bool _isInteracting = false; // Track if user is panning/zooming
  Offset? _lastTapPosition;
  DateTime? _lastTapTime;
  String? _currentlyPlayingUri;
  StreamSubscription<String?>? _playbackSubscription;

  @override
  void initState() {
    super.initState();
    _loadGardenData();
    _startPlaybackTracking();
    
    // Set initial transformation to show center of canvas
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Start centered and slightly zoomed out to see more flowers
      final screenSize = MediaQuery.of(context).size;
      final scale = 0.8; // Slight zoom out
      final translateX = -(screenSize.width / 2); // Center horizontally on canvas center (1000px)
      final translateY = -(screenSize.height / 2); // Center vertically on canvas center (1500px)
      
      _transformationController.value = Matrix4.identity()
        ..translate(translateX, translateY)
        ..scale(scale);
    });
  }

  @override
  void dispose() {
    _playbackSubscription?.cancel();
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadGardenData() async {
    final gardenService = Provider.of<GardenService>(context, listen: false);
    final spotifyService = Provider.of<SpotifyService>(context, listen: false);
    
    // Get garden info
    var garden = gardenService.getGardenById(widget.gardenId);
    
    // Load tracks from Spotify
    final tracks = await spotifyService.fetchPlaylistTracks(widget.playlistId);
    
    debugPrint('========================================');
    debugPrint('Loading garden: ${garden?.playlistName}');
    debugPrint('Track count: ${tracks.length}');
    debugPrint('Has flower positions: ${garden?.flowerPositions != null}');
    if (garden?.flowerPositions != null) {
      debugPrint('Flower positions count: ${garden!.flowerPositions!.length}');
    }
    
    // Generate flower positions if not already generated
    if (garden != null && garden.flowerPositions == null) {
      debugPrint('Generating new flower positions...');
      final positions = FlowerPosition.generatePositions(
        tracks.length,
        1200, // Canvas width - reduced for better visibility
        1600, // Canvas height - reduced for better visibility
      );
      
      garden = garden.copyWith(flowerPositions: positions);
      await gardenService.updateGarden(garden);
      debugPrint('Saved ${positions.length} flower positions to garden');
    }
    
    // Create flower data
    final flowerData = <FlowerData>[];
    if (garden?.flowerPositions != null) {
      debugPrint('Creating flower data for ${garden!.flowerPositions!.length} positions...');
      for (var pos in garden.flowerPositions!) {
        if (pos.trackIndex < tracks.length) {
          final track = tracks[pos.trackIndex];
          flowerData.add(FlowerData(
            position: pos,
            trackName: track.name ?? 'Unknown',
            artistName: track.artists?.map((a) => a.name).join(', ') ?? 'Unknown',
            albumArt: track.album?.images?.isNotEmpty == true 
                ? track.album!.images!.first.url 
                : null,
            spotifyUri: track.uri,
          ));
          debugPrint('Flower ${pos.trackIndex}: ${track.name} at (${pos.x}, ${pos.y})');
        } else {
          debugPrint('WARNING: Position trackIndex ${pos.trackIndex} >= tracks.length ${tracks.length}');
        }
      }
    }
    
    debugPrint('Created ${flowerData.length} flower data objects');
    debugPrint('========================================');
    
    setState(() {
      _garden = garden;
      _tracks = tracks;
      _flowerData = flowerData;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _garden?.playlistName.toUpperCase() ?? 'GARDEN',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
          ),
        ),
        backgroundColor: Colors.blueGrey,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red,),
            onPressed: () => _showDeleteDialog(),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2d5016), Color(0xFF1a4d1a)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _flowerData == null || _flowerData!.isEmpty
                ? const Center(
                    child: Text(
                      'No flowers in this garden',
                      style: TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                  )
                : _buildGardenCanvas(),
      ),
    );
  }

Widget _buildGardenCanvas() {
    return Stack(
      children: [
        // Garden canvas with gesture detection
        InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.3,
          maxScale: 3.0,
          boundaryMargin: const EdgeInsets.all(50),
          constrained: false,
          onInteractionStart: (details) {
            debugPrint('InteractiveViewer: interaction started');
            setState(() {
              _isInteracting = false;
            });
          },
          onInteractionUpdate: (details) {
            // Only mark as interacting if there's actual scale/pan change
            if (details.scale != 1.0 || details.focalPointDelta.distance > 3) {
              if (!_isInteracting) {
                debugPrint('InteractiveViewer: interaction detected (scale or pan)');
                setState(() {
                  _isInteracting = true;
                });
              }
            }
            // Trigger rebuild to update card position
            setState(() {});
          },
          onInteractionEnd: (details) {
            debugPrint('InteractiveViewer: interaction ended');
            // Reset after a short delay
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                setState(() {
                  _isInteracting = false;
                });
              }
            });
          },
          child: Container(
            width: 1200,
            height: 1600,
            decoration: const BoxDecoration(
              gradient:  LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF2d5016),
                  Color(0xFF1a4d1a),
                ],
              ),
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (details) {
                debugPrint('GestureDetector: onTapDown at ${details.localPosition}');
                _lastTapPosition = details.localPosition;
                _lastTapTime = DateTime.now();
              },
              onTapUp: (details) {
                debugPrint('GestureDetector: onTapUp at ${details.localPosition}');
                
                if (_lastTapPosition != null && _lastTapTime != null) {
                  final distance = (details.localPosition - _lastTapPosition!).distance;
                  final duration = DateTime.now().difference(_lastTapTime!).inMilliseconds;
                  
                  debugPrint('Tap validation: isInteracting=$_isInteracting distance=${distance.toStringAsFixed(1)}px duration=${duration}ms');
                  
                  if (!_isInteracting && distance < 30 && duration < 500) {
                    _handleTap(details.localPosition);
                  } else {
                    debugPrint('Tap rejected: isInteracting=$_isInteracting distance=${distance.toStringAsFixed(1)} duration=$duration');
                  }
                }
                
                _lastTapPosition = null;
                _lastTapTime = null;
              },
              onTapCancel: () {
                debugPrint('GestureDetector: onTapCancel');
                _lastTapPosition = null;
                _lastTapTime = null;
              },
              child: CustomPaint(
                size: const Size(1200, 1600),
                painter: PixelFlowerPainter(
                  flowers: _flowerData!,
                  selectedFlower: _selectedFlower,
                  playingFlowerUri: _currentlyPlayingUri,
                ),
              ),
            ),
          ),
        ),
        
        // Info card positioned in screen space (doesn't zoom)
        if (_selectedFlower != null)
          _buildFloatingInfoCard(_selectedFlower!),
        
        // Info overlay
        if (_garden == null)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black45,
                border: Border.all(color: Colors.green, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_florist, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${_garden!.trackCount} FLOWERS',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _handleTap(Offset position) {
    if (_flowerData == null || _flowerData!.isEmpty) {
      debugPrint('No flower data available for tap detection');
      return;
    }
    
    // position is already in canvas coordinates since GestureDetector is inside the Container
    debugPrint('========================================');
    debugPrint('Tap detected at canvas position: $position');
    
    // Find the closest flower within tap radius
    FlowerData? tappedFlower;
    double minDistance = double.infinity;
    const double tapRadius = 50.0; // Generous tap radius
    
    for (var flower in _flowerData!) {
      final dx = position.dx - flower.position.x;
      final dy = position.dy - flower.position.y;
      final distance = sqrt(dx * dx + dy * dy);
      
      if (distance < tapRadius && distance < minDistance) {
        tappedFlower = flower;
        minDistance = distance;
        debugPrint('Found closer flower: ${flower.trackName} at distance $distance');
      }
    }
    
    if (tappedFlower != null) {
      debugPrint('✓ Tapped flower: ${tappedFlower.trackName} (distance: $minDistance px)');
      debugPrint('========================================');
      setState(() {
        // Toggle selection - tap same flower to deselect
        if (_selectedFlower?.position.trackIndex == tappedFlower?.position.trackIndex) {
          _selectedFlower = null;
        } else {
          _selectedFlower = tappedFlower;
        }
      });
    } else {
      debugPrint('✗ No flower within ${tapRadius}px radius - clearing selection');
      setState(() {
        _selectedFlower = null; // Tap on empty space clears selection
      });
      
      // Show the 3 closest flowers for debugging
      final sortedFlowers = List<FlowerData>.from(_flowerData!)
        ..sort((a, b) {
          final distA = sqrt(pow(position.dx - a.position.x, 2) + pow(position.dy - a.position.y, 2));
          final distB = sqrt(pow(position.dx - b.position.x, 2) + pow(position.dy - b.position.y, 2));
          return distA.compareTo(distB);
        });
      
      for (int i = 0; i < 3 && i < sortedFlowers.length; i++) {
        final f = sortedFlowers[i];
        final dist = sqrt(pow(position.dx - f.position.x, 2) + pow(position.dy - f.position.y, 2));
        debugPrint('  ${i + 1}. ${f.trackName} at (${f.position.x.toInt()}, ${f.position.y.toInt()}) - ${dist.toInt()}px away');
      }
      debugPrint('========================================');
    }
  }

    Widget _buildFloatingInfoCard(FlowerData flower) {
    // Get transformation matrix to convert canvas coordinates to screen coordinates
    final matrix = _transformationController.value;
    
    // Transform flower position from canvas space to screen space
    final flowerCanvasPos = Offset(flower.position.x, flower.position.y);
    final flowerScreenPos = MatrixUtils.transformPoint(matrix, flowerCanvasPos);
    
    // Card dimensions
    const cardWidth = 280.0;
    const cardHeight = 280.0;
    
    // Get screen size and safe area
    final screenSize = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    
    // Safe area bounds (accounting for overlays and system UI)
    final topMargin = 80.0 + padding.top; // Space for info overlay + status bar
    final bottomMargin = 20.0 + padding.bottom; // Space for system navigation
    
    // Available vertical space for the card
    final availableHeight = screenSize.height - topMargin - bottomMargin;

    // Determine card position - prefer right side, but flip if too close to edge
    double cardX;
    // Center on screen if flower is at edge
    cardX = (screenSize.width - cardWidth) / 2;
    
    // Vertical positioning
    double cardY;
    // Card doesn't fit - just pin it to top of safe area
    cardY = topMargin;
    
    return Positioned(
      left: cardX,
      top: cardY,
      child: GestureDetector(
        onTap: () {
          debugPrint('Tapped on info card - preventing propagation');
          // Prevent tap from propagating
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: cardWidth,
          constraints: BoxConstraints(
            maxHeight: availableHeight, // Constrain to available space
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1a1a1a),
            border: Border.all(color: Colors.green, width: 3),
            boxShadow: const [
              BoxShadow(
                color:  Colors.black45,
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with close button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2d5016),
                    border: Border(
                      bottom: BorderSide(color: Colors.green, width: 2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.music_note, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'SONG INFO',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedFlower = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white70, width: 1),
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Album art
                      if (flower.albumArt != null)
                        Center(
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.green, width: 2),
                            ),
                            child: Image.network(
                              flower.albumArt!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.green.shade900,
                                  child: const Icon(
                                    Icons.music_note,
                                    color: Colors.green,
                                    size: 40,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 12),
                      
                      // Track name
                      const Text(
                        'TRACK',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        flower.trackName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 10),
                      
                      // Artist name
                      const Text(
                        'ARTIST',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        flower.artistName,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Play button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _playTrackInGarden(flower),//_openInSpotify(flower.spotifyUri),
                          icon: const Icon(Icons.play_circle_fill, size: 20),
                          label: const Text(
                            'PLAY',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1DB954),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                              side: BorderSide(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openInSpotify(String? uri) async {
    if (uri == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Spotify URI not available'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      // Try to open in Spotify app
      final spotifyAppUri = Uri.parse(uri);
      if (await canLaunchUrl(spotifyAppUri)) {
        await launchUrl(spotifyAppUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to web player
        final trackId = uri.split(':').last;
        final webUrl = Uri.parse('https://open.spotify.com/track/$trackId');
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open Spotify: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a1a),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: Colors.red, width: 2),
        ),
        title: const Text(
          'DELETE GARDEN?',
          style: TextStyle(color: Colors.red, letterSpacing: 2),
        ),
        content: Text(
          'Are you sure you want to delete "${_garden?.playlistName}"?\n\nThis will only remove the garden from this app. Your Spotify playlist will not be affected.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              _deleteGarden();
            },
            child: const Text(
              'DELETE',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGarden() async {
    final gardenService = Provider.of<GardenService>(context, listen: false);
    await gardenService.deleteGarden(widget.gardenId);
    
    if (mounted) {
      Navigator.pop(context); // Go back to home screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Garden deleted'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _startPlaybackTracking() {
    final spotifyService = Provider.of<SpotifyService>(context, listen: false);
    _playbackSubscription = spotifyService.currentlyPlayingTrackUri.listen((uri) {
      if (mounted && uri != _currentlyPlayingUri) {
        setState(() {
          debugPrint('New URI:');
          debugPrint(uri);
          _currentlyPlayingUri = uri;
        });
      }
    });
  }

  Future<void> _playTrackInGarden(FlowerData flower) async {
    if (flower.spotifyUri == null) {
      _showErrorSnackBar('Track URI not available');
      return;
    }
    
    final spotifyService = Provider.of<SpotifyService>(context, listen: false);
    
    // Show loading
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('Starting playback...'),
            ],
          ),
          duration: Duration(seconds: 5),
          backgroundColor: Color(0xFF1DB954),
        ),
      );
    }
    
    final playlistUri = 'spotify:playlist:${widget.playlistId}';
    
    final result = await spotifyService.playTrackInPlaylist(
      playlistUri: playlistUri,
      trackUri: flower.spotifyUri!,
      shuffle: true,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      
      switch (result) {
        case PlaybackResult.success:
          // Played seamlessly
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.music_note, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      flower.trackName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1DB954),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
          break;
          
        case PlaybackResult.openedSpotify:
          // Spotify was opened
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Playing: ${flower.trackName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Next time you can play directly without opening Spotify!',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1DB954),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
          break;
          
        case PlaybackResult.failed:
          _showErrorSnackBar('Could not start playback. Please check Spotify.');
          break;
      }
    }
  }
  
  void _showNoDeviceDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a1a),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: Colors.orange, width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.devices, color: Colors.orange),
            SizedBox(width: 8),
            Text(
              'NO DEVICE FOUND',
              style: TextStyle(color: Colors.orange, letterSpacing: 2, fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          'Please open Spotify on one of your devices first, then try again.\n\n'
          'Playback can be controlled on:\n'
          '• Your phone\n'
          '• Desktop app\n'
          '• Smart speakers\n'
          '• Other connected devices',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFF1DB954)),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}