import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as image;
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

    final identity = user?['id'] ?? user?['email'] ?? user?['phone'] ?? 'guest';

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

  Future<Uint8List?> pickPhoto(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
    );

    return picked?.readAsBytes();
  }

  Future<void> savePhoto(Uint8List croppedBytes) async {
    final key = _storageKey;
    final bytes = await compute(_prepareAvatar, croppedBytes);
    if (key != _storageKey) return;
    final prefs = await SharedPreferences.getInstance();

    final saved = await prefs.setString(key, base64Encode(bytes));
    if (!saved) throw StateError('Could not save profile photo.');
    if (key != _storageKey) return;

    _photoBytes = bytes;
    _loadedForKey = _storageKey;

    notifyListeners();
  }

  Future<Uint8List> prepareForCrop(Uint8List bytes) =>
      compute(_prepareCropImage, bytes);

  Future<void> removePhoto() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_storageKey);

    _photoBytes = null;
    _loadedForKey = _storageKey;

    notifyListeners();
  }
}

Uint8List _prepareAvatar(Uint8List bytes) {
  final decoded = image.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Unsupported photo.');
  final resized = image.copyResize(decoded, width: 512, height: 512);
  return Uint8List.fromList(image.encodeJpg(resized, quality: 85));
}

Uint8List _prepareCropImage(Uint8List bytes) {
  final decoded = image.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Unsupported photo.');
  final oriented = image.bakeOrientation(decoded);
  final resized = oriented.width > 1600 || oriented.height > 1600
      ? image.copyResize(
          oriented,
          width: oriented.width >= oriented.height ? 1600 : null,
          height: oriented.height > oriented.width ? 1600 : null,
        )
      : oriented;
  return Uint8List.fromList(image.encodeJpg(resized, quality: 90));
}
