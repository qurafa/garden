import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify/spotify.dart' as spotify_sdk;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;

// Add enum for clearer result handling
enum PlaybackResult {
  success,        // Played on existing device
  openedSpotify,  // Had to open Spotify
  failed,         // Complete failure
}

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
  String? _lastKnownDeviceId;
  DateTime? _lastPlaybackTime;
  
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
  
  // Add this helper method
  /*
  Future<spotify_sdk.Device?> _getPreferredDevice() async {
    final devices = await _spotify!.player.devices();
    final deviceList = devices.toList();
    
    if (deviceList.isEmpty) return null;
    
    // If we recently used a device (within 5 minutes), prefer it
    if (_lastKnownDeviceId != null && 
        _lastPlaybackTime != null &&
        DateTime.now().difference(_lastPlaybackTime!) < const Duration(minutes: 5)) {
      
      final lastDevice = deviceList.firstWhere(
        (d) => d.id == _lastKnownDeviceId,
        orElse: () => deviceList.first,
      );
      
      debugPrint('Using last known device: ${lastDevice.name}');
      return lastDevice;
    }
    else {
      spotify_sdk.Device? targetDevice;
      // First, look for devices on this platform (smartphone/computer)
      final currentPlatformDevices = deviceList.where((d) {
        return d.isActive!;
        // final type = d.type?.name.toLowerCase() ?? '';
        // return type.contains('smartphone') || type.contains('computer');
      }).toList();
      
      if (currentPlatformDevices.isNotEmpty) {
        targetDevice = currentPlatformDevices.firstWhere(
          (d) => d.isActive == true,
          orElse: () => deviceList.first,
        );
        debugPrint('Found current active platform device: ${targetDevice.name}');
      } else {
        targetDevice = deviceList.first;
        debugPrint('Using first available device: ${targetDevice.name}');
      }

      return targetDevice;
    }
  }
  */

  /// Start playing a specific track in the context of a playlist
  Future<PlaybackResult> playTrackInPlaylist({
    required String playlistUri,
    required String trackUri,
    bool shuffle = true,
  }) async {
    try {
      // Strategy 1: Try to play on existing active device
      if (await _tryPlayOnActiveDevice(playlistUri, trackUri, shuffle)) {
        debugPrint('✓ Successfully played on active device');
        return PlaybackResult.success;
      }
      
      debugPrint('No active device found, trying to activate...');
      
      // Strategy 2: Try to activate an available device (even if marked inactive)
      if (await _tryActivateAndPlay(playlistUri, trackUri, shuffle)) {
        debugPrint('✓ Successfully activated device and played');
        return PlaybackResult.success;
      }
      
      debugPrint('Could not activate device, falling back to opening Spotify...');
      
      // Strategy 3: Open Spotify app and play
      final opened = await _openSpotifyAndPlay(trackUri, playlistUri);
      return opened ? PlaybackResult.openedSpotify : PlaybackResult.failed;
      
    } catch (e) {
      debugPrint('Error in playTrackInPlaylist: $e');
      return PlaybackResult.failed;
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
      
      // Find an ACTIVE device (must be actively playing)
      final activeDevice = deviceList.firstWhere(
        (d) => d.isActive == true,
        orElse: () => deviceList.first,
      );
      
      // Only proceed if we found an actually active device
      if (activeDevice.isActive != true) {
        debugPrint('No actively playing device found');
        return false;
      }
      
      final deviceId = activeDevice.id;
      if (deviceId == null) return false;
      
      debugPrint('Found active device: ${activeDevice.name}');
      
      if (shuffle) {
        await _spotify!.player.shuffle(true, deviceId: deviceId);
      }
      
      await _spotify!.player.startWithContext(
        playlistUri, 
        deviceId: deviceId,
        offset: spotify_sdk.UriOffset(trackUri)
      );
      
      // Cache successful device
      _lastKnownDeviceId = deviceId;
      _lastPlaybackTime = DateTime.now();
      
      return true;
    } catch (e) {
      debugPrint('Error in _tryPlayOnActiveDevice: $e');
      return false;
    }
  }

  /// Strategy 2: Try to activate ANY available device (even paused ones)
  Future<bool> _tryActivateAndPlay(
    String playlistUri,
    String trackUri,
    bool shuffle,
  ) async {
    try {    
      final devices = await _spotify!.player.devices();
      final deviceList = devices.toList();
      
      if (deviceList.isEmpty) {
        debugPrint('No devices available to activate');
        return false;
      }
      
      // KEY FIX: Accept ANY device, not just active ones
      spotify_sdk.Device? targetDevice;
      
      // Prefer recently used device
      if (_lastKnownDeviceId != null && 
          _lastPlaybackTime != null &&
          DateTime.now().difference(_lastPlaybackTime!) < const Duration(minutes: 5)) {
        
        targetDevice = deviceList.firstWhere(
          (d) => d.id == _lastKnownDeviceId,
          orElse: () => deviceList.first,
        );
        debugPrint('Using last known device: ${targetDevice.name}');
      } else {
        // Otherwise, prefer this device (smartphone)
        final currentPlatformDevices = deviceList.where((d) {
          final type = d.name?.toLowerCase() ?? '';
          return type.contains('smartphone') || type.contains('computer');
        }).toList();
        
        if (currentPlatformDevices.isNotEmpty) {
          targetDevice = currentPlatformDevices.first;
          debugPrint('Found current platform device: ${targetDevice.name}');
        } else {
          targetDevice = deviceList.first;
          debugPrint('Using first available device: ${targetDevice.name}');
        }
      }

      final deviceId = targetDevice.id;
      if (deviceId == null) {
        return false;
      }
      
      debugPrint('Attempting to activate device: ${targetDevice.name} (currently active: ${targetDevice.isActive})');
      
      try {
        // Transfer playback to wake up the device
        await _spotify!.player.transfer(deviceId, false);
        
        // Give device time to wake up
        await Future.delayed(const Duration(milliseconds: 1200));
        
        // Verify device is now ready
        final updatedDevices = await _spotify!.player.devices();
        final updatedDevice = updatedDevices.toList().firstWhere(
          (d) => d.id == deviceId,
          orElse: () => targetDevice!,
        );
        
        debugPrint('Device after transfer: ${updatedDevice.name} (active: ${updatedDevice.isActive})');
        
        // Enable shuffle if requested
        if (shuffle) {
          try {
            await _spotify!.player.shuffle(true, deviceId: deviceId);
            await Future.delayed(const Duration(milliseconds: 200));
          } catch (e) {
            debugPrint('Could not set shuffle (continuing anyway): $e');
          }
        }
        
        // Try to start playback
        await _spotify!.player.startWithContext(
          playlistUri, 
          deviceId: deviceId,
          offset: spotify_sdk.UriOffset(trackUri)
        );
        
        // Cache successful device
        _lastKnownDeviceId = deviceId;
        _lastPlaybackTime = DateTime.now();

        debugPrint('✓ Successfully started playback after activation');
        return true;
        
      } catch (e) {
        debugPrint('Failed to activate and play: $e');
        
        // One more retry with a fresh device check
        try {
          debugPrint('Retrying after brief delay...');
          await Future.delayed(const Duration(seconds: 1));
          
          final retryDevices = await _spotify!.player.devices();
          final retryList = retryDevices.toList();
          
          if (retryList.isEmpty) {
            return false;
          }
          
          final retryDevice = retryList.firstWhere(
            (d) => d.id == deviceId,
            orElse: () => retryList.first,
          );
          
          if (retryDevice.id == null) {
            return false;
          }
          
          await _spotify!.player.startWithContext(
            playlistUri, 
            deviceId: retryDevice.id!,
            offset: spotify_sdk.UriOffset(trackUri)
          );
          
          // Cache successful device
          _lastKnownDeviceId = retryDevice.id;
          _lastPlaybackTime = DateTime.now();

          debugPrint('✓ Playback started on retry');
          return true;
          
        } catch (retryError) {
          debugPrint('Retry also failed: $retryError');
          return false;
        }
      }
    } catch (e) {
      debugPrint('Error in _tryActivateAndPlay: $e');
      return false;
    }
  }

  /// Strategy 3: Open Spotify app (with iOS-specific fixes)
  Future<bool> _openSpotifyAndPlay(String trackUri, String playlistUri) async {
    try {
      debugPrint('Opening Spotify to play track...');
      
      final trackId = trackUri.split(':').last;
      final playlistId = playlistUri.split(':').last;
      
      bool spotifyOpened = false;
      
      if (Platform.isAndroid) {
        // Android: Try multiple URI formats
        try {
          final playIntent = Uri.parse('spotify:playlist:$playlistId:play:$trackId');
          await launchUrl(playIntent, mode: LaunchMode.externalApplication);
          spotifyOpened = true;
          debugPrint('✓ Opened Spotify via Android play intent');
        } catch (e) {
          try {
            final spotifyUri = Uri.parse('spotify:playlist:$playlistId:track:$trackId');
            await launchUrl(spotifyUri, mode: LaunchMode.externalApplication);
            spotifyOpened = true;
            debugPrint('✓ Opened Spotify via standard URI');
          } catch (e2) {
            try {
              final trackOnlyUri = Uri.parse('spotify:track:$trackId');
              await launchUrl(trackOnlyUri, mode: LaunchMode.externalApplication);
              spotifyOpened = true;
              debugPrint('✓ Opened Spotify via track URI');
            } catch (e3) {
              debugPrint('All Android URIs failed');
            }
          }
        }
      } else {
        // iOS: Simpler approach - just open the track
        // The complex playlist URIs cause the error message
        try {
          // Try track-only URI (most reliable on iOS)
          final trackOnlyUri = Uri.parse('spotify:track:$trackId');
          debugPrint('Trying iOS track URI: $trackOnlyUri');
          await launchUrl(trackOnlyUri, mode: LaunchMode.externalApplication);
          spotifyOpened = true;
          debugPrint('✓ Opened Spotify via iOS track URI');
        } catch (e) {
          debugPrint('iOS track URI failed: $e');
          
          // Fallback: Try web URL
          try {
            final webUrl = Uri.parse('https://open.spotify.com/track/$trackId');
            await launchUrl(webUrl, mode: LaunchMode.externalApplication);
            spotifyOpened = true;
            debugPrint('✓ Opened Spotify via web URL');
          } catch (e2) {
            debugPrint('Web URL failed: $e2');
          }
        }
      }
      
      if (!spotifyOpened) {
        debugPrint('Could not open Spotify app');
        return false;
      }
      
      // Wait for Spotify to open
      debugPrint('Waiting for Spotify to activate...');
      await Future.delayed(const Duration(seconds: 3));
      
      // Now try to control playback via API and set playlist context
      for (int attempt = 0; attempt < 4; attempt++) {
        try {
          debugPrint('Playback attempt ${attempt + 1}/4...');
          
          final devices = await _spotify!.player.devices();
          final deviceList = devices.toList();
          
          if (deviceList.isEmpty) {
            debugPrint('No devices found yet, waiting...');
            await Future.delayed(const Duration(milliseconds: 1500));
            continue;
          }
          
          // Find any available device
          final device = deviceList.firstWhere(
            (d) => d.isActive == true,
            orElse: () => deviceList.first,
          );
          
          final deviceId = device.id;
          if (deviceId == null) {
            debugPrint('Device ID is null');
            await Future.delayed(const Duration(seconds: 1));
            continue;
          }
          
          debugPrint('Found device: ${device.name} (active: ${device.isActive}), attempting to control playback...');
          
          // Transfer/activate if needed
          try {
            await _spotify!.player.transfer(deviceId, false);
            await Future.delayed(const Duration(milliseconds: 1000));
          } catch (e) {
            debugPrint('Transfer failed (continuing): $e');
          }
          
          // Start playback with playlist context
          // This ensures future tracks will be from the playlist
          await _spotify!.player.startWithContext(
            playlistUri,
            deviceId: deviceId,
            offset: spotify_sdk.UriOffset(trackUri),
          );
          
          // Cache successful device
          _lastKnownDeviceId = deviceId;
          _lastPlaybackTime = DateTime.now();
          
          debugPrint('✓ Successfully started playback with playlist context!');
          return true;
          
        } catch (e) {
          debugPrint('Playback attempt ${attempt + 1} failed: $e');
          if (attempt < 3) {
            await Future.delayed(const Duration(milliseconds: 1500));
          }
        }
      }
      
      // Spotify opened but couldn't set playlist context - still a partial success
      debugPrint('Spotify opened but could not set playlist context via API');
      return true;
      
    } catch (e) {
      debugPrint('Error in _openSpotifyAndPlay: $e');
      return false;
    }
  }

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