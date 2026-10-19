import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:build_up/core/notification_provider/notification_provider.dart';
import 'package:build_up/core/services/account_session.dart';
import 'package:build_up/core/services/local_storage_service.dart';
import 'package:build_up/core/services/native_health_service.dart';
import 'package:build_up/core/services/notification_service.dart';
import 'package:build_up/core/services/widget_service.dart';
import 'package:build_up/core/utils/activity_log.dart';
import 'package:build_up/core/utils/step_counter_math.dart';
import 'package:build_up/features/social/presentation/providers/challenge_provider.dart'
    show ChallengeItem, ChallengeNotifier, challengeProvider;
import 'package:build_up/features/step_tracking/data/step_cloud.dart';
import 'package:build_up/features/step_tracking/presentation/providers/step_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// The step counter: [steps] since boot, or -1 without a sensor. [hold]
/// keeps the read waiting, as the real one can for up to 30 s.
class _FakeSensor extends Fake implements NativeHealthService {
  int steps = 0;
  List<Drive> drives = const [];
  Completer<void>? hold;
  final removed = <List<int>>[];
  int driveDetectionStarts = 0;
  int recordingStarts = 0;

  /// Recording on since midnight with no walking seen, unless set.
  RecordedSteps? Function(DateTime day)? recording;
  int recordingReads = 0;
  Completer<void>? recordingHold;

  @override
  Future<int> getHardwareSteps() async {
    await hold?.future;
    return steps;
  }

  @override
  Future<List<Drive>> getDrives() async => drives;

  @override
  Future<void> checkStillDriving() async {}

  @override
  Future<void> removeDrives(List<int> ids) async => removed.add(ids);

  @override
  Future<bool> startDriveDetection() async {
    driveDetectionStarts++;
    return true;
  }

  @override
  Future<bool> startStepRecording() async {
    recordingStarts++;
    return true;
  }

  @override
  Future<RecordedSteps?> getRecordedSteps(DateTime day) async {
    recordingReads++;
    await recordingHold?.future;
    final midnight = DateTime(day.year, day.month, day.day);
    return (recording ??
        (_) =>
            RecordedSteps(since: midnight, until: day, minutes: const []))(day);
  }
}

class _FakeNotifications extends Fake implements NotificationService {
  final goalReached = <int>[];

  @override
  Future<void> showGoalReached(int steps) async => goalReached.add(steps);
}

class _FakeWidget extends Fake implements WidgetService {
  final steps = <int>[];

  @override
  Future<void> updateWidgetData({
    required int steps,
    required int goal,
    required double distance,
    required double calories,
  }) async => this.steps.add(steps);
}

typedef _Day = ({
  DateTime day,
  int steps,
  int? yesterdaySteps,
  int coins,
  List<int> weekly,
  String league,
});

class _FakeCloud implements StepCloud {
  @override
  bool isSignedIn = true;

  final coins = <int>[];
  final days = <_Day>[];
  final bodies = <(double, double)>[];
  final goals = <int>[];
  final deletedDays = <List<String>>[];
  final bests = <int>[];

  /// The account's document for [load]; an error to throw instead.
  Map<String, dynamic>? account;
  Object? loadError;
  Completer<void>? loadHold;

  /// The best the account keeps (see saveMonthlyBest); an error to throw.
  int Function(int localBest) keepBest = (local) => local;
  Object? bestError;

  @override
  void saveCoins(int coins) => this.coins.add(coins);

  @override
  void saveDay({
    required DateTime day,
    required int steps,
    required int? yesterdaySteps,
    required int coins,
    required List<int> weekly,
    required String league,
  }) => days.add((
    day: day,
    steps: steps,
    yesterdaySteps: yesterdaySteps,
    coins: coins,
    weekly: weekly,
    league: league,
  ));

  @override
  void saveBody({required double height, required double weight}) =>
      bodies.add((height, weight));

