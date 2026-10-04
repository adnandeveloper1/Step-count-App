import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart' as g_sign_in;
import '../../../../core/services/local_storage_service.dart';
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
    await _ref.read(stepNotifierProvider.notifier).restoreDataFromFirebase();
  }

  Future<void> signInAnonymously() async {
    final userCredential = await _auth.signInAnonymously();
    final user = userCredential.user;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        await _firestore.collection('users').doc(user.uid).set({
          'name': 'Guest User',
          'displayName': 'Guest User',
          'totalSteps': 0,
          'avatarUrl': '👤',
          'isGuest': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  Future<void> signInWithGoogle() async {
    try {

      final g_sign_in.GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();
      if (googleUser == null) return;


      final g_sign_in.GoogleSignInAuthentication googleAuth = await googleUser.authentication;


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
            'displayName': user.displayName ?? 'Google User',
            'totalSteps': 0,
            'avatarUrl': '🌟',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        await _ref.read(stepNotifierProvider.notifier).restoreDataFromFirebase();
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
        'displayName': name,
        'totalSteps': 0,
        'avatarUrl': '🙂',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await user.updateDisplayName(name);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    final storage = LocalStorageService();
    await storage.init();
    await storage.clearAllUserData();
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
