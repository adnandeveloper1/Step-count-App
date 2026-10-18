import 'dart:async';

import 'package:build_up/features/settings/presentation/edit_profile_screen.dart';
import 'package:build_up/features/step_tracking/presentation/providers/step_provider.dart';
import 'package:flutter/material.dart' hide StepState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

// Values already on the phone, different from StepState's 170 cm / 70 kg
// defaults so a test can tell them apart.
class _FakeStepNotifier extends StepNotifier {
  final profiles = <(double, double)>[];
  final goals = <int>[];

  @override
  StepState build() => const StepState(
    currentSteps: 0,
    height: 181,
    weight: 82.5,
    goalSteps: 8000,
    calories: 0,
    distanceKm: 0,
    isRestMode: false,
    coins: 0,
  );

  // No Firebase in tests.
  @override
  void updateProfile(double height, double weight) {
    profiles.add((height, weight));
    state = state.copyWith(height: height, weight: weight);
  }

  @override
  void updateGoal(int newGoal) {
    goals.add(newGoal);
    state = state.copyWith(goalSteps: newGoal);
  }
}

class _FakeProfileCloud implements ProfileCloud {
  Future<Map<String, dynamic>?> Function() onLoad = () async => null;
  Future<void> Function(String name) onRename = (_) async {};
  final saved = <Map<String, dynamic>>[];
  final renames = <String>[];

  @override
  String? get displayName => 'Moiz';

  @override
  Future<Map<String, dynamic>?> load() => onLoad();

  @override
  void save(Map<String, dynamic> data) => saved.add(data);

  @override
  Future<void> updateDisplayName(String name) {
    renames.add(name);
    return onRename(name);
  }
}

final _name = find.byKey(const Key('profile.name'));
final _goal = find.byKey(const Key('profile.goal'));
final _weight = find.byKey(const Key('profile.weight'));
final _height = find.byKey(const Key('profile.height'));
final _bodyFat = find.byKey(const Key('profile.bodyFat'));
final _save = find.byKey(const Key('profile.save'));

