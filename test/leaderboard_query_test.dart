import 'package:build_up/features/social/models/leaderboard_card.dart';
import 'package:build_up/features/social/presentation/providers/leaderboard_provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Early in the month: last month's bests are still on their cards and are
  // higher than anything walked so far this month.
  final now = DateTime(2026, 10, 2, 9);
  late FakeFirebaseFirestore firestore;

  Future<void> card(String uid, Map<String, Object> fields) => firestore
      .collection(leaderboardCollection)
      .doc(uid)
      .set({'name': uid, 'avatarUrl': '', ...fields});

  setUp(() => firestore = FakeFirebaseFirestore());

  group('month board', () {
    test("last month's high scores outnumbering this month's don't hide this "
        "month's walkers", () async {
      for (var i = 0; i < 60; i++) {
        await card('sep$i', {
          'monthlyHighScore': 20000 + i,
          'monthlyHighScoreMonth': '2026-09',
        });
      }
      await card('ali', {
        'monthlyHighScore': 6200,
        'monthlyHighScoreMonth': '2026-10',
      });
      await card('sara', {
        'monthlyHighScore': 4100,
        'monthlyHighScoreMonth': '2026-10',
      });

      final users = await leaderboardStream(
        firestore,
        LeaderboardPeriod.month,
        now: now,
      ).first;

      expect(users.map((u) => u.id), ['ali', 'sara']);
    });

    test('takes the top 50 of this month, highest first', () async {
      for (var i = 0; i < 55; i++) {
        await card('oct$i', {
          'monthlyHighScore': 1000 + i,
          'monthlyHighScoreMonth': '2026-10',
        });
      }

      final users = await leaderboardStream(
        firestore,
        LeaderboardPeriod.month,
        now: now,
      ).first;

      expect(users, hasLength(50));
      expect(users.first.id, 'oct54');
      expect(users.last.id, 'oct5');
    });

    test('a card without a month is left out', () async {
      await card('old', {'monthlyHighScore': 9000});
      await card('ali', {
        'monthlyHighScore': 6200,
        'monthlyHighScoreMonth': '2026-10',
      });

      final users = await leaderboardStream(
        firestore,
        LeaderboardPeriod.month,
        now: now,
      ).first;

      expect(users.map((u) => u.id), ['ali']);
    });
  });

  group('today board', () {
    test(
      "yesterday's steps outnumbering today's don't hide today's walkers",
      () async {
        for (var i = 0; i < 60; i++) {
          await card('yday$i', {
            'monthlyHighScore': 20000 + i,
            'monthlyHighScoreMonth': '2026-10',
            'daySteps': {'2026-10-01': 20000 + i},
          });
        }
        await card('ali', {
          'monthlyHighScore': 20000,
          'monthlyHighScoreMonth': '2026-10',
          'daySteps': {'2026-10-02': 3100},
        });
        await card('sara', {
          'monthlyHighScore': 20000,
          'monthlyHighScoreMonth': '2026-10',
          'daySteps': {'2026-10-02': 1200},
        });

        final users = await leaderboardStream(
          firestore,
          LeaderboardPeriod.today,
          now: now,
        ).first;

        expect(users.map((u) => u.id), ['ali', 'sara']);
        expect(users.map((u) => u.todaySteps), [3100, 1200]);
      },
    );
  });
}
