import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'profile_camera_screen.dart';
import 'profile_photo_crop_screen.dart';
import 'profile_photo_source_sheet.dart';

import '../../core/auth/auth_service.dart';
import '../../core/profile/profile_avatar.dart';
import '../../core/profile/profile_photo_service.dart';

class AccountDetailsScreen extends StatefulWidget {
  const AccountDetailsScreen({super.key});

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  static const _navy = Color(0xFF1E3A8A);

  final _formKey = GlobalKey<FormState>();
  final _photoService = ProfilePhotoService.instance;

  late final bool _usePhone = AuthService.instance.user?['email'] == null;

  late final _name = TextEditingController(
    text: AuthService.instance.user?['name'] as String? ?? '',
  );

  late final _contact = TextEditingController(
    text:
        AuthService.instance.user?[_usePhone ? 'phone' : 'email'] as String? ??
        '',
  );

  late DateTime? _birthDate = _savedBirthDate();
  late final _birthday = TextEditingController(
    text: _birthDate == null ? '' : _displayDate(_birthDate!),
  );

  int? _selectedBarangayId = int.tryParse(
    '${AuthService.instance.user?['barangay_id']}',
  );
  List<Map<String, dynamic>> _barangays = [];
  bool _loadingBarangays = true;
  bool _barangayError = false;

  bool _saving = false;
  bool _changingPhoto = false;

  bool get _busy => _saving || _changingPhoto;

  @override
  void initState() {
    super.initState();
    _photoService.addListener(_onPhotoChanged);
    _photoService.load();
    _loadBarangays();
  }

  Future<void> _loadBarangays() async {
    setState(() {
      _loadingBarangays = true;
      _barangayError = false;
    });
    try {
      final rows = await AuthService.instance.getBarangays();
      if (!mounted) return;
      setState(() {
        _barangays = rows
            .where((row) => row['id'] is int && row['name'] is String)
            .toList();
      });
    } catch (_) {
      if (mounted) setState(() => _barangayError = true);
    } finally {
      if (mounted) setState(() => _loadingBarangays = false);
    }
  }

  @override
  void dispose() {
    _photoService.removeListener(_onPhotoChanged);
    _name.dispose();
    _contact.dispose();
    _birthday.dispose();
    super.dispose();
  }

  /// Date only: a saved time zone must never move the birthday by a day.
  DateTime? _savedBirthDate() {
    final saved = AuthService.instance.user?['date_of_birth'];
    return saved is String ? DateTime.tryParse(saved.split('T').first) : null;
  }

