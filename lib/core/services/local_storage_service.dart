import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

import '../ads/rewarded_ad_limits.dart';
import 'app_review_service.dart';
import '../utils/activity_log.dart';
import '../utils/step_counter_math.dart';
import '../utils/step_history.dart';

class LocalStorageService {
  static const String _boxName = 'buildUpData';

  Future<void> init() async {
    // Already open in this isolate (tests open it themselves).
    if (Hive.isBoxOpen(_boxName)) return;
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
  }

  Box get _box => Hive.box(_boxName);

  /// Flushes pending writes and closes the box.
  Future<void> close() => _box.close();

  void saveSteps(int steps) {
    _box.put('currentSteps', steps);
  }

  int getSteps() {
    return _box.get('currentSteps', defaultValue: 0);
  }

  void saveHeight(double height) {
    _box.put('height', height);
  }

  double getHeight() {
    return _box.get('height', defaultValue: 170.0);
  }

  void saveWeight(double weight) {
    _box.put('weight', weight);
  }

  double getWeight() {
    return _box.get('weight', defaultValue: 70.0);
  }

  void saveCoins(int coins) {
    _box.put('coins', coins);
  }

  int getCoins() {
    return _box.get('coins', defaultValue: 0);
  }

  void saveBaselineSteps(int steps) {
    _box.put('baselineSteps', steps);
  }

  int getBaselineSteps() {
    return _box.get('baselineSteps', defaultValue: 0);
  }

  void saveLastDate(String date) {
    _box.put('lastDate', date);
  }

  String getLastDate() {
    return _box.get('lastDate', defaultValue: '');
  }

  void saveLastCoinStep(int steps) {
    _box.put('lastCoinStep', steps);
  }

  int getLastCoinStep() {
    return _box.get('lastCoinStep', defaultValue: 0);
  }

  void saveHardwareBaseline(int steps) {
    _box.put('hardwareBaseline', steps);
  }

  int getHardwareBaseline() {
    return _box.get('hardwareBaseline', defaultValue: 0);
  }

  List<String> getPurchasedThemes() {
    final data = _box.get(
      'purchasedThemes',
      defaultValue: ['default_dark', 'default_light'],
    );
    return List<String>.from(data);
  }

  void savePurchasedThemes(List<String> themes) {
    _box.put('purchasedThemes', themes);
  }

  String getActiveTheme() {
    final val = _box.get('activeTheme', defaultValue: 'default_dark');
    if (val == 'default') return 'default_dark';
    return val;
  }

  void saveActiveTheme(String themeId) {
    _box.put('activeTheme', themeId);
  }

  int getMonthlyHighScore() {
    return _box.get('monthlyHighScore', defaultValue: 0);
  }

  void saveMonthlyHighScore(int score) {
    _box.put('monthlyHighScore', score);
  }

  int getSavedMonth() {
    return _box.get('savedMonth', defaultValue: 0);
  }

  void saveSavedMonth(int month) {
    _box.put('savedMonth', month);
  }

  int getStepOffset() {
    return _box.get('stepOffset', defaultValue: 0);
  }

  void saveStepOffset(int offset) {
    _box.put('stepOffset', offset);
  }

  bool getGoalNotified() {
    return _box.get('goalNotified', defaultValue: false);
  }

  void saveGoalNotified(bool value) {
    _box.put('goalNotified', value);
  }

  // Day (yyyy-MM-dd) the goal congrats screen was last shown.
  String getGoalCelebratedDate() {
    return _box.get('goalCelebratedDate', defaultValue: '');
  }

  void saveGoalCelebratedDate(String date) {
    _box.put('goalCelebratedDate', date);
  }

  bool getBatteryPromptShown() {
    return _box.get('batteryPromptShown', defaultValue: false);
  }

  void saveBatteryPromptShown(bool value) {
    _box.put('batteryPromptShown', value);
  }

  // The one-time message about Restricted battery use (see
  // showBackgroundAccessPromptIfNeeded).
  bool getBackgroundAccessPromptShown() =>
      _box.get('backgroundAccessPromptShown', defaultValue: false);

