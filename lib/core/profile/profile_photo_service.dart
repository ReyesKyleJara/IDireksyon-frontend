import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_service.dart';

class ProfilePhotoService extends ChangeNotifier {
  ProfilePhotoService._();

  static final ProfilePhotoService instance = ProfilePhotoService._();

  final ImagePicker _picker = ImagePicker();

  Uint8List? _photoBytes;
  String? _loadedForKey;

  Uint8List? get photoBytes => _photoBytes;

  bool get hasPhoto => _photoBytes != null;

  String get _storageKey {
    final user = AuthService.instance.user;

    final identity =
        user?['id'] ??
        user?['email'] ??
        user?['phone'] ??
        'guest';

    return 'profile_photo_$identity';
  }

  Future<void> load() async {
    final key = _storageKey;

    if (_loadedForKey == key) return;

    _photoBytes = null;
    _loadedForKey = key;

    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(key);

    if (encoded != null && encoded.isNotEmpty) {
      try {
        _photoBytes = base64Decode(encoded);
      } catch (_) {
        await prefs.remove(key);
        _photoBytes = null;
      }
    }

    notifyListeners();
  }

  Future<bool> pickFromGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 72,
    );

    if (picked == null) return false;

    final bytes = await picked.readAsBytes();

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _storageKey,
      base64Encode(bytes),
    );

    _photoBytes = bytes;
    _loadedForKey = _storageKey;

    notifyListeners();

    return true;
  }

  Future<void> removePhoto() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_storageKey);

    _photoBytes = null;
    _loadedForKey = _storageKey;

    notifyListeners();
  }
}