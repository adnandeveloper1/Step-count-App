import 'dart:async';

import 'package:build_up/core/services/account_session.dart';
import 'package:build_up/core/services/local_storage_service.dart';
import 'package:build_up/features/auth/data/account_deletion_cloud.dart';
import 'package:build_up/features/auth/presentation/providers/auth_provider.dart';
import 'package:build_up/features/step_tracking/presentation/providers/step_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

class _FakeStorage extends LocalStorageService {
  bool cleared = false;

  @override
  Future<void> init() async {}

  @override
  Future<void> clearAllUserData() async => cleared = true;
}

/// Records every call in order. Each step throws [errors]' next entry for
/// it, if there is one.
class _FakeCloud implements AccountDeletionCloud {
  _FakeCloud(this.signInMethod);

  @override
  final SignInMethod? signInMethod;

  final calls = <String>[];
  final errors = <String, List<Object>>{};
  // Whether step and coin syncs were held off during each call.
  final syncsHeld = <String, bool>{};
  bool googleChosen = true;

  Future<void> _run(String call) async {
    calls.add(call);
    syncsHeld[call] = AccountSession.deleting;
    final queued = errors[call];
    if (queued != null && queued.isNotEmpty) throw queued.removeAt(0);
  }

  void failNext(String call, Object error) => (errors[call] ??= []).add(error);

  @override
  Future<void> reauthenticateWithPassword(String password) =>
      _run('password:$password');

  @override
  Future<bool> reauthenticateWithGoogle() async {
    await _run('google');
    return googleChosen;
  }

  @override
  Future<void> deleteData() => _run('deleteData');

  @override
  Future<void> deleteUser() => _run('deleteUser');

  @override
  Future<void> revokeGoogle() => _run('revokeGoogle');

  @override
  Future<void> signOut() => _run('signOut');
}

class _FakeAuth extends Fake implements FirebaseAuth {}

class _FakeFirestore extends Fake implements FirebaseFirestore {}

class _FakeGoogleSignIn extends Fake implements GoogleSignIn {}

FirebaseAuthException _authError(String code) =>
    FirebaseAuthException(code: code);

