import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/notification_provider/notification_provider.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../../core/services/native_health_service.dart';
import '../../../../core/services/widget_service.dart';
import '../../../social/presentation/providers/challenge_provider.dart';

// list of all  ranks users can reach based on their walking.
enum LeagueTier { bronze, silver, gold, diamond }

// color for each tier
extension LeagueTierColor on LeagueTier {
  Color get color {
    switch (this) {
      case LeagueTier.diamond: return Colors.cyanAccent;
      case LeagueTier.gold: return Colors.amber;
      case LeagueTier.silver: return const Color(0xFFC0C0C0);
      case LeagueTier.bronze: return const Color(0xFFCD7F32);
    }
  }
}

// user's step info, coins, etc class

class StepState {
  final int currentSteps;
  final double height;
  final double weight;
  final int goalSteps;
  final double calories;
  final double distanceKm;
  final bool isRestMode;
  final String pedestrianStatus;
  final int coins;
  final List<int> weeklySteps;

  const StepState({
    required this.currentSteps,
    this.height = 170.0,
    this.weight = 70.0,
    required this.goalSteps,
    required this.calories,
    required this.distanceKm,
    required this.isRestMode,
    this.pedestrianStatus = 'stopped',
    this.coins = 0,
    this.weeklySteps = const [0, 0, 0, 0, 0, 0, 0],
  });

  // Converting steps into active Distance
  String get activeDuration {
    final totalMinutes = currentSteps ~/ 100;
    if (totalMinutes < 60) return '$totalMinutes min';
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '$hours:${minutes.toString().padLeft(2, '0')}';
  }

  // state update without changing the original data.

  StepState copyWith({
    int? currentSteps,
    double? height,
    double? weight,
    int? goalSteps,
    double? calories,
    double? distanceKm,
    bool? isRestMode,
    String? pedestrianStatus,
    int? coins,
    List<int>? weeklySteps,
  }) {
    return StepState(
      currentSteps: currentSteps ?? this.currentSteps,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      goalSteps: goalSteps ?? this.goalSteps,
      calories: calories ?? this.calories,
      distanceKm: distanceKm ?? this.distanceKm,
      isRestMode: isRestMode ?? this.isRestMode,
      pedestrianStatus: pedestrianStatus ?? this.pedestrianStatus,
      coins: coins ?? this.coins,
      weeklySteps: weeklySteps ?? this.weeklySteps,
    );
  }

  // calculates league by average steps this week.
  LeagueTier get currentLeague {
    int activeDays = DateTime.now().weekday;

    int totalWeeklySteps = weeklySteps.sublist(0, activeDays).fold(0, (sum, item) => sum + item);
    int averageSteps = totalWeeklySteps ~/ activeDays;

    if (averageSteps >= 12000) return LeagueTier.diamond;
    if (averageSteps >= 8000) return LeagueTier.gold;
    if (averageSteps >= 5000) return LeagueTier.silver;
    return LeagueTier.bronze;
  }

  // name current tier.
  String get tierName {
    switch (currentLeague) {
      case LeagueTier.diamond: return 'Diamond Tier';
      case LeagueTier.gold: return 'Gold Tier';
      case LeagueTier.silver: return 'Silver Tier';
      case LeagueTier.bronze: return 'Bronze Tier';
    }
  }
}


final storageProvider = Provider<LocalStorageService>((ref) => LocalStorageService());
final widgetServiceProvider = Provider<WidgetService>((ref) => WidgetService());
final stepNotifierProvider = NotifierProvider<StepNotifier, StepState>(StepNotifier.new);

final Health _health = Health();

// brain of the whole step tracker It handles all the logic for counting and saving.

class StepNotifier extends Notifier<StepState> {
  Timer? _pollingTimer;

  AppLifecycleListener? _lifecycleListener;
  int _lastSyncedSteps = 0;
  String? _lastProcessedDate;

  //  runs on app start up , loads saved data

