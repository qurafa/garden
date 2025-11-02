import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'services/spotify_service.dart';
import 'services/garden_service.dart';
import 'services/avatar_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const PixelGardenApp());
}

class PixelGardenApp extends StatelessWidget {
  const PixelGardenApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SpotifyService()),
        ChangeNotifierProvider(create: (_) => GardenService()),
      ],
      child: MaterialApp(
        title: 'Pixel Garden',
        theme: ThemeData(
          primarySwatch: Colors.green,
          scaffoldBackgroundColor: const Color(0xFF1a1a1a),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Colors.white),
            bodyMedium: TextStyle(color: Colors.white),
          ),
        ),
        home: const DeepLinkHandler(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class DeepLinkHandler extends StatefulWidget {
  const DeepLinkHandler({Key? key}) : super(key: key);

  @override
  State<DeepLinkHandler> createState() => _DeepLinkHandlerState();
}

class _DeepLinkHandlerState extends State<DeepLinkHandler> {
  late AppLinks _appLinks;
  StreamSubscription? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinkListener();
  }

  Future<void> _initDeepLinkListener() async {
    _appLinks = AppLinks();

    // Handle initial link if app was opened from it
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(initialLink);
      }
    } catch (e) {
      debugPrint('Error getting initial link: $e');
    }

    // Listen for links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint('Error listening to links: $err');
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('========================================');
    debugPrint('Deep link received: $uri');
    debugPrint('Scheme: ${uri.scheme}');
    debugPrint('Host: ${uri.host}');
    debugPrint('Query params: ${uri.queryParameters}');
    
    if (uri.scheme == 'pixelgarden' && uri.host == 'callback') {
      final code = uri.queryParameters['code'];
      final error = uri.queryParameters['error'];
      
      if (error != null) {
        debugPrint('ERROR in callback: $error');
        debugPrint('========================================');
        return;
      }
      
      if (code != null) {
        debugPrint('Auth code received: ${code.substring(0, 10)}...');
        try {
          final spotifyService = Provider.of<SpotifyService>(
            context,
            listen: false,
          );
          spotifyService.handleAuthCallback(code);
          debugPrint('Called handleAuthCallback successfully');
        } catch (e) {
          debugPrint('ERROR calling handleAuthCallback: $e');
        }
      } else {
        debugPrint('No code found in callback URL');
      }
    } else {
      debugPrint('Deep link does not match expected scheme/host');
    }
    debugPrint('========================================');
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const AuthWrapper();
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<SpotifyService>(
      builder: (context, spotifyService, child) {
        if (spotifyService.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        if (spotifyService.isAuthenticated) {
          return const HomeScreen();
        }
        
        return const LoginScreen();
      },
    );
  }
}