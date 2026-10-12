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
});

/// Saves [hardwareSteps] to storage. Call only while holding storage (see
/// StepSyncCoordinator.runAsStorageOwner). Returns null when the reading is
/// not usable. [now] is for tests.
Future<BackgroundSyncResult?> saveStepsInBackground(
  int hardwareSteps, {
  DateTime? now,
}) async {
  final storage = LocalStorageService();
  await storage.init();
  try {
    now ??= DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final isNewDay = storage.getLastDate() != dateStr;

    final result = resolveTodaySteps(
      hardwareSteps: hardwareSteps,
      baseline: storage.getHardwareBaseline(),
      savedToday: storage.getSteps(),
      isNewDay: isNewDay,
    );
    if (result == null) return null;

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
    if (isNewDay) {
      storage.saveLastDate(dateStr);
      storage.saveSteps(0);
      storage.saveLastCoinStep(0);
      storage.saveGoalNotified(false);

      String weeklyData = storage.getWeeklySteps();
      List<int> weekly = weeklyData
          .split(',')
          .map((e) => int.tryParse(e) ?? 0)
          .toList();
      if (weekly.length != 7) weekly = [0, 0, 0, 0, 0, 0, 0];
      weekly[now.weekday - 1] = 0;
      storage.saveWeeklySteps(weekly.join(','));
    }

    storage.saveHardwareBaseline(result.baseline);
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
    final double strideLengthMeters = (height * 0.413) / 100;
    final double distanceKm = (todaySteps * strideLengthMeters) / 1000;
    final double calories = distanceKm * weight * 1.036;

    return (
      todaySteps: todaySteps,
      goal: goal,
      coins: currentCoins,
      distanceKm: distanceKm,
      calories: calories,
      weekly: weekly,
      notifyGoal: notifyGoal,
    );
  } finally {
    // Flushes the writes above before another isolate may open the box.
    await storage.close();
  }
}
