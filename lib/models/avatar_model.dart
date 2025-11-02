import 'dart:convert';
import 'package:flutter/material.dart';

class Avatar {
  final Color faceColor;
  final int eyeStyle; // 0-4: different eye types
  final int mouthStyle; // 0-4: different mouth types
  
  Avatar({
    required this.faceColor,
    required this.eyeStyle,
    required this.mouthStyle,
  });

  Avatar copyWith({
    Color? faceColor,
    int? eyeStyle,
    int? mouthStyle,
  }) {
    return Avatar(
      faceColor: faceColor ?? this.faceColor,
      eyeStyle: eyeStyle ?? this.eyeStyle,
      mouthStyle: mouthStyle ?? this.mouthStyle,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'faceColor': faceColor,
      'eyeStyle': eyeStyle,
      'mouthStyle': mouthStyle,
    };
  }

  factory Avatar.fromJson(Map<String, dynamic> json) {
    return Avatar(
      faceColor: Color(json['faceColor']),
      eyeStyle: json['eyeStyle'],
      mouthStyle: json['mouthStyle'],
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory Avatar.fromJsonString(String jsonString) =>
      Avatar.fromJson(jsonDecode(jsonString));

  // Default avatar
  factory Avatar.defaultAvatar() {
    return Avatar(
      faceColor: const Color(0xFFFFD700), // Gold
      eyeStyle: 0,
      mouthStyle: 0,
    );
  }

  // Preset colors
  static const List<Color> presetColors = [
    Color(0xFFFFD700), // Gold
    Color(0xFFFF6B6B), // Red
    Color(0xFF4ECDC4), // Teal
    Color(0xFF95E1D3), // Mint
    Color(0xFFFFA07A), // Light Salmon
    Color(0xFF9B59B6), // Purple
    Color(0xFF3498DB), // Blue
    Color(0xFFE74C3C), // Dark Red
    Color(0xFF2ECC71), // Green
    Color(0xFFF39C12), // Orange
  ];
}