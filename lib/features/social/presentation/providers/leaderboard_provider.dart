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

/// One Step Race board as the screen shows it: [users] sorted by [period]'s
/// score, highest first, and their shared [ranks].
class StepRaceBoard {
  final List<LeaderboardUser> users;
  final List<int> ranks;
  final LeaderboardPeriod period;

  const StepRaceBoard._(this.users, this.ranks, this.period);

  /// Sorts [users] by [period]'s score itself instead of trusting the query
  /// order: the Today query picks its day when it subscribes, so after
  /// midnight its order can follow yesterday while scores show today. Equal
  /// scores keep their incoming order.
  factory StepRaceBoard.from(
    List<LeaderboardUser> users,
    LeaderboardPeriod period,
  ) {
    final order = List<int>.generate(users.length, (i) => i)
      ..sort((a, b) {
        final byScore = users[b]
            .scoreFor(period)
            .compareTo(users[a].scoreFor(period));
        return byScore != 0 ? byScore : a.compareTo(b);
      });
    final sorted = [for (final i in order) users[i]];
    return StepRaceBoard._(sorted, leaderboardRanks(sorted, period), period);
  }

  bool get isEmpty => users.isEmpty;
  int get length => users.length;
}

/// Where the signed-in user stands on a [StepRaceBoard].
class StepRaceStanding {
  /// False when nobody is signed in.
  final bool isSignedIn;

  /// Shared position (ties share it), or null when the user isn't on the
  /// board: signed out, or outside the top 50.
  final int? rank;

  /// The user's score, or null when they aren't on the board.
  final int? score;

  /// Steps needed to get past the nearest walker with a higher score
  /// (always at least 2: one to draw level, one to pass). Null when nobody
  /// is ahead.
  final int? stepsToPass;
  final String? aheadName;

  /// Share of the way to [aheadName]'s score, 0 to 1.
  final double progress;

  /// Someone else has the same score as the user.
  final bool isTied;

  const StepRaceStanding({
    required this.isSignedIn,
    required this.rank,
    required this.score,
    required this.stepsToPass,
    required this.aheadName,
    required this.progress,
    required this.isTied,
  });

  bool get isRanked => rank != null;
  bool get isLeader => isRanked && stepsToPass == null;

  factory StepRaceStanding.from(StepRaceBoard board, String? myId) {
    final users = board.users;
    final myIndex = myId == null ? -1 : users.indexWhere((u) => u.id == myId);
    if (myIndex < 0) {
      return StepRaceStanding(
        isSignedIn: myId != null,
        rank: null,
        score: null,
        stepsToPass: null,
        aheadName: null,
        progress: 0,
        isTied: false,
      );
    }

    final period = board.period;
    final score = users[myIndex].scoreFor(period);
    final isTied = [
      for (var i = 0; i < users.length; i++)
        if (i != myIndex) users[i].scoreFor(period),
    ].contains(score);

    LeaderboardUser? ahead;
    for (var i = myIndex - 1; i >= 0; i--) {
      if (users[i].scoreFor(period) > score) {
        ahead = users[i];
        break;
      }
    }
    final aheadScore = ahead?.scoreFor(period);
    return StepRaceStanding(
      isSignedIn: true,
      rank: board.ranks[myIndex],
      score: score,
      stepsToPass: aheadScore == null ? null : aheadScore - score + 1,
      aheadName: ahead?.name,
      progress: aheadScore == null ? 1 : (score / aheadScore).clamp(0.0, 1.0),
      isTied: isTied,
    );
  }
}
