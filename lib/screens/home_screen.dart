import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/spotify_service.dart';
import '../services/garden_service.dart';
import '../models/garden_model.dart';
import 'add_garden_screen.dart';
import 'garden_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MY GARDENS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
          ),
        ),
        backgroundColor: Colors.blueGrey,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red,),
            onPressed: () {
              _showLogoutDialog(context);
            },
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
        child: Consumer<GardenService>(
          builder: (context, gardenService, child) {
            if (gardenService.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!gardenService.hasGardens) {
              return _EmptyGardensView();
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: gardenService.gardens.length + 1,
              itemBuilder: (context, index) {
                if (index == gardenService.gardens.length) {
                  return _AddGardenCard();
                }
                return _GardenCard(garden: gardenService.gardens[index]);
              },
            );
          },
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a1a),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: Colors.green, width: 2),
        ),
        title: const Text(
          'LOGOUT',
          style: TextStyle(color: Colors.green, letterSpacing: 2),
        ),
        content: const Text(
          'Are you sure you want to disconnect from Spotify? Your gardens will be saved.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Provider.of<SpotifyService>(context, listen: false).logout();
            },
            child: const Text('LOGOUT', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _EmptyGardensView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color.fromARGB(65, 27, 94, 31),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: const Icon(
                Icons.add,
                size: 60,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'NO GARDENS YET',
              style: TextStyle(
                color: Colors.green,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Create your first musical garden\nfrom a Spotify playlist',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddGardenScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                  side: BorderSide(color: Colors.white, width: 2),
                ),
              ),
              child: const Text(
                'CREATE GARDEN',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GardenCard extends StatelessWidget {
  final Garden garden;

  const _GardenCard({required this.garden});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: const Color.fromARGB(0, 0, 0, 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0.0)
      ),
      child: InkWell(
        onTap: () {
          Provider.of<GardenService>(context, listen: false)
              .updateLastViewed(garden.id);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GardenScreen(
                playlistId: garden.playlistId,
                gardenId: garden.id,
              ),
            ),
          );
        },
        onLongPress: () {
          _showDeleteDialog(context);
        },
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    child: garden.playlistImageUrl != null
                        ? Image.network(
                            garden.playlistImageUrl!,
                            fit: BoxFit.cover,
                          )
                        : const Icon(
                            Icons.music_note,
                            size: 80,
                            color: Colors.green,
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        garden.playlistName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                height: 30,
                width: 30,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  border: Border.all(color: Colors.red, width: 1),
                ),
                child: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  padding: const EdgeInsets.all(3),
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  onPressed: () {
                    _showDeleteDialog(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
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
          'Are you sure you want to delete "${garden.playlistName}"?\n\nThis will only remove the garden from this app. Your Spotify playlist will not be affected.',
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
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              
              final gardenService = Provider.of<GardenService>(
                context,
                listen: false,
              );
              await gardenService.deleteGarden(garden.id);
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Garden deleted'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text(
              'DELETE',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddGardenCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.black38,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: Color.fromARGB(146, 76, 175, 79), width: 2),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddGardenScreen()),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color.fromARGB(42, 76, 175, 79),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: const Icon(
                Icons.add,
                size: 40,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'NEW\nGARDEN',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.green,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}