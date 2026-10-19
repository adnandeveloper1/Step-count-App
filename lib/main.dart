import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_sign_in/google_sign_in.dart' as g_sign_in;
import 'package:workmanager/workmanager.dart';
import 'app/app.dart';
import 'core/services/app_review_service.dart';
import 'core/services/background_step_save.dart';
import 'core/services/local_storage_service.dart';
import 'core/services/native_health_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/step_sync_coordinator.dart';
import 'core/services/widget_service.dart';
import 'core/utils/calorie_calculator.dart';
import 'core/utils/local_data_state.dart';
import 'core/utils/step_counter_math.dart';
import 'core/utils/step_history.dart';
import 'features/social/models/leaderboard_card.dart';
import 'features/step_tracking/presentation/providers/step_provider.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // The app is running in this process: it syncs with its own storage, so
    // this isolate must not open a second copy of the box.
    if (await StepSyncCoordinator.delegateToApp()) {
      return Future.value(true);
    }

    // Read the sensor before taking storage: it can take up to 30 s.
    final int hardwareSteps = await NativeHealthService().getHardwareSteps();
    // No sensor or no reading in time: keep what is stored and try next run.
    if (hardwareSteps <= 0) return Future.value(true);
    // Drives to remove from today's steps; empty without Play Services.
    final drives = await NativeHealthService().getDrives();
    if (needsDriveCheck(drives, DateTime.now())) {
      await NativeHealthService().checkStillDriving();
    }

    // The account the saved data belongs to, read before saving so a switch
    // during the run can't send it to another account's document.
    final uid = FirebaseAuth.instance.currentUser?.uid;

    // Checks again: the app may have started during the sensor read.
    BackgroundSyncResult? synced;
    final outcome = await StepSyncCoordinator.runInBackground(() async {
      synced = await saveStepsInBackground(
        hardwareSteps,
        drives: drives,
        readRecorded: NativeHealthService().getRecordedSteps,
      );
    });
    if (outcome != BackgroundSyncOutcome.ranHere) return Future.value(true);
    final result = synced;
    if (result == null) return Future.value(true);

    // The baseline now includes these drives, and their ids are stored.
    await NativeHealthService().removeDrives(result.appliedDriveIds);

    await WidgetService().updateWidgetData(
      steps: result.todaySteps,
      goal: result.goal,
      distance: result.distanceKm,
      calories: result.calories,
    );

    if (result.notifyGoal) {
      // A failed notification must not stop the Firestore sync below.
      try {
        final notifications = NotificationService();
        await notifications.init(requestPermission: false);
        await notifications.showGoalReached(result.todaySteps);
      } catch (_) {}
    }

    // Keeps vehicle detection registered even if the restart receiver
    // missed (e.g. the app was force-stopped before a reboot). After the
    // sensor read, so Play Services can't delay it.
    await NativeHealthService().startDriveDetection();
    // Keeps minute-by-minute step recording on for the activity screen.
    await NativeHealthService().startStepRecording();

    // 5. Silent Firebase Sync, only of data that is this account's: before
    // the app loads the account onto a fresh install, coins and steps here
    // start from 0 and would overwrite the real ones.
    if (uid != null &&
        localDataState(
              owner: result.dataOwner,
              uid: uid,
              hasLocalData: result.hadLocalData,
            ) !=
            LocalDataState.restore) {
      final now = DateTime.now();
      final firebaseDateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'currentCoins': result.coins,
        'weeklySteps': result.weekly,
        'lastUpdated': FieldValue.serverTimestamp(),
        'dailyHistory': {
          firebaseDateStr: result.todaySteps,
          // Steps from just before midnight can raise yesterday's total.
          dateKey(DateTime(now.year, now.month, now.day - 1)):
              ?result.yesterdaySteps,
          // Keep only the last 31 days in the cloud too.
          for (final key in expiredDayKeys(now)) key: FieldValue.delete(),
        },
      }, SetOptions(merge: true));

      // The Step Race reads today's steps from the public card. Only an
      // existing card is updated (a missing one fails): the app creates it
      // with the name and avatar on the next open.
      try {
        await FirebaseFirestore.instance
            .collection(leaderboardCollection)
            .doc(uid)
            .update(leaderboardDaySteps(result.todaySteps, now: now));
      } on FirebaseException catch (e) {
        debugPrint('Leaderboard card update failed: ${e.code}');
      }
    }

    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Claim storage first: waits for a background task that is saving, then
  // background tasks hand their sync to this isolate instead of opening the
  // box themselves. The sync waits for storage to open, since a request can
  // arrive first.
  final container = ProviderContainer();
  final storageReady = Completer<void>();
  final storageClaim = await StepSyncCoordinator.claimForApp(() async {
    await storageReady.future;
    await container
        .read(stepNotifierProvider.notifier)
        .syncFromBackgroundRequest();
  });
  try {
    await _startApp(container, storageReady);
  } catch (_) {
    // Without a running app, background tasks must save the steps themselves.
    storageClaim.dispose();
    rethrow;
  }
}

Future<void> _startApp(
  ProviderContainer container,
  Completer<void> storageReady,
) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Not awaited: ads load once it is ready and must not delay the app start.
  unawaited(MobileAds.instance.initialize());

  await NotificationService().init();
  // Housekeeping only: a failure here must not stop the app starting.
  try {
    await NotificationService().syncWalkReminder();
  } catch (_) {}

  await g_sign_in.GoogleSignIn.instance.initialize(
    serverClientId:
        '477084231873-0ehsragfu755ik8ijnh68pak6v36h2s3.apps.googleusercontent.com',
  );

  final storage = LocalStorageService();
  await storage.init();
  storageReady.complete();
  AppReviewService().recordLaunch();

  final int steps = storage.getSteps();
  final int goal = storage.getStepGoal();
  final double h = storage.getHeight();
  final double w = storage.getWeight();
  final double d = CalorieCalculator.distanceKm(steps, h);
  final double c = CalorieCalculator.calories(steps, heightCm: h, weightKg: w);

  final widgetService = WidgetService();
  await widgetService.updateWidgetData(
    steps: steps,
    goal: goal,
    distance: d,
    calories: c,
  );

  Workmanager().initialize(callbackDispatcher);
  Workmanager().registerPeriodicTask(
    "step_tracker_task_id",
    "process_background_steps",
    frequency: const Duration(minutes: 15),
  );

  runApp(
    UncontrolledProviderScope(container: container, child: const BuildUpApp()),
  );
}
