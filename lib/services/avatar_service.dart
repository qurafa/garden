import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/avatar_model.dart';

class AvatarService extends ChangeNotifier {
  Avatar _avatar = Avatar.defaultAvatar();
  bool _isLoading = true;

  Avatar get avatar => _avatar;
  bool get isLoading => _isLoading;

  AvatarService() {
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final avatarJson = prefs.getString('user_avatar');
      
      if (avatarJson != null) {
        _avatar = Avatar.fromJsonString(avatarJson);
      }
    } catch (e) {
      debugPrint('Error loading avatar: $e');
      _avatar = Avatar.defaultAvatar();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveAvatar(Avatar avatar) async {
    _avatar = avatar;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_avatar', avatar.toJsonString());
    } catch (e) {
      debugPrint('Error saving avatar: $e');
    }
  }
}