String _text(WidgetTester tester, Finder field) => tester
    .widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    )
    .controller
    .text;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late _FakeProfileCloud cloud;
  late _FakeStepNotifier steps;
  late GlobalKey<NavigatorState> navigator;

  // Opens the screen on top of a home page, as Settings does, so Save can
  // close it.
  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    navigator = GlobalKey<NavigatorState>();
    final container = ProviderContainer(
      overrides: [
        profileCloudProvider.overrideWithValue(cloud),
        stepNotifierProvider.overrideWith(() => steps = _FakeStepNotifier()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: Text('home')),
        ),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const EditProfileScreen()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.ensureVisible(_save);
    await tester.tap(_save);
    await tester.pump();
  }

  setUp(() => cloud = _FakeProfileCloud());

  group('prefill when the account can not be read (offline)', () {
    setUp(() => cloud.onLoad = () => Future.error(Exception('offline')));

    testWidgets('shows the goal, weight and height saved on the phone', (
      tester,
    ) async {
      await open(tester);

      expect(_text(tester, _goal), '8000');
      expect(_text(tester, _weight), '82.5');
      expect(_text(tester, _height), '181');
    });

    testWidgets('Save keeps the phone values, not 70 kg / 170 cm', (
      tester,
    ) async {
      await open(tester);
      await tapSave(tester);
      await tester.pumpAndSettle();

      expect(steps.profiles.last, (181.0, 82.5));
      expect(steps.goals.last, 8000);
    });

    testWidgets('a field left blank keeps its saved value', (tester) async {
      await open(tester);
      await tester.enterText(_weight, '');
      await tester.enterText(_height, '');
      await tester.enterText(_goal, '');
      await tapSave(tester);
      await tester.pumpAndSettle();

      expect(steps.profiles, isEmpty);
      expect(steps.goals, isEmpty);
      expect(cloud.saved.single.containsKey('bodyFat'), isFalse);
    });
  });

  testWidgets('the account values replace the phone ones once loaded', (
    tester,
  ) async {
    cloud.onLoad = () async => {'weight': 79, 'height': 183, 'bodyFat': 18};
    await open(tester);

    expect(_text(tester, _weight), '79');
    expect(_text(tester, _height), '183');
    expect(_text(tester, _bodyFat), '18');
  });

  testWidgets('a late account answer does not undo what the user typed', (
    tester,
  ) async {
    final answer = Completer<Map<String, dynamic>?>();
    cloud.onLoad = () => answer.future;
    await open(tester);

    await tester.enterText(_weight, '90');
    answer.complete({'weight': 79, 'height': 183});
    await tester.pumpAndSettle();

    expect(_text(tester, _weight), '90');
    expect(_text(tester, _height), '183');
  });

  group('Save does not wait for the server', () {
    testWidgets('closes the screen while the account write is pending', (
      tester,
    ) async {
      cloud.onLoad = () => Completer<Map<String, dynamic>?>().future;
      await open(tester);
      await tester.enterText(_weight, '80');
      await tapSave(tester);
      await tester.pumpAndSettle();

      expect(find.byType(EditProfileScreen), findsNothing);
      expect(find.text('PROFILE UPDATED'), findsOneWidget);
      expect(steps.profiles.last, (181.0, 80.0));
      expect(cloud.saved.single['avatarUrl'], isNotNull);
    });

    testWidgets('an unchanged name is not sent to sign-in', (tester) async {
      cloud.onRename = (_) => Completer<void>().future;
      await open(tester);
      await tapSave(tester);
      await tester.pumpAndSettle();

      expect(cloud.renames, isEmpty);
      expect(find.byType(EditProfileScreen), findsNothing);
    });

    testWidgets('a failed name change says so and keeps the screen open', (
      tester,
    ) async {
      cloud.onRename = (_) => Future.error(Exception('network-request-failed'));
      await open(tester);
      await tester.enterText(_name, 'New Name');
      await tester.enterText(_weight, '80');
      await tapSave(tester);
      await tester.pumpAndSettle();

      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('NAME NOT CHANGED'), findsOneWidget);
      // Everything else is still saved, and the account keeps its old name.
      expect(steps.profiles.last, (181.0, 80.0));
      expect(cloud.saved.any((d) => d.containsKey('name')), isFalse);
    });

    testWidgets('a name change that never answers stops the spinner', (
      tester,
    ) async {
      cloud.onRename = (_) => Completer<void>().future;
      await open(tester);
      await tester.enterText(_name, 'New Name');
      await tapSave(tester);
      await tester.pump(const Duration(seconds: 20));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('NAME NOT CHANGED'), findsOneWidget);
    });

    testWidgets('a changed name is saved to sign-in and the account', (
      tester,
    ) async {
      await open(tester);
      await tester.enterText(_name, '  New Name ');
      await tapSave(tester);
      await tester.pumpAndSettle();

      expect(cloud.renames, ['New Name']);
      expect(cloud.saved.last, {'name': 'New Name'});
      expect(find.byType(EditProfileScreen), findsNothing);
    });
  });

  group('ranges', () {
    for (final (field, label, bad, error) in [
      (_goal, 'goal', '0', 'Enter 500 to 100,000 steps'),
      (_goal, 'goal', '-5', 'Enter 500 to 100,000 steps'),
      (_goal, 'goal', '200000', 'Enter 500 to 100,000 steps'),
      (_goal, 'goal', '9.5', 'Enter 500 to 100,000 steps'),
      (_weight, 'weight', '0', 'Enter 20 to 300 kg'),
      (_weight, 'weight', '900', 'Enter 20 to 300 kg'),
      (_weight, 'weight', 'abc', 'Enter 20 to 300 kg'),
      (_height, 'height', '0', 'Enter 50 to 250 cm'),
      (_height, 'height', '400', 'Enter 50 to 250 cm'),
      (_bodyFat, 'body fat', '0', 'Enter 2 to 70 %'),
      (_bodyFat, 'body fat', '95', 'Enter 2 to 70 %'),
    ]) {
      testWidgets('$label "$bad" shows an error while typing and blocks Save', (
        tester,
      ) async {
        await open(tester);
        await tester.enterText(field, bad);
        await tester.pump();

        expect(find.text(error), findsOneWidget);

        await tapSave(tester);
        await tester.pumpAndSettle();

        expect(find.byType(EditProfileScreen), findsOneWidget);
        expect(steps.profiles, isEmpty);
        expect(steps.goals, isEmpty);
        expect(cloud.saved, isEmpty);
      });
    }

    testWidgets('values at the edges are accepted', (tester) async {
      await open(tester);
      await tester.enterText(_goal, '100000');
      await tester.enterText(_weight, '20');
      await tester.enterText(_height, '250');
      await tester.enterText(_bodyFat, '70');
      await tapSave(tester);
      await tester.pumpAndSettle();

      expect(steps.goals.last, 100000);
      expect(steps.profiles.last, (250.0, 20.0));
      expect(cloud.saved.single['bodyFat'], 70.0);
    });
  });

  testWidgets('leaving before the account answers does not throw', (
    tester,
  ) async {
    final answer = Completer<Map<String, dynamic>?>();
    cloud.onLoad = () => answer.future;
    await open(tester);

    // A caught setState error would only reach the log.
    final logs = <String?>[];
    final print = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message);
    try {
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      answer.complete({
        'avatarUrl': '🦊',
        'weight': 79,
        'proAvatarEquipped': true,
      });
      await tester.pumpAndSettle();
    } finally {
      debugPrint = print;
    }

    expect(tester.takeException(), isNull);
    expect(logs, isEmpty);
  });
}