  void saveBackgroundAccessPromptShown(bool value) =>
      _box.put('backgroundAccessPromptShown', value);

  String getWeeklySteps() {
    final data = _box.get('weeklySteps');
    if (data == null || data is! String) {
      return '0,0,0,0,0,0,0';
    }
    return data;
  }

  void saveWeeklySteps(String data) {
    _box.put('weeklySteps', data);
  }

  /// Rebuilds the week of [now] from the daily history (see calendarWeek)
  /// and saves it. Call after saving today's steps to the history.
  List<int> refreshWeeklySteps(DateTime now) {
    final week = calendarWeek(getDailyHistory(), now);
    saveWeeklySteps(week.join(','));
    return week;
  }

  // Date (yyyy-MM-dd) to steps for the last 31 days, kept by step_history.dart.
  Map<String, int> getDailyHistory() {
    try {
      final decoded = jsonDecode(_box.get('dailyHistory', defaultValue: '{}'));
      return {
        for (final entry in (decoded as Map<String, dynamic>).entries)
          if (entry.value is num) entry.key: (entry.value as num).toInt(),
      };
    } catch (_) {
      return {};
    }
  }

  void saveDailyHistory(Map<String, int> history) {
    _box.put('dailyHistory', jsonEncode(history));
  }

  void saveStepGoal(int goal) {
    _box.put('stepGoal', goal);
  }

  int getStepGoal() {
    return _box.get('stepGoal', defaultValue: 10000);
  }

  bool getHealthSupported() {
    return _box.get('healthSupported', defaultValue: true);
  }

  void saveHealthSupported(bool supported) {
    _box.put('healthSupported', supported);
  }

  // Steps of today already added to challenges, and steps from an earlier day
  // still waiting to be added (see settleChallengeSteps).
  int getChallengeCreditedSteps() =>
      _box.get('challengeCreditedSteps', defaultValue: 0);

  void saveChallengeCreditedSteps(int steps) =>
      _box.put('challengeCreditedSteps', steps);

  int getChallengePendingSteps() =>
      _box.get('challengePendingSteps', defaultValue: 0);

  void saveChallengePendingSteps(int steps) =>
      _box.put('challengePendingSteps', steps);

  /// Resets today's counters for a new day [date] (yyyy-MM-dd). Both the app
  /// and the background task call this.
  void startNewDay(String date) {
    saveLastDate(date);
    saveSteps(0);
    saveLastCoinStep(0);
    saveGoalNotified(false);
    saveDrivingStepsToday(0);
    // Also drops last week's days when the week changed.
    refreshWeeklySteps(DateTime.parse(date));
  }

  // Drives already folded into the hardware baseline, so a drive the native
  // side has not deleted yet is not removed twice (see resolveTodaySteps).
  List<int> getAppliedDriveIds() =>
      List<int>.from(_box.get('appliedDriveIds', defaultValue: const <int>[]));

  /// Records the drives [result] folded into the saved baseline and adds
  /// their steps to today's driving steps. Call after any new-day reset and
  /// after saving the baseline; delete the drives natively afterwards.
  void markDrivesApplied(StepCounterResult result) {
    if (result.appliedDriveIds.isEmpty) return;
    _box.put(
      'appliedDriveIds',
      rememberAppliedDrives(getAppliedDriveIds(), result.appliedDriveIds),
    );
    saveDrivingStepsToday(getDrivingStepsToday() + result.drivingSteps);
  }

  /// Steps removed today because they were counted in a vehicle.
  int getDrivingStepsToday() => _box.get('drivingStepsToday', defaultValue: 0);

  void saveDrivingStepsToday(int steps) => _box.put('drivingStepsToday', steps);

  ActivityLog getActivityLog() =>
      ActivityLog.fromJson(_box.get('activityLog', defaultValue: '{}'));

