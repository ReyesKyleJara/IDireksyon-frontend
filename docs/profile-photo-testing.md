# Edit Profile photos

Open Edit Profile, then Add profile photo / Change photo.

- Upload from gallery selects an image; Take a photo opens the native camera on Android/iOS or an in-app camera preview on web.
- Both sources open the circular crop preview. Drag and zoom, then choose Use photo to save. Cancel leaves the current photo unchanged.
- Photos retain the existing per-account local storage behavior. Saved avatars are resized to 512 × 512 JPEGs.
- The options sheet supports light/dark themes, large text, and narrow screens.

Browser camera access requires permission and a secure context: localhost or HTTPS. Opening the web app on a phone at a plain HTTP LAN IP may block camera access. Gallery remains available. Native Android testing does not have that browser restriction.

After updating native dependencies, stop the app and run `flutter run` again; hot reload alone is insufficient. iOS builds require macOS. Camera/photo permission descriptions are configured in `ios/Runner/Info.plist`.

Focused checks: `flutter test test/profile_photo_test.dart`. These cover crop confirmation/cancellation, avatar preparation/storage, and source selection at narrow widths with large text. Verify camera hardware and permission prompts on a real device.
