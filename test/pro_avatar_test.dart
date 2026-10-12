import 'package:build_up/core/widgets/pro_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  Finder framePaint() => find.descendant(
    of: find.byType(ProAvatar),
    matching: find.byType(CustomPaint),
  );

  testWidgets('non-pro shows a plain avatar without the frame', (tester) async {
    await tester.pumpWidget(
      host(const ProAvatar(emojiAvatar: '🏃', isPro: false)),
    );

    expect(find.text('🏃'), findsOneWidget);
    expect(framePaint(), findsNothing);
  });

  testWidgets('pro shows the emoji inside the gold frame', (tester) async {
    await tester.pumpWidget(host(const ProAvatar(emojiAvatar: '🏃')));

    expect(find.text('🏃'), findsOneWidget);
    expect(
      tester.widget<CustomPaint>(framePaint()).foregroundPainter,
      isA<ProFramePainter>(),
    );
    expect(tester.getSize(find.byType(ProAvatar)), const Size(80, 80));
  });

  testWidgets('the frame is static, so nothing keeps ticking', (tester) async {
    await tester.pumpWidget(host(const ProAvatar(emojiAvatar: '🏃')));

    expect(tester.hasRunningAnimations, isFalse);
  });

  for (final radius in [22.0, 35.0, 45.0]) {
    testWidgets('lays out cleanly at radius $radius', (tester) async {
      await tester.pumpWidget(
        host(ProAvatar(emojiAvatar: '🏃', radius: radius)),
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(ProAvatar)),
        Size(radius * 2, radius * 2),
      );
    });
  }

  test('geometry scales with size and keeps minimums', () {
    final small = ProFramePainter.geometry(44);
    final large = ProFramePainter.geometry(96);

    expect(small.stroke, 3);
    expect(small.gap, 2);
    expect(small.gem, 8);
    expect(large.stroke, closeTo(96 * 0.055, 1e-9));
    expect(large.gem, closeTo(96 * 0.14, 1e-9));
    expect(ProFramePainter.avatarRadius(96), 48 - large.stroke - large.gap);
  });
}
