import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/notification_provider/notification_provider.dart';
import '../../../../core/services/account_session.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../../core/services/native_health_service.dart';
import '../../../../core/services/widget_service.dart';
import '../../../../core/utils/activity_log.dart';
import '../../../../core/utils/calorie_calculator.dart';
import '../../../../core/utils/monthly_best.dart';
import '../../../../core/utils/step_counter_math.dart';
import '../../../../core/utils/step_history.dart';
import '../../../../core/utils/step_upload.dart';
import '../../data/account_restore.dart';
import '../../data/step_cloud.dart';
import '../../../social/presentation/providers/challenge_provider.dart';

// list of all  ranks users can reach based on their walking.
enum LeagueTier { bronze, silver, gold, diamond }

// color for each tier
extension LeagueTierColor on LeagueTier {
  Color get color {
    switch (this) {
      case LeagueTier.diamond:
        return Colors.cyanAccent;
      case LeagueTier.gold:
        return Colors.amber;
      case LeagueTier.silver:
        return const Color(0xFFC0C0C0);
      case LeagueTier.bronze:
        return const Color(0xFFCD7F32);
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

  /// Today's steps removed because they were counted in a vehicle.
  final int drivingSteps;

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
    this.drivingSteps = 0,
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
    int? drivingSteps,
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
      drivingSteps: drivingSteps ?? this.drivingSteps,
    );
  }

  // calculates league by average steps this week.
  LeagueTier get currentLeague => leagueOn(DateTime.now());

  /// The league on [now]'s day: the average of this week's days so far.
  LeagueTier leagueOn(DateTime now) {
    int activeDays = now.weekday;

    int totalWeeklySteps = weeklySteps
        .sublist(0, activeDays)
        .fold(0, (total, item) => total + item);
    int averageSteps = totalWeeklySteps ~/ activeDays;

    if (averageSteps >= 12000) return LeagueTier.diamond;
    if (averageSteps >= 8000) return LeagueTier.gold;
    if (averageSteps >= 5000) return LeagueTier.silver;
    return LeagueTier.bronze;
  }

  // name current tier.
  String get tierName {
    switch (currentLeague) {
      case LeagueTier.diamond:
        return 'Diamond Tier';
      case LeagueTier.gold:
        return 'Gold Tier';
      case LeagueTier.silver:
        return 'Silver Tier';
      case LeagueTier.bronze:
        return 'Bronze Tier';
    }
  }
}

final storageProvider = Provider<LocalStorageService>(
  (ref) => LocalStorageService(),
);
final widgetServiceProvider = Provider<WidgetService>((ref) => WidgetService());
final stepNotifierProvider = NotifierProvider<StepNotifier, StepState>(
  StepNotifier.new,
);

// brain of the whole step tracker It handles all the logic for counting and saving.

class StepNotifier extends Notifier<StepState> {
  Timer? _pollingTimer;

  AppLifecycleListener? _lifecycleListener;
  // Today's steps last sent to Firestore by this run; null until the first.
  SentSteps? _lastSent;
  // Day (yyyy-MM-dd) that state.currentSteps belongs to. Just after midnight
  // it is still yesterday until the next sensor read.
  String? _stepsDay;

  // Monthly best last written to Firestore by this run; null until the first
  // write, so every app start syncs it once.
  int? _syncedHighScore;
  bool _highScoreSyncing = false;

  StepCloud get _cloud => ref.read(stepCloudProvider);
  DateTime _now() => ref.read(clockProvider)();

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
    final now = _now();
    _syncedHighScore = null;
    _lastSent = null;
    // Steps saved on an earlier day are shown as 0 for today.
    _stepsDay = dateKey(now);

    final isToday = storage.getLastDate() == _stepsDay;
    final displaySteps = isToday ? storage.getSteps() : 0;
    final savedCoins = storage.getCoins();
    final savedGoal = storage.getStepGoal();
    final savedHeight = storage.getHeight();
    final savedWeight = storage.getWeight();

    final initialDistanceKm = CalorieCalculator.distanceKm(
      displaySteps,
      savedHeight,
    );
    final initialCalories = CalorieCalculator.calories(
      displaySteps,
      heightCm: savedHeight,
      weightKg: savedWeight,
    );

