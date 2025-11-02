import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify/spotify.dart' as spotify_sdk;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;

class SpotifyService extends ChangeNotifier {
  static String get clientId => dotenv.env['SPOTIFY_CLIENT_ID'] ?? '';
  static String get clientSecret => dotenv.env['SPOTIFY_CLIENT_SECRET'] ?? '';
  static String get redirectUri => dotenv.env['SPOTIFY_REDIRECT_URI'] ?? '';
  
  spotify_sdk.SpotifyApi? _spotify;
  String? _accessToken;
  String? _refreshToken;
  bool _isAuthenticated = false;
  bool _isLoading = true;
  List<spotify_sdk.PlaylistSimple>? _cachedPlaylists;
  DateTime? _playlistsCacheTime;
  DateTime? _tokenExpiryTime;
  
  SpotifyService() {
    _initService();
  }
  
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  spotify_sdk.SpotifyApi? get spotify => _spotify;
  List<spotify_sdk.PlaylistSimple>? get cachedPlaylists => _cachedPlaylists;
  
  Future<void> _initService() async {
    await _loadSavedToken();
    _isLoading = false;
    notifyListeners();
  }
  
  Future<void> _loadSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('spotify_token');
    _refreshToken = prefs.getString('spotify_refresh_token');
    final expiryString = prefs.getString('spotify_token_expiry');
    
    if (expiryString != null) {
      _tokenExpiryTime = DateTime.parse(expiryString);
    }
    
