import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart' as g_sign_in;
import 'package:health/health.dart';
import 'package:workmanager/workmanager.dart';
import 'app/app.dart';
import 'core/services/local_storage_service.dart';
import 'core/services/native_health_service.dart';
import 'core/services/widget_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();

    final storage = LocalStorageService();
    await storage.init();
    final now = DateTime.now();

    int hardwareSteps = 0;
    final health = Health();
    int? healthSteps = await health.getTotalStepsInInterval(DateTime(now.year, now.month, now.day), now);

    if (healthSteps != null && healthSteps > 0) {
      hardwareSteps = healthSteps;
    } else {
      final nativeHealth = NativeHealthService();
      hardwareSteps = await nativeHealth.getHardwareSteps();
    }

    if (hardwareSteps == 0) return Future.value(true);


    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    String lastDate = storage.getLastDate();
    int baseline = storage.getHardwareBaseline();

    // 1. Process Daily and Weekly Resets
    if (lastDate != dateStr) {
      storage.saveLastDate(dateStr);
      storage.saveSteps(0);
      storage.saveLastCoinStep(0);
      storage.saveGoalNotified(false);

      storage.saveHardwareBaseline(hardwareSteps);
      baseline = hardwareSteps;

      String weeklyData = storage.getWeeklySteps();
      List<int> weekly = weeklyData.split(',').map((e) => int.tryParse(e) ?? 0).toList();
      if (weekly.length != 7) weekly = [0, 0, 0, 0, 0, 0, 0];


      weekly[now.weekday - 1] = 0;
      storage.saveWeeklySteps(weekly.join(','));
    }

    if (baseline > 0 && hardwareSteps < baseline) {
      int savedStepsToday = storage.getSteps();
      int newBaseline = -savedStepsToday;
      storage.saveHardwareBaseline(newBaseline);
      baseline = newBaseline;
    }
    int todaySteps = hardwareSteps - baseline;

    if (todaySteps < 0) {
      int savedStepsToday = storage.getSteps();
      int accumulatedSteps = savedStepsToday + hardwareSteps;
      storage.saveHardwareBaseline(hardwareSteps - accumulatedSteps);
      todaySteps = accumulatedSteps;
    }

    // 3. Process Coins
    int lastCoinStep = storage.getLastCoinStep();
    int currentCoins = storage.getCoins();

    if (todaySteps >= lastCoinStep + 100) {
      int newCoins = (todaySteps - lastCoinStep) ~/ 100;
      currentCoins += newCoins;
      storage.saveCoins(currentCoins);
      storage.saveLastCoinStep(lastCoinStep + (newCoins * 100));
    }

    // 4. Update Hive and Widget
    storage.saveSteps(todaySteps);

    String weeklyData = storage.getWeeklySteps();
    List<int> weekly = weeklyData.split(',').map((e) => int.tryParse(e) ?? 0).toList();
    if (weekly.length == 7) {
      weekly[now.weekday - 1] = todaySteps;
      storage.saveWeeklySteps(weekly.join(','));
    }
    final double height = storage.getHeight();
    final double weight = storage.getWeight();
    final double strideLengthMeters = (height * 0.413) / 100;
    final double distanceKm = (todaySteps * strideLengthMeters) / 1000;
    final double calories = distanceKm * weight * 1.036;

    final widgetService = WidgetService();
    await widgetService.updateWidgetData(
      steps: todaySteps,
      goal: storage.getStepGoal(),
      distance: distanceKm,
      calories: calories,
    );

    // 5. Silent Firebase Sync
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final firebaseDateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      int totalWeeklySteps = weekly.reduce((a, b) => a + b);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'currentCoins': currentCoins,
        'todaySteps': todaySteps,
        'todayCalories': calories,      
        'todayDistanceKm': distanceKm,
        'weeklySteps': weekly,
        'weeklyCalories': totalWeeklySteps * 0.04,
        'lastUpdated': FieldValue.serverTimestamp(),
        'dailyHistory': {
          firebaseDateStr: todaySteps,
        }
      }, SetOptions(merge: true));
    }

    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await g_sign_in.GoogleSignIn.instance.initialize(
    serverClientId: '348703955298-5nrsu7etb9jbvl8cqi7m4g1o222hc61p.apps.googleusercontent.com',
  );

  final storage = LocalStorageService();
  await storage.init();

  final int steps = storage.getSteps();
  final int goal = storage.getStepGoal();
  final double h = storage.getHeight();
  final double w = storage.getWeight();
  final double d = (steps * (h * 0.413) / 100) / 1000;
  final double c = d * w * 1.036;

  final widgetService = WidgetService();
  await widgetService.updateWidgetData(
    steps: steps,
    goal: goal,
    distance: d,
    calories: c,
  );

  Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  Workmanager().registerPeriodicTask(
    "step_tracker_task_id",
    "process_background_steps",
    frequency: const Duration(minutes: 15),
  );

  runApp(
    const ProviderScope(
      child: BuildUpApp(),
    ),
  );
}