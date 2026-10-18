import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/activity_log.dart';
import '../../../../core/utils/monthly_best.dart' as monthly;

import '../../models/leaderboard_card.dart';

class LeaderboardUser {
  final String id;
  final String name;
  final int monthlyHighScore;
  final String avatarUrl;
  final String? currentLeague;
  final bool showsProAvatar;

  /// False when [monthlyHighScore] is from an earlier month: the user hasn't
  /// walked since, so they are left out of this month's race.
  final bool bestIsThisMonth;

  /// Steps for today, from the card's `daySteps`. 0 when the user hasn't
  /// synced today.
  final int todaySteps;

  LeaderboardUser({
    required this.id,
    required this.name,
    required this.monthlyHighScore,
    required this.avatarUrl,
    this.currentLeague,
    this.todaySteps = 0,
    this.showsProAvatar = false,
    this.bestIsThisMonth = true,
  });

  int scoreFor(LeaderboardPeriod period) => switch (period) {
    LeaderboardPeriod.month => monthlyHighScore,
    LeaderboardPeriod.today => todaySteps,
  };

  /// A `leaderboard/{uid}` card (see leaderboardCard).
  factory LeaderboardUser.fromCard(
    String id,
    Map<String, dynamic> card, {
    required DateTime now,
  }) {
    final days = card['daySteps'] as Map?;
    final today = days?[dayKey(now)];
    return LeaderboardUser(
      id: id,
      name: card['name'] as String? ?? defaultLeaderboardName,
      monthlyHighScore: (card['monthlyHighScore'] as num?)?.toInt() ?? 0,
      avatarUrl: card['avatarUrl'] as String? ?? '',
      currentLeague: card['currentLeague'] as String?,
      todaySteps: today is num ? today.toInt() : 0,
      showsProAvatar: card['proAvatar'] == true,
      bestIsThisMonth: monthly.bestIsThisMonth(
        month: card['monthlyHighScoreMonth'] as String?,
        now: now,
      ),
    );
  }
}

/// [users] without those whose best is from an earlier month.
List<LeaderboardUser> monthRace(List<LeaderboardUser> users) =>
    users.where((u) => u.bestIsThisMonth).toList();

/// Which score the Step Race ranks by.
enum LeaderboardPeriod {
  /// Best single day this month (`monthlyHighScore`).
  month,

  /// Steps so far today (`daySteps.<today>`).
  today,
}

/// Top 50 users for [LeaderboardPeriod], highest score first, updating live.
/// Reads the public cards, never other users' profiles.
final leaderboardProvider =
    StreamProvider.family<List<LeaderboardUser>, LeaderboardPeriod>((
      ref,
      period,
    ) {
      final now = DateTime.now();
      final cards = FirebaseFirestore.instance.collection(
        leaderboardCollection,
      );
      final query = switch (period) {
        LeaderboardPeriod.month => cards.orderBy(
          'monthlyHighScore',
          descending: true,
        ),
        LeaderboardPeriod.today => cards.orderBy(
          FieldPath(['daySteps', dayKey(now)]),
          descending: true,
        ),
      };
      return query.limit(50).snapshots().map((snapshot) {
        final users = snapshot.docs
            .map(
              (doc) => LeaderboardUser.fromCard(doc.id, doc.data(), now: now),
            )
            .toList();
        return period == LeaderboardPeriod.month ? monthRace(users) : users;
      });
    });

/// Leaderboard positions for [users], who must already be sorted by
/// [period]'s score, highest first. Equal scores share a position and the
/// next score skips ahead (100, 80, 80, 50 → 1, 2, 2, 4).
List<int> leaderboardRanks(
  List<LeaderboardUser> users, [
  LeaderboardPeriod period = LeaderboardPeriod.month,
]) {
  final ranks = <int>[];
  for (var i = 0; i < users.length; i++) {
    final tied =
        i > 0 && users[i].scoreFor(period) == users[i - 1].scoreFor(period);
    ranks.add(tied ? ranks[i - 1] : i + 1);
  }
  return ranks;
}

/// Whole days left before the monthly leaderboard resets on the 1st
/// (counting today), e.g. 18 on 14 October.
int daysUntilMonthlyReset(DateTime now) {
  // UTC so a daylight-saving change in between can't shave off a day.
  final nextMonth = DateTime.utc(now.year, now.month + 1);
  final today = DateTime.utc(now.year, now.month, now.day);
  return nextMonth.difference(today).inDays;
}

/// 10000 → "10,000".
String formatSteps(int steps) {
  final digits = steps.abs().toString();
  final out = StringBuffer(steps < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}
