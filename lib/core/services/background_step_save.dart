import '../utils/activity_log.dart';
import '../utils/calorie_calculator.dart';
import '../utils/step_counter_math.dart';
import '../utils/step_history.dart';
import 'local_storage_service.dart';

/// What the background task saved, for the widget and Firestore updates
/// that run after it releases storage.
typedef BackgroundSyncResult = ({
  int todaySteps,
  int goal,
  int coins,
  double distanceKm,
  double calories,
  List<int> weekly,
  bool notifyGoal,
  List<int> appliedDriveIds,
  // Whose data this is (see localDataState); Firestore is only synced when
  // it is the signed-in account's.
  String? dataOwner,
  bool hadLocalData,
});

/// Saves [hardwareSteps], less the steps counted during [drives], to storage.
/// Call only while holding storage (see StepSyncCoordinator.runInBackground).
/// Returns null when the reading is not usable. [now] is for tests.
Future<BackgroundSyncResult?> saveStepsInBackground(
  int hardwareSteps, {
  List<Drive> drives = const [],
  DateTime? now,
}) async {
  final storage = LocalStorageService();
  await storage.init();
  try {
    now ??= DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final hadLocalData = storage.getLastDate().isNotEmpty;
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
    if (result == null) return null;

    // Steps from before midnight finish off the last saved day.
    if (isNewDay) {
      storage.addStepsToLastDay(result.earlierDaySteps, CheckSource.background);
    }

    // Only the app credits challenges; keep yesterday's uncredited steps for it.
    final credit = settleChallengeSteps(
      todaySteps: result.todaySteps,
      previousSavedSteps: storage.getSteps(),
      credited: storage.getChallengeCreditedSteps(),
      pending: storage.getChallengePendingSteps(),
      isNewDay: isNewDay,
      canCredit: false,
    );
    storage.saveChallengeCreditedSteps(credit.credited);
    storage.saveChallengePendingSteps(credit.pending);

    // 1. Process Daily and Weekly Resets
    if (isNewDay) storage.startNewDay(dateStr, now.weekday);

    storage.saveHardwareBaseline(result.baseline);
    storage.markDrivesApplied(result);
    final int todaySteps = result.todaySteps;

    // 3. Process Coins
    int lastCoinStep = storage.getLastCoinStep();
    int currentCoins = storage.getCoins();

    if (todaySteps >= lastCoinStep + 100) {
      int newCoins = (todaySteps - lastCoinStep) ~/ 100;
      currentCoins += newCoins;
      storage.saveCoins(currentCoins);
      storage.saveLastCoinStep(lastCoinStep + (newCoins * 100));
    }

    // 4. Update Hive
    storage.saveSteps(todaySteps);
    storage.logStepSync(
      todaySteps,
      now,
      CheckSource.background,
      rides: result.rides,
    );
    String weeklyData = storage.getWeeklySteps();
    List<int> weekly = weeklyData
        .split(',')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
    if (weekly.length == 7) {
      weekly[now.weekday - 1] = todaySteps;
      storage.saveWeeklySteps(weekly.join(','));
    }
    storage.saveDailyHistory(
      recordDay(storage.getDailyHistory(), now, todaySteps),
    );
    // Marked now, while holding storage, so the app won't show it again.
    final goal = storage.getStepGoal();
    final notifyGoal = shouldNotifyGoal(
      todaySteps: todaySteps,
      goal: goal,
      alreadyNotified: storage.getGoalNotified(),
    );
    if (notifyGoal) storage.saveGoalNotified(true);

    final double height = storage.getHeight();
    final double weight = storage.getWeight();
    final double distanceKm = CalorieCalculator.distanceKm(todaySteps, height);
    final double calories = CalorieCalculator.calories(
      todaySteps,
      heightCm: height,
      weightKg: weight,
    );

    return (
      todaySteps: todaySteps,
      goal: goal,
      coins: currentCoins,
      distanceKm: distanceKm,
      calories: calories,
      weekly: weekly,
      notifyGoal: notifyGoal,
      appliedDriveIds: result.appliedDriveIds,
      dataOwner: storage.getDataOwner(),
      hadLocalData: hadLocalData,
    );
  } finally {
    // Flushes the writes above before another isolate may open the box.
    await storage.close();
  }
}
