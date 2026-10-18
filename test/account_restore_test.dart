import 'dart:io';
import 'package:build_up/core/services/local_storage_service.dart';
import 'package:build_up/features/step_tracking/data/account_restore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Fails on saving today's steps, like a storage write that throws.
class _FailingStorage extends LocalStorageService {
  @override
  void saveSteps(int steps) => throw const FileSystemException('disk full');
}

void main() {
  late Directory dir;
  final storage = LocalStorageService();
  // Monday 19 Oct 2026.
  final now = DateTime(2026, 10, 19, 9);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hive_account_restore_test');
    Hive.init(dir.path);
    await Hive.openBox('buildUpData');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  test('restores every field of the account', () {
    final restored = restoreAccount(storage, {
      'stepGoal': 12000,
      'height': 182,
      'weight': 77.5,
      'currentCoins': 340,
      'monthlyHighScore': 15000,
      'monthlyHighScoreMonth': '2026-10',
      'lastUpdated': Timestamp.fromDate(DateTime(2026, 10, 18, 22)),
      'dailyHistory': {'2026-10-18': 15000, '2026-10-19': 6400},
    }, now);

    expect(storage.getStepGoal(), 12000);
    expect(storage.getHeight(), 182.0);
    expect(storage.getWeight(), 77.5);
    expect(storage.getCoins(), 340);
    expect(storage.getMonthlyHighScore(), 15000);
    expect(storage.getSteps(), 6400);
    expect(storage.getLastDate(), '2026-10-19');
    expect(storage.getLastCoinStep(), 6400);
    expect(storage.getChallengeCreditedSteps(), 6400);
    expect(restored.todaySteps, 6400);
    expect(restored.goal, 12000);
    expect(restored.coins, 340);
  });

  test('numbers stored as doubles still restore today\'s steps', () {
    // Firestore returns a double for a number written as one, e.g. 12000.0.
    final restored = restoreAccount(storage, {
      'stepGoal': 12000.0,
      'currentCoins': 340.0,
      'weeklySteps': [8000.0, 9000.0, 0, 0, 0, 0, 0],
      'dailyHistory': {'2026-10-19': 6400.0},
    }, now);

    expect(storage.getStepGoal(), 12000);
    expect(storage.getCoins(), 340);
    expect(storage.getSteps(), 6400);
    expect(storage.getLastDate(), '2026-10-19');
    expect(restored.todaySteps, 6400);
  });

  test('a bad field is skipped and the rest restored', () {
    final restored = restoreAccount(storage, {
      'stepGoal': 'ten thousand',
      'height': 'tall',
      'weight': 77.5,
      'currentCoins': null,
      'monthlyHighScore': 15000,
      'monthlyHighScoreMonth': 202610,
      'lastUpdated': '2026-10-18',
      'weeklySteps': 'oops',
      'dailyHistory': {'2026-10-18': 'x', '2026-10-19': 6400},
    }, now);

    expect(storage.getStepGoal(), 10000);
    expect(storage.getHeight(), 170.0);
    expect(storage.getWeight(), 77.5);
    expect(storage.getCoins(), 0);
    expect(storage.getSteps(), 6400);
    expect(storage.getDailyHistory(), {'2026-10-19': 6400});
    expect(restored.goal, 10000);
    expect(restored.height, 170.0);
  });

  test('the week comes from the history, not the cloud\'s weekly array', () {
    // The cloud array was last written on Sunday 18 Oct, last week.
    final restored = restoreAccount(storage, {
      'weeklySteps': [8000, 9000, 12000, 7000, 6000, 5000, 11000],
      'dailyHistory': {'2026-10-18': 11000, '2026-10-19': 2500},
    }, now);

    expect(restored.weekly, [2500, 0, 0, 0, 0, 0, 0]);
    expect(storage.getWeeklySteps(), '2500,0,0,0,0,0,0');
  });

  test('without a count for today the day is left unset', () {
    final restored = restoreAccount(storage, {
      'dailyHistory': {'2026-10-18': 11000},
    }, now);

    expect(restored.todaySteps, 0);
    expect(storage.getLastDate(), '');
  });

  test('lists cloud days older than the 31 day window', () {
    final restored = restoreAccount(storage, {
      'dailyHistory': {'2026-09-01': 5000, '2026-10-19': 100},
    }, now);

    expect(restored.staleCloudDays, ['2026-09-01']);
  });

  test('a failed save reaches the caller before the day is marked', () async {
    expect(
      () => restoreAccount(_FailingStorage(), {
        'dailyHistory': {'2026-10-19': 6400},
      }, now),
      throwsA(isA<FileSystemException>()),
    );
    // Not marked as holding today's data, so Try again restores again
    // instead of adopting the half restore.
    expect(storage.getLastDate(), '');
  });
}
