import 'dart:io';
import 'package:build_up/core/ads/rewarded_ad_limits.dart';
import 'package:build_up/core/services/app_review_service.dart';
import 'package:build_up/core/services/local_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory dir;
  final storage = LocalStorageService();
  final today = DateTime(2026, 10, 14, 9);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hive_rewarded_ads_test');
    Hive.init(dir.path);
    await Hive.openBox('buildUpData');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  test('all ads are available before any is watched', () {
    expect(storage.rewardedAdsLeft(RewardedAdKind.coins, today), 3);
    expect(storage.rewardedAdsLeft(RewardedAdKind.goal, today), 1);
  });

  test('each kind is counted separately', () {
    storage.recordRewardedAd(RewardedAdKind.coins, today);
    storage.recordRewardedAd(RewardedAdKind.coins, today);

    expect(storage.rewardedAdsLeft(RewardedAdKind.coins, today), 1);
    expect(storage.rewardedAdsLeft(RewardedAdKind.goal, today), 1);
  });

  test('a new day resets both counts', () {
    storage.recordRewardedAd(RewardedAdKind.coins, today);
    storage.recordRewardedAd(RewardedAdKind.goal, today);
    final tomorrow = today.add(const Duration(days: 1));

    expect(storage.rewardedAdsLeft(RewardedAdKind.goal, tomorrow), 1);

    storage.recordRewardedAd(RewardedAdKind.coins, tomorrow);
    expect(storage.rewardedAdsLeft(RewardedAdKind.coins, tomorrow), 2);
    // Yesterday's goal view was dropped, not carried into the new day.
    expect(storage.rewardedAdsLeft(RewardedAdKind.goal, tomorrow), 1);
  });

  test('signing out keeps the review prompt\'s counts', () async {
    // They belong to the phone: clearing them would restart the 5 launches
    // and 3 days, and forget that Play was asked in the last 30 days.
    final box = Hive.box('buildUpData');
    await box.putAll({
      AppReviewService.launchCountKey: 7,
      AppReviewService.firstOpenKey: 1000,
      AppReviewService.lastAskedKey: 2000,
    });

    await storage.clearAllUserData();

    expect(box.get(AppReviewService.launchCountKey), 7);
    expect(box.get(AppReviewService.firstOpenKey), 1000);
    expect(box.get(AppReviewService.lastAskedKey), 2000);
  });

  test('signing out keeps the counts of today', () async {
    for (var i = 0; i < 3; i++) {
      storage.recordRewardedAd(RewardedAdKind.coins, today);
    }
    storage.recordRewardedAd(RewardedAdKind.goal, today);
    storage.saveCoins(250);

    await storage.clearAllUserData();

    // Same phone, same day: signing in again gives no new ads.
    expect(storage.rewardedAdsLeft(RewardedAdKind.coins, today), 0);
    expect(storage.rewardedAdsLeft(RewardedAdKind.goal, today), 0);
    // The account's data is still cleared.
    expect(storage.getCoins(), 0);
  });

  test('a clear before any ad was watched leaves all ads', () async {
    await storage.clearAllUserData();

    expect(storage.rewardedAdsLeft(RewardedAdKind.coins, today), 3);
    expect(storage.rewardedAdsLeft(RewardedAdKind.goal, today), 1);
  });
}
