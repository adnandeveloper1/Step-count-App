import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/activity_log.dart';

class LeaderboardUser {
  final String id;
  final String name;
  final int totalSteps;
  final int monthlyHighScore;
  final String avatarUrl;
  final String? currentLeague; // New field
  final List<String> unlockedItems;

  /// Steps for today, read from the synced `dailyHistory` map. 0 when the
  /// user hasn't synced today.
  final int todaySteps;

  LeaderboardUser({
    required this.id,
    required this.name,
    required this.totalSteps,
    required this.monthlyHighScore,
    required this.avatarUrl,
    this.currentLeague,
    this.unlockedItems = const [],
    this.todaySteps = 0,
  });

  int scoreFor(LeaderboardPeriod period) => switch (period) {
    LeaderboardPeriod.month => monthlyHighScore,
    LeaderboardPeriod.today => todaySteps,
  };

  factory LeaderboardUser.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final items = data['unlockedItems'] as List<dynamic>?;
    final history = data['dailyHistory'] as Map<String, dynamic>?;
    final today = history?[dayKey(DateTime.now())];
    return LeaderboardUser(
      id: doc.id,
      name: data['name'] ?? 'Anonymous Walker',
      totalSteps: data['totalSteps'] ?? 0,
      monthlyHighScore: data['monthlyHighScore'] ?? 0,
      avatarUrl: data['avatarUrl'] ?? data['photoUrl'] ?? '',
      currentLeague: data['currentLeague'], // Read from Firestore
      unlockedItems: items?.map((e) => e.toString()).toList() ?? [],
      todaySteps: today is num ? today.toInt() : 0,
    );
  }
}

/// Which score the Step Race ranks by.
enum LeaderboardPeriod {
  /// Best single day this month (`monthlyHighScore`).
  month,

  /// Steps so far today (`dailyHistory.<today>`).
  today,
}

/// Top 50 users for [LeaderboardPeriod], highest score first, updating live.
final leaderboardProvider =
    StreamProvider.family<List<LeaderboardUser>, LeaderboardPeriod>((
      ref,
      period,
    ) {
      final users = FirebaseFirestore.instance.collection('users');
      final query = switch (period) {
        LeaderboardPeriod.month => users.orderBy(
          'monthlyHighScore',
          descending: true,
        ),
        LeaderboardPeriod.today => users.orderBy(
          FieldPath(['dailyHistory', dayKey(DateTime.now())]),
          descending: true,
        ),
      };
      return query
          .limit(50)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => LeaderboardUser.fromDocument(doc))
                .toList(),
          );
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