    if (_accessToken != null) {
      // Check if token is expired
      if (_tokenExpiryTime != null && DateTime.now().isAfter(_tokenExpiryTime!)) {
        debugPrint('Access token expired, attempting refresh...');
        if (_refreshToken != null) {
          await _refreshAccessToken();
        } else {
          debugPrint('No refresh token available');
          _accessToken = null;
          _isAuthenticated = false;
        }
      } else {
        try {
          // Create SpotifyApi with OAuth credentials
          // final credentials = spotify_sdk.SpotifyApiCredentials(
          //   clientId,
          //   clientSecret,
          // );
          _spotify = spotify_sdk.SpotifyApi.withAccessToken(_accessToken!);
          _isAuthenticated = true;
        } catch (e) {
          debugPrint('Error loading saved token: $e');
          _accessToken = null;
          _isAuthenticated = false;
        }
      }
    }
  }
  
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('spotify_token', token);
  }
  
  Future<void> _saveRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('spotify_refresh_token', token);
  }
  
  Future<void> _saveTokenExpiry(DateTime expiry) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('spotify_token_expiry', expiry.toIso8601String());
  }
  
  Future<void> authenticateWithSpotify() async {
    final scopes = [
      'user-read-private',
      'user-read-email',
      'user-read-currently-playing',  // Read current playing song
      'user-read-playback-state',
      'user-modify-playback-state',   // Required to control playback!
      'playlist-read-private',
      'playlist-read-collaborative',
      // 'streaming'                    // Optional: for SDK streaming
    ];
    
    final authUrl = Uri.https('accounts.spotify.com', '/authorize', {
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'scope': scopes.join(' '),
      'show_dialog': 'true',
    });
    
    try {
      final launched = await launchUrl(
        authUrl,
        mode: LaunchMode.externalApplication,
      );
      
      if (!launched) {
        debugPrint('Could not launch $authUrl');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }
  
  Future<void> handleAuthCallback(String code) async {
    try {
      debugPrint('========================================');
      debugPrint('Handling auth callback with code: ${code.substring(0, 10)}...');
      
      final response = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Basic ${base64Encode(utf8.encode('$clientId:$clientSecret'))}',
        },
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
        },
      );
      
      debugPrint('Token response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Token response data keys: ${data.keys}');
        
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        final expiresIn = data['expires_in'] as int; // seconds
        _tokenExpiryTime = DateTime.now().add(Duration(seconds: expiresIn));
        
        debugPrint('Access token: ${_accessToken?.substring(0, 20)}...');
        debugPrint('Refresh token: ${_refreshToken?.substring(0, 20)}...');
        debugPrint('Expires in: $expiresIn seconds');
        debugPrint('Token expires at: $_tokenExpiryTime');
        
        await _saveToken(_accessToken!);
        await _saveRefreshToken(_refreshToken!);
        await _saveTokenExpiry(_tokenExpiryTime!);
        
        // Use the withAccessToken factory method
        _spotify = spotify_sdk.SpotifyApi.withAccessToken(_accessToken!);
        _isAuthenticated = true;
        
        debugPrint('Authentication successful! Token saved.');
        debugPrint('isAuthenticated: $_isAuthenticated');
        debugPrint('SpotifyApi created: ${_spotify != null}');
        debugPrint('========================================');
        
        notifyListeners();
      } else {
        debugPrint('Failed to get access token: ${response.body}');
        throw Exception('Failed to get access token: ${response.body}');
      }
    } catch (e) {
      debugPrint('ERROR during authentication: $e');
      debugPrint('========================================');
      rethrow;
    }
  }
  
  Future<void> _refreshAccessToken() async {
    if (_refreshToken == null) {
      debugPrint('No refresh token available');
      return;
    }

    try {
      debugPrint('Refreshing access token...');
      final response = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Basic ${base64Encode(utf8.encode('$clientId:$clientSecret'))}',
        },
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': _refreshToken!,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        
        // Refresh token might be included, update if present
        if (data['refresh_token'] != null) {
          _refreshToken = data['refresh_token'];
          await _saveRefreshToken(_refreshToken!);
        }
        
        final expiresIn = data['expires_in'] as int;
        _tokenExpiryTime = DateTime.now().add(Duration(seconds: expiresIn));
        
        await _saveToken(_accessToken!);
        await _saveTokenExpiry(_tokenExpiryTime!);
        
        // Use withAccessToken factory method
        _spotify = spotify_sdk.SpotifyApi.withAccessToken(_accessToken!);
        _isAuthenticated = true;
        
        debugPrint('Token refreshed successfully! Expires at: $_tokenExpiryTime');
        notifyListeners();
      } else {
        debugPrint('Failed to refresh token: ${response.body}');
        // Token refresh failed, need to re-authenticate
        _accessToken = null;
        _refreshToken = null;
        _spotify = null;
        _isAuthenticated = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error refreshing token: $e');
      _isAuthenticated = false;
      notifyListeners();
    }
  }
  
  Future<List<spotify_sdk.PlaylistSimple>> fetchUserPlaylists({bool forceRefresh = false}) async {
    debugPrint('========================================');
    debugPrint('fetchUserPlaylists called');
    debugPrint('_spotify is null: ${_spotify == null}');
    debugPrint('_accessToken: ${_accessToken?.substring(0, 20)}...');
    debugPrint('Token expiry: $_tokenExpiryTime');
    debugPrint('Is expired: ${_tokenExpiryTime != null ? DateTime.now().isAfter(_tokenExpiryTime!) : "no expiry set"}');
    
    if (_spotify == null) {
      debugPrint('_spotify is null, returning empty list');
      debugPrint('========================================');
      return [];
    }
    
    // Check if token needs refresh before making API call
    if (_tokenExpiryTime != null && DateTime.now().isAfter(_tokenExpiryTime!)) {
      debugPrint('Token expired, refreshing before API call...');
      await _refreshAccessToken();
      if (_spotify == null) {
        debugPrint('Failed to refresh token, user needs to re-authenticate');
        debugPrint('========================================');
        return [];
      }
    }
    
    // Return cached playlists if available and less than 5 minutes old
    if (!forceRefresh && 
        _cachedPlaylists != null && 
        _playlistsCacheTime != null &&
        DateTime.now().difference(_playlistsCacheTime!) < const Duration(minutes: 5)) {
      debugPrint('Returning cached playlists (${_cachedPlaylists!.length} items)');
      debugPrint('========================================');
      return _cachedPlaylists!;
    }
    
    try {
      debugPrint('Fetching playlists from Spotify API...');
      final playlists = await _spotify!.playlists.me.all();
      _cachedPlaylists = playlists.toList();
      _playlistsCacheTime = DateTime.now();
      debugPrint('Fetched ${_cachedPlaylists!.length} playlists successfully');
      debugPrint('========================================');
      notifyListeners();
      return _cachedPlaylists!;
    } catch (e) {
      debugPrint('Error fetching playlists: $e');
      
      // If it's a 401 error, try refreshing token once
      if (e.toString().contains('401')) {
        debugPrint('Got 401 error, attempting token refresh...');
        await _refreshAccessToken();
        if (_spotify != null) {
          try {
            debugPrint('Retrying playlist fetch after token refresh...');
            final playlists = await _spotify!.playlists.me.all();
            _cachedPlaylists = playlists.toList();
            _playlistsCacheTime = DateTime.now();
            debugPrint('Fetched ${_cachedPlaylists!.length} playlists after refresh');
            debugPrint('========================================');
            notifyListeners();
            return _cachedPlaylists!;
          } catch (e2) {
            debugPrint('Error fetching playlists after refresh: $e2');
            debugPrint('========================================');
          }
        }
      }
      
      debugPrint('========================================');
      return _cachedPlaylists ?? [];
    }
  }
  
  Future<List<spotify_sdk.Track>> fetchPlaylistTracks(String playlistId) async {
    if (_spotify == null) return [];
    
    try {
      final tracks = await _spotify!.playlists.getTracksByPlaylistId(playlistId).all();
      return tracks.toList();
    } catch (e) {
      debugPrint('Error fetching tracks: $e');
      return [];
    }
  }
  
  ///---Playback related methods---///
  Future<spotify_sdk.PlaybackState?> getCurrentPlayback() async {
    try {
      final playback = await _spotify!.player.currentlyPlaying();
      return playback;
    } catch (e) {
      debugPrint('Error getting playback state: $e');
      return null;
    }
  }
  
  // Poll for playback updates
  Stream<String?> get currentlyPlayingTrackUri async* {
    while (true) {
      final playback = await getCurrentPlayback();
      yield playback?.item?.uri;
      await Future.delayed(const Duration(seconds: 2)); // Poll every 2 seconds
    }
  }

  /// Start playing a specific track in the context of a playlist
  /// Play track with multiple fallback strategies