  /// Adds a sync that saved [todaySteps] at [now] to the activity log, with
  /// the [rides] it looked at. The app, the background task and the goal ad
  /// call this.
  void logStepSync(
    int todaySteps,
    DateTime now,
    CheckSource source, {
    List<RideSteps> rides = const [],
  }) {
    final log = getActivityLog().record(
      now: now,
      todaySteps: todaySteps,
      source: source,
      rides: rides,
    );
    _box.put('activityLog', log.toJson());
    _box.put('lastSyncMs', now.millisecondsSinceEpoch);
  }

  /// When the steps were last saved; null before the first save.
  DateTime? getLastSyncAt() => switch (_box.get('lastSyncMs')) {
    final int ms => DateTime.fromMillisecondsSinceEpoch(ms),
    _ => null,
  };

  /// On a new day, before [startNewDay]: adds the [steps] taken after the
  /// last sync, before the end of its day, to that day (see
  /// StepCounterResult.earlierDaySteps). Updates its total, coins, history
  /// and activity log, as a sync at the end of that day would have.
  void addStepsToLastDay(int steps, CheckSource source) {
    final lastSync = getLastSyncAt();
    if (steps <= 0 || lastSync == null) return;
    final total = getSteps() + steps;
    saveSteps(total);

    final lastCoinStep = getLastCoinStep();
    if (total >= lastCoinStep + 100) {
      final coins = (total - lastCoinStep) ~/ 100;
      saveCoins(getCoins() + coins);
      saveLastCoinStep(lastCoinStep + coins * 100);
    }

    // The week is rebuilt from this history by the startNewDay that follows.
    saveDailyHistory({...getDailyHistory(), dateKey(lastSync): total});

    final endOfDay = DateTime(
      lastSync.year,
      lastSync.month,
      lastSync.day + 1,
    ).subtract(const Duration(milliseconds: 1));
    final log = getActivityLog().record(
      now: endOfDay,
      todaySteps: total,
      source: source,
    );
    _box.put('activityLog', log.toJson());
  }

  /// Rewarded ads left today (see [adsLeftToday]).
  int rewardedAdsLeft(RewardedAdKind kind, DateTime now) => adsLeftToday(
    kind,
    storedDate: _box.get('rewardedAdDate', defaultValue: ''),
    watched: _box.get('rewardedAds_${kind.name}', defaultValue: 0),
    today: now,
  );

  /// Counts one watched rewarded ad of [kind] for the day of [now]; the
  /// counts of an earlier day are dropped.
  void recordRewardedAd(RewardedAdKind kind, DateTime now) {
    final today = dateKey(now);
    if (_box.get('rewardedAdDate', defaultValue: '') != today) {
      _box.put('rewardedAdDate', today);
      for (final k in RewardedAdKind.values) {
        _box.put('rewardedAds_${k.name}', 0);
      }
    }
    final key = 'rewardedAds_${kind.name}';
    _box.put(key, _box.get(key, defaultValue: 0) + 1);
  }

  /// Uid of the account the saved data belongs to; null on a fresh install
  /// and on data saved before this was stored.
  String? getDataOwner() => _box.get('dataOwner') as String?;

  void saveDataOwner(String uid) {
    _box.put('dataOwner', uid);
  }

  /// Clears the account's data. What belongs to the phone, not the account,
  /// is kept: today's rewarded ad counts (signing out and in again must not
  /// give more ads) and the review prompt's counts (see AppReviewService).
  Future<void> clearAllUserData() async {
    final phoneKeys = [
      'rewardedAdDate',
      for (final kind in RewardedAdKind.values) 'rewardedAds_${kind.name}',
      AppReviewService.launchCountKey,
      AppReviewService.firstOpenKey,
      AppReviewService.lastAskedKey,
    ];
    final kept = {
      for (final key in phoneKeys)
        if (_box.containsKey(key)) key: _box.get(key),
    };
    await _box.clear();
    await _box.putAll(kept);
  }

  String getChallengeData() {
    return _box.get('challenge_data', defaultValue: '{}');
  }

  void saveChallengeData(String data) {
    _box.put('challenge_data', data);
  }
}
