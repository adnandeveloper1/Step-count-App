import 'dart:async';

import 'package:build_up/features/auth/presentation/providers/auth_provider.dart';
import 'package:build_up/features/settings/presentation/delete_account_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _FakeAuthController extends Fake implements AuthController {
  _FakeAuthController(this.result, {this.asksPassword = false});

  final DeleteAccountResult result;
  final bool asksPassword;
  int deletes = 0;
  String? password;
  Completer<void>? hold;

  @override
  Future<DeleteAccountResult> deleteAccount({
    required Future<String?> Function() askPassword,
  }) async {
    deletes++;
    if (asksPassword) {
      password = await askPassword();
      if (password == null) return DeleteAccountResult.cancelled;
    }
    await hold?.future;
    return result;
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late _FakeAuthController auth;

  Future<void> pump(WidgetTester tester, _FakeAuthController controller) async {
    auth = controller;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authControllerProvider.overrideWithValue(controller)],
        child: const MaterialApp(home: Scaffold(body: DeleteAccountTile())),
      ),
    );
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DeleteAccountTile.confirmKey));
    // Not pumpAndSettle: the spinner runs while a password prompt is open.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('asks first, saying it is permanent and what goes', (
    tester,
  ) async {
    await pump(tester, _FakeAuthController(DeleteAccountResult.deleted));

    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();

    expect(find.text('Delete your account?'), findsOneWidget);
    expect(find.textContaining('permanently'), findsOneWidget);
    expect(find.textContaining('can\'t be undone'), findsOneWidget);
    expect(find.textContaining('Step Race'), findsOneWidget);
    expect(find.textContaining('routes'), findsOneWidget);
    expect(find.textContaining('coins'), findsOneWidget);
    expect(auth.deletes, 0);
  });

  testWidgets('Cancel deletes nothing', (tester) async {
    await pump(tester, _FakeAuthController(DeleteAccountResult.deleted));

    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Delete your account?'), findsNothing);
    expect(auth.deletes, 0);
  });

  testWidgets('says when the account was deleted', (tester) async {
    await pump(tester, _FakeAuthController(DeleteAccountResult.deleted));

    await confirm(tester);

    expect(auth.deletes, 1);
    expect(
      find.text(deleteAccountMessage(DeleteAccountResult.deleted)!),
      findsOneWidget,
    );
  });

  testWidgets('shows progress and ignores taps while deleting', (tester) async {
    await pump(tester, _FakeAuthController(DeleteAccountResult.deleted));
    auth.hold = Completer();

    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DeleteAccountTile.confirmKey));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Delete Account'), warnIfMissed: false);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Delete your account?'), findsNothing);

    auth.hold!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(auth.deletes, 1);
  });

  testWidgets('an email account types its password', (tester) async {
    await pump(
      tester,
      _FakeAuthController(DeleteAccountResult.deleted, asksPassword: true),
    );

    await confirm(tester);
    expect(find.text('Enter your password'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'secret');
    await tester.tap(find.byKey(DeleteAccountTile.passwordConfirmKey));
    await tester.pumpAndSettle();

    expect(auth.password, 'secret');
  });

  testWidgets('closing the password prompt says nothing', (tester) async {
    await pump(
      tester,
      _FakeAuthController(DeleteAccountResult.deleted, asksPassword: true),
    );

    await confirm(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(auth.password, isNull);
    expect(find.byType(SnackBar), findsNothing);
  });

  for (final result in [
    DeleteAccountResult.offline,
    DeleteAccountResult.wrongPassword,
    DeleteAccountResult.wrongGoogleAccount,
    DeleteAccountResult.tooManyAttempts,
    DeleteAccountResult.failed,
  ]) {
    testWidgets('${result.name} says the account was not deleted', (
      tester,
    ) async {
      await pump(tester, _FakeAuthController(result));

      await confirm(tester);

      final message = deleteAccountMessage(result)!;
      expect(message, contains('not deleted'));
      expect(find.text(message), findsOneWidget);
    });
  }

  testWidgets('a half-finished deletion is explained in a dialog', (
    tester,
  ) async {
    await pump(tester, _FakeAuthController(DeleteAccountResult.unfinished));

    await confirm(tester);

    expect(find.text('Deleting didn\'t finish'), findsOneWidget);
    expect(
      find.text(deleteAccountMessage(DeleteAccountResult.unfinished)!),
      findsOneWidget,
    );
    expect(
      deleteAccountMessage(DeleteAccountResult.unfinished),
      contains('Delete Account again'),
    );
  });

  test('cancelling has no message', () {
    expect(deleteAccountMessage(DeleteAccountResult.cancelled), isNull);
  });
}
