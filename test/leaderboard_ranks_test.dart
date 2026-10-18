import 'package:build_up/features/social/presentation/providers/leaderboard_provider.dart';
import 'package:flutter_test/flutter_test.dart';

LeaderboardUser _user(String id, int score, {int today = 0}) => LeaderboardUser(
  id: id,
  name: id,
  monthlyHighScore: score,
  avatarUrl: '',
  todaySteps: today,
);

void main() {
  group('leaderboardRanks', () {
    test('positions follow the score order', () {
      final users = [_user('a', 900), _user('b', 500), _user('c', 100)];
      expect(leaderboardRanks(users), [1, 2, 3]);
    });

    test('equal scores share a position and the next one skips ahead', () {
      final users = [
        _user('a', 10000),
        _user('b', 1365),
        _user('c', 0),
        _user('d', 0),
      ];
      expect(leaderboardRanks(users), [1, 2, 3, 3]);

      final tiedAtTop = [_user('a', 80), _user('b', 80), _user('c', 50)];
      expect(leaderboardRanks(tiedAtTop), [1, 1, 3]);
    });

    test('the today board ranks by today\'s steps, not the monthly best', () {
      final users = [
        _user('a', 9000, today: 400),
        _user('b', 100, today: 400),
        _user('c', 9000, today: 50),
      ];
      expect(leaderboardRanks(users, LeaderboardPeriod.today), [1, 1, 3]);
      expect(leaderboardRanks(users), [1, 2, 3]);
    });

    test('empty leaderboard', () {
      expect(leaderboardRanks(const []), isEmpty);
    });
  });

  group('daysUntilMonthlyReset', () {
    test('counts today up to the 1st of next month', () {
      expect(daysUntilMonthlyReset(DateTime(2026, 10, 14, 10, 30)), 18);
      expect(daysUntilMonthlyReset(DateTime(2026, 10, 31, 23, 59)), 1);
      expect(daysUntilMonthlyReset(DateTime(2026, 10, 1)), 31);
    });

    test('rolls over the year and handles February', () {
      expect(daysUntilMonthlyReset(DateTime(2026, 12, 31)), 1);
      expect(daysUntilMonthlyReset(DateTime(2028, 2, 1)), 29);
    });

    test('a daylight-saving change in the month does not lose a day', () {
      // Europe and the US change clocks in late March and early November.
      expect(daysUntilMonthlyReset(DateTime(2026, 3, 1)), 31);
      expect(daysUntilMonthlyReset(DateTime(2026, 11, 1)), 30);
    });
  });

  group('monthRace', () {
    test('drops users whose best is from an earlier month', () {
      final users = [
        LeaderboardUser.fromCard('old', {
          'monthlyHighScore': 9000,
          'monthlyHighScoreMonth': '2026-09',
        }, now: DateTime(2026, 10, 18)),
        _user('a', 900),
      ];
      expect(monthRace(users).map((u) => u.id), ['a']);
    });
  });

  test('formatSteps groups thousands', () {
    expect(formatSteps(0), '0');
    expect(formatSteps(999), '999');
    expect(formatSteps(1365), '1,365');
    expect(formatSteps(10000), '10,000');
    expect(formatSteps(1234567), '1,234,567');
  });
}
