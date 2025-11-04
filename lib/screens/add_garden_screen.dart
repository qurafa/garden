import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spotify/spotify.dart' as spotify;
import '../services/spotify_service.dart';
import '../services/garden_service.dart';
import 'garden_screen.dart';

class AddGardenScreen extends StatefulWidget {
  const AddGardenScreen({Key? key}) : super(key: key);

  @override
  State<AddGardenScreen> createState() => _AddGardenScreenState();
}

class _AddGardenScreenState extends State<AddGardenScreen> {
  List<spotify.PlaylistSimple>? _playlists;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final spotifyService = Provider.of<SpotifyService>(context, listen: false);
      
      // Check if we have cached playlists
      if (spotifyService.cachedPlaylists != null) {
        setState(() {
          _playlists = spotifyService.cachedPlaylists;
          _isLoading = false;
        });
        return;
      }
      
      // Fetch from API
      final playlists = await spotifyService.fetchUserPlaylists();
      setState(() {
        _playlists = playlists;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load playlists: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SELECT PLAYLIST',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
          ),
        ),
        backgroundColor: Colors.blueGrey,
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                final spotifyService = Provider.of<SpotifyService>(context, listen: false);
                setState(() => _isLoading = true);
                final playlists = await spotifyService.fetchUserPlaylists(forceRefresh: true);
                setState(() {
                  _playlists = playlists;
                  _isLoading = false;
                });
              },
              tooltip: 'Refresh playlists',
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2d5016), Color(0xFF1a1a1a)],
          ),
        ),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_playlists == null || _playlists!.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _playlists!.length,
      itemBuilder: (context, index) {
        final playlist = _playlists![index];
        return _PlaylistCard(playlist: playlist);
      },
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6, // Show 6 skeleton cards
      itemBuilder: (context, index) {
        return _SkeletonPlaylistCard();
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadPlaylists,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                foregroundColor: Colors.white,
              ),
              child: const Text('RETRY'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note,
              size: 64,
              color: Colors.white38,
            ),
            SizedBox(height: 16),
            Text(
              'No playlists found',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Create a playlist on Spotify first',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonPlaylistCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: Color.fromARGB(77, 76, 175, 79), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color.fromARGB(67, 27, 94, 31),
                border: Border.all(color: const Color.fromARGB(57, 76, 175, 79), width: 2),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      border: Border.all(color: const Color.fromARGB(58, 76, 175, 79), width: 1),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 100,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      border: Border.all(color: const Color.fromARGB(58, 76, 175, 79), width: 1),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final spotify.PlaylistSimple playlist;

  const _PlaylistCard({required this.playlist});

  @override
  Widget build(BuildContext context) {
    final gardenService = Provider.of<GardenService>(context);
    final alreadyAdded = gardenService.hasGardenForPlaylist(playlist.id ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: alreadyAdded ? Colors.black26 : Colors.black54,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6.25),
        side: BorderSide(
          color: alreadyAdded ? Colors.grey : Colors.green,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: alreadyAdded
            ? null
            : () async {
                await _createGarden(context);
              },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.shade900,
                  border: Border.all(color: Colors.green, width: 1),
                ),
                child: playlist.images != null && playlist.images!.isNotEmpty
                    ? Image.network(
                        playlist.images!.first.url!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.green,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.music_note,
                            color: Colors.green,
                            size: 30,
                          );
                        },
                      )
                    : const Icon(
                        Icons.music_note,
                        color: Colors.green,
                        size: 30,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name ?? 'Unnamed Playlist',
                      style: TextStyle(
                        color: alreadyAdded ? Colors.white38 : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alreadyAdded
                          ? 'Garden already created'
                          : '${playlist.tracksLink?.total ?? 0} tracks',
                      style: TextStyle(
                        color: alreadyAdded ? Colors.white24 : Colors.white60,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                alreadyAdded ? Icons.check_circle : Icons.arrow_forward_ios,
                color: alreadyAdded ? Colors.grey : Colors.green,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createGarden(BuildContext context) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Container(
        color: Colors.black54,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.green),
              SizedBox(height: 16),
              Text(
                'Creating garden...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final gardenService = Provider.of<GardenService>(context, listen: false);
      
      // Add garden
      await gardenService.addGarden(
        playlistId: playlist.id!,
        playlistName: playlist.name ?? 'Unnamed Playlist',
        playlistImageUrl: playlist.images?.isNotEmpty == true
            ? playlist.images!.first.url
            : null,
        trackCount: playlist.tracksLink?.total ?? 0,
      );

      // Get the newly created garden
      final garden = gardenService.gardens.firstWhere(
        (g) => g.playlistId == playlist.id,
      );

      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      // Navigate to garden screen
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => GardenScreen(
              playlistId: playlist.id!,
              gardenId: garden.id,
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) Navigator.pop(context);
      
      // Show error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating garden: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}