import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart' as g_sign_in;
import '../../../../core/services/account_session.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../social/presentation/providers/challenge_provider.dart';
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
    // Drop the signed-out account's in-memory steps, coins and challenges and
    // stop the step poll first, so nothing writes them back after the clear.
    AccountSession.end();
    _resetUserState();
    try {
      final storage = LocalStorageService();
      await storage.init();
      await storage.clearAllUserData();
    } catch (_) {}
    // Anything rebuilt while clearing re-reads the now empty storage.
    _resetUserState();
  }

  void _resetUserState() {
    _ref.invalidate(stepNotifierProvider);
    _ref.invalidate(challengeProvider);
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
