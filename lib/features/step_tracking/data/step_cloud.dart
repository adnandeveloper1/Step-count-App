import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/utils/monthly_best.dart';
import '../../../core/utils/step_history.dart';

/// The step tracker's reads and writes of the signed-in account's
/// `users/{uid}` document. Replaced in tests.
///
/// Writes aren't waited for: offline, Firestore keeps them and only
/// completes them once back online. Each does nothing when nobody is signed
/// in.
class StepCloud {
  User? get _user => FirebaseAuth.instance.currentUser;

  DocumentReference<Map<String, dynamic>>? get _doc {
    final user = _user;
    if (user == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(user.uid);
  }

  bool get isSignedIn => _user != null;

  void _merge(Map<String, dynamic> data) {
    _doc
        ?.set(data, SetOptions(merge: true))
        .catchError((Object e) => debugPrint('Step sync failed: $e'));
  }

  void saveCoins(int coins) => _merge({
    'currentCoins': coins,
    'lastUpdated': FieldValue.serverTimestamp(),
  });

  /// Saves [steps] for [day], with [yesterdaySteps] (steps from just before
  /// midnight can raise it) and the account's coins, week and league.
  void saveDay({
    required DateTime day,
    required int steps,
    required int? yesterdaySteps,
    required int coins,
    required List<int> weekly,
    required String league,
  }) => _merge({
    'currentCoins': coins,
    'weeklySteps': weekly,
    'currentLeague': league,
    'lastUpdated': FieldValue.serverTimestamp(),
    'dailyHistory': {
      dateKey(day): steps,
      dateKey(DateTime(day.year, day.month, day.day - 1)): ?yesterdaySteps,
      // Keep only the last 31 days in the cloud too.
      for (final key in expiredDayKeys(day)) key: FieldValue.delete(),
    },
  });

  void saveBody({required double height, required double weight}) =>
      _merge({'height': height, 'weight': weight});

  void saveGoal(int goal) => _merge({'stepGoal': goal});

  /// Saves this month's best (see mergeMonthlyBest: never lower than the
  /// account's) and [league]. Returns the best saved, or null when the
  /// account document doesn't exist. Throws when it can't be written.
  Future<int?> saveMonthlyBest({
    required int localBest,
    required String league,
    required DateTime now,
  }) async {
    final doc = _doc;
    if (doc == null) return null;
    return FirebaseFirestore.instance.runTransaction((tx) async {
      final data = (await tx.get(doc)).data();
      if (data == null) return null;
      final best = mergeMonthlyBest(
        localBest: localBest,
        remoteBest: (data['monthlyHighScore'] as num?)?.toInt(),
        remoteMonth: data['monthlyHighScoreMonth'] as String?,
        remoteUpdatedAt: (data['lastUpdated'] as Timestamp?)?.toDate(),
        now: now,
      );
      tx.update(doc, {
        'monthlyHighScore': best,
        'monthlyHighScoreMonth': monthKey(now),
        'currentLeague': league,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      return best;
    });
  }

  /// The account document, or null when signed out or it doesn't exist.
  /// Throws when it can't be read (offline with nothing cached).
  Future<Map<String, dynamic>?> load() async {
    final doc = _doc;
    if (doc == null) return null;
    return (await doc.get()).data();
  }

  /// Deletes history [days] older than the 31 day window.
  void deleteHistoryDays(List<String> days) {
    if (days.isEmpty) return;
    _doc
        ?.update({
          for (final key in days)
            FieldPath(['dailyHistory', key]): FieldValue.delete(),
        })
        .catchError((Object e) => debugPrint('History cleanup failed: $e'));
  }
}

final stepCloudProvider = Provider<StepCloud>((ref) => StepCloud());

/// The time the step tracker works with. Replaced in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Asks for, or reads, the activity recognition permission the step sensor
/// needs; true when granted. Replaced in tests.
final activityPermissionProvider = Provider<Future<bool> Function()>(
  (ref) =>
      () async => (await Permission.activityRecognition.request()).isGranted,
);
