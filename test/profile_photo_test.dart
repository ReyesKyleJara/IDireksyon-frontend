import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/core/profile/profile_photo_service.dart';
import 'package:idireksyon_frontend/features/profile/profile_photo_source_sheet.dart';
import 'package:idireksyon_frontend/features/profile/profile_photo_crop_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final confirm in [false, true]) {
    testWidgets(
      'crop preview returns a square only after confirmation: $confirm',
      (tester) async {
        final bytes = Uint8List.fromList(
          image.encodePng(image.Image(width: 120, height: 80)),
        );
        Uint8List? result;
        bool returned = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await Navigator.of(context).push<Uint8List>(
                      MaterialPageRoute(
                        builder: (_) => ProfilePhotoCropScreen(bytes: bytes),
                      ),
                    );
                    returned = true;
                  },
                  child: const Text('Open crop'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open crop'));
        await tester.pumpAndSettle();
        if (confirm) {
          for (var attempt = 0; attempt < 20; attempt++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 100)),
            );
            await tester.pumpAndSettle();
            if (tester
                    .widget<FilledButton>(
                      find.widgetWithText(FilledButton, 'Use photo'),
                    )
                    .onPressed !=
                null) {
              break;
            }
          }
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Use photo'),
                )
                .onPressed,
            isNotNull,
          );
        }
        await tester.tap(find.text(confirm ? 'Use photo' : 'Cancel'));
        for (var attempt = 0; !returned && attempt < 20; attempt++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pumpAndSettle();
        }
        expect(returned, isTrue);
        if (confirm) {
          final cropped = image.decodeImage(result!)!;
          expect(cropped.width, cropped.height);
          expect(cropped.width, lessThanOrEqualTo(80));
        } else {
          expect(result, isNull);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('preparing a photo does not overwrite the saved avatar; invalid data preserves it', () async {
    SharedPreferences.setMockInitialValues({});
    final original = AuthService.instance;
    AuthService.instance = AuthService()..user = {'id': 'photo-test'};
    addTearDown(() => AuthService.instance = original);
    final service = ProfilePhotoService.instance;
    await service.load();
    final source = Uint8List.fromList(
      image.encodePng(image.Image(width: 800, height: 400)),
    );
    await service.savePhoto(source);
    final saved = service.photoBytes!;
    final avatar = image.decodeImage(saved)!;
    expect(avatar.width, 512);
    expect(avatar.height, 512);
    final prepared = await service.prepareForCrop(source);
    expect(image.decodeImage(prepared)!.width, 800);
    expect(service.photoBytes, same(saved));
    await expectLater(
      service.prepareForCrop(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
    expect(service.photoBytes, same(saved));
    await service.removePhoto();
    expect(service.hasPhoto, isFalse);
  });

  for (final action in [
    ProfilePhotoAction.gallery,
    ProfilePhotoAction.camera,
  ]) {
    testWidgets(
      'photo source modal selects $action on a narrow screen with large text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        ProfilePhotoAction? selected;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () async {
                      selected = await showModalBottomSheet<ProfilePhotoAction>(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        builder: (_) =>
                            const ProfilePhotoSourceSheet(hasPhoto: true),
                      );
                    },
                    child: const Text('Open photo options'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open photo options'));
        await tester.pumpAndSettle();
        final target = find.text(
          action == ProfilePhotoAction.gallery
              ? 'Upload from gallery'
              : 'Take a photo',
        );
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(selected, action);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
