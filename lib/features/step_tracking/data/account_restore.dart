import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/local_storage_service.dart';
import '../../../core/utils/monthly_best.dart';
import '../../../core/utils/step_history.dart';
import '../../shop/models/owned_themes.dart';

/// What [restoreAccount] put on the phone, for the step state.
typedef RestoredAccount = ({
  int goal,
  double height,
  double weight,
  int coins,
  int todaySteps,
  List<int> weekly,
  // Cloud history days older than the 31 day window, for the caller to
  // delete from Firestore.
  List<String> staleCloudDays,
});

/// Saves the account's cloud document [data] to [storage] on sign-in.
///
/// Each field is read on its own: a number stored as a double is used as
/// an int, and a missing or unreadable field is skipped, so one bad field
/// can't stop the others (today's steps above all) from being restored.
/// A failed save throws, before today is marked as restored, so the caller
/// tries again instead of keeping half of the account. [now] is for tests.
RestoredAccount restoreAccount(
  LocalStorageService storage,
  Map<String, dynamic> data,
  DateTime now,
) {
  final goal = _int(data['stepGoal']);
  if (goal != null && goal > 0) storage.saveStepGoal(goal);
  final height = _double(data['height']);
  if (height != null && height > 0) storage.saveHeight(height);
  final weight = _double(data['weight']);
  if (weight != null && weight > 0) storage.saveWeight(weight);
  final coins = _int(data['currentCoins']);
  if (coins != null && coins >= 0) storage.saveCoins(coins);

  final themes = themesFromAccount(data, local: storage.getPurchasedThemes());
  storage.savePurchasedThemes(themes.owned);
  if (themes.active != null) storage.saveActiveTheme(themes.active!);

  final remoteBest = _int(data['monthlyHighScore']);
  if (remoteBest != null) {
    // Restores the month too: without it the next step update would see
    // a new month and start the best again from today's steps.
    final localBest = storage.getSavedMonth() == now.month
        ? storage.getMonthlyHighScore()
        : 0;
    final remoteMonth = data['monthlyHighScoreMonth'];
    final updatedAt = data['lastUpdated'];
    storage.saveSavedMonth(now.month);
    storage.saveMonthlyHighScore(
      mergeMonthlyBest(
        localBest: localBest,
        remoteBest: remoteBest,
        remoteMonth: remoteMonth is String ? remoteMonth : null,
        remoteUpdatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
        now: now,
      ),
    );
  }

  final cloudHistory = _history(data['dailyHistory']);
  storage.saveDailyHistory(
    mergeHistories(storage.getDailyHistory(), cloudHistory, now),
  );

  final today = dateKey(now);
  var todaySteps = 0;
  if (cloudHistory.containsKey(today)) {
    todaySteps = storage.getDailyHistory()[today] ?? 0;
    storage.saveSteps(todaySteps);
    storage.saveLastCoinStep((todaySteps ~/ 100) * 100);
    // Re-anchor the sensor baseline to the restored steps on the next read.
    storage.saveHardwareBaseline(0);
    // Challenges are restored from Firestore with these steps included.
    storage.saveChallengeCreditedSteps(todaySteps);
    storage.saveChallengePendingSteps(0);
    // Last: with today saved, the phone counts as holding data (see
    // localDataState).
    storage.saveLastDate(today);
  }

  return (
    goal: storage.getStepGoal(),
    height: storage.getHeight(),
    weight: storage.getWeight(),
    coins: storage.getCoins(),
    todaySteps: todaySteps,
    // From the history: the cloud's weekly array may be from an older week.
    weekly: storage.refreshWeeklySteps(now),
    staleCloudDays: staleKeys(cloudHistory.keys, now),
  );
}

int? _int(Object? value) =>
    value is num && value.isFinite ? value.toInt() : null;

double? _double(Object? value) =>
    value is num && value.isFinite ? value.toDouble() : null;

// The days of a cloud history that have a usable count.
Map<String, int> _history(Object? value) => {
  if (value is Map)
    for (final entry in value.entries)
      if (_int(entry.value) case final steps? when entry.key is String)
        entry.key as String: steps,
};
