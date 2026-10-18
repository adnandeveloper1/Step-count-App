import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/account_session.dart';
import '../../../../core/utils/local_data_state.dart';
import '../../../shop/data/shop_cloud.dart';
import '../../../shop/models/owned_themes.dart';
import '../../../shop/presentation/providers/theme_provider.dart';
import '../../../social/presentation/providers/challenge_provider.dart'
    show challengeProvider;
import '../../../step_tracking/presentation/providers/step_provider.dart';

/// Loads the signed-in account from Firebase onto the phone. Throws when it
/// can't be read. Replaced in tests.
final accountRestoreProvider = Provider<Future<void> Function()>(
  (ref) => ref.read(stepNotifierProvider.notifier).restoreDataFromFirebase,
);

/// Completes once the phone holds [uid]'s data. The home screen waits for
/// it, so no step, coin or score sync can run on an empty fresh install.
/// Disposed at sign-out, so signing in again checks the cleared storage.
final accountDataProvider = FutureProvider.autoDispose.family<void, String>(
  (ref, uid) async {
    final storage = ref.read(storageProvider);
    final state = localDataState(
      owner: storage.getDataOwner(),
      uid: uid,
      hasLocalData: storage.getLastDate().isNotEmpty,
    );
    switch (state) {
      case LocalDataState.ready:
        _backUpThemes(ref);
        return;
      case LocalDataState.adopt:
        storage.saveDataOwner(uid);
        _backUpThemes(ref);
        return;
      case LocalDataState.restore:
        final session = AccountSession.current;
        if (storage.getDataOwner() != null) {
          await storage.clearAllUserData();
          ref.invalidate(stepNotifierProvider);
          ref.invalidate(challengeProvider);
        }
        await ref.read(accountRestoreProvider)();
        // The load may have brought back bought themes.
        ref.invalidate(themeProvider);
        // Signed out meanwhile: the data was cleared, not loaded.
        if (session == AccountSession.current) storage.saveDataOwner(uid);
    }
  },
  // The screen offers Try again instead.
  retry: (_, _) => null,
);

/// Themes bought before they were saved to the account are only on the
/// phone: adds them to the account (once they are there it changes nothing).
void _backUpThemes(Ref ref) {
  final storage = ref.read(storageProvider);
  final paid = paidThemes(storage.getPurchasedThemes());
  if (paid.isEmpty) return;
  unawaited(ref.read(shopCloudProvider).backUpThemes(paid));
}
