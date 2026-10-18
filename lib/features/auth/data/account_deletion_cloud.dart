import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../social/models/leaderboard_card.dart';

/// How the signed-in account signs in, which decides how it confirms who
/// it is before it is deleted.
enum SignInMethod { guest, email, google }

/// Thrown by [AccountDeletionCloud.deleteData] once some deletes may have
/// reached the server, so part of the data may already be gone.
class DataDeletionInterrupted implements Exception {
  const DataDeletionInterrupted(this.cause);

  final Object cause;

  @override
  String toString() => 'DataDeletionInterrupted: $cause';
}

/// The Firebase calls that delete the signed-in account. Replaced in tests.
class AccountDeletionCloud {
  /// Offline, Firestore keeps writes and never completes them, so each
  /// step gives up after this.
  static const _timeout = Duration(seconds: 20);

  /// Firestore allows 500 writes per batch.
  static const _batchSize = 450;

  User? get _user => FirebaseAuth.instance.currentUser;

  /// Null when nobody is signed in.
  SignInMethod? get signInMethod {
    final user = _user;
    if (user == null) return null;
    if (user.isAnonymous) return SignInMethod.guest;
    final providers = user.providerData.map((p) => p.providerId);
    if (providers.contains(GoogleAuthProvider.PROVIDER_ID)) {
      return SignInMethod.google;
    }
    return SignInMethod.email;
  }

  Future<void> reauthenticateWithPassword(String password) async {
    final user = _user!;
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: user.email!, password: password),
    );
  }

  /// Returns false when the user closes the account picker.
  Future<bool> reauthenticateWithGoogle() async {
    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      rethrow;
    }
    await _user!.reauthenticateWithCredential(
      GoogleAuthProvider.credential(idToken: account.authentication.idToken),
    );
    return true;
  }

  /// Deletes `users/{uid}` with its `routes` and the public Step Race card.
  ///
  /// Reads the routes from the server first, so offline it throws before
  /// anything is deleted. After that, a failure throws
  /// [DataDeletionInterrupted]. The profile and card go last, in one batch,
  /// so a stop midway leaves the account usable for another try.
  Future<void> deleteData() async {
    final uid = _user!.uid;
    final firestore = FirebaseFirestore.instance;
    final profile = firestore.collection('users').doc(uid);
    final routes = await profile
        .collection('routes')
        .get(const GetOptions(source: Source.server))
        .timeout(_timeout);
    try {
      for (var i = 0; i < routes.docs.length; i += _batchSize) {
        final batch = firestore.batch();
        for (final doc in routes.docs.skip(i).take(_batchSize)) {
          batch.delete(doc.reference);
        }
        await batch.commit().timeout(_timeout);
      }
      await (firestore.batch()
            ..delete(profile)
            ..delete(firestore.collection(leaderboardCollection).doc(uid)))
          .commit()
          .timeout(_timeout);
    } catch (e) {
      throw DataDeletionInterrupted(e);
    }
  }

  Future<void> deleteUser() => _user!.delete();

  /// Removes Build Up from the Google account's connected apps.
  Future<void> revokeGoogle() => GoogleSignIn.instance.disconnect();

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('Google sign-out failed: $e');
    }
  }
}

final accountDeletionCloudProvider = Provider<AccountDeletionCloud>(
  (ref) => AccountDeletionCloud(),
);
