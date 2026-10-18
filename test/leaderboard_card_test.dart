import 'package:build_up/features/social/models/leaderboard_card.dart';
import 'package:build_up/features/social/presentation/providers/leaderboard_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 18, 9);

  group('leaderboardCard', () {
    test('copies only what the Step Race shows', () {
      final card = leaderboardCard({
        'name': 'Moiz',
        'avatarUrl': '🌟',
        'monthlyHighScore': 5475,
        'monthlyHighScoreMonth': '2026-10',
        'currentLeague': 'gold',
        'unlockedItems': ['avatar_pro'],
        'proAvatarEquipped': true,
        'dailyHistory': {'2026-10-17': 8000, '2026-10-18': 1942},
        // Private fields that must never reach the card.
        'weight': 82.5,
        'height': 180.0,
        'bodyFat': 18.0,
        'currentCoins': 1200,
        'weeklySteps': [1, 2, 3, 4, 5, 6, 7],
        'challengeProgress': {'c1': 300},
        'stepGoal': 10000,
      }, now: now);

      expect(card, {
        'name': 'Moiz',
        'avatarUrl': '🌟',
        'monthlyHighScore': 5475,
        'monthlyHighScoreMonth': '2026-10',
        'currentLeague': 'gold',
        'proAvatar': true,
        'daySteps': {'2026-10-18': 1942},
      });
    });

    test('keys are exactly the ones the security rules allow', () {
      final card = leaderboardCard({
        'monthlyHighScore': 1,
        'monthlyHighScoreMonth': '2026-10',
        'currentLeague': 'bronze',
      }, now: now);
      expect(card.keys.toSet(), leaderboardCardFields.toSet());
    });

    test('a new account gets a card with defaults', () {
      final card = leaderboardCard({
        'name': 'Guest User',
        'monthlyHighScore': 0,
        'avatarUrl': '👤',
      }, now: now);
      expect(card, {
        'name': 'Guest User',
        'avatarUrl': '👤',
        'monthlyHighScore': 0,
        'proAvatar': false,
        'daySteps': <String, int>{},
      });
    });

    test('an empty profile still gives a valid card', () {
      expect(leaderboardCard({}, now: now), {
        'name': 'Anonymous Walker',
        'avatarUrl': '',
        'monthlyHighScore': 0,
        'proAvatar': false,
        'daySteps': <String, int>{},
      });
    });

    test('the pro frame shows only when owned and not unequipped', () {
      bool pro(Map<String, dynamic> p) =>
          leaderboardCard(p, now: now)['proAvatar'] as bool;
      expect(
        pro({
          'unlockedItems': ['avatar_pro'],
        }),
        isTrue,
      );
      expect(
        pro({
          'unlockedItems': ['avatar_pro'],
          'proAvatarEquipped': false,
        }),
        isFalse,
      );
      expect(pro({'proAvatarEquipped': true}), isFalse);
    });

    test('an untagged best takes its month from the last update', () {
      final card = leaderboardCard({
        'monthlyHighScore': 9000,
        'lastUpdated': Timestamp.fromDate(DateTime(2026, 9, 30, 22)),
      }, now: now);
      expect(card['monthlyHighScoreMonth'], '2026-09');
    });

    test("a day other than today is not today's steps", () {
      final card = leaderboardCard({
        'dailyHistory': {'2026-10-17': 8000},
      }, now: now);
      expect(card['daySteps'], <String, int>{});
    });

    test('a double step count is stored as a whole number', () {
      final card = leaderboardCard({
        'monthlyHighScore': 5475.0,
        'dailyHistory': {'2026-10-18': 1942.0},
      }, now: now);
      expect(card['monthlyHighScore'], 5475);
      expect(card['daySteps'], {'2026-10-18': 1942});
    });
  });

  group('sameLeaderboardCard', () {
    final base = {
      'name': 'Moiz',
      'monthlyHighScore': 10,
      'dailyHistory': {'2026-10-18': 5},
    };

    test('equal cards are the same, so nothing is rewritten', () {
      expect(
        sameLeaderboardCard(
          leaderboardCard(base, now: now),
          leaderboardCard({...base, 'weight': 90.0}, now: now),
        ),
        isTrue,
      );
    });

    test("a change to today's steps is a different card", () {
      expect(
        sameLeaderboardCard(
          leaderboardCard(base, now: now),
          leaderboardCard({
            ...base,
            'dailyHistory': {'2026-10-18': 6},
          }, now: now),
        ),
        isFalse,
      );
    });

    test('a change to the name is a different card', () {
      expect(
        sameLeaderboardCard(
          leaderboardCard(base, now: now),
          leaderboardCard({...base, 'name': 'Rao'}, now: now),
        ),
        isFalse,
      );
    });
  });

  test("leaderboardDaySteps replaces the day map with today's steps", () {
    expect(leaderboardDaySteps(1942, now: now), {
      'daySteps': {'2026-10-18': 1942},
    });
  });

  group('LeaderboardUser.fromCard', () {
    test('reads back what leaderboardCard wrote', () {
      final user = LeaderboardUser.fromCard(
        'u1',
        leaderboardCard({
          'name': 'Moiz',
          'avatarUrl': '🌟',
          'monthlyHighScore': 5475,
          'monthlyHighScoreMonth': '2026-10',
          'currentLeague': 'gold',
          'unlockedItems': ['avatar_pro'],
          'dailyHistory': {'2026-10-18': 1942},
        }, now: now),
        now: now,
      );
      expect(user.id, 'u1');
      expect(user.name, 'Moiz');
      expect(user.avatarUrl, '🌟');
      expect(user.monthlyHighScore, 5475);
      expect(user.currentLeague, 'gold');
      expect(user.showsProAvatar, isTrue);
      expect(user.todaySteps, 1942);
      expect(user.bestIsThisMonth, isTrue);
    });

    test("a best from last month is not this month's", () {
      final user = LeaderboardUser.fromCard('u1', {
        'monthlyHighScore': 9000,
        'monthlyHighScoreMonth': '2026-09',
      }, now: now);
      expect(user.bestIsThisMonth, isFalse);
    });

    test("yesterday's steps are not today's", () {
      final user = LeaderboardUser.fromCard('u1', {
        'daySteps': {'2026-10-17': 8000},
      }, now: now);
      expect(user.todaySteps, 0);
    });

    test('missing fields fall back to defaults', () {
      final user = LeaderboardUser.fromCard('u1', {}, now: now);
      expect(user.name, 'Anonymous Walker');
      expect(user.avatarUrl, '');
      expect(user.monthlyHighScore, 0);
      expect(user.currentLeague, isNull);
      expect(user.showsProAvatar, isFalse);
      expect(user.todaySteps, 0);
      expect(user.bestIsThisMonth, isTrue);
    });
  });
}