Future<bool> playTrackInPlaylist({
  required String playlistUri,
  required String trackUri,
  bool shuffle = true,
}) async {
  try {
    debugPrint('✓ Playing...');
    // Strategy 1: Try to play on existing active device
    if (await _tryPlayOnActiveDevice(playlistUri, trackUri, shuffle)) {
      debugPrint('✓ Successfully played on active device');
      return true;
    }
    
    debugPrint('No active device found, trying to activate...');
    
    // Strategy 2: Try to activate an available device and play
    if (await _tryActivateAndPlay(playlistUri, trackUri, shuffle)) {
      debugPrint('✓ Successfully activated device and played');
      return true;
    }
    
    debugPrint('Could not activate device, falling back to opening Spotify...');
    
    // Strategy 3: Open Spotify app and play in playlist context (last resort)
    return await _openSpotifyAndPlay(trackUri, playlistUri); // Pass both URIs
    
  } catch (e) {
    debugPrint('Error in playTrackInPlaylist: $e');
    return false;
  }
}

/// Strategy 1: Try to play on an active device
Future<bool> _tryPlayOnActiveDevice(
  String playlistUri,
  String trackUri,
  bool shuffle,
) async {
  try {
    final devices = await _spotify!.player.devices();
    final deviceList = devices.toList();
    
    if (deviceList.isEmpty) {
      return false;
    }
    
    // Find an already active device
    final activeDevice = deviceList.firstWhere(
      (d) => d.isActive == true,
      orElse: () => deviceList.first,
    );
    
    // Only proceed if we found an actually active device
    if (activeDevice.isActive != true) {
      return false;
    }
    
    final deviceId = activeDevice.id;
    if (deviceId == null) {
      return false;
    }
    
    debugPrint('Found active device: ${activeDevice.name}');
    
    // Enable shuffle if requested
    if (shuffle) {
      await _spotify!.player.shuffle(true, deviceId: deviceId);
    }
    
    // Start playback
    await _spotify!.player.startWithContext(
        playlistUri, 
        deviceId: deviceId,
        offset: spotify_sdk.UriOffset(trackUri)
      );
    
    return true;
  } catch (e) {
    debugPrint('Error in _tryPlayOnActiveDevice: $e');
    return false;
  }
}

