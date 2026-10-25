import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:idireksyon_frontend/features/auth/auth_feature_bubble.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/features/auth/auth_mascot_peek.dart';
import 'package:idireksyon_frontend/features/auth/welcome_screen.dart';
import 'package:idireksyon_frontend/features/auth/email_signup_screen.dart';
import 'package:idireksyon_frontend/features/auth/phone_signup_screen.dart';

void main() {
  final mascot = find.byKey(const ValueKey('auth-random-peek'));
  final bubble = find.byKey(const ValueKey('auth-feature-bubble'));

  testWidgets('Welcome shows a large peek without covering either action', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(mascot, findsOneWidget);
    expect(bubble, findsOneWidget);
    expect(tester.getSize(mascot).width, inInclusiveRange(132, 264));
    final viewport =
        Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
    final visible = tester.getRect(mascot).intersect(viewport);
    for (final label in ['Log In', 'Sign Up']) {
      expect(find.text(label).hitTestable(), findsOneWidget);
      expect(visible.overlaps(tester.getRect(find.text(label))), isFalse);
      expect(
        tester.getRect(bubble).overlaps(tester.getRect(find.text(label))),
        isFalse,
      );
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Mobile Welcome has room for both mascot and tip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(mascot, findsOneWidget);
    expect(bubble, findsOneWidget);
    for (final label in ['Log In', 'Sign Up', 'Welcome!']) {
      expect(
        tester.getRect(bubble).overlaps(tester.getRect(find.text(label))),
        isFalse,
      );
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final phone in [false, true]) {
    testWidgets('Random peeks leave small signup forms usable: phone=$phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: phone ? const PhoneSignupScreen() : const EmailSignupScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(AuthMascotPeek), findsOneWidget);
      expect(mascot, findsOneWidget);
      expect(bubble, findsOneWidget);
      for (final field in tester.widgetList<TextFormField>(
        find.byType(TextFormField),
      )) {
        final bounds = tester.getRect(find.byWidget(field));
        expect(tester.getRect(mascot).overlaps(bounds), isFalse);
        expect(tester.getRect(bubble).overlaps(bounds), isFalse);
      }
      expect(find.byType(TextFormField), findsNWidgets(3));
      await tester.enterText(
        find.byType(TextFormField).first,
        phone ? '09091234567' : 'resident@example.com',
      );
      await tester.pump(const Duration(milliseconds: 600));
      final submit = find.widgetWithText(FilledButton, 'Create Account');
      await tester.ensureVisible(submit);
      expect(submit.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('New turns change pose and location while avoiding content', (
    tester,
  ) async {
    var taps = 0;
    const textKey = ValueKey('protected-text');
    const actionKey = ValueKey('protected-action');
    await tester.pumpWidget(
      MaterialApp(
        home: AuthMascotPeek(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Keep this message readable',
                  key: textKey,
                  style: TextStyle(
                    inherit: false,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
                TextButton(
                  key: actionKey,
                  onPressed: () => taps++,
                  child: const Text('Form action'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    Rect? previous;
    String? previousPose;
    final poses = <String>{};
    final messages = <String>{};
    final directions = <String>{};
    for (var turn = 0; turn < 8; turn++) {
      if (turn > 0) {
        await tester.pump(const Duration(seconds: 4));
        await tester.pump();
      }
      expect(mascot, findsOneWidget);
      final bounds = tester.getRect(mascot);
      final screen =
          Offset.zero &
          (tester.view.physicalSize / tester.view.devicePixelRatio);
      final face = Rect.fromLTRB(
        bounds.left + bounds.width * .22,
        bounds.top + bounds.height * .22,
        bounds.left + bounds.width * .80,
        bounds.top + bounds.height * .78,
      );
      expect(screen.contains(face.topLeft), isTrue);
      expect(screen.contains(face.bottomRight), isTrue);
      final image = tester.widget<Image>(
        find.descendant(of: mascot, matching: find.byType(Image)),
      );
      final pose = (image.image as AssetImage).assetName;
      poses.add(pose);
      final tip = tester.widget<AuthFeatureBubble>(
        find.byType(AuthFeatureBubble),
      );
      messages.add(tip.message);
      final bubbleBounds = tester.getRect(bubble);
      final viewport =
          Offset.zero &
          (tester.view.physicalSize / tester.view.devicePixelRatio);
      if (bounds.left < 0) directions.add('left');
      if (bounds.right > viewport.right) directions.add('right');
      if (bounds.top < 0) directions.add('top');
      if (bounds.bottom > viewport.bottom) directions.add('bottom');
      final words = find.descendant(of: bubble, matching: find.byType(Text));
      final paragraph = tester.renderObject<RenderParagraph>(words);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(
        bubbleBounds.deflate(7).contains(tester.getRect(words).topLeft),
        isTrue,
      );
      expect(
        bubbleBounds.deflate(7).contains(tester.getRect(words).bottomRight),
        isTrue,
      );
      expect(viewport.contains(bubbleBounds.topLeft), isTrue);
      expect(viewport.contains(bubbleBounds.bottomRight), isTrue);
      if (previous != null) expect(bounds.topLeft, isNot(previous.topLeft));
      if (previousPose != null) expect(pose, isNot(previousPose));
      for (final key in [textKey, actionKey]) {
        expect(bounds.overlaps(tester.getRect(find.byKey(key))), isFalse);
        expect(bubbleBounds.overlaps(tester.getRect(find.byKey(key))), isFalse);
      }
      previous = bounds;
      previousPose = pose;
    }
    expect(poses.length, greaterThanOrEqualTo(2));
    expect(messages.length, 5);
    expect(directions, containsAll(['left', 'right', 'top', 'bottom']));
    await tester.tap(find.text('Form action'));
    expect(taps, 1);
    await tester.pump(const Duration(milliseconds: 2800));
    expect(
      tester
          .widget<Opacity>(
            find.descendant(of: mascot, matching: find.byType(Opacity)),
          )
          .opacity,
      0,
    );
    expect(
      tester
          .widget<Opacity>(
            find.descendant(of: bubble, matching: find.byType(Opacity)),
          )
          .opacity,
      0,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Feature message fits even with different inherited typography', (
    tester,
  ) async {
    const message = 'Follow your ID journey step by step.';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DefaultTextStyle(
            style: const TextStyle(fontSize: 44, letterSpacing: 5, height: 2),
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.35)),
              child: Builder(
                builder: (context) {
                  final size = AuthFeatureBubble.measure(context, message, 182);
                  return Center(
                    child: SizedBox.fromSize(
                      size: size,
                      child: const AuthFeatureBubble(
                        message: message,
                        tail: AxisDirection.left,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    final words = find.text(message);
    final paragraph = tester.renderObject<RenderParagraph>(words);
    final card = tester.getRect(find.byType(AuthFeatureBubble));
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(card.deflate(7).contains(tester.getRect(words).topLeft), isTrue);
    expect(card.deflate(7).contains(tester.getRect(words).bottomRight), isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('No empty space means no mascot over the form', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AuthMascotPeek(child: TextField(expands: true, maxLines: null)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(mascot, findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('A narrow free strip cannot show a mascot without its bubble', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AuthMascotPeek(
            child: Row(
              children: [
                SizedBox(width: 140),
                Expanded(child: TextField(expands: true, maxLines: null)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(mascot, findsNothing);
    expect(bubble, findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Keyboard, large text and reduced motion hide peeks', (
    tester,
  ) async {
    for (final data in [
      const MediaQueryData(disableAnimations: true),
      const MediaQueryData(viewInsets: EdgeInsets.only(bottom: 280)),
      const MediaQueryData(textScaler: TextScaler.linear(2)),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: data,
            child: const AuthMascotPeek(child: Text('Form')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(mascot, findsNothing);
      expect(find.text('Form'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
