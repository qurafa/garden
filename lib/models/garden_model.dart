import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';

class Garden {
  final String id;
  final String playlistId;
  final String playlistName;
  final String? playlistImageUrl;
  final int trackCount;
  final DateTime createdAt;
  final DateTime lastViewedAt;
  final List<FlowerPosition>? flowerPositions;

  Garden({
    required this.id,
    required this.playlistId,
    required this.playlistName,
    this.playlistImageUrl,
    required this.trackCount,
    required this.createdAt,
    required this.lastViewedAt,
    this.flowerPositions,
  });

  Garden copyWith({
    String? id,
    String? playlistId,
    String? playlistName,
    String? playlistImageUrl,
    int? trackCount,
    DateTime? createdAt,
    DateTime? lastViewedAt,
    List<FlowerPosition>? flowerPositions,
  }) {
    return Garden(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      playlistName: playlistName ?? this.playlistName,
      playlistImageUrl: playlistImageUrl ?? this.playlistImageUrl,
      trackCount: trackCount ?? this.trackCount,
      createdAt: createdAt ?? this.createdAt,
      lastViewedAt: lastViewedAt ?? this.lastViewedAt,
      flowerPositions: flowerPositions ?? this.flowerPositions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'playlistId': playlistId,
      'playlistName': playlistName,
      'playlistImageUrl': playlistImageUrl,
      'trackCount': trackCount,
      'createdAt': createdAt.toIso8601String(),
      'lastViewedAt': lastViewedAt.toIso8601String(),
      'flowerPositions': flowerPositions?.map((f) => f.toJson()).toList(),
    };
  }

  factory Garden.fromJson(Map<String, dynamic> json) {
    return Garden(
      id: json['id'],
      playlistId: json['playlistId'],
      playlistName: json['playlistName'],
      playlistImageUrl: json['playlistImageUrl'],
      trackCount: json['trackCount'],
      createdAt: DateTime.parse(json['createdAt']),
      lastViewedAt: DateTime.parse(json['lastViewedAt']),
      flowerPositions: json['flowerPositions'] != null
          ? (json['flowerPositions'] as List)
              .map((f) => FlowerPosition.fromJson(f))
              .toList()
          : null,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory Garden.fromJsonString(String jsonString) =>
      Garden.fromJson(jsonDecode(jsonString));
}

class FlowerPosition {
  final double x;
  final double y;
  final int trackIndex;
  final int flowerType; // Different flower styles
  final int colorVariant; // Color variation

  FlowerPosition({
    required this.x,
    required this.y,
    required this.trackIndex,
    required this.flowerType,
    required this.colorVariant,
  });

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'trackIndex': trackIndex,
      'flowerType': flowerType,
      'colorVariant': colorVariant,
    };
  }

  factory FlowerPosition.fromJson(Map<String, dynamic> json) {
    return FlowerPosition(
      x: json['x'],
      y: json['y'],
      trackIndex: json['trackIndex'],
      flowerType: json['flowerType'],
      colorVariant: json['colorVariant'],
    );
  }

  static List<FlowerPosition> generatePositions(int trackCount, double canvasWidth, double canvasHeight) {
    final random = Random();
    final positions = <FlowerPosition>[];
    
    debugPrint('Generating positions for $trackCount tracks on canvas ${canvasWidth}x$canvasHeight');
    
    // Grid-based placement with randomness for natural look
    final minSpacing = 50.0; // Reduced from 60 for more flowers to fit
    
    for (int i = 0; i < trackCount; i++) {
      bool validPosition = false;
      int attempts = 0;
      double x = 0, y = 0;
      
      // Try to find a valid position
      while (!validPosition && attempts < 100) { // Increased attempts from 50
        x = 40 + random.nextDouble() * (canvasWidth - 80);
        y = 40 + random.nextDouble() * (canvasHeight - 80);
        
        // Check if too close to other flowers
        validPosition = true;
        for (var pos in positions) {
          final distance = sqrt(pow(x - pos.x, 2) + pow(y - pos.y, 2));
          if (distance < minSpacing) {
            validPosition = false;
            break;
          }
        }
        attempts++;
      }
      
      // If we couldn't find a good spot after many attempts, just place it anyway
      // This ensures all flowers get placed
      if (!validPosition) {
        debugPrint('Warning: Could not find ideal position for flower $i after $attempts attempts, placing anyway');
        x = 40 + random.nextDouble() * (canvasWidth - 80);
        y = 40 + random.nextDouble() * (canvasHeight - 80);
      }
      
      final position = FlowerPosition(
        x: x,
        y: y,
        trackIndex: i,
        flowerType: random.nextInt(5), // 5 different flower types
        colorVariant: random.nextInt(4), // 4 color variants
      );
      
      positions.add(position);
      debugPrint('Placed flower $i at ($x, $y) type=${position.flowerType} color=${position.colorVariant}');
    }
    
    debugPrint('Generated ${positions.length} flower positions');
    return positions;
  }
}