  String _displayDate(DateTime date) =>
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.day.toString().padLeft(2, '0')}/${date.year}';

  String _apiDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> _pickBirthDate() async {
    if (_busy) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      // A birthday has to be before today, the same rule as profile setup.
      lastDate: DateTime(now.year, now.month, now.day - 1),
      helpText: 'Select your birthday',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _birthDate = picked;
      _birthday.text = _displayDate(picked);
    });
  }

  void _onPhotoChanged() {
    if (mounted) setState(() {});
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _changePhoto() async {
    if (_busy) return;

    await _photoService.load();
    if (!mounted) return;

    final action = await showModalBottomSheet<ProfilePhotoAction>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => ProfilePhotoSourceSheet(hasPhoto: _photoService.hasPhoto),
    );

    if (!mounted || action == null) return;

    setState(() => _changingPhoto = true);

    try {
      if (action == ProfilePhotoAction.remove) {
        await _photoService.removePhoto();
        if (mounted) _message('Profile photo removed.');
      } else {
        final bytes = action == ProfilePhotoAction.camera && kIsWeb
            ? await Navigator.of(context).push<Uint8List>(
                MaterialPageRoute(builder: (_) => const ProfileCameraScreen()),
              )
            : await _photoService.pickPhoto(
                action == ProfilePhotoAction.camera
                    ? ImageSource.camera
                    : ImageSource.gallery,
              );
        if (!mounted || bytes == null) return;
        final prepared = await _photoService.prepareForCrop(bytes);
        if (!mounted) return;
        final cropped = await Navigator.of(context).push<Uint8List>(
          MaterialPageRoute(
            builder: (_) => ProfilePhotoCropScreen(bytes: prepared),
          ),
        );
        if (!mounted || cropped == null) return;
        await _photoService.savePhoto(cropped);
        if (mounted) _message('Profile photo updated.');
      }
    } on PlatformException catch (error) {
      if (mounted) {
        _message(
          error.code.toLowerCase().contains('access') ||
                  error.code.toLowerCase().contains('denied')
              ? 'Allow camera or photo access in your device settings, then try again.'
              : 'Could not open your camera or gallery. Try another photo source.',
        );
      }
    } catch (_) {
      if (mounted) {
        _message('Unable to update your profile photo. Try a different image.');
      }
    } finally {
      if (mounted) setState(() => _changingPhoto = false);
    }
  }

  Future<void> _saveAccount() async {
    if (_busy || !_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      await AuthService.instance.updateAccount(
        name: _name.text.trim(),
        contact: _contact.text.trim(),
        usePhone: _usePhone,
        barangayId: _barangays.any((row) => row['id'] == _selectedBarangayId)
            ? _selectedBarangayId
            : null,
        dateOfBirth: _birthDate == null ? null : _apiDate(_birthDate!),
      );

      if (!mounted) return;

      final user = AuthService.instance.user;
      final savedBirthDate = _savedBirthDate();
      if (savedBirthDate != null) {
        _birthDate = savedBirthDate;
        _birthday.text = _displayDate(savedBirthDate);
      }

      _name.text = user?['name'] as String? ?? _name.text;
      _contact.text =
          user?[_usePhone ? 'phone' : 'email'] as String? ?? _contact.text;

      _message('Profile updated successfully.');
    } on AuthException catch (error) {
      if (mounted) _message(error.message);
    } catch (_) {
      if (mounted) {
        _message('Unable to save changes.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = colors.onSurfaceVariant;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(''),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Edit profile',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Make changes to your personal details.',
                      style: TextStyle(fontSize: 14, color: muted, height: 1.4),
                    ),

                    const SizedBox(height: 32),

                    // PROFILE PHOTO
                    Center(
                      child: Column(
                        children: [
                          ProfileAvatar(size: 100, onTap: _changePhoto),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: _busy ? null : _changePhoto,
                            style: TextButton.styleFrom(foregroundColor: _navy),
                            child: Text(
                              _photoService.hasPhoto
                                  ? 'Change photo'
                                  : 'Add profile photo',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // NAME
                    _field(
                      label: 'Full name',
                      controller: _name,
                      autofill: const [AutofillHints.name],
                      validator: (value) {
                        final name = value?.trim() ?? '';

                        if (name.isEmpty) {
                          return 'Please enter your name.';
                        }
                        if (name.length > 255) {
                          return 'Maximum of 255 characters.';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 23),

                    // EMAIL OR PHONE
                    _field(
                      label: _usePhone ? 'Mobile number' : 'Email address',
                      controller: _contact,
                      keyboardType: _usePhone
                          ? TextInputType.phone
                          : TextInputType.emailAddress,
                      autofill: [
                        _usePhone
                            ? AutofillHints.telephoneNumber
                            : AutofillHints.email,
                      ],
                      validator: (value) {
                        final contact = (value ?? '').trim();

                        if (_usePhone) {
                          final normalized = contact.replaceAll(
                            RegExp(r'[\s()-]'),
                            '',
                          );

                          if (!RegExp(r'^(09\d{9}|\+639\d{9})$')
                              .hasMatch(normalized)) {
                            return 'Enter a valid Philippine mobile number.';
                          }
                        } else {
                          if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(contact)) {
                            return 'Enter a valid email address.';
                          }
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 23),

                    // BIRTHDAY
                    _field(
                      label: 'Birthday',
                      controller: _birthday,
                      readOnly: true,
                      onTap: _pickBirthDate,
                      hint: 'MM/DD/YYYY',
                      suffixIcon: Icon(
                        Icons.calendar_today_outlined,
                        size: 19,
                        color: colors.primary,
                      ),
                      validator: (_) => null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Used to check age-based eligibility.',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),

                    const SizedBox(height: 23),

                    Text(
                      'Barangay',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_loadingBarangays)
                      const Text(
                        'Loading barangays…',
                        style: TextStyle(fontSize: 13),
                      )
                    else if (_barangayError)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AuthService.instance.user?['barangay_name']
                                    as String? ??
                                'Barangay details unavailable',
                            style: TextStyle(fontSize: 13, color: muted),
                          ),
                          TextButton(
                            onPressed: _busy ? null : _loadBarangays,
                            child: const Text(
                              'Could not load barangays. Retry',
                            ),
                          ),
                        ],
                      )
                    else
                      DropdownButtonFormField<int>(
                        key: ValueKey('barangay-$_selectedBarangayId'),
                        initialValue:
                            _barangays.any(
                              (row) => row['id'] == _selectedBarangayId,
                            )
                            ? _selectedBarangayId
                            : null,
                        isExpanded: true,
                        menuMaxHeight: 320,
                        dropdownColor: colors.surface,
                        itemHeight: null,
                        selectedItemBuilder: (_) => [
                          for (final row in _barangays)
                            Text(
                              row['name'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
                        ],
                        decoration: InputDecoration(
                          hintText: 'Select your barangay',
                          filled: true,
                          fillColor: colors.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 17,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: colors.outlineVariant,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: _navy,
                              width: 1.5,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        items: [
                          for (final row in _barangays)
                            DropdownMenuItem(
                              value: row['id'] as int,
                              child: Text(
                                row['name'] as String,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) =>
                                  setState(() => _selectedBarangayId = value),
                      ),
                    const SizedBox(height: 28),

                    // SAVE BUTTON
                    FilledButton(
                      onPressed: _busy ? null : _saveAccount,
                      style: FilledButton.styleFrom(
                        backgroundColor: _navy,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save changes',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    Iterable<String>? autofill,
    bool readOnly = false,
    VoidCallback? onTap,
    String? hint,
    Widget? suffixIcon,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          enabled: !_busy,
          validator: validator,
          keyboardType: keyboardType,
          autofillHints: autofill,
          autocorrect: false,
          readOnly: readOnly,
          onTap: onTap,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
            errorMaxLines: 3,
            filled: true,
            fillColor: colors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 17,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _navy, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
