import 'package:build_up/core/utils/route_simplify.dart';
import 'package:build_up/features/step_tracking/presentation/providers/gps_tracking_provider.dart';
import 'package:build_up/features/step_tracking/presentation/screens/gps_tracking_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

Position _position(double lat, {double speed = 1.5}) => Position(
  latitude: lat,
  longitude: 67.0,
  timestamp: DateTime(2026, 10, 19),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: speed,
  speedAccuracy: 0,
);

/// A straight walk north, 2 m between fixes.
List<Position> _walk(int count) => [
  for (var i = 0; i < count; i++) _position(24.86 + i * 2 / 111320),
];

/// Never asks for location, so the screen can be pumped in tests.
class _QuietGpsNotifier extends GpsTrackingNotifier {
  _QuietGpsNotifier(super.ref, {super.routeSaver});

  @override
  Future<void> checkPermissionAndGetLocation() async {}

  /// Starts with a walk already recorded, without touching the GPS.
  @override
  Future<void> startTracking() async {
    state = state.copyWith(
      isTracking: true,
      recordedPositions: _walk(10),
      startTime: DateTime.now(),
    );
  }
}

Widget _screen(void Function(_QuietGpsNotifier) onCreated) => ProviderScope(
  overrides: [
    gpsTrackingProvider.overrideWith((ref) {
      final notifier = _QuietGpsNotifier(
        ref,
        routeSaver: (_, _) async => throw Exception('too big'),
      );
      onCreated(notifier);
      return notifier;
    }),
  ],
  child: const MaterialApp(home: GpsTrackingScreen()),
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('saveRoute', () {
    test('stores the thinned route', () async {
      List<Map<String, dynamic>>? stored;
      int? recorded;
      final container = ProviderContainer(
        overrides: [
          gpsTrackingProvider.overrideWith(
            (ref) => GpsTrackingNotifier(
              ref,
              routeSaver: (points, recordedCount) async {
                stored = points;
                recorded = recordedCount;
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final walk = _walk(1000);

      await container.read(gpsTrackingProvider.notifier).saveRoute(walk);

      expect(stored, [
        RoutePoint.fromPosition(walk.first).toMap(),
        RoutePoint.fromPosition(walk.last).toMap(),
      ]);
      expect(recorded, 1000);
      expect(container.read(gpsTrackingProvider).saveErrorMessage, isNull);
    });

    test('skips an empty route', () async {
      var calls = 0;
      final container = ProviderContainer(
        overrides: [
          gpsTrackingProvider.overrideWith(
            (ref) =>
                GpsTrackingNotifier(ref, routeSaver: (_, _) async => calls++),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(gpsTrackingProvider.notifier).saveRoute([]);

      expect(calls, 0);
    });

    test('says so when the save fails', () async {
      final container = ProviderContainer(
        overrides: [
          gpsTrackingProvider.overrideWith(
            (ref) => GpsTrackingNotifier(
              ref,
              routeSaver: (_, _) async => throw Exception('too big'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(gpsTrackingProvider.notifier).saveRoute(_walk(10));

      expect(
        container.read(gpsTrackingProvider).saveErrorMessage,
        routeSaveFailedMessage,
      );
    });
  });

  testWidgets('the GPS screen shows a failed save as a snackbar', (
    tester,
  ) async {
    late _QuietGpsNotifier notifier;
    await tester.pumpWidget(_screen((n) => notifier = n));
    await tester.pump();

    await notifier.saveRoute(_walk(10));
    await tester.pump();

    expect(find.text(routeSaveFailedMessage.toUpperCase()), findsOneWidget);
  });

  testWidgets('the workout summary shows a failed save', (tester) async {
    await tester.pumpWidget(_screen((_) {}));
    await tester.pump();

    await tester.tap(find.text('Start Route'));
    await tester.pump();
    await tester.tap(find.text('Stop Route'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Workout Complete'), findsOneWidget);
    expect(find.text(routeSaveFailedMessage), findsOneWidget);
    // Not also hidden behind the summary as a snackbar.
    expect(find.text(routeSaveFailedMessage.toUpperCase()), findsNothing);
  });
}
