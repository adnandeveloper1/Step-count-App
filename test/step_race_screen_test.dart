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

final _myPosition = find.byKey(const Key('leaderboard-my-position'));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('top three go on the podium, the rest are ranked rows', (
    tester,
  ) async {
    await _pump(
      tester,
      month: [
        _user('a', 10000),
        _user('b', 1365),
        _user('c', 900),
        _user('d', 0),
        _user('e', 0),
      ],
    );

    for (final id in ['a', 'b', 'c']) {
      expect(find.byKey(Key('podium-$id')), findsOneWidget);
      expect(find.byKey(Key('leaderboard-rank-$id')), findsNothing);
    }
    expect(find.text('10,000'), findsOneWidget);
    expect(find.text('1,365'), findsOneWidget);

    // Tied scores share 4th.
    for (final id in ['d', 'e']) {
      final badge = find.byKey(Key('leaderboard-rank-$id'));
      expect(find.descendant(of: badge, matching: find.text('4')), findsOne);
    }

    expect(find.textContaining('Resets in'), findsOneWidget);
    expect(find.text('Race your friends'), findsOneWidget);
  });

  testWidgets('fewer than three users still show on the podium', (
    tester,
  ) async {
    await _pump(tester, month: [_user('a', 500)]);

    expect(find.byKey(const Key('podium-a')), findsOneWidget);
    expect(find.text('500'), findsOneWidget);
  });

  testWidgets('Today tab shows today\'s board and its reset line', (
    tester,
  ) async {
    await _pump(
      tester,
      month: [_user('a', 10000)],
      today: [_user('z', 10000, today: 4321)],
    );

    await tester.tap(find.byKey(const Key('leaderboard-tab-today')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('podium-z')), findsOneWidget);
    expect(find.byKey(const Key('podium-a')), findsNothing);
    expect(find.text('4,321'), findsOneWidget);
    expect(find.text('Steps so far today · Resets at midnight'), findsOne);
  });

  testWidgets('empty board explains itself and still offers the invite', (
    tester,
  ) async {
    await _pump(tester, month: const []);

    expect(find.text('No scores this month yet.'), findsOneWidget);
    expect(find.text('Race your friends'), findsOneWidget);
  });

  testWidgets('your position is pinned while your row is off screen', (
    tester,
  ) async {
    final users = [for (var i = 0; i < 20; i++) _user('u$i', 20000 - i * 500)];
    await _pump(tester, month: users, myId: 'u15');

    expect(find.text('YOU'), findsOneWidget);
    expect(_myPosition, findsOneWidget);
    expect(
      find.descendant(of: _myPosition, matching: find.text('16')),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('leaderboard-rank-u15')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(_myPosition, findsNothing);
  });

  final twenty = [for (var i = 0; i < 20; i++) _user('u$i', 20000 - i * 500)];

  testWidgets('no pinned bar when you are on the podium', (tester) async {
    await _pump(tester, month: twenty, myId: 'u0');

    expect(find.text('YOU'), findsOneWidget);
    expect(_myPosition, findsNothing);
  });

  testWidgets('no pinned bar or YOU tag when you are not in the top 50', (
    tester,
  ) async {
    await _pump(tester, month: twenty, myId: 'someone-else');

    expect(find.text('YOU'), findsNothing);
    expect(_myPosition, findsNothing);
  });
}