void main() {
  late _FakeStorage storage;
  late _FakeCloud cloud;
  late List<String?> passwords;
  late int passwordPrompts;

  AuthController controller() {
    final c = ProviderContainer(
      overrides: [
        firebaseAuthProvider.overrideWithValue(_FakeAuth()),
        firestoreProvider.overrideWithValue(_FakeFirestore()),
        googleSignInProvider.overrideWithValue(_FakeGoogleSignIn()),
        storageProvider.overrideWithValue(storage),
        accountDeletionCloudProvider.overrideWithValue(cloud),
      ],
    );
    addTearDown(c.dispose);
    return c.read(authControllerProvider);
  }

  Future<DeleteAccountResult> delete() => controller().deleteAccount(
    askPassword: () async {
      passwordPrompts++;
      return passwords.isEmpty ? null : passwords.removeAt(0);
    },
  );

  setUp(() {
    storage = _FakeStorage();
    passwords = [];
    passwordPrompts = 0;
  });

  group('step and coin syncs during a deletion', () {
    // A sync between deleting the data and deleting the sign-in would write
    // the profile, and through it the public Step Race card, back.
    test(
      'are held off from the data deletion until the sign-in is gone',
      () async {
        cloud = _FakeCloud(SignInMethod.email);
        passwords = ['pw'];

        expect(await delete(), DeleteAccountResult.deleted);

        expect(cloud.syncsHeld['password:pw'], isFalse);
        expect(cloud.syncsHeld['deleteData'], isTrue);
        expect(cloud.syncsHeld['deleteUser'], isTrue);
        expect(AccountSession.deleting, isFalse);
      },
    );

    test('resume when the deletion stops halfway', () async {
      cloud = _FakeCloud(SignInMethod.guest)
        ..failNext('deleteUser', _authError('network-request-failed'));

      expect(await delete(), DeleteAccountResult.unfinished);
      expect(AccountSession.deleting, isFalse);
    });

    test('resume when nothing could be deleted', () async {
      cloud = _FakeCloud(SignInMethod.guest)
        ..failNext('deleteData', Exception('offline'));

      expect(await delete(), DeleteAccountResult.failed);
      expect(AccountSession.deleting, isFalse);
    });
  });

  group('a guest', () {
    setUp(() => cloud = _FakeCloud(SignInMethod.guest));

    test('is deleted without confirming who they are', () async {
      final session = AccountSession.current;

      expect(await delete(), DeleteAccountResult.deleted);

      expect(cloud.calls, ['deleteData', 'deleteUser']);
      expect(passwordPrompts, 0);
      expect(storage.cleared, isTrue);
      expect(AccountSession.current, isNot(session));
    });

    test(
      'whose sign-in can\'t be deleted is signed out once the data is gone',
      () async {
        // A guest can't sign in again, so nobody can reach the account.
        cloud.failNext('deleteUser', _authError('requires-recent-login'));

        expect(await delete(), DeleteAccountResult.deleted);

        expect(cloud.calls, ['deleteData', 'deleteUser', 'signOut']);
        expect(storage.cleared, isTrue);
      },
    );
  });

  group('an email account', () {
    setUp(() => cloud = _FakeCloud(SignInMethod.email));

    test('confirms the password before anything is deleted', () async {
      passwords = ['secret'];

      expect(await delete(), DeleteAccountResult.deleted);

      expect(cloud.calls, ['password:secret', 'deleteData', 'deleteUser']);
      expect(storage.cleared, isTrue);
    });

    test('closing the password prompt deletes nothing', () async {
      expect(await delete(), DeleteAccountResult.cancelled);

      expect(cloud.calls, isEmpty);
      expect(storage.cleared, isFalse);
    });

    for (final code in ['wrong-password', 'invalid-credential']) {
      test('a wrong password ($code) deletes nothing', () async {
        passwords = ['nope'];
        cloud.failNext('password:nope', _authError(code));

        expect(await delete(), DeleteAccountResult.wrongPassword);

        expect(cloud.calls, ['password:nope']);
        expect(storage.cleared, isFalse);
      });
    }

    test('too many tries deletes nothing', () async {
      passwords = ['nope'];
      cloud.failNext('password:nope', _authError('too-many-requests'));

      expect(await delete(), DeleteAccountResult.tooManyAttempts);
      expect(cloud.calls, ['password:nope']);
    });

    test('offline while confirming deletes nothing', () async {
      passwords = ['secret'];
      cloud.failNext('password:secret', _authError('network-request-failed'));

      expect(await delete(), DeleteAccountResult.offline);
      expect(cloud.calls, ['password:secret']);
    });

    test(
      'asks for the password again when the sign-in still needs it',
      () async {
        passwords = ['secret', 'secret'];
        cloud.failNext('deleteUser', _authError('requires-recent-login'));

        expect(await delete(), DeleteAccountResult.deleted);

        expect(cloud.calls, [
          'password:secret',
          'deleteData',
          'deleteUser',
          'password:secret',
          'deleteUser',
        ]);
        expect(storage.cleared, isTrue);
      },
    );

    test('closing the second prompt leaves the sign-in, and says so', () async {
      passwords = ['secret'];
      cloud.failNext('deleteUser', _authError('requires-recent-login'));

      expect(await delete(), DeleteAccountResult.unfinished);

      expect(cloud.calls, ['password:secret', 'deleteData', 'deleteUser']);
      expect(storage.cleared, isFalse);
    });
  });

  group('a Google account', () {
    setUp(() => cloud = _FakeCloud(SignInMethod.google));

    test(
      'confirms the Google account, then revokes the app\'s access',
      () async {
        expect(await delete(), DeleteAccountResult.deleted);

        expect(cloud.calls, [
          'google',
          'deleteData',
          'deleteUser',
          'revokeGoogle',
        ]);
        expect(passwordPrompts, 0);
        expect(storage.cleared, isTrue);
      },
    );

    test('closing the account picker deletes nothing', () async {
      cloud.googleChosen = false;

      expect(await delete(), DeleteAccountResult.cancelled);
      expect(cloud.calls, ['google']);
    });

    test('picking another Google account deletes nothing', () async {
      cloud.failNext('google', _authError('user-mismatch'));

      expect(await delete(), DeleteAccountResult.wrongGoogleAccount);
      expect(cloud.calls, ['google']);
    });

    test('a failed revoke still finishes the deletion', () async {
      cloud.failNext('revokeGoogle', Exception('no network'));

      expect(await delete(), DeleteAccountResult.deleted);
      expect(storage.cleared, isTrue);
    });
  });

  group('when the data can\'t be deleted', () {
    setUp(() => cloud = _FakeCloud(SignInMethod.guest));

    test('offline before anything was deleted, nothing is', () async {
      cloud.failNext(
        'deleteData',
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );

      expect(await delete(), DeleteAccountResult.offline);

      expect(cloud.calls, ['deleteData']);
      expect(storage.cleared, isFalse);
    });

    test('a slow server before anything was deleted is offline', () async {
      cloud.failNext('deleteData', TimeoutException('read'));

      expect(await delete(), DeleteAccountResult.offline);
      expect(cloud.calls, ['deleteData']);
    });

    test('a stop midway says some data may be gone', () async {
      cloud.failNext('deleteData', const DataDeletionInterrupted('commit'));

      expect(await delete(), DeleteAccountResult.unfinished);

      expect(cloud.calls, ['deleteData']);
      expect(storage.cleared, isFalse);
    });

    test('any other error deletes nothing', () async {
      cloud.failNext(
        'deleteData',
        FirebaseException(plugin: 'cloud_firestore', code: 'internal'),
      );

      expect(await delete(), DeleteAccountResult.failed);
      expect(storage.cleared, isFalse);
    });
  });

  test('a sign-in that can\'t be deleted after the data says so', () async {
    cloud = _FakeCloud(SignInMethod.google);
    cloud.failNext('deleteUser', _authError('network-request-failed'));

    expect(await delete(), DeleteAccountResult.unfinished);

    expect(cloud.calls, ['google', 'deleteData', 'deleteUser']);
    expect(storage.cleared, isFalse);
  });

  test('nobody signed in is a failure', () async {
    cloud = _FakeCloud(null);

    expect(await delete(), DeleteAccountResult.failed);
    expect(cloud.calls, isEmpty);
  });
}
