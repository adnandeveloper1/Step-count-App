import 'package:build_up/core/services/local_storage_service.dart';
import 'package:build_up/core/services/native_health_service.dart';
import 'package:build_up/features/step_tracking/presentation/widgets/background_access_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _FakeHealth extends NativeHealthService {
  final bool restricted;
  int asked = 0;

  _FakeHealth({required this.restricted});

  @override
  Future<bool> isBackgroundRestricted() async {
    asked++;
    return restricted;
  }
}

class _FakeStorage extends LocalStorageService {
  bool shown;

  _FakeStorage({this.shown = false});

  @override
  bool getBackgroundAccessPromptShown() => shown;

  @override
  void saveBackgroundAccessPromptShown(bool value) => shown = value;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const dialogKey = Key('background_access_dialog');

  Future<int> pumpAndPrompt(
    WidgetTester tester, {
    required NativeHealthService health,
    required LocalStorageService storage,
  }) async {
    var settingsOpened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showBackgroundAccessPromptIfNeeded(
              context,
              health: health,
              storage: storage,
              openSettings: () async {
                settingsOpened++;
                return true;
              },
            ),
            child: const Text('start'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
    if (find.byKey(dialogKey).evaluate().isNotEmpty) {
      await tester.tap(
        find.byKey(const Key('background_access_open_settings')),
      );
      await tester.pumpAndSettle();
    }
    return settingsOpened;
  }

  testWidgets('explains where to allow background use when Restricted', (
    tester,
  ) async {
    final storage = _FakeStorage();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showBackgroundAccessPromptIfNeeded(
              context,
              health: _FakeHealth(restricted: true),
              storage: storage,
              openSettings: () async => true,
            ),
            child: const Text('start'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();

    expect(find.byKey(dialogKey), findsOneWidget);
    expect(find.textContaining('Restricted'), findsWidgets);
    expect(find.textContaining('App battery usage'), findsWidgets);
    expect(storage.shown, isTrue);
  });

  testWidgets('Open settings opens the app settings and closes the message', (
    tester,
  ) async {
    final opened = await pumpAndPrompt(
      tester,
      health: _FakeHealth(restricted: true),
      storage: _FakeStorage(),
    );
    expect(opened, 1);
    expect(find.byKey(dialogKey), findsNothing);
  });

  testWidgets('shows nothing when background use is allowed', (tester) async {
    final storage = _FakeStorage();
    final opened = await pumpAndPrompt(
      tester,
      health: _FakeHealth(restricted: false),
      storage: storage,
    );
    expect(opened, 0);
    expect(storage.shown, isFalse);
  });

  testWidgets('shows the message only once', (tester) async {
    final health = _FakeHealth(restricted: true);
    final opened = await pumpAndPrompt(
      tester,
      health: health,
      storage: _FakeStorage(shown: true),
    );
    expect(opened, 0);
    expect(health.asked, 0);
  });
}
