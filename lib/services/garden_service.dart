import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/garden_model.dart';

class GardenService extends ChangeNotifier {
  List<Garden> _gardens = [];
  bool _isLoading = true;

  List<Garden> get gardens => _gardens;
  bool get isLoading => _isLoading;
  bool get hasGardens => _gardens.isNotEmpty;

  GardenService() {
    _loadGardens();
  }

  Future<void> _loadGardens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gardensJson = prefs.getStringList('gardens') ?? [];
      _gardens = gardensJson
          .map((json) => Garden.fromJsonString(json))
          .toList()
        ..sort((a, b) => b.lastViewedAt.compareTo(a.lastViewedAt));
    } catch (e) {
      debugPrint('Error loading gardens: $e');
      _gardens = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveGardens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gardensJson = _gardens.map((g) => g.toJsonString()).toList();
      await prefs.setStringList('gardens', gardensJson);
    } catch (e) {
      debugPrint('Error saving gardens: $e');
    }
  }

  Future<void> addGarden({
    required String playlistId,
    required String playlistName,
    String? playlistImageUrl,
    required int trackCount,
  }) async {
    // Check if garden already exists
    if (_gardens.any((g) => g.playlistId == playlistId)) {
      debugPrint('Garden for playlist $playlistId already exists');
      return;
    }

    final garden = Garden(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      playlistId: playlistId,
      playlistName: playlistName,
      playlistImageUrl: playlistImageUrl,
      trackCount: trackCount,
      createdAt: DateTime.now(),
      lastViewedAt: DateTime.now(),
    );

    _gardens.add(garden);
    _gardens.sort((a, b) => b.lastViewedAt.compareTo(a.lastViewedAt));
    await _saveGardens();
    notifyListeners();
  }

  Future<void> updateGarden(Garden garden) async {
    final index = _gardens.indexWhere((g) => g.id == garden.id);
    if (index != -1) {
      _gardens[index] = garden;
      await _saveGardens();
      notifyListeners();
    }
  }

  Future<void> updateLastViewed(String gardenId) async {
    final index = _gardens.indexWhere((g) => g.id == gardenId);
    if (index != -1) {
      _gardens[index] = _gardens[index].copyWith(
        lastViewedAt: DateTime.now(),
      );
      _gardens.sort((a, b) => b.lastViewedAt.compareTo(a.lastViewedAt));
      await _saveGardens();
      notifyListeners();
    }
  }

  Future<void> deleteGarden(String gardenId) async {
    _gardens.removeWhere((g) => g.id == gardenId);
    await _saveGardens();
    notifyListeners();
  }

  Garden? getGardenById(String gardenId) {
    try {
      return _gardens.firstWhere((g) => g.id == gardenId);
    } catch (e) {
      return null;
    }
  }

  bool hasGardenForPlaylist(String playlistId) {
    return _gardens.any((g) => g.playlistId == playlistId);
  }
}