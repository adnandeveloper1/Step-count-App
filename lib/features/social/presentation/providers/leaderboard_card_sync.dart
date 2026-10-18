import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../models/leaderboard_card.dart';

/// Keeps [uid]'s public card (see leaderboardCard) in step with their own
/// `users/{uid}` profile while they are signed in. Every change the app
/// makes there (the high-score transaction, step syncs, edit profile, the
/// store, account creation) reaches the card this way, and a user who
/// updated from a version without cards gets one on their first open.
///
/// Mirrors the server copy of the profile, never local storage, so a fresh
/// install that hasn't restored the account yet can't publish zeros.
final leaderboardCardSyncProvider = Provider.autoDispose.family<void, String>((
  ref,
  uid,
) {
  final firestore = ref.watch(firestoreProvider);
  final card = firestore.collection(leaderboardCollection).doc(uid);
  Map<String, Object>? written;
  final subscription = firestore
      .collection('users')
      .doc(uid)
      .snapshots()
      .listen(
        (doc) {
          final profile = doc.data();
          if (profile == null) return;
          final next = leaderboardCard(profile, now: DateTime.now());
          if (written != null && sameLeaderboardCard(written!, next)) return;
          written = next;
          card.set(next).catchError((Object e) {
            // Written again on the next profile change.
            if (identical(written, next)) written = null;
            debugPrint('Leaderboard card sync failed: $e');
          });
        },
        onError: (Object e) => debugPrint('Leaderboard card listen failed: $e'),
      );
  ref.onDispose(subscription.cancel);
});
