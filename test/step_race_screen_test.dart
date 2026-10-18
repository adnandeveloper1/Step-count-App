import 'package:build_up/features/auth/presentation/providers/auth_provider.dart';
import 'package:build_up/features/social/presentation/providers/leaderboard_provider.dart';
import 'package:build_up/features/social/presentation/screens/social_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _FakeUser implements User {
  _FakeUser(this.uid);

  @override
  final String uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

LeaderboardUser _user(String id, int score, {int today = 0}) => LeaderboardUser(
  id: id,
  name: 'User $id',
  totalSteps: 0,
  monthlyHighScore: score,
  avatarUrl: '',
  todaySteps: today,
);

Future<void> _pump(
  WidgetTester tester, {
  required List<LeaderboardUser> month,
  List<LeaderboardUser> today = const [],
  String? myId,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith(
          (ref) => Stream.value(myId == null ? null : _FakeUser(myId)),
        ),
        leaderboardProvider(
          LeaderboardPeriod.month,
        ).overrideWith((ref) => Stream.value(month)),
        leaderboardProvider(
          LeaderboardPeriod.today,
        ).overrideWith((ref) => Stream.value(today)),
      ],
      child: const MaterialApp(home: ChallengeScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

final _rankCard = find.byKey(const Key('step-race-rank-card'));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('rank card first, then everyone as ranked rows', (tester) async {
    await _pump(
      tester,
      month: [
        _user('a', 10000),
        _user('me', 5475),
        _user('c', 900),
        _user('d', 0),
        _user('e', 0),
      ],
      myId: 'me',
    );

    expect(_rankCard, findsOneWidget);
    expect(find.descendant(of: _rankCard, matching: find.text('#2')), findsOne);
    expect(find.text('4,526 STEPS TO PASS USER A'), findsOneWidget);

    for (final id in ['a', 'me', 'c', 'd', 'e']) {
      expect(find.byKey(Key('leaderboard-row-$id')), findsOneWidget);
    }
    expect(find.text('You'), findsOneWidget);
    expect(find.text('10,000'), findsOneWidget);

    // Tied scores share 4th.
    for (final id in ['d', 'e']) {
      final rank = tester.widget<Text>(find.byKey(Key('leaderboard-rank-$id')));
      expect(rank.data, '4');
    }

    expect(find.textContaining('Resets in'), findsOneWidget);
    expect(find.text('Race your friends'), findsOneWidget);
  });

  testWidgets('the rank card sits above the list', (tester) async {
    await _pump(tester, month: [_user('a', 500), _user('me', 100)], myId: 'me');

    final cardY = tester.getTopLeft(_rankCard).dy;
    final firstRowY = tester
        .getTopLeft(find.byKey(const Key('leaderboard-row-a')))
        .dy;
    expect(cardY, lessThan(firstRowY));
  });

  testWidgets('Today tab ranks by today\'s steps', (tester) async {
    await _pump(
      tester,
      month: [_user('a', 10000)],
      today: [_user('z', 10000, today: 4321), _user('me', 0, today: 1000)],
      myId: 'me',
    );

    await tester.tap(find.byKey(const Key('leaderboard-tab-today')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('leaderboard-row-z')), findsOneWidget);
    expect(find.byKey(const Key('leaderboard-row-a')), findsNothing);
    expect(find.text('4,321'), findsOneWidget);
    expect(find.text('3,322 STEPS TO PASS USER Z'), findsOneWidget);
    expect(find.text('Steps so far today · Resets at midnight'), findsOne);
  });

  testWidgets('empty board explains itself, no rank card, still invites', (
    tester,
  ) async {
    await _pump(tester, month: const [], myId: 'me');

    expect(find.text('No scores this month yet.'), findsOneWidget);
    expect(_rankCard, findsNothing);
    expect(find.text('Race your friends'), findsOneWidget);
  });

  final twenty = [for (var i = 0; i < 20; i++) _user('u$i', 20000 - i * 500)];

  testWidgets('far down the board: rank card shows your place at the top', (
    tester,
  ) async {
    await _pump(tester, month: twenty, myId: 'u15');

    expect(
      find.descendant(of: _rankCard, matching: find.text('#16')),
      findsOne,
    );
    expect(find.text('501 STEPS TO PASS USER U14'), findsOneWidget);
  });

  testWidgets('leader sees the lead message', (tester) async {
    await _pump(tester, month: twenty, myId: 'u0');

    expect(find.text('YOU ARE IN THE LEAD'), findsOneWidget);
  });

  testWidgets('not in the top 50: dashes and no You row', (tester) async {
    await _pump(tester, month: twenty, myId: 'someone-else');

    expect(find.descendant(of: _rankCard, matching: find.text('--')), findsOne);
    expect(find.text('You'), findsNothing);
  });

  testWidgets('load error shows the error line, no rank card', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(_FakeUser('me')),
          ),
          leaderboardProvider(LeaderboardPeriod.month).overrideWith(
            (ref) => Stream<List<LeaderboardUser>>.error(Exception('offline')),
          ),
        ],
        child: const MaterialApp(home: ChallengeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Error loading leaderboard'), findsOneWidget);
    expect(_rankCard, findsNothing);
  });

  testWidgets('while loading shows a spinner, no rank card', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(_FakeUser('me')),
          ),
          leaderboardProvider(
            LeaderboardPeriod.month,
          ).overrideWith((ref) => const Stream<List<LeaderboardUser>>.empty()),
        ],
        child: const MaterialApp(home: ChallengeScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(_rankCard, findsNothing);
  });

  testWidgets('switching tabs updates the rank card to that board', (
    tester,
  ) async {
    await _pump(
      tester,
      month: [_user('a', 9000), _user('me', 5000)],
      today: [_user('me', 5000, today: 3000), _user('a', 9000, today: 100)],
      myId: 'me',
    );
    expect(find.descendant(of: _rankCard, matching: find.text('#2')), findsOne);

    await tester.tap(find.byKey(const Key('leaderboard-tab-today')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: _rankCard, matching: find.text('#1')), findsOne);
    expect(find.text('YOU ARE IN THE LEAD'), findsOneWidget);

    await tester.tap(find.byKey(const Key('leaderboard-tab-month')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: _rankCard, matching: find.text('#2')), findsOne);
  });

  testWidgets('signed out: dashes, list still shows', (tester) async {
    await _pump(tester, month: twenty);

    expect(find.text('WALK MORE TO JOIN THE RACE'), findsOneWidget);
    expect(find.byKey(const Key('leaderboard-row-u0')), findsOneWidget);
  });
}
