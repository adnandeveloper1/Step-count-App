import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';

/// Loads and shows one rewarded ad. Completes once the ad is closed: true
/// when the user watched it long enough to earn the reward, false when it
/// was closed early or failed to load or show. Give the reward after this
/// completes, so it lands on the screen the user returns to.
Future<bool> showRewardedAd() {
  final done = Completer<bool>();
  void finish(bool earned) {
    if (!done.isCompleted) done.complete(earned);
  }

  RewardedAd.load(
    adUnitId: AdIds.rewarded,
    request: const AdRequest(),
    rewardedAdLoadCallback: RewardedAdLoadCallback(
      onAdLoaded: (ad) {
        var earned = false;
        ad.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();
            finish(earned);
          },
          onAdFailedToShowFullScreenContent: (ad, _) {
            ad.dispose();
            finish(false);
          },
        );
        ad.show(onUserEarnedReward: (_, _) => earned = true);
      },
      onAdFailedToLoad: (_) => finish(false),
    ),
  );
  return done.future;
}
