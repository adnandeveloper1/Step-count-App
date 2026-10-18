import 'dart:async';

import 'package:build_up/core/services/account_session.dart';
import 'package:build_up/core/services/local_storage_service.dart';
import 'package:build_up/core/utils/local_data_state.dart';
import 'package:build_up/features/auth/presentation/providers/account_data_provider.dart';
import 'package:build_up/features/auth/presentation/screens/account_data_gate.dart';
import 'package:build_up/features/step_tracking/presentation/providers/step_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStorage extends LocalStorageService {
  _FakeStorage({this.owner, this.lastDate = ''});

  String? owner;
  String lastDate;
  bool cleared = false;

  @override
  String? getDataOwner() => owner;

  @override
  void saveDataOwner(String uid) => owner = uid;

  @override
  String getLastDate() => lastDate;

  @override
  Future<void> clearAllUserData() async {
    cleared = true;
    owner = null;
    lastDate = '';
  }
}

void main() {
  group('localDataState', () {
    test('data saved for this account is ready', () {
      expect(
        localDataState(owner: 'a', uid: 'a', hasLocalData: true),
        LocalDataState.ready,
      );
    });

    test(
      'data from before the owner was stored is taken as this account\'s',
      () {
        expect(
          localDataState(owner: null, uid: 'a', hasLocalData: true),
          LocalDataState.adopt,
        );
      },
    );

    test('a fresh install loads the account from Firebase', () {
      expect(
        localDataState(owner: null, uid: 'a', hasLocalData: false),
        LocalDataState.restore,
      );
    });

    test('another account\'s data is replaced', () {
      expect(
        localDataState(owner: 'b', uid: 'a', hasLocalData: true),
        LocalDataState.restore,
      );
    });
  });

  group('accountDataProvider', () {
    late _FakeStorage storage;
    late int restores;
    late Completer<void> restore;

    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          storageProvider.overrideWithValue(storage),
          accountRestoreProvider.overrideWithValue(() {
            restores++;
            return restore.future;
          }),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    Future<void> load(ProviderContainer c) {
      final sub = c.listen(accountDataProvider('a'), (_, _) {});
      addTearDown(sub.close);
      return c.read(accountDataProvider('a').future);
    }

    setUp(() {
      restores = 0;
      restore = Completer<void>();
    });

    test(
      'a fresh install waits for the Firebase load before it is ready',
      () async {
        storage = _FakeStorage();
        final c = container();
        final sub = c.listen(accountDataProvider('a'), (_, _) {});
        addTearDown(sub.close);

        await pumpEventQueue();
        expect(restores, 1);
        expect(c.read(accountDataProvider('a')).isLoading, isTrue);
        expect(storage.owner, isNull);

        restore.complete();
        await c.read(accountDataProvider('a').future);
        expect(storage.owner, 'a');
      },
    );

    test(
      'a failed load is an error and does not mark the data as loaded',
      () async {
        storage = _FakeStorage();
        final c = container();
        final sub = c.listen(accountDataProvider('a'), (_, _) {});
        addTearDown(sub.close);

        restore.completeError(Exception('offline'));
        await expectLater(
          c.read(accountDataProvider('a').future),
          throwsException,
        );
        expect(storage.owner, isNull);
      },
    );

    test('this account\'s saved data needs no load', () async {
      storage = _FakeStorage(owner: 'a', lastDate: '2026-10-18');
      await load(container());
      expect(restores, 0);
    });

    test('data from an older app version is kept without a load', () async {
      storage = _FakeStorage(lastDate: '2026-10-18');
      await load(container());
      expect(restores, 0);
      expect(storage.owner, 'a');
    });

    test('another account\'s data is cleared before the load', () async {
      storage = _FakeStorage(owner: 'b', lastDate: '2026-10-18');
      restore.complete();
      await load(container());
      expect(storage.cleared, isTrue);
      expect(restores, 1);
      expect(storage.owner, 'a');
    });

    test(
      'a sign-out during the load does not mark the data as loaded',
      () async {
        storage = _FakeStorage();
        final c = container();
        final sub = c.listen(accountDataProvider('a'), (_, _) {});
        addTearDown(sub.close);
        await pumpEventQueue();

        AccountSession.end();
        restore.complete();
        await c.read(accountDataProvider('a').future);
        expect(storage.owner, isNull);
      },
    );
  });

  group('AccountDataGate', () {
    const home = Key('home');

    Future<void> pump(
      WidgetTester tester,
      Future<void> Function() restore,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageProvider.overrideWithValue(_FakeStorage()),
            accountRestoreProvider.overrideWithValue(restore),
          ],
          child: const MaterialApp(
            home: AccountDataGate(
              uid: 'a',
              child: SizedBox(key: home),
            ),
          ),
        ),
      );
    }

    testWidgets('shows the home screen only after the account loaded', (
      tester,
    ) async {
      final restore = Completer<void>();
      await pump(tester, () => restore.future);
      await tester.pump();
      expect(find.byKey(const Key('accountData.loading')), findsOneWidget);
      expect(find.byKey(home), findsNothing);

      restore.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(home), findsOneWidget);
    });

    testWidgets('a failed load offers Try again, which loads again', (
      tester,
    ) async {
      var tries = 0;
      await pump(tester, () async {
        if (++tries == 1) throw Exception('offline');
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('accountData.error')), findsOneWidget);
      expect(find.byKey(home), findsNothing);

      await tester.tap(find.byKey(const Key('accountData.retry')));
      await tester.pumpAndSettle();
      expect(tries, 2);
      expect(find.byKey(home), findsOneWidget);
    });
  });
}