  @override
  StepState build() {

    _lifecycleListener = AppLifecycleListener(
      onPause: _forceCloudSync,
      onInactive: _forceCloudSync,
      onDetach: _forceCloudSync,
    );

    ref.onDispose(() {
      _pollingTimer?.cancel();
      _lifecycleListener?.dispose();
    });

    final storage = ref.watch(storageProvider);
    final now = DateTime.now();
    _lastProcessedDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
    final displaySteps = storage.getLastDate() == _lastProcessedDate ? storage.getSteps() : 0;
    final savedCoins = storage.getCoins();
    final savedGoal = storage.getStepGoal();
    final savedHeight = storage.getHeight();
    final savedWeight = storage.getWeight();

    double strideLengthMeters = (savedHeight * 0.413) / 100;
    double initialDistanceKm = (displaySteps * strideLengthMeters) / 1000;
    double initialCalories = initialDistanceKm * savedWeight * 1.036;

    String weeklyData = storage.getWeeklySteps();
    List<int> loadedWeeklySteps = weeklyData.split(',').map((e) => int.tryParse(e) ?? 0).toList();
    if (loadedWeeklySteps.length != 7) loadedWeeklySteps = [0, 0, 0, 0, 0, 0, 0];

    return StepState(
      currentSteps: displaySteps,
      height: savedHeight,
      weight: savedWeight,
      goalSteps: savedGoal,
      calories: initialCalories,
      distanceKm: initialDistanceKm,
      isRestMode: false,
      coins: savedCoins,
      weeklySteps: loadedWeeklySteps,
    );
  }


  void addCoins(int amount) {
    final storage = ref.read(storageProvider);
    final newTotal = state.coins + amount;
    storage.saveCoins(newTotal);
    state = state.copyWith(coins: newTotal);
    _syncCoinsToFirestore(newTotal);
  }

  bool deductCoins(int amount) {
    final storage = ref.read(storageProvider);
    if (state.coins >= amount) {
      final newTotal = state.coins - amount;
      storage.saveCoins(newTotal);
      state = state.copyWith(coins: newTotal);
      _syncCoinsToFirestore(newTotal);
      return true;
    }
    return false;
  }

  void _syncCoinsToFirestore(int coins) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'currentCoins': coins,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  // Pushes all data to cloud right now if their is new data

  void _forceCloudSync() {
    if (state.currentSteps > _lastSyncedSteps) {
      _syncCompleteProfileToFirestore(
        state.currentSteps,
        state.calories,
        state.distanceKm,
        state.coins,
        state.weeklySteps,
      );
      _lastSyncedSteps = state.currentSteps;
    }
  }

  // Every morning resets everything back

  void _handleDailyResetIfNeeded({int? hardwareSteps}) {
    final storage = ref.read(storageProvider);
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    if (storage.getLastDate() != dateStr) {
      storage.saveLastDate(dateStr);
      storage.saveSteps(0);
      storage.saveLastCoinStep(0);
      storage.saveGoalNotified(false);

      storage.saveHardwareBaseline(0);

      String weeklyData = storage.getWeeklySteps();
      List<int> weekly = weeklyData.split(',').map((e) => int.tryParse(e) ?? 0).toList();
      if (weekly.length != 7) weekly = [0, 0, 0, 0, 0, 0, 0];
      weekly[now.weekday - 1] = 0;
      storage.saveWeeklySteps(weekly.join(','));
    }
    // This is for older phones that poll slowly
    if (hardwareSteps != null && hardwareSteps > 0) {
      if (storage.getHardwareBaseline() == 0 || storage.getSteps() == 0) {
        storage.saveHardwareBaseline(hardwareSteps);
      }
    }
  }

  //sets up connection to sensors to ask permission first.

