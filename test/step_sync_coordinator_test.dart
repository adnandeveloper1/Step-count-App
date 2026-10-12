import 'dart:async';
import 'dart:isolate';

import 'package:build_up/core/services/step_sync_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

const _fast = Duration(milliseconds: 300);

/// Runs the background side in its own isolate, like the WorkManager engine.
Future<BackgroundSyncOutcome> backgroundRun({Duration hold = Duration.zero}) =>
    Isolate.run(
      () => StepSyncCoordinator.runInBackground(
        () => Future.delayed(hold),
        pingTimeout: _fast,
      ),
    );

/// A background isolate that takes storage and dies before releasing it.
Future<void> backgroundOwnerThatDies() => Isolate.run(() async {
  unawaited(
    StepSyncCoordinator.runInBackground(() => Completer<void>().future),
  );
  await Future.delayed(const Duration(milliseconds: 50));
});

void main() {
  tearDown(StepSyncCoordinator.clearForTest);

  group('background task', () {
    test('runs here when the app is not running', () async {
      expect(await backgroundRun(), BackgroundSyncOutcome.ranHere);
    });

    test(
      'hands the sync to the running app and leaves storage alone',
      () async {
        var syncs = 0;
        final claim = await StepSyncCoordinator.claimForApp(
          () async => syncs++,
        );
        addTearDown(claim.dispose);

        expect(await backgroundRun(), BackgroundSyncOutcome.delegatedToApp);
        await pumpEventQueue();
        expect(syncs, 1);
      },
    );

    test(
      'that found no app before its sensor read still hands off if the app started meanwhile',
      () async {
        // Quick check before the sensor read: no app yet.
        expect(
          await Isolate.run(
            () => StepSyncCoordinator.delegateToApp(timeout: _fast),
          ),
          isFalse,
        );
        // The user opens the app during the sensor read.
        final claim = await StepSyncCoordinator.claimForApp(() async {});
        addTearDown(claim.dispose);

        expect(await backgroundRun(), BackgroundSyncOutcome.delegatedToApp);
      },
    );

    test(
      'runs here when the app isolate died without releasing its claim',
      () async {
        await Isolate.run(() async {
          await StepSyncCoordinator.claimForApp(() async {});
        });

        final stopwatch = Stopwatch()..start();
        expect(await backgroundRun(), BackgroundSyncOutcome.ranHere);
        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
      },
    );

    test('runs here after the app releases its claim', () async {
      final claim = await StepSyncCoordinator.claimForApp(() async {});
      claim.dispose();
      expect(await backgroundRun(), BackgroundSyncOutcome.ranHere);
    });

    test('skips while another background task owns storage', () async {
      final first = backgroundRun(hold: const Duration(milliseconds: 600));
      await Future.delayed(const Duration(milliseconds: 200));

      expect(await backgroundRun(), BackgroundSyncOutcome.skippedBusy);
      expect(await first, BackgroundSyncOutcome.ranHere);
    });

    test('takes over from a background owner whose isolate died', () async {
      await backgroundOwnerThatDies();
      expect(await backgroundRun(), BackgroundSyncOutcome.ranHere);
    });

    test('quick check hands off to a running app', () async {
      final claim = await StepSyncCoordinator.claimForApp(() async {});
      addTearDown(claim.dispose);
      expect(
        await Isolate.run(
          () => StepSyncCoordinator.delegateToApp(timeout: _fast),
        ),
        isTrue,
      );
    });
  });

  group('app syncs for the background task', () {
    test(
      'a failing sync still keeps the background out and the next sync runs',
      () async {
        var calls = 0;
        final claim = await StepSyncCoordinator.claimForApp(() async {
          calls++;
          if (calls == 1) throw StateError('sensor read failed');
        });
        addTearDown(claim.dispose);

        expect(await backgroundRun(), BackgroundSyncOutcome.delegatedToApp);
        await pumpEventQueue();
        expect(await backgroundRun(), BackgroundSyncOutcome.delegatedToApp);
        await pumpEventQueue();
        expect(calls, 2);
      },
    );

    test('requests arriving while a sync is running join it', () async {
      var calls = 0;
      final inFlight = Completer<void>();
      final claim = await StepSyncCoordinator.claimForApp(() {
        calls++;
        return inFlight.future;
      });
      addTearDown(claim.dispose);

      expect(await Future.wait([backgroundRun(), backgroundRun()]), [
        BackgroundSyncOutcome.delegatedToApp,
        BackgroundSyncOutcome.delegatedToApp,
      ]);
      expect(calls, 1);

      inFlight.complete();
      await pumpEventQueue();
      await backgroundRun();
      await pumpEventQueue();
      expect(
        calls,
        2,
        reason: 'a request after the sync finished starts a new one',
      );
    });

    test(
      'a sync that throws synchronously does not block later syncs',
      () async {
        var calls = 0;
        final claim = await StepSyncCoordinator.claimForApp(() {
          calls++;
          throw StateError('thrown before any await');
        });
        addTearDown(claim.dispose);

        await backgroundRun();
        await pumpEventQueue();
        await backgroundRun();
        await pumpEventQueue();
        expect(calls, 2);
      },
    );
  });

  group('app start-up', () {
    test('does not wait when no background task owns storage', () async {
      final waited = Stopwatch()..start();
      final claim = await StepSyncCoordinator.claimForApp(
        () async {},
        pingTimeout: _fast,
      );
      addTearDown(claim.dispose);
      expect(waited.elapsedMilliseconds, lessThan(100));
    });

    test('waits while a background task owns storage', () async {
      final owner = backgroundRun(hold: const Duration(milliseconds: 600));
      await Future.delayed(const Duration(milliseconds: 200));

      final waited = Stopwatch()..start();
      final claim = await StepSyncCoordinator.claimForApp(
        () async {},
        pingTimeout: _fast,
      );
      addTearDown(claim.dispose);

      expect(
        waited.elapsedMilliseconds,
        greaterThan(250),
        reason: 'claimed while the owner still held storage',
      );
      expect(await owner, BackgroundSyncOutcome.ranHere);
    });

    test(
      'keeps waiting for a slow but live background owner past the ping timeout',
      () async {
        final owner = backgroundRun(hold: const Duration(milliseconds: 1500));
        await Future.delayed(const Duration(milliseconds: 200));

        final waited = Stopwatch()..start();
        final claim = await StepSyncCoordinator.claimForApp(
          () async {},
          pingTimeout: _fast,
        );
        addTearDown(claim.dispose);

        expect(waited.elapsedMilliseconds, greaterThan(1000));
        expect(await owner, BackgroundSyncOutcome.ranHere);
      },
    );

    test(
      'takes over quickly from a background owner whose isolate died',
      () async {
        await backgroundOwnerThatDies();

        final waited = Stopwatch()..start();
        final claim = await StepSyncCoordinator.claimForApp(
          () async {},
          pingTimeout: _fast,
        );
        addTearDown(claim.dispose);
        expect(waited.elapsed, lessThan(const Duration(seconds: 2)));
      },
    );
  });
}