/// Strategy 2: Try to activate a device and play
Future<bool> _tryActivateAndPlay(
  String playlistUri,
  String trackUri,
  bool shuffle,
) async {
  try {
    // Wait a moment for devices to register
    await Future.delayed(const Duration(seconds: 1));
    
    final devices = await _spotify!.player.devices();
    final deviceList = devices.toList();
    
    if (deviceList.isEmpty) {
      debugPrint('No devices available to activate');
      return false;
    }
    
    // Get first available device (even if not active)
    final device = deviceList.first;
    final deviceId = device.id;
    
    if (deviceId == null) {
      return false;
    }
    
    debugPrint('Attempting to activate device: ${device.name}');
    
    try {
      // Try to transfer playback to activate the device
      await _spotify!.player.transfer(deviceId, false);
      
      // Give device time to activate
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Enable shuffle if requested
      if (shuffle) {
        await _spotify!.player.shuffle(true, deviceId: deviceId);
      }
      
      // Try to start playback
      await _spotify!.player.startWithContext(
        playlistUri, 
        deviceId: deviceId,
        offset: spotify_sdk.UriOffset(trackUri)
      );
      
      return true;
    } catch (e) {
      debugPrint('Failed to activate and play: $e');
      return false;
    }
  } catch (e) {
    debugPrint('Error in _tryActivateAndPlay: $e');
    return false;
  }
}

/// Strategy 3 with platform-specific handling
Future<bool> _openSpotifyAndPlay(String trackUri, String playlistUri) async {
  try {
    final trackId = trackUri.split(':').last;
    final playlistId = playlistUri.split(':').last;
    
    // For Android: Use Spotify's intent with playlist context
    if (Platform.isAndroid) {
      // This intent tells Spotify to play the playlist starting at the track
      final androidIntent = Uri.parse(
        'spotify:playlist:$playlistId:play?uri=spotify:track:$trackId'
      );
      
      if (await canLaunchUrl(androidIntent)) {
        debugPrint('Opening Spotify via Android intent with playlist context');
        await launchUrl(
          androidIntent,
          mode: LaunchMode.externalApplication,
        );
        await Future.delayed(const Duration(seconds: 2));
        return true;
      }
    }
    
    // For iOS or fallback: Use universal link
    // Spotify URI scheme with track in playlist context
    final spotifyUri = Uri.parse('spotify:playlist:$playlistId:track:$trackId');
    
    if (await canLaunchUrl(spotifyUri)) {
      debugPrint('Opening Spotify with playlist context');
      await launchUrl(
        spotifyUri,
        mode: LaunchMode.externalApplication,
      );
      await Future.delayed(const Duration(seconds: 2));
      return true;
    }
    
    // Web fallback
    final webUrl = Uri.parse(
      'https://open.spotify.com/playlist/$playlistId?uri=spotify:track:$trackId'
    );
    
    if (await canLaunchUrl(webUrl)) {
      debugPrint('Opening Spotify web player with playlist context');
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      return true;
    }
    
    return false;
    
  } catch (e) {
    debugPrint('Error opening Spotify: $e');
    return false;
  }
}

//   Future<bool> playTrackInPlaylist({
//   required String playlistUri,
//   required String trackUri,
//   bool shuffle = true,
// }) async {
//   try {
//     // Get user's active devices
//     var devices = await _spotify!.player.devices();
//     var deviceList = devices.toList();
    
//     if (deviceList.isEmpty) {
//       debugPrint('No active Spotify devices found - attempting to activate...');
      
//       // Wait a moment and try again (sometimes devices need time to register)
//       await Future.delayed(const Duration(seconds: 1));
//       devices = await _spotify!.player.devices();
//       deviceList = devices.toList();
      
//       if (deviceList.isEmpty) {
//         debugPrint('Still no devices found after retry');
//         return false;
//       }
//     }
    
//     // Find the best device to use
//     spotify_sdk.Device? targetDevice;
    
//     // First, try to find an already active device
//     targetDevice = deviceList.firstWhere(
//       (d) => d.isActive == true,
//       orElse: () => deviceList.first,
//     );
    
//     final deviceId = targetDevice.id;
    
