import 'dart:async';

import 'package:build_up/core/services/account_session.dart';
import 'package:build_up/core/services/local_storage_service.dart';
import 'package:build_up/core/utils/local_data_state.dart';
import 'package:build_up/features/auth/presentation/providers/account_data_provider.dart';
import 'package:build_up/features/auth/presentation/screens/account_data_gate.dart';
import 'package:build_up/features/shop/data/shop_cloud.dart';
import 'package:build_up/features/shop/presentation/providers/theme_provider.dart';
import 'package:build_up/features/step_tracking/presentation/providers/step_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStorage extends LocalStorageService {
  _FakeStorage({this.owner, this.lastDate = '', List<String>? purchased})
    : purchased = purchased ?? ['default_dark', 'default_light'];

  String? owner;
  String lastDate;
  bool cleared = false;
  List<String> purchased;
  String active = 'default_dark';

  @override
  List<String> getPurchasedThemes() => List.of(purchased);

  @override
  void savePurchasedThemes(List<String> themes) => purchased = List.of(themes);

  @override
  String getActiveTheme() => active;

  @override
  void saveActiveTheme(String themeId) => active = themeId;

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
    purchased = ['default_dark', 'default_light'];
    active = 'default_dark';
  }
}

class _FakeShopCloud implements ShopCloud {
  @override
  bool get isSignedIn => true;

  final backups = <List<String>>[];

  @override
  Future<void> backUpThemes(List<String> owned) async => backups.add(owned);

  @override
  Future<void> saveThemePurchase(String themeId) async {}

  @override
  Future<void> saveActiveTheme(String themeId) async {}

  @override
  Future<void> buyItem(String itemId) async {}

  @override
  Future<void> setProAvatarEquipped(bool equipped) async {}
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
    late _FakeShopCloud cloud;

    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          storageProvider.overrideWithValue(storage),
          shopCloudProvider.overrideWithValue(cloud),
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
      cloud = _FakeShopCloud();
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

    test(
      'themes bought before they were saved to the account are backed up',
      () async {
        storage = _FakeStorage(
          owner: 'a',
          lastDate: '2026-10-18',
          purchased: ['default_dark', 'default_light', 'ocean_wave'],
        )..active = 'ocean_wave';
        await load(container());

        // Only the themes: the equipped one may differ between phones, and a
        // start on one must not change the other's.
        expect(cloud.backups.single, ['ocean_wave']);
      },
    );

    test('themes on older app versions\' data are backed up too', () async {
      storage = _FakeStorage(
        lastDate: '2026-10-18',
        purchased: ['default_dark', 'default_light', 'sunset_glow'],
      );
      await load(container());

      expect(cloud.backups.single, ['sunset_glow']);
    });

    test('nothing is backed up with only the free themes', () async {
      storage = _FakeStorage(owner: 'a', lastDate: '2026-10-18');
      await load(container());

      expect(cloud.backups, isEmpty);
    });

    test('the theme screen shows the themes the load brought back', () async {
      storage = _FakeStorage();
      final c = container();
      // The theme state is read before the load, as the app does.
      expect(
        c.read(themeProvider).purchasedThemeIds,
        isNot(contains('ocean_wave')),
      );

      storage.purchased = ['default_dark', 'default_light', 'ocean_wave'];
      storage.active = 'ocean_wave';
      restore.complete();
      await load(c);

      expect(c.read(themeProvider).purchasedThemeIds, contains('ocean_wave'));
      expect(c.read(themeProvider).activeThemeId, 'ocean_wave');
    });
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
            shopCloudProvider.overrideWithValue(_FakeShopCloud()),
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
