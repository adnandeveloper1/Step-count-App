import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pro_avatar_item.dart';

/// Saves store purchases to the signed-in account's Firestore document.
///
/// Callers don't wait for these: offline, Firestore keeps the write and only
/// completes it once back online. A failed write is logged. Does nothing when
/// nobody is signed in. Replaced in tests.
class ShopCloud {
  DocumentReference<Map<String, dynamic>>? get _doc {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(user.uid);
  }

  bool get isSignedIn => _doc != null;

  Future<void> _merge(Map<String, dynamic> data) async {
    final doc = _doc;
    if (doc == null) return;
    try {
      await doc.set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Store sync failed: $e');
    }
  }

  /// Adds [themeId] to the account's themes and equips it.
  Future<void> saveThemePurchase(String themeId) => _merge({
    'purchasedThemes': FieldValue.arrayUnion([themeId]),
    'activeTheme': themeId,
  });

  Future<void> saveActiveTheme(String themeId) =>
      _merge({'activeTheme': themeId});

  /// Adds the paid themes in [owned] to the account, for themes bought before
  /// they were saved there. Leaves the equipped theme alone: it runs on
  /// every start, and another phone may have equipped a different one.
  Future<void> backUpThemes(List<String> owned) =>
      _merge({'purchasedThemes': FieldValue.arrayUnion(owned)});

  /// Adds [itemId] to the account's items and shows the Pro Avatar frame.
  Future<void> buyItem(String itemId) => _merge({
    'unlockedItems': FieldValue.arrayUnion([itemId]),
    proAvatarEquippedField: true,
  });

  Future<void> setProAvatarEquipped(bool equipped) =>
      _merge({proAvatarEquippedField: equipped});
}

final shopCloudProvider = Provider<ShopCloud>((ref) => ShopCloud());