    // Rebuilt, as the saved week may be from before this one began.
    final loadedWeeklySteps = storage.refreshWeeklySteps(now);

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
      drivingSteps: isToday ? storage.getDrivingStepsToday() : 0,
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
    if (AccountSession.deleting) return;
    _cloud.saveCoins(coins);
  }

  // Pushes all data to cloud right now if their is new data

  void _forceCloudSync() => _syncIfNeeded(minNewSteps: 1);

  // Sends today's steps once [minNewSteps] more were taken since the last
  // send, and on the first update of each day (see needsStepUpload).
  void _syncIfNeeded({required int minNewSteps}) {
    final day = _stepsDay ?? dateKey(_now());
    if (!needsStepUpload(
      todaySteps: state.currentSteps,
      today: day,
      sent: _lastSent,
      minNewSteps: minNewSteps,
    )) {
      return;
    }
    _syncCompleteProfileToFirestore(
      day,
      state.currentSteps,
      state.coins,
      state.weeklySteps,
    );
    _lastSent = (day: day, steps: state.currentSteps);
  }

  Future initializeTracking() async {
    final granted = await ref.read(activityPermissionProvider)();
    if (!ref.mounted) return;

    if (!granted) {
      state = state.copyWith(pedestrianStatus: 'Permission Denied');
      return;
    }

    // Removes steps counted in a vehicle; does nothing without Play Services.
    await ref.read(nativeHealthProvider).startDriveDetection();
    if (!ref.mounted) return;

    // Steps minute by minute for the activity screen; does nothing without
    // Play Services.
    await ref.read(nativeHealthProvider).startStepRecording();
    if (!ref.mounted) return;

    await _setupFallbackTracking();
  }

  Future<void> _setupFallbackTracking() async {
    await _fetchFallbackData();
    if (!ref.mounted) return;
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (!state.isRestMode) _fetchFallbackData();
    });
  }

  Future<void> _fetchFallbackData() async {
    final nativeHealth = ref.read(nativeHealthProvider);
    final session = AccountSession.current;
    final hardwareSteps = await nativeHealth.getHardwareSteps();
    final drives = hardwareSteps > 0
        ? await nativeHealth.getDrives()
        : const <Drive>[];
    if (needsDriveCheck(drives, _now())) {
      unawaited(nativeHealth.checkStillDriving());
    }
    // Signed out or reset while the sensor was read: this account's state
    // must not be written back.
    if (!ref.mounted || session != AccountSession.current) return;

    if (hardwareSteps == -1) {
      state = state.copyWith(pedestrianStatus: 'No Sensor Detected');
      return;
    }

    final storage = ref.read(storageProvider);
    final now = _now();
    final dateStr = dateKey(now);
    final isNewDay = storage.getLastDate() != dateStr;

    final result = resolveTodaySteps(
      hardwareSteps: hardwareSteps,
      baseline: storage.getHardwareBaseline(),
      savedToday: storage.getSteps(),
      isNewDay: isNewDay,
      drives: drives,
      appliedDriveIds: storage.getAppliedDriveIds(),
      now: now,
      lastSyncAt: storage.getLastSyncAt(),
    );
    if (result == null) return;

    // Steps from before midnight finish off the last saved day, coins
    // included.
    if (isNewDay && result.earlierDaySteps > 0) {
      storage.addStepsToLastDay(result.earlierDaySteps, CheckSource.app);
      state = state.copyWith(coins: storage.getCoins());
      _syncCoinsToFirestore(state.coins);
    }

    // Credit challenges from what is stored, so steps the background task
    // counted while the app was closed are included.
    final credit = settleChallengeSteps(
      todaySteps: result.todaySteps,
      previousSavedSteps: storage.getSteps(),
      credited: storage.getChallengeCreditedSteps(),
      pending: storage.getChallengePendingSteps(),
      isNewDay: isNewDay,
      canCredit: true,
    );
    storage.saveChallengeCreditedSteps(credit.credited);
    storage.saveChallengePendingSteps(credit.pending);

    if (isNewDay) storage.startNewDay(dateStr);
    storage.saveHardwareBaseline(result.baseline);
    storage.markDrivesApplied(result);

    _processSteps(
      result.todaySteps,
      'fallback',
      challengeSteps: credit.stepsToCredit,
    );
    storage.logStepSync(
      state.currentSteps,
      now,
      CheckSource.app,
      rides: result.rides,
    );
    // The baseline now includes these drives, and their ids are stored.
    await nativeHealth.removeDrives(result.appliedDriveIds);
  }

  /// Syncs on behalf of the background task while the app is running (see
  /// StepSyncCoordinator).
  Future<void> syncFromBackgroundRequest() => _fetchFallbackData();

  /// Syncs, then whether today's goal can still be filled by the goal ad:
  /// today's count is read and below the goal. Check before showing the ad.
  Future<bool> canFillStepsToGoal() async {
    await _fetchFallbackData();
    if (!ref.mounted) return false;
    final storage = ref.read(storageProvider);
    return storage.getLastDate() == dateKey(_now()) &&
        state.goalSteps > 0 &&
        storage.getSteps() < state.goalSteps;
  }

  /// Reward of the goal ad: fills today's steps up to the goal (see
  /// fillToGoal). Syncs first so the fill starts from the latest count.
  /// Returns false when nothing was filled.
  Future<bool> fillStepsToGoal() async {
    final session = AccountSession.current;
    await _fetchFallbackData();
    if (!ref.mounted || session != AccountSession.current) return false;

    final storage = ref.read(storageProvider);
    // Without today's sensor read the stored count belongs to an earlier
    // day; filling it would mix the two.
    if (storage.getLastDate() != dateKey(_now())) return false;
    final fill = fillToGoal(
      todaySteps: storage.getSteps(),
      goal: state.goalSteps,
      baseline: storage.getHardwareBaseline(),
      lastCoinStep: storage.getLastCoinStep(),
      challengeCredited: storage.getChallengeCreditedSteps(),
    );
    if (fill == null) return false;

    storage.saveHardwareBaseline(fill.baseline);
    storage.saveLastCoinStep(fill.lastCoinStep);
    storage.saveChallengeCreditedSteps(fill.challengeCredited);
    _processSteps(fill.todaySteps, state.pedestrianStatus, challengeSteps: 0);
    // Logged apart so the activity screen does not show them as a walk.
    storage.logStepSync(fill.todaySteps, _now(), CheckSource.goalReward);
    _forceCloudSync();
    return true;
  }

  void updateProfile(double height, double weight) {
    final storage = ref.read(storageProvider);
    storage.saveHeight(height);
    storage.saveWeight(weight);

    // Recalculate based on current steps
    final dist = CalorieCalculator.distanceKm(state.currentSteps, height);
    final cals = CalorieCalculator.calories(
      state.currentSteps,
      heightCm: height,
      weightKg: weight,
    );

    state = state.copyWith(
      height: height,
      weight: weight,
      distanceKm: dist,
      calories: cals,
    );

    _cloud.saveBody(height: height, weight: weight);
  }

  //  It calculates everything

  void _processSteps(
    int todaySteps,
    String trackingStatus, {
    required int challengeSteps,
  }) {
    final storage = ref.read(storageProvider);
    final now = _now();

    if (todaySteps < 0) todaySteps = 0;
    if (challengeSteps > 0) {
      final challengeCoins = ref
          .read(challengeProvider.notifier)
          .addStepsToActiveChallenges(challengeSteps);
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

    if (shouldNotifyGoal(
      todaySteps: todaySteps,
      goal: state.goalSteps,
      alreadyNotified: storage.getGoalNotified(),
    )) {
      ref.read(notificationServiceProvider).showGoalReached(todaySteps);
      storage.saveGoalNotified(true);
    }

    _updateLeaderboardScore(todaySteps);

    storage.saveDailyHistory(
      recordDay(storage.getDailyHistory(), now, todaySteps),
    );
    final weekly = storage.refreshWeeklySteps(now);

    final calculatedDistanceKm = CalorieCalculator.distanceKm(
      todaySteps,
      state.height,
    );
    final calculatedCalories = CalorieCalculator.calories(
      todaySteps,
      heightCm: state.height,
      weightKg: state.weight,
    );

    state = state.copyWith(
      currentSteps: todaySteps,
      calories: calculatedCalories,
      distanceKm: calculatedDistanceKm,
      coins: currentCoins,
      pedestrianStatus: trackingStatus,
      weeklySteps: weekly,
      drivingSteps: storage.getDrivingStepsToday(),
    );
    _stepsDay = dateKey(now);
    storage.saveSteps(todaySteps);
    // After the state update, so the new count is what gets sent.
    _syncIfNeeded(minNewSteps: 500);
    ref
        .read(widgetServiceProvider)
        .updateWidgetData(
          steps: todaySteps,
          goal: state.goalSteps,
          distance: calculatedDistanceKm,
          calories: calculatedCalories,
        );
  }

  //  check if  user broke  personal record of month right here.
  void _updateLeaderboardScore(int todaySteps) {
    final storage = ref.read(storageProvider);
    final now = _now();
    final local = localMonthlyBest(
      savedMonth: storage.getSavedMonth(),
      savedBest: storage.getMonthlyHighScore(),
      todaySteps: todaySteps,
      now: now,
    );
    if (local.monthChanged) {
      storage.saveSavedMonth(now.month);
      _syncedHighScore = null;
    }
    storage.saveMonthlyHighScore(local.best);
    if (local.best != _syncedHighScore) _syncHighScoreToFirestore();
  }

  // Tells Firestore what the user's best score is so their friends can see it.
  // Never lowers this month's remote best: storage may have been lost (a
  // reinstall), so the phone's copy can be lower than the real best. A failed
  // write (e.g. offline) is retried on the next step update.
  Future<void> _syncHighScoreToFirestore() async {
    if (!_cloud.isSignedIn || _highScoreSyncing) return;
    _highScoreSyncing = true;
    final session = AccountSession.current;
    final storage = ref.read(storageProvider);
    final now = _now();
    try {
      final best = await _cloud.saveMonthlyBest(
        localBest: storage.getMonthlyHighScore(),
        league: state.leagueOn(now).name,
        now: now,
      );
      if (best == null || session != AccountSession.current) return;
      _syncedHighScore = best;
      // A higher remote best (from before a reinstall) becomes the local one.
      if (storage.getSavedMonth() == now.month &&
          best > storage.getMonthlyHighScore()) {
        storage.saveMonthlyHighScore(best);
      }
    } catch (e) {
      debugPrint('High score sync failed: $e');
    } finally {
      _highScoreSyncing = false;
    }
  }

  // sync that sends everything Firebase

  // [dateStr] (yyyy-MM-dd) is the day [todaySteps] were counted on.
  void _syncCompleteProfileToFirestore(
    String dateStr,
    int todaySteps,
    int coins,
    List<int> weekly,
  ) {
    if (AccountSession.deleting) return;
    final day = DateTime.parse(dateStr);
    final yesterday = dateKey(DateTime(day.year, day.month, day.day - 1));
    _cloud.saveDay(
      day: day,
      steps: todaySteps,
      yesterdaySteps: ref.read(storageProvider).getDailyHistory()[yesterday],
      coins: coins,
      weekly: weekly,
      league: state.leagueOn(day).name,
    );
  }

  // goal update
  void updateGoal(int newGoal) {
    ref.read(storageProvider).saveStepGoal(newGoal);
    state = state.copyWith(goalSteps: newGoal);
    ref
        .read(widgetServiceProvider)
        .updateWidgetData(
          steps: state.currentSteps,
          goal: newGoal,
          distance: state.distanceKm,
          calories: state.calories,
        );

    _cloud.saveGoal(newGoal);
  }

  // force refresh

  Future<void> forceRefresh() async {
    final session = AccountSession.current;
    Map<String, dynamic>? data;
    try {
      data = await _cloud.load();
    } catch (e) {
      // Offline: keep the coins on the phone and still read the sensor.
      debugPrint('Coin refresh failed: $e');
    }
    if (!ref.mounted) return;
    final coins = data?['currentCoins'];
    if (session == AccountSession.current && coins is num) {
      final storage = ref.read(storageProvider);
      storage.saveCoins(coins.toInt());
      state = state.copyWith(coins: coins.toInt());
    }
    await initializeTracking();
  }

  // After user logs in restore data from firebase. Throws when the account
  // can't be read (e.g. offline) or saved, so the caller can try again.

  Future<void> restoreDataFromFirebase() async {
    if (!_cloud.isSignedIn) return;
    final session = AccountSession.current;
    final data = await _cloud.load();
    if (!ref.mounted || session != AccountSession.current || data == null) {
      return;
    }
    final now = _now();
    final restored = restoreAccount(ref.read(storageProvider), data, now);
    _cloud.deleteHistoryDays(restored.staleCloudDays);

    _stepsDay = dateKey(now);
    state = state.copyWith(
      currentSteps: restored.todaySteps,
      goalSteps: restored.goal,
      height: restored.height,
      weight: restored.weight,
      coins: restored.coins,
      weeklySteps: restored.weekly,
      calories: CalorieCalculator.calories(
        restored.todaySteps,
        heightCm: restored.height,
        weightKg: restored.weight,
      ),
      distanceKm: CalorieCalculator.distanceKm(
        restored.todaySteps,
        restored.height,
      ),
    );
    await ref.read(challengeProvider.notifier).syncWithFirestore();
  }
}
