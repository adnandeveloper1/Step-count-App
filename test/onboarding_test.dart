import 'package:build_up/core/services/local_storage_service.dart';
import 'package:build_up/features/onboarding/onboarding_content.dart';
import 'package:build_up/features/onboarding/onboarding_provider.dart';
import 'package:build_up/features/onboarding/screens/onboarding_screen.dart';
import 'package:build_up/features/step_tracking/presentation/providers/step_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _FakeStorage extends LocalStorageService {
  bool seen = false;

  @override
  bool getOnboardingSeen() => seen;

  @override
  void saveOnboardingSeen(bool value) => seen = value;
}

Future<(ProviderContainer, _FakeStorage)> _pump(
  WidgetTester tester,
  Widget screen, {
  bool reducedMotion = false,
  double textScale = 1,
}) async {
  final storage = _FakeStorage();
  final container = ProviderContainer(
    overrides: [storageProvider.overrideWithValue(storage)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: reducedMotion,
            textScaler: TextScaler.linear(textScale),
          ),
          child: screen,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (container, storage);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final reducedMotion in [false, true]) {
    final label = reducedMotion ? ' (reduced motion)' : '';

    testWidgets('Next walks every page, then Get started finishes$label', (
      tester,
    ) async {
      final (container, storage) = await _pump(
        tester,
        const OnboardingScreen(),
        reducedMotion: reducedMotion,
      );
      for (var i = 0; i < onboardingPages.length - 1; i++) {
        expect(find.text('Next'), findsOneWidget);
        await tester.tap(find.byKey(const Key('onboarding_next')));
        await tester.pumpAndSettle();
      }
      expect(find.text('Get started'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding_next')));
      await tester.pumpAndSettle();
      expect(container.read(onboardingSeenProvider), isTrue);
      expect(storage.seen, isTrue);
    });
  }

  testWidgets('Skip finishes from the first page', (tester) async {
    final (container, _) = await _pump(tester, const OnboardingScreen());
    await tester.tap(find.byKey(const Key('onboarding_skip')));
    await tester.pumpAndSettle();
    expect(container.read(onboardingSeenProvider), isTrue);
  });

  testWidgets('Back button and phone back return to the previous page', (
    tester,
  ) async {
    await _pump(tester, const OnboardingScreen());
    expect(find.byKey(const Key('onboarding_back')), findsNothing);

    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    expect(find.text('Map your routes.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding_back')));
    await tester.pumpAndSettle();
    expect(find.text('Every step counts.'), findsOneWidget);
    expect(find.byKey(const Key('onboarding_back')), findsNothing);

    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Every step counts.'), findsOneWidget);
  });

  for (var i = 0; i < onboardingPages.length; i++) {
    testWidgets('page ${i + 1} fits a 360dp phone with 1.3x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await _pump(tester, OnboardingScreen(initialPage: i), textScale: 1.3);
      expect(tester.takeException(), isNull);
    });
  }
}
