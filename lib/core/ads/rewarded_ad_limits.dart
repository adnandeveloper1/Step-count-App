import '../utils/step_history.dart';

/// Coins given for watching the coin ad (worth 5,000 steps).
const int coinAdReward = 50;

/// The rewarded ads offered in the store.
enum RewardedAdKind {
  /// Gives [coinAdReward] coins.
  coins(dailyLimit: 3),

  /// Fills today's steps up to the step goal.
  goal(dailyLimit: 1);

  final int dailyLimit;

  const RewardedAdKind({required this.dailyLimit});
}

/// Views of [kind] left today, given [watched] views stored for
/// [storedDate] (yyyy-MM-dd). Views from an earlier day don't count.
int adsLeftToday(
  RewardedAdKind kind, {
  required String storedDate,
  required int watched,
  required DateTime today,
}) {
  final usedToday = storedDate == dateKey(today) ? watched : 0;
  final left = kind.dailyLimit - usedToday;
  return left > 0 ? left : 0;
}
