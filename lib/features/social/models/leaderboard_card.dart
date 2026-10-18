// A user's public Step Race card, `leaderboard/{uid}`. Other phones read
// these instead of `users/{uid}`, which holds private data (weight, height,
// body fat, coins, challenge progress) and is readable only by its owner.
// The card is rebuilt from the owner's profile, so it never holds more than
// the race shows. Keep in sync with firestore.rules and the
// mirrorLeaderboardCard Cloud Function in docs/leaderboard-privacy.md.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/utils/activity_log.dart';
import '../../../core/utils/monthly_best.dart';
import '../../shop/models/pro_avatar_item.dart' as pro_avatar;

const leaderboardCollection = 'leaderboard';

/// Every field a card may have; the security rules allow only these.
const leaderboardCardFields = [
  'name',
  'avatarUrl',
  'monthlyHighScore',
  'monthlyHighScoreMonth',
  'currentLeague',
  'proAvatar',
  'daySteps',
];

const defaultLeaderboardName = 'Anonymous Walker';

/// The card for [profile], a `users/{uid}` document. `daySteps` holds only
/// today's steps, keyed by day, so the today race can order by
/// `daySteps.<today>` and skips users who haven't walked today.
Map<String, Object> leaderboardCard(
  Map<String, dynamic> profile, {
  required DateTime now,
}) {
  final today = dayKey(now);
  final history = profile['dailyHistory'];
  final todaySteps = history is Map ? history[today] : null;
  final month =
      profile['monthlyHighScoreMonth'] as String? ??
      switch (profile['lastUpdated']) {
        Timestamp t => monthKey(t.toDate()),
        _ => null,
      };
  final league = profile['currentLeague'] as String?;
  return {
    'name': profile['name'] as String? ?? defaultLeaderboardName,
    'avatarUrl': profile['avatarUrl'] as String? ?? '',
    'monthlyHighScore': (profile['monthlyHighScore'] as num?)?.toInt() ?? 0,
    'monthlyHighScoreMonth': ?month,
    'currentLeague': ?league,
    'proAvatar': pro_avatar.showsProAvatar(profile),
    'daySteps': <String, int>{if (todaySteps is num) today: todaySteps.toInt()},
  };
}

/// Update for a card whose only known change is today's steps (the
/// background sync). Replaces the whole map, so older days drop out.
Map<String, Object> leaderboardDaySteps(
  int todaySteps, {
  required DateTime now,
}) => {
  'daySteps': {dayKey(now): todaySteps},
};

/// Whether two cards from [leaderboardCard] hold the same values, so an
/// unchanged card isn't written again.
bool sameLeaderboardCard(Map<String, Object> a, Map<String, Object> b) =>
    mapEquals({...a, 'daySteps': null}, {...b, 'daySteps': null}) &&
    mapEquals(a['daySteps'] as Map?, b['daySteps'] as Map?);