  @override
  void saveGoal(int goal) => goals.add(goal);

  @override
  Future<int?> saveMonthlyBest({
    required int localBest,
    required String league,
    required DateTime now,
  }) async {
    if (bestError != null) throw bestError!;
    final best = keepBest(localBest);
    bests.add(best);
    return best;
  }

  @override
  Future<Map<String, dynamic>?> load() async {
    await loadHold?.future;
    if (loadError != null) throw loadError!;
    return account;
  }

  @override
  void deleteHistoryDays(List<String> days) => deletedDays.add(days);
}

/// Active challenges that take [coinsPerCredit] coins' worth of steps.
class _FakeChallenges extends ChallengeNotifier {
  final credited = <int>[];
  int coinsPerCredit = 0;
  int syncs = 0;

  @override
  List<ChallengeItem> build() => const [];

  @override
  int addStepsToActiveChallenges(int stepsDelta) {
    credited.add(stepsDelta);
    return coinsPerCredit;
  }

  @override
  Future<void> syncWithFirestore() async => syncs++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Wednesday 14 October 2026, mid-morning.
  final wednesday = DateTime(2026, 10, 14, 10);

  late Directory dir;
  late Box box;
  late DateTime clock;
  late _FakeSensor sensor;
  late _FakeCloud cloud;
  late _FakeNotifications notifications;
  late _FakeWidget widget;
  late _FakeChallenges challenges;
  late bool permissionGranted;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('step_notifier_test');
    Hive.init(dir.path);
    box = await Hive.openBox('buildUpData');
    clock = wednesday;
    sensor = _FakeSensor();
    cloud = _FakeCloud();
    notifications = _FakeNotifications();
    widget = _FakeWidget();
    challenges = _FakeChallenges();
    permissionGranted = true;
    AccountSession.deleting = false;
  });

  tearDown(() async {
    AccountSession.deleting = false;
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        storageProvider.overrideWithValue(LocalStorageService()),
        stepCloudProvider.overrideWithValue(cloud),
        clockProvider.overrideWithValue(() => clock),
        activityPermissionProvider.overrideWithValue(
          () async => permissionGranted,
        ),
        nativeHealthProvider.overrideWithValue(sensor),
        notificationServiceProvider.overrideWithValue(notifications),
        widgetServiceProvider.overrideWithValue(widget),
        challengeProvider.overrideWith(() => challenges),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Today as an earlier sync left it: [steps] counted from the sensor
  /// reading [baseline], at [syncedAt].
  Future<void> seed({
    required int steps,
    int baseline = 1000,
    String lastDate = '2026-10-14',
    DateTime? syncedAt,
    int coins = 0,
    int goal = 10000,
    Map<String, int>? history,
  }) async {
    await box.putAll({
      'lastDate': lastDate,
      'currentSteps': steps,
      'hardwareBaseline': baseline,
      'lastCoinStep': (steps ~/ 100) * 100,
      'coins': coins,
      'stepGoal': goal,
      'challengeCreditedSteps': steps,
      'lastSyncMs': (syncedAt ?? wednesday).millisecondsSinceEpoch,
      'dailyHistory': '{"$lastDate":$steps}',
    });
    if (history != null) {
      LocalStorageService().saveDailyHistory(history);
    }
  }

  /// One sensor read, as the minute poll or a background task's request.
  Future<StepState> read(ProviderContainer c, int sensorSteps) async {
    sensor.steps = sensorSteps;
    await c.read(stepNotifierProvider.notifier).syncFromBackgroundRequest();
    return c.read(stepNotifierProvider);
  }

  group('on start', () {
    test('shows today\'s saved steps, coins and goal', () async {
      await seed(steps: 4200, coins: 42, goal: 8000);

      final state = container().read(stepNotifierProvider);

      expect(state.currentSteps, 4200);
      expect(state.coins, 42);
      expect(state.goalSteps, 8000);
      expect(state.distanceKm, greaterThan(0));
    });

    test('steps saved on an earlier day show as 0 today', () async {
      await seed(steps: 9000, lastDate: '2026-10-13', coins: 90);

      final state = container().read(stepNotifierProvider);

      expect(state.currentSteps, 0);
      expect(state.coins, 90);
    });
  });

  group('a sensor read', () {
    test('saves today\'s steps and shows them', () async {
      await seed(steps: 4200);
      final c = container();

      final state = await read(c, 1000 + 4500);

      expect(state.currentSteps, 4500);
      expect(box.get('currentSteps'), 4500);
      expect(LocalStorageService().getDailyHistory()['2026-10-14'], 4500);
      expect(widget.steps.last, 4500);
      // Wednesday is the third day of the week.
      expect(state.weeklySteps[2], 4500);
    });

    test('gives 1 coin per 100 steps, once', () async {
      await seed(steps: 4200, coins: 42);
      final c = container();

      await read(c, 1000 + 4450);
      expect(c.read(stepNotifierProvider).coins, 44);

      // The same count again earns nothing more.
      await read(c, 1000 + 4450);
      expect(c.read(stepNotifierProvider).coins, 44);
      expect(box.get('coins'), 44);
      expect(cloud.coins.last, 44);
    });

    test('notifies the goal once a day', () async {
      await seed(steps: 9900, goal: 10000);
      final c = container();

      await read(c, 1000 + 10050);
      await read(c, 1000 + 10400);

      expect(notifications.goalReached, [10050]);
    });

    test('without a sensor says so and saves nothing', () async {
      await seed(steps: 4200);
      final c = container();

      final state = await read(c, -1);

      expect(state.pedestrianStatus, 'No Sensor Detected');
      expect(state.currentSteps, 4200);
      expect(cloud.days, isEmpty);
    });

    test('a sensor that returned nothing in time changes nothing', () async {
      await seed(steps: 4200);
      final c = container();

      final state = await read(c, -2);

      expect(state.currentSteps, 4200);
      expect(box.get('currentSteps'), 4200);
      expect(cloud.days, isEmpty);
    });

    test('a sign-out during the read writes nothing back', () async {
      await seed(steps: 4200, coins: 42);
      final c = container();
      sensor
        ..steps = 1000 + 6000
        ..hold = Completer();

      final reading = c
          .read(stepNotifierProvider.notifier)
          .syncFromBackgroundRequest();
      AccountSession.end();
      sensor.hold!.complete();
      await reading;

      expect(box.get('currentSteps'), 4200);
      expect(box.get('coins'), 42);
      expect(cloud.days, isEmpty);
      expect(cloud.coins, isEmpty);
    });

    test('takes out steps counted in a vehicle and clears the drive', () async {
      await seed(steps: 4200);
      final c = container();
      // A finished 3000-step drive since the last sync.
      sensor.drives = const [
        Drive(id: 7, enterSteps: 1000 + 4300, exitSteps: 1000 + 7300),
      ];

      final state = await read(c, 1000 + 7500);

      expect(state.currentSteps, 4500);
      expect(state.drivingSteps, 3000);
      expect(sensor.removed.last, [7]);
    });

    test('takes out vehicle bumps from before a ride was noticed', () async {
      // Synced at 10:00 (sensor 5200). The ride was noticed at 12:00 after
      // 140 steps the recording did not see as walking, held 358, and
      // ended at 12:09; 17 steps since.
      await seed(steps: 4200);
      await box.put('lastSyncReading', 5200);
      final c = container();
      sensor.drives = [
        Drive(
          id: 7,
          enterSteps: 5340,
          exitSteps: 5698,
          enteredAt: wednesday.add(const Duration(hours: 2)),
          exitedAt: wednesday.add(const Duration(hours: 2, minutes: 9)),
        ),
      ];
      clock = wednesday.add(const Duration(hours: 2, minutes: 18));

      final state = await read(c, 5715);

      expect(state.currentSteps, 4200 + 17);
      expect(state.drivingSteps, 358 + 140);
      expect(box.get('currentSteps'), 4200 + 17);
      expect(widget.steps.last, 4200 + 17);
      final day = LocalStorageService().getActivityLog().day(wednesday);
      expect(day.rides.single.notCounted, 358 + 140);
    });

    test('two reads at once take the bumps out once', () async {
      await seed(steps: 4200);
      await box.put('lastSyncReading', 5200);
      final c = container();
      sensor.drives = [
        Drive(
          id: 7,
          enterSteps: 5340,
          exitSteps: 5698,
          enteredAt: wednesday.add(const Duration(hours: 2)),
          exitedAt: wednesday.add(const Duration(hours: 2, minutes: 9)),
        ),
      ];
      clock = wednesday.add(const Duration(hours: 2, minutes: 18));
      sensor.steps = 5715;
      sensor.recordingHold = Completer();
      final notifier = c.read(stepNotifierProvider.notifier);

      // The minute poll and a background request, both waiting on the
      // recording.
      final first = notifier.syncFromBackgroundRequest();
      final second = notifier.syncFromBackgroundRequest();
      await Future<void>.delayed(Duration.zero);
      sensor.recordingHold!.complete();
      await Future.wait([first, second]);

      expect(c.read(stepNotifierProvider).currentSteps, 4200 + 17);
      expect(box.get('currentSteps'), 4200 + 17);
      expect(
        LocalStorageService()
            .getActivityLog()
            .day(wednesday)
            .rides
            .single
            .bumps,
        140,
      );
    });

    test('reads the step recording only with a stretch to check', () async {
      await seed(steps: 4200);
      final c = container();
      await read(c, 1000 + 4300);
      expect(sensor.recordingReads, 0);
    });

    test('adds new steps to active challenges and pays their coins', () async {
      await seed(steps: 4200, coins: 42);
      final c = container();
      challenges.coinsPerCredit = 15;

      final state = await read(c, 1000 + 4300);

      expect(challenges.credited, [100]);
      // 15 from the challenge, 1 for the 100 steps.
      expect(state.coins, 58);
    });
  });

  group('sending steps to the account', () {
    test('the first read since the app started is sent', () async {
      await seed(steps: 4200);
      final c = container();

      await read(c, 1000 + 4250);

      expect(cloud.days.single.steps, 4250);
      expect(cloud.days.single.day, DateTime(2026, 10, 14));
    });

    test('then once 500 more steps were taken', () async {
      await seed(steps: 4200);
      final c = container();
      await read(c, 1000 + 4250);

      await read(c, 1000 + 4600);
      expect(cloud.days, hasLength(1));

      await read(c, 1000 + 4750);
      expect(cloud.days.map((d) => d.steps), [4250, 4750]);
    });

    test('leaving the app sends what is new', () async {
      await seed(steps: 4200);
      final c = container();
      await read(c, 1000 + 4250);
      await read(c, 1000 + 4300);

      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
      addTearDown(
        () => TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );

      expect(cloud.days.map((d) => d.steps), [4250, 4300]);
    });

    test(
      'after midnight today is sent though yesterday had more steps',
      () async {
        // Tuesday ended at 12,000 with the app open.
        clock = DateTime(2026, 10, 13, 23);
        await seed(
          steps: 12000,
          lastDate: '2026-10-13',
          syncedAt: DateTime(2026, 10, 13, 23),
        );
        final c = container();
        await read(c, 1000 + 12000);
        expect(cloud.days.last.steps, 12000);

        // 600 steps walked between 23:00 and 01:00: half on each day.
        clock = DateTime(2026, 10, 14, 1);
        final state = await read(c, 1000 + 12600);

        expect(state.currentSteps, 300);
        final sent = cloud.days.last;
        expect(sent.day, DateTime(2026, 10, 14));
        expect(sent.steps, 300);
        expect(sent.yesterdaySteps, 12300);
      },
    );

    test('a read the app is told about mid-deletion writes nothing', () async {
      await seed(steps: 4200, coins: 42);
      final c = container();
      AccountSession.deleting = true;

      await read(c, 1000 + 4800);

      expect(cloud.days, isEmpty);
      expect(cloud.coins, isEmpty);
    });
  });

  group('coins', () {
    test('added coins are saved', () async {
      await seed(steps: 0, coins: 10);
      final c = container();

      c.read(stepNotifierProvider.notifier).addCoins(50);

      expect(c.read(stepNotifierProvider).coins, 60);
      expect(box.get('coins'), 60);
      expect(cloud.coins, [60]);
    });

    test('spending more than there is spends nothing', () async {
      await seed(steps: 0, coins: 26);
      final c = container();

      expect(c.read(stepNotifierProvider.notifier).deductCoins(500), isFalse);

      expect(c.read(stepNotifierProvider).coins, 26);
      expect(cloud.coins, isEmpty);
    });

    test('spending what there is takes it off', () async {
      await seed(steps: 0, coins: 600);
      final c = container();

      expect(c.read(stepNotifierProvider.notifier).deductCoins(500), isTrue);

      expect(box.get('coins'), 100);
      expect(cloud.coins, [100]);
    });
  });

  group('profile', () {
    test(
      'a new goal is saved on the phone, the widget and the account',
      () async {
        await seed(steps: 4200);
        final c = container();

        c.read(stepNotifierProvider.notifier).updateGoal(8000);

        expect(c.read(stepNotifierProvider).goalSteps, 8000);
        expect(box.get('stepGoal'), 8000);
        expect(cloud.goals, [8000]);
        expect(widget.steps.last, 4200);
      },
    );

    test('new body values recalculate distance and calories', () async {
      await seed(steps: 4200);
      final c = container();
      final before = c.read(stepNotifierProvider);

      c.read(stepNotifierProvider.notifier).updateProfile(190, 95);

      final after = c.read(stepNotifierProvider);
      expect(after.distanceKm, greaterThan(before.distanceKm));
      expect(after.calories, greaterThan(before.calories));
      expect(cloud.bodies, [(190.0, 95.0)]);
    });
  });

  group('monthly best', () {
    test('a higher best on the account becomes the phone\'s', () async {
      await seed(steps: 4200);
      // Before a reinstall the account had 15,000 this month.
      cloud.keepBest = (local) => local > 15000 ? local : 15000;
      final c = container();

      await read(c, 1000 + 4300);
      await pumpEventQueue();

      expect(box.get('monthlyHighScore'), 15000);
    });

    test('a failed save is tried again on the next read', () async {
      await seed(steps: 4200);
      cloud.bestError = Exception('offline');
      final c = container();
      await read(c, 1000 + 4300);
      await pumpEventQueue();
      expect(cloud.bests, isEmpty);

      cloud.bestError = null;
      await read(c, 1000 + 4400);
      await pumpEventQueue();

      expect(cloud.bests, [4400]);
    });
  });

  group('signing in on this phone', () {
    test('loads the account and drops cloud days older than 31', () async {
      cloud.account = {
        'stepGoal': 9000,
        'currentCoins': 300,
        'height': 182,
        'weight': 80.5,
        'dailyHistory': {'2026-10-14': 3100, '2026-08-01': 5000},
      };
      final c = container();

      await c.read(stepNotifierProvider.notifier).restoreDataFromFirebase();

      final state = c.read(stepNotifierProvider);
      expect(state.currentSteps, 3100);
      expect(state.coins, 300);
      expect(state.goalSteps, 9000);
      expect(state.height, 182);
      expect(cloud.deletedDays.single, ['2026-08-01']);
      expect(challenges.syncs, 1);
    });

    test('an account without a document changes nothing', () async {
      await seed(steps: 0, coins: 5);
      final c = container();

      await c.read(stepNotifierProvider.notifier).restoreDataFromFirebase();

      expect(c.read(stepNotifierProvider).coins, 5);
      expect(challenges.syncs, 0);
    });

    test(
      'an account that can\'t be read fails, so it is tried again',
      () async {
        cloud.loadError = Exception('offline');
        final c = container();

        expect(
          c.read(stepNotifierProvider.notifier).restoreDataFromFirebase(),
          throwsException,
        );
      },
    );

    test('a sign-out during the load keeps nothing', () async {
      await seed(steps: 0, coins: 5);
      cloud
        ..account = {'currentCoins': 300}
        ..loadHold = Completer();
      final c = container();

      final restoring = c
          .read(stepNotifierProvider.notifier)
          .restoreDataFromFirebase();
      AccountSession.end();
      cloud.loadHold!.complete();
      await restoring;

      expect(box.get('coins'), 5);
      expect(challenges.syncs, 0);
    });
  });

  group('pull to refresh', () {
    test('takes the account\'s coins, stored as a decimal or not', () async {
      await seed(steps: 4200, coins: 42);
      cloud.account = {'currentCoins': 120.0};
      final c = container();

      await c.read(stepNotifierProvider.notifier).forceRefresh();

      expect(c.read(stepNotifierProvider).coins, 120);
      expect(box.get('coins'), 120);
    });

    test('offline keeps the phone\'s coins and still reads steps', () async {
      await seed(steps: 4200, coins: 42);
      cloud.loadError = Exception('offline');
      sensor.steps = 1000 + 4250;
      final c = container();

      await c.read(stepNotifierProvider.notifier).forceRefresh();

      final state = c.read(stepNotifierProvider);
      expect(state.coins, 42);
      expect(state.currentSteps, 4250);
    });
  });

  group('starting tracking', () {
    test('without the activity permission says so', () async {
      await seed(steps: 4200);
      permissionGranted = false;
      final c = container();

      await c.read(stepNotifierProvider.notifier).initializeTracking();

      expect(
        c.read(stepNotifierProvider).pedestrianStatus,
        'Permission Denied',
      );
      expect(sensor.driveDetectionStarts, 0);
    });

    test('with it starts the drive and step recording, then reads', () async {
      await seed(steps: 4200);
      sensor.steps = 1000 + 4300;
      final c = container();

      await c.read(stepNotifierProvider.notifier).initializeTracking();

      expect(sensor.driveDetectionStarts, 1);
      expect(sensor.recordingStarts, 1);
      expect(c.read(stepNotifierProvider).currentSteps, 4300);
    });
  });

  group('the goal ad', () {
    test('fills today up to the goal without paying coins for it', () async {
      await seed(steps: 4200, coins: 42, goal: 8000);
      sensor.steps = 1000 + 4200;
      final c = container();
      final notifier = c.read(stepNotifierProvider.notifier);

      expect(await notifier.canFillStepsToGoal(), isTrue);
      expect(await notifier.fillStepsToGoal(), isTrue);

      final state = c.read(stepNotifierProvider);
      expect(state.currentSteps, 8000);
      expect(state.coins, 42);
      expect(cloud.days.last.steps, 8000);
    });

    test('is not offered once the goal is reached', () async {
      await seed(steps: 9000, goal: 8000);
      sensor.steps = 1000 + 9000;
      final c = container();

      expect(
        await c.read(stepNotifierProvider.notifier).canFillStepsToGoal(),
        isFalse,
      );
    });

    test('fills nothing when today\'s steps can\'t be read', () async {
      await seed(steps: 4000, lastDate: '2026-10-13', goal: 8000);
      sensor.steps = -1;
      final c = container();

      expect(
        await c.read(stepNotifierProvider.notifier).fillStepsToGoal(),
        isFalse,
      );
      expect(c.read(stepNotifierProvider).currentSteps, 0);
    });
  });
}