//     if (deviceId == null) {
//       debugPrint('Device ID is null');
//       return false;
//     }
    
//     debugPrint('Using device: ${targetDevice.name} (active: ${targetDevice.isActive})');
    
//     // If device is not active, activate it first by transferring playback
//     if (targetDevice.isActive != true) {
//       debugPrint('Device not active, activating...');
//       try {
//         await _spotify!.player.transfer(deviceId, false);
//         // Give it a moment to activate
//         await Future.delayed(const Duration(milliseconds: 500));
//       } catch (e) {
//         debugPrint('Could not transfer playback: $e');
//         // Continue anyway, might still work
//       }
//     }
    
//     // Enable shuffle if requested
//     if (shuffle) {
//       await _spotify!.player.shuffle(true, deviceId: deviceId);
//     }
    
//     // Start playback with the playlist context and specific track
//     await _spotify!.player.startWithContext(
//         playlistUri, 
//         deviceId: deviceId,
//         offset: spotify_sdk.UriOffset(trackUri)
//       );
    
//     debugPrint('Started playing $trackUri in playlist $playlistUri');
//     return true;
    
//   } catch (e) {
//     debugPrint('Error playing track: $e');
//     return false;
//   }
// }
  // Future<bool> playTrackInPlaylist({
  //   required String playlistUri,
  //   required String trackUri,
  //   bool shuffle = true,
  // }) async {
  //   try {
  //     // Get user's active devices
  //     final devices = await _spotify!.player.devices();
      
  //     if (devices.isEmpty) {
  //       debugPrint('No active Spotify devices found');
  //       return false;
  //     }
      
  //     // Use the first available device (or you could let user choose)
  //     final deviceId = devices.first.id;
      
  //     if (deviceId == null) {
  //       debugPrint('Device ID is null');
  //       return false;
  //     }
      
  //     debugPrint('Playing on device: ${devices.first.name}');
      
  //     // Enable shuffle if requested
  //     if (shuffle) {
  //       await _spotify!.player.shuffle(true, deviceId: deviceId);
  //     }
      
  //     // Start playback with the playlist context and specific track
  //     await _spotify!.player.startWithContext(
  //       playlistUri, 
  //       deviceId: deviceId,
  //       offset: spotify_sdk.UriOffset(trackUri)
  //     );
  //     debugPrint('Started playing $trackUri in playlist $playlistUri');
  //     return true;
      
  //   } catch (e) {
  //     debugPrint('Error playing track: $e');
  //     return false;
  //   }
  // }
  
  /// Check if user has active Spotify devices
  Future<bool> hasActiveDevice() async {
    try {
      final devices = await _spotify!.player.devices();
      return devices.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking devices: $e');
      return false;
    }
  }
  
  /// Get list of available devices
  Future<List<spotify_sdk.Device>> getDevices() async {
    try {
      final devices = await _spotify!.player.devices();
      return devices.toList();
    } catch (e) {
      debugPrint('Error getting devices: $e');
      return [];
    }
  }
  
  /// Transfer playback to a specific device
  Future<void> transferPlayback(String deviceId, {bool play = true}) async {
    try {
      await _spotify!.player.transfer(deviceId);
    } catch (e) {
      debugPrint('Error transferring playback: $e');
    }
  }
  
  /// Simple playback controls
  Future<void> pause() async {
    try {
      await _spotify!.player.pause();
    } catch (e) {
      debugPrint('Error pausing: $e');
    }
  }
  
  Future<void> resume() async {
    try {
      await _spotify!.player.resume();
    } catch (e) {
      debugPrint('Error resuming: $e');
    }
  }
  
  Future<void> skipNext() async {
    try {
      await _spotify!.player.next();
    } catch (e) {
      debugPrint('Error skipping: $e');
    }
  }
  
  Future<void> skipPrevious() async {
    try {
      await _spotify!.player.previous();
    } catch (e) {
      debugPrint('Error going back: $e');
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('spotify_token');
    await prefs.remove('spotify_refresh_token');
    await prefs.remove('spotify_token_expiry');
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiryTime = null;
    _spotify = null;
    _isAuthenticated = false;
    _cachedPlaylists = null;
    _playlistsCacheTime = null;
    notifyListeners();
  }
}