  Future initializeTracking() async {

    final storage = ref.read(storageProvider);

    // 1. If we already know Health isn't supported, go straight to hardware
    if (!storage.getHealthSupported()) {
      await _setupFallbackTracking();
      return;
    }
    final types = [HealthDataType.STEPS];
    final activityStatus = await Permission.activityRecognition.request();

    if (!activityStatus.isGranted) {
      state = state.copyWith(pedestrianStatus: 'Permission Denied');
      return;
    }
  bool hasPermissions = false;
  try {
    _health.configure();
    hasPermissions = await _health.hasPermissions(types) ?? false;
    if (!hasPermissions) {
        hasPermissions = await _health.requestAuthorization(types);
    }
  } catch (e) {
    debugPrint('Health Connect not supported, falling back: $e');
    storage.saveHealthSupported(false);
    hasPermissions = false;
  }
    if (hasPermissions) {
      await _fetchHealthData();
      _pollingTimer?.cancel();
      _pollingTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
        if (!state.isRestMode) _fetchHealthData();
      });
    }  else {
      // 3. If permissions failed or service is missing, switch to hardware
      storage.saveHealthSupported(false);
      await _setupFallbackTracking();
    }
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  Future<void> _setupFallbackTracking() async {
    await _fetchFallbackData();
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (!state.isRestMode) _fetchFallbackData();
    });
  }

  // step count from OS Health or Apple Health

  Future<void> _fetchHealthData() async {
    try {
      _handleDailyResetIfNeeded();
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      int? steps = await _health.getTotalStepsInInterval(midnight, now);
      _processSteps(steps ?? 0, 'tracking');
    } catch (e) { await _fetchFallbackData(); }
  }

  // If the health sensors fail, we use this backup way to count steps directly from the phone.

  Future<void> _fetchFallbackData() async {
    final nativeHealth = ref.read(nativeHealthProvider);
    final hardwareSteps = await nativeHealth.getHardwareSteps();

    if (hardwareSteps == -1) {
      state = state.copyWith(pedestrianStatus: 'No Sensor Detected');
      return;
    }

    _handleDailyResetIfNeeded(hardwareSteps: hardwareSteps);

    if (state.pedestrianStatus != 'fallback') {
      state = state.copyWith(pedestrianStatus: 'fallback');
    }

    if (hardwareSteps == 0) return;

    final storage = ref.read(storageProvider);
    int baseline = storage.getHardwareBaseline();
    if (baseline > 0 && hardwareSteps < baseline) {
      int savedStepsToday = storage.getSteps();
      int newBaseline = hardwareSteps - savedStepsToday;
      storage.saveHardwareBaseline(newBaseline);
      baseline = newBaseline;
    }
    if (baseline == 0) {
      storage.saveHardwareBaseline(hardwareSteps);
      baseline = hardwareSteps;
    }
    int todaySteps = hardwareSteps - baseline;
    if (todaySteps < 0) todaySteps = 0;
    _processSteps(todaySteps, 'fallback');
  }


  void updateProfile(double height, double weight) {
    final storage = ref.read(storageProvider);
    storage.saveHeight(height);
    storage.saveWeight(weight);

    // Recalculate based on current steps
    double strideLengthMeters = (height * 0.413) / 100;
    double dist = (state.currentSteps * strideLengthMeters) / 1000;
    double cals = dist * weight * 1.036;

    state = state.copyWith(
      height: height,
      weight: weight,
      distanceKm: dist,
      calories: cals,
    );

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'height': height,
        'weight': weight,
      }, SetOptions(merge: true));
    }
  }

  //  It calculates everything

  void _processSteps(int todaySteps, String trackingStatus) {

    final storage = ref.read(storageProvider);
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    if (todaySteps < 0) todaySteps = 0;
    int previousSteps = state.currentSteps;
    if (_lastProcessedDate != dateStr) {
      previousSteps = 0;
      _lastProcessedDate = dateStr;
    }
    final int deltaSteps = todaySteps - previousSteps;
    if (deltaSteps > 0) {
      final challengeCoins = ref.read(challengeProvider.notifier).addStepsToActiveChallenges(deltaSteps);
      if (challengeCoins > 0) addCoins(challengeCoins);
    }

    int lastCoinStep = storage.getLastCoinStep();
    int currentCoins = state.coins;
    if (todaySteps >= lastCoinStep + 100) {
      int newCoins = (todaySteps - lastCoinStep) ~/ 100;
      currentCoins += newCoins;
      storage.saveCoins(currentCoins);
      storage.saveLastCoinStep(lastCoinStep + (newCoins * 100));
      _syncCoinsToFirestore(currentCoins);
    }

    if (todaySteps >= state.goalSteps && !storage.getGoalNotified()) {
      ref.read(notificationServiceProvider).showGoalReached(todaySteps);
      storage.saveGoalNotified(true);
    }

    _updateLeaderboardScore(todaySteps);

    String weeklyData = storage.getWeeklySteps();
    List<int> weekly = weeklyData.split(',').map((e) => int.tryParse(e) ?? 0).toList();
    if (weekly.length != 7) weekly = [0, 0, 0, 0, 0, 0, 0];
    weekly[now.weekday - 1] = todaySteps;
    storage.saveWeeklySteps(weekly.join(','));

    if (todaySteps - _lastSyncedSteps >= 500) _forceCloudSync();

    double strideLengthMeters = (state.height * 0.413) / 100;

    //  Calculate accurate distance
    double calculatedDistanceKm = (todaySteps * strideLengthMeters) / 1000;

    //  Calculate precise calories
    double calculatedCalories = calculatedDistanceKm * state.weight * 1.036;


    state = state.copyWith(
      currentSteps: todaySteps,
      calories: calculatedCalories,
      distanceKm: calculatedDistanceKm,
      coins: currentCoins,
      pedestrianStatus: trackingStatus,
      weeklySteps: weekly,
    );
    storage.saveSteps(todaySteps);
    ref.read(widgetServiceProvider).updateWidgetData(
      steps: todaySteps,
      goal: state.goalSteps,
      distance: calculatedDistanceKm,
      calories: calculatedCalories,
    );
  }

  //  check if  user broke  personal record of month right here.
  void _updateLeaderboardScore(int todaySteps) {
    final storage = ref.read(storageProvider);
    final now = DateTime.now();
    if (now.month != storage.getSavedMonth()) {
      storage.saveSavedMonth(now.month);
      storage.saveMonthlyHighScore(0);
      _syncHighScoreToFirestore(0);
    }
    if (todaySteps > storage.getMonthlyHighScore()) {
      storage.saveMonthlyHighScore(todaySteps);
      _syncHighScoreToFirestore(todaySteps);
    }
  }

  // Tells Firestore what the user's best score is so their friends can see it.

  void _syncHighScoreToFirestore(int score) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'monthlyHighScore': score,
        'currentLeague': state.currentLeague.name,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }
  }

  // sync that sends everything Firebase

  void _syncCompleteProfileToFirestore(int todaySteps, double calories, double distance, int coins, List<int> weekly) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final dateStr = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
      FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'currentCoins': coins,
        'todaySteps': todaySteps,
        'todayCalories': calories,
        'todayDistanceKm': distance,
        'weeklySteps': weekly,
        'currentLeague': state.currentLeague.name,
        'lastUpdated': FieldValue.serverTimestamp(),
        'dailyHistory': {dateStr: todaySteps}
      }, SetOptions(merge: true));
    }
  }

  // goal update
  void updateGoal(int newGoal) {
    ref.read(storageProvider).saveStepGoal(newGoal);
    state = state.copyWith(goalSteps: newGoal);
    ref.read(widgetServiceProvider).updateWidgetData(
      steps: state.currentSteps,
      goal: newGoal,
      distance: state.distanceKm,
      calories: state.calories,
    );
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'stepGoal': newGoal,
      }, SetOptions(merge: true));
    }
  }

  // force refresh

  Future<void> forceRefresh() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        final storage = ref.read(storageProvider);
        int fetchedCoins = data['currentCoins'] ?? storage.getCoins();
        storage.saveCoins(fetchedCoins);
        state = state.copyWith(coins: fetchedCoins);
      }
    }
    await initializeTracking();
  }

  // After user logs in restore data from firebase

  Future<void> restoreDataFromFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!doc.exists) return;
      final data = doc.data()!;
      final storage = ref.read(storageProvider);

      if (data.containsKey('stepGoal')) storage.saveStepGoal(data['stepGoal']);
      if (data.containsKey('height')) storage.saveHeight((data['height'] as num).toDouble());
      if (data.containsKey('weight')) storage.saveWeight((data['weight'] as num).toDouble());
      if (data.containsKey('currentCoins')) storage.saveCoins(data['currentCoins']);
      if (data.containsKey('monthlyHighScore')) storage.saveMonthlyHighScore(data['monthlyHighScore']);

      List<int> loadedWeekly = [0, 0, 0, 0, 0, 0, 0];
      if (data.containsKey('weeklySteps')) {
        loadedWeekly = (data['weeklySteps'] as List).map((e) => e as int).toList();
        storage.saveWeeklySteps(loadedWeekly.join(','));
      }

      final dateStr = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
      int restoredSteps = 0;
      if (data.containsKey('dailyHistory') && data['dailyHistory'][dateStr] != null) {
        restoredSteps = data['dailyHistory'][dateStr] as int;
        storage.saveSteps(restoredSteps);
        storage.saveLastDate(dateStr);
        storage.saveLastCoinStep((restoredSteps ~/ 100) * 100);
      }

      final h = (data['height'] as num?)?.toDouble() ?? 170.0;
      final w = (data['weight'] as num?)?.toDouble() ?? 70.0;
      double strideLengthMeters = (h * 0.413) / 100;
      double dist = (restoredSteps * strideLengthMeters) / 1000;
      double cals = dist * w * 1.036;

      state = state.copyWith(
        currentSteps: restoredSteps,
        goalSteps: data['stepGoal'] ?? 10000,
        height: h,
        weight: w,
        coins: data['currentCoins'] ?? 0,
        weeklySteps: loadedWeekly,
        calories: cals,
        distanceKm: dist,
      );
      await ref.read(challengeProvider.notifier).syncWithFirestore();
    } catch (e) { debugPrint('Firebase restore failed: $e'); }
  }
}
