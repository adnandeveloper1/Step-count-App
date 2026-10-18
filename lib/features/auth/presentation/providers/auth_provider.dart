import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart' as g_sign_in;
import '../../../../core/services/account_session.dart';
import '../../data/account_deletion_cloud.dart';
import '../../../shop/presentation/providers/theme_provider.dart';
import '../../../social/presentation/providers/challenge_provider.dart'
    show challengeProvider;
import '../../../step_tracking/presentation/providers/step_provider.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final googleSignInProvider = Provider<g_sign_in.GoogleSignIn>((ref) {
  return g_sign_in.GoogleSignIn.instance;
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final userProfileProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);

  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.data());
});

/// How [AuthController.deleteAccount] ended.
enum DeleteAccountResult {
  deleted,

  /// The user closed the password prompt or Google picker first.
  cancelled,

  // Nothing was deleted:
  wrongPassword,
  wrongGoogleAccount,
  tooManyAttempts,
  offline,
  failed,

  /// Some or all of the data was deleted, but the sign-in remains. Trying
  /// again finishes it.
  unfinished,
}

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
    ref.watch(googleSignInProvider),
    ref,
  );
});

class AuthController {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final g_sign_in.GoogleSignIn _googleSignIn;
  final Ref _ref;

  AuthController(this._auth, this._firestore, this._googleSignIn, this._ref);

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signInAnonymously() async {
    final userCredential = await _auth.signInAnonymously();
    final user = userCredential.user;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        await _firestore.collection('users').doc(user.uid).set({
          'name': 'Guest User',
          'monthlyHighScore': 0,
          'avatarUrl': '👤',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final g_sign_in.GoogleSignInAccount googleUser = await _googleSignIn
          .authenticate();

      final g_sign_in.GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: null,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (!doc.exists) {
          await _firestore.collection('users').doc(user.uid).set({
            'name': user.displayName ?? 'Google User',
            'monthlyHighScore': 0,
            'avatarUrl': '🌟',
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signUp(String email, String password, String name) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = userCredential.user;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({
        'name': name,
        'monthlyHighScore': 0,
        'avatarUrl': '🙂',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await user.updateDisplayName(name);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _clearLocalData();
  }

  /// Permanently deletes the signed-in account: confirms who the user is
  /// (guests can't), deletes their Firestore data, then their sign-in, then
  /// clears the phone like [signOut]. [askPassword] returns null when the
  /// user closes the prompt.
  Future<DeleteAccountResult> deleteAccount({
    required Future<String?> Function() askPassword,
  }) async {
    final cloud = _ref.read(accountDeletionCloudProvider);
    final method = cloud.signInMethod;
    if (method == null) return DeleteAccountResult.failed;

    // Nothing is deleted until the data deletion starts.
    try {
      if (!await _confirmIdentity(cloud, method, askPassword)) {
        return DeleteAccountResult.cancelled;
      }
      // Drops in-flight step and coin syncs, so they can't write the
      // profile back while it is deleted.
      AccountSession.end();
      await cloud.deleteData();
    } on DataDeletionInterrupted catch (e) {
      debugPrint('Account data deletion stopped: $e');
      return DeleteAccountResult.unfinished;
    } catch (e) {
      debugPrint('Account deletion failed: $e');
      return _deletionFailure(e, method);
    }

    // The data is gone, so from here a failure leaves the sign-in behind.
    try {
      if (!await _deleteSignIn(cloud, method, askPassword)) {
        return DeleteAccountResult.unfinished;
      }
    } catch (e) {
      debugPrint('Sign-in deletion failed: $e');
      return DeleteAccountResult.unfinished;
    }

    if (method == SignInMethod.google) {
      try {
        await cloud.revokeGoogle();
      } catch (e) {
        debugPrint('Google revoke failed: $e');
      }
    }
    await _clearLocalData();
    return DeleteAccountResult.deleted;
  }

  /// Firebase deletes a sign-in only after a recent sign-in, so this runs
  /// before any data is deleted rather than after it. Returns false when the
  /// user closes the prompt or picker.
  Future<bool> _confirmIdentity(
    AccountDeletionCloud cloud,
    SignInMethod method,
    Future<String?> Function() askPassword,
  ) async {
    switch (method) {
      case SignInMethod.guest:
        return true;
      case SignInMethod.google:
        return cloud.reauthenticateWithGoogle();
      case SignInMethod.email:
        final password = await askPassword();
        if (password == null) return false;
        await cloud.reauthenticateWithPassword(password);
        return true;
    }
  }

  /// Returns false when the user closes the second prompt.
  Future<bool> _deleteSignIn(
    AccountDeletionCloud cloud,
    SignInMethod method,
    Future<String?> Function() askPassword,
  ) async {
    try {
      await cloud.deleteUser();
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login') rethrow;
      // A guest can't sign in again, so once signed out nobody can reach
      // the empty account.
      if (method == SignInMethod.guest) {
        await cloud.signOut();
        return true;
      }
      if (!await _confirmIdentity(cloud, method, askPassword)) return false;
      await cloud.deleteUser();
    }
    return true;
  }

  DeleteAccountResult _deletionFailure(Object e, SignInMethod method) {
    return switch (e) {
      FirebaseAuthException(code: 'wrong-password' || 'invalid-credential')
          when method == SignInMethod.email =>
        DeleteAccountResult.wrongPassword,
      FirebaseAuthException(code: 'user-mismatch') =>
        DeleteAccountResult.wrongGoogleAccount,
      FirebaseAuthException(code: 'too-many-requests') =>
        DeleteAccountResult.tooManyAttempts,
      FirebaseException(code: 'network-request-failed' || 'unavailable') ||
      TimeoutException() => DeleteAccountResult.offline,
      _ => DeleteAccountResult.failed,
    };
  }

  /// Drops the account's data from the phone and from memory.
  Future<void> _clearLocalData() async {
    // Drop the signed-out account's in-memory steps, coins and challenges and
    // stop the step poll first, so nothing writes them back after the clear.
    AccountSession.end();
    _resetUserState();
    try {
      final storage = _ref.read(storageProvider);
      await storage.init();
      await storage.clearAllUserData();
    } catch (_) {}
    // Anything rebuilt while clearing re-reads the now empty storage.
    _resetUserState();
  }

  void _resetUserState() {
    _ref.invalidate(stepNotifierProvider);
    _ref.invalidate(challengeProvider);
    // Back to the free themes; the next account's come back when it loads.
    _ref.invalidate(themeProvider);